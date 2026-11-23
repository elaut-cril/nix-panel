'use strict';

const fs = require('fs');
const path = require('path');
const { execFile } = require('child_process');
const si = require('systeminformation');
const { createProcessSampler } = require('./process-metrics');

const sampleProcesses = createProcessSampler();

function cached(loader, ttl) {
  let value;
  let loadedAt = 0;
  let pending = null;
  return () => {
    if (value !== undefined && Date.now() - loadedAt < ttl) return Promise.resolve(value);
    if (pending) return pending;
    pending = loader().then(result => {
      value = result;
      loadedAt = Date.now();
      return result;
    }).finally(() => {
      pending = null;
    });
    return pending;
  };
}

function hasBinary(name) {
  for (const directory of (process.env.PATH || '/usr/local/bin:/usr/bin:/bin').split(':')) {
    try {
      fs.accessSync(path.join(directory, name), fs.constants.X_OK);
      return true;
    } catch (error) {}
  }
  return false;
}

function execText(command, args, timeout = 2500) {
  return new Promise((resolve, reject) => {
    execFile(command, args, { timeout, maxBuffer: 1024 * 1024, windowsHide: true }, (error, stdout) => {
      if (error) return reject(error);
      resolve(stdout.trim());
    });
  });
}

async function nvidiaGpu() {
  if (!hasBinary('nvidia-smi')) return [];
  try {
    const output = await execText('nvidia-smi', ['--query-gpu=index,name,utilization.gpu,memory.used,memory.total', '--format=csv,noheader,nounits']);
    return output.split('\n').filter(Boolean).map(line => {
      const parts = line.split(', ');
      return {
        index: Number.parseInt(parts[0], 10) || 0,
        name: parts[1] || 'NVIDIA GPU',
        gpuUtil: Number.parseFloat(parts[2]) || 0,
        memUsed: Number.parseFloat(parts[3]) || 0,
        memTotal: Number.parseFloat(parts[4]) || 0
      };
    });
  } catch (error) {
    return [];
  }
}

const gpu = cached(nvidiaGpu, 4000);
const system = cached(async () => {
  const [osInfo, cpuInfo, mem, systemInfo, netIf] = await Promise.all([
    si.osInfo(), si.cpu(), si.mem(), si.system(), si.networkInterfaces()
  ]);
  return {
    hostname: osInfo.hostname,
    platform: osInfo.platform,
    distro: osInfo.distro,
    release: osInfo.release,
    kernel: osInfo.kernel,
    cpu: {
      manufacturer: cpuInfo.manufacturer,
      brand: cpuInfo.brand,
      cores: cpuInfo.cores,
      physicalCores: cpuInfo.physicalCores,
      processors: cpuInfo.processors || 1,
      speed: cpuInfo.speed
    },
    memory: { total: mem.total },
    system: { manufacturer: systemInfo.manufacturer, model: systemInfo.model, version: systemInfo.version },
    network: netIf.map(item => ({ iface: item.iface, ip4: item.ip4, ip6: item.ip6, mac: item.mac, type: item.type, speed: item.speed }))
  };
}, 60000);

const taskManager = cached(async () => {
  const processMetricsPromise = sampleProcesses().catch(() => ({ cpu: new Map(), rssKb: new Map() }));
  const [processes, cpuInfo, currentLoad, mem, diskIO, netStats, gpuInfo] = await Promise.all([
    si.processes(),
    si.cpu(),
    si.currentLoad().catch(() => ({ currentLoad: 0, cpus: [], avgLoad: [0, 0, 0] })),
    si.mem(),
    si.disksIO().catch(() => null),
    si.networkStats().catch(() => []),
    gpu()
  ]);
  const processMetrics = await processMetricsPromise;
  const procList = processes.list.map(item => {
    const rssKb = processMetrics.rssKb.get(item.pid);
    return {
      pid: item.pid,
      name: item.name,
      command: item.command || item.name,
      cpu: processMetrics.cpu.get(item.pid) ?? item.cpu ?? 0,
      mem: rssKb !== undefined && mem.total > 0 ? rssKb * 1024 / mem.total * 100 : item.mem || 0,
      memRss: rssKb ?? item.memRss ?? 0,
      memRssKb: rssKb ?? item.memRss ?? 0,
      user: item.user || 'unknown',
      state: item.state || 'running',
      started: item.started || null
    };
  }).sort((a, b) => b.cpu - a.cpu);
  return {
    processes: procList,
    cpu: {
      cores: cpuInfo.cores,
      physicalCores: cpuInfo.physicalCores,
      processors: cpuInfo.processors || 1,
      currentLoad: currentLoad.currentLoad,
      loadPerCore: currentLoad.cpus ? currentLoad.cpus.map(core => core.load) : [],
      avgLoad: currentLoad.avgLoad || [0, 0, 0]
    },
    memory: {
      total: mem.total,
      used: mem.used,
      active: mem.active,
      available: mem.available,
      swapTotal: mem.swaptotal,
      swapUsed: mem.swapused
    },
    diskIO: diskIO ? { rIO: diskIO.rIO || 0, wIO: diskIO.wIO || 0, rIO_sec: diskIO.rIO_sec || 0, wIO_sec: diskIO.wIO_sec || 0 } : { rIO: 0, wIO: 0, rIO_sec: 0, wIO_sec: 0 },
    network: netStats.map(item => ({ iface: item.iface, rx_sec: item.rx_sec || 0, tx_sec: item.tx_sec || 0, rx: item.rx || 0, tx: item.tx || 0 })),
    gpu: gpuInfo
  };
}, 1500);

async function capabilities() {
  const gpus = await gpu();
  const hasDisplay = ['import', 'xwd', 'grim', 'spectacle'].some(hasBinary);
  return { hasGPU: gpus.length > 0, hasDisplay, gpus };
}

module.exports = { capabilities, system, taskManager };
