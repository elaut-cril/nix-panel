'use strict';
/**
 * NIX Panel — Remote Control (KDE Plasma: X11 и Wayland)
 *
 * Подключение в server.js:
 *   app.use('/api/system/remote', require('./remote')({ checkPerm, config: CONFIG.remote }));
 *
 * Что изменилось по сравнению со старой версией:
 *  - никаких shell-строк и `|| true`: команды запускаются через spawn(args[]), ошибки НЕ глотаются
 *  - всё асинхронно (раньше execSync вешал весь сервер на время скриншота)
 *  - берётся именно активная пользовательская сессия (не greeter SDDM)
 *  - окружение (DISPLAY/XAUTHORITY/WAYLAND_DISPLAY/DBUS) берётся из процесса plasmashell/kwin
 *  - команды выполняются от пользователя сессии (uid/gid), а не через sudo
 *  - скриншоты не накладываются друг на друга (один захват одновременно + короткий кэш)
 *  - ввод: и позиция, и клик — одним запросом; клавиши маппятся в keysym/keycode
 *  - /diagnose показывает, что именно не работает
 */

const express = require('express');
const fs = require('fs');
const os = require('os');
const path = require('path');
const { spawn } = require('child_process');

// ---------------------------------------------------------------- helpers

function hasBin(name) {
  const dirs = (process.env.PATH || '/usr/bin:/bin:/usr/local/bin').split(':');
  for (const d of dirs) {
    try { fs.accessSync(path.join(d, name), fs.constants.X_OK); return true; } catch (e) {}
  }
  return false;
}

/**
 * Запуск без shell. Возвращает { stdout, stderr }, при ненулевом коде — reject с текстом ошибки.
 * ignoreOutput нужен для wl-copy (он форкается и держит pipe открытым).
 */
function run(cmd, args, opts = {}) {
  const { env, uid, gid, timeout = 8000, input, ignoreOutput = false } = opts;
  return new Promise((resolve, reject) => {
    let out = '', err = '', finished = false, child;
    const done = (e, val) => {
      if (finished) return;
      finished = true;
      clearTimeout(timer);
      e ? reject(e) : resolve(val);
    };
    try {
      child = spawn(cmd, args, {
        env, uid, gid, cwd: '/',
        stdio: [input == null ? 'ignore' : 'pipe', ignoreOutput ? 'ignore' : 'pipe', ignoreOutput ? 'ignore' : 'pipe'],
      });
    } catch (e) { return reject(e); }
    const timer = setTimeout(() => {
      try { child.kill('SIGKILL'); } catch (e) {}
      done(new Error(`${cmd}: не ответил за ${timeout} мс`));
    }, timeout);
    if (!ignoreOutput) {
      child.stdout.on('data', d => { out += d; });
      child.stderr.on('data', d => { err += d; });
    }
    child.on('error', e => done(e.code === 'ENOENT' ? new Error(`${cmd}: не установлен`) : e));
    child.on(ignoreOutput ? 'exit' : 'close', code => {
      if (code === 0) return done(null, { stdout: out, stderr: err });
      done(new Error(`${cmd} завершился с кодом ${code}: ${(err || out).trim().slice(0, 400) || 'без вывода'}`));
    });
    if (input != null) {
      // A short-lived child may close stdin before consuming the whole input.
      // Handle EPIPE as a normal command failure instead of crashing the panel.
      child.stdin.on('error', e => done(new Error(`${cmd}: ошибка передачи данных: ${e.message}`)));
      child.stdin.end(input);
    }
  });
}


async function runBinary(cmd, args, opts = {}) {
  const { env, uid, gid, timeout = 8000, input } = opts;
  return new Promise((resolve, reject) => {
    let chunks = [], err = '', done = false, child;
    const finish = (errObj, value) => { if (done) return; done = true; clearTimeout(timer); errObj ? reject(errObj) : resolve(value); };
    try {
      child = spawn(cmd, args, { env, uid, gid, cwd: '/', stdio: [input == null ? 'ignore' : 'pipe', 'pipe', 'pipe'] });
    } catch (e) { return reject(e); }
    const timer = setTimeout(() => { try { child.kill('SIGKILL'); } catch (e) {} finish(new Error(`${cmd}: не ответил за ${timeout} мс`)); }, timeout);
    child.stdout.on('data', d => chunks.push(Buffer.from(d)));
    child.stderr.on('data', d => { err += d.toString(); });
    child.on('error', e => finish(e.code === 'ENOENT' ? new Error(`${cmd}: не установлен`) : e));
    child.on('close', code => code === 0 ? finish(null, Buffer.concat(chunks)) : finish(new Error(`${cmd} завершился с кодом ${code}: ${(err || '').trim().slice(0,400) || 'без вывода'}`)));
    if (input != null) {
      // Encoders can exit early (for example, when a codec/argument is unsupported).
      // Treat a closed stdin as an encoding failure so the caller can fall back to PNG.
      child.stdin.on('error', e => finish(new Error(`${cmd}: ошибка передачи данных: ${e.message}`)));
      child.stdin.end(input);
    }
  });
}

// ---------------------------------------------------------------- session detection

let sessionCache = { t: 0, val: null };

function parseProps(text) {
  const o = {};
  for (const line of text.split('\n')) {
    const i = line.indexOf('=');
    if (i > 0) o[line.slice(0, i)] = line.slice(i + 1).trim();
  }
  return o;
}

/** Активная графическая сессия обычного пользователя (без greeter/ssh/tty). */
async function detectSession() {
  if (sessionCache.val && Date.now() - sessionCache.t < 5000) return sessionCache.val;

  let list;
  try {
    list = (await run('loginctl', ['list-sessions', '--no-legend'], { timeout: 3000 })).stdout;
  } catch (e) {
    throw new Error('Не удалось вызвать loginctl: ' + e.message);
  }
  const ids = list.split('\n').map(l => l.trim().split(/\s+/)[0]).filter(Boolean);
  const seen = [];
  for (const id of ids) {
    let p;
    try {
      p = parseProps((await run('loginctl', ['show-session', id,
        '-p', 'Type', '-p', 'Class', '-p', 'Active', '-p', 'Name', '-p', 'User', '-p', 'Display', '-p', 'Remote'],
        { timeout: 3000 })).stdout);
    } catch (e) { continue; }
    seen.push(`${id}:${p.Name}/${p.Type}/${p.Class}/active=${p.Active}`);
    if (p.Class !== 'user' || p.Active !== 'yes' || p.Remote === 'yes') continue;
    if (p.Type !== 'x11' && p.Type !== 'wayland') continue;
    const val = { id, type: p.Type, name: p.Name, uid: parseInt(p.User, 10), display: p.Display || '' };
    sessionCache = { t: Date.now(), val };
    return val;
  }
  throw new Error('Нет активной графической сессии (x11/wayland). Видел сессии: ' + (seen.join(', ') || 'никаких') +
    '. Пользователь должен быть залогинен в KDE и экран не должен быть на greeter.');
}

async function passwdEntry(uid) {
  const line = (await run('getent', ['passwd', String(uid)], { timeout: 3000 })).stdout.trim().split(':');
  return { name: line[0], gid: parseInt(line[3], 10), home: line[5] };
}

/** Из /proc/<pid>/environ окружения plasmashell/kwin — самый надёжный источник DISPLAY/XAUTHORITY и т.п. */
async function envFromCompositor(uid) {
  const wanted = ['DISPLAY', 'XAUTHORITY', 'WAYLAND_DISPLAY', 'DBUS_SESSION_BUS_ADDRESS', 'XDG_RUNTIME_DIR',
    'XDG_CURRENT_DESKTOP', 'XDG_SESSION_TYPE', 'KDE_FULL_SESSION', 'LANG', 'YDOTOOL_SOCKET'];
  for (const name of ['plasmashell', 'kwin_wayland', 'kwin_x11']) {
    try {
      const pid = (await run('pgrep', ['-u', String(uid), '-x', name], { timeout: 2000 })).stdout.trim().split('\n')[0];
      if (!pid) continue;
      const raw = fs.readFileSync(`/proc/${pid}/environ`, 'utf8').split('\0');
      const env = {};
      for (const kv of raw) {
        const i = kv.indexOf('=');
        if (i > 0 && wanted.includes(kv.slice(0, i))) env[kv.slice(0, i)] = kv.slice(i + 1);
      }
      if (Object.keys(env).length) return { env, source: `/proc/${pid}/environ (${name})` };
    } catch (e) { /* нет прав или процесса нет — идём дальше */ }
  }
  return { env: {}, source: null };
}

function findFirst(dir, re) {
  try {
    const f = fs.readdirSync(dir).filter(n => re.test(n)).sort();
    return f.length ? path.join(dir, f[0]) : null;
  } catch (e) { return null; }
}

/** Контекст запуска команд: env + uid/gid для смены пользователя. */
async function buildContext() {
  const sess = await detectSession();
  const pw = await passwdEntry(sess.uid);
  const rt = `/run/user/${sess.uid}`;
  const found = await envFromCompositor(sess.uid);

  const env = {
    PATH: process.env.PATH || '/usr/local/bin:/usr/bin:/bin',
    HOME: pw.home, USER: pw.name, LOGNAME: pw.name,
    XDG_RUNTIME_DIR: rt,
    DBUS_SESSION_BUS_ADDRESS: `unix:path=${rt}/bus`,
    ...found.env,
  };
  if (sess.type === 'wayland' && !env.WAYLAND_DISPLAY) {
    env.WAYLAND_DISPLAY = (findFirst(rt, /^wayland-\d+$/) || '/wayland-0').split('/').pop();
  }
  if (!env.DISPLAY && sess.display) env.DISPLAY = sess.display;
  if (sess.type === 'x11') {
    if (!env.DISPLAY) env.DISPLAY = ':0';
    if (!env.XAUTHORITY) {
      env.XAUTHORITY = findFirst(rt, /^xauth_/) ||
        (fs.existsSync(path.join(pw.home, '.Xauthority')) ? path.join(pw.home, '.Xauthority') : null) ||
        findFirst('/run/sddm', /^xauth_/) || undefined;
      if (!env.XAUTHORITY) delete env.XAUTHORITY;
    }
  }
  // Кем запускать команды
  const me = process.getuid();
  const spawnOpts = { env };
  if (me !== sess.uid) {
    if (me !== 0) {
      throw new Error(`Панель запущена от uid=${me}, а графическая сессия принадлежит ${pw.name} (uid=${sess.uid}). ` +
        `Запусти панель от пользователя ${pw.name} или от root.`);
    }
    spawnOpts.uid = sess.uid;
    spawnOpts.gid = pw.gid;
  }

  return { sess, type: sess.type, user: pw.name, env, spawnOpts, envSource: found.source };
}

/**
 * Проверяет сокет ydotoold. Его локальный протокол использует Unix datagram,
 * поэтому net.createConnection() (Unix stream) всегда ошибочно считал демон
 * недоступным. Подтверждаем socket-файл живым процессом ydotoold, привязанным
 * именно к этому пути, без отправки фиктивной команды ввода.
 */
function probeSocket(sockPath, expectedUid) {
  let socketStat;
  try {
    socketStat = fs.lstatSync(sockPath);
    if (!socketStat.isSocket() || (expectedUid !== undefined && socketStat.uid !== expectedUid && socketStat.uid !== 0) || (socketStat.mode & 0o077) !== 0) return Promise.resolve(false);
  } catch (e) { return Promise.resolve(false); }
  try {
    for (const entry of fs.readdirSync('/proc')) {
      if (!/^\d+$/.test(entry) || Number(entry) === process.pid) continue;
      const proc = '/proc/' + entry;
      try {
        if (path.basename(fs.readlinkSync(proc + '/exe')) !== 'ydotoold') continue;
        const status = fs.readFileSync(proc + '/status', 'utf8');
        const uidMatch = status.match(/^Uid:\s+(\d+)/m);
        const processUid = uidMatch ? Number(uidMatch[1]) : -1;
        if (expectedUid !== undefined && processUid !== expectedUid && processUid !== 0) continue;
        const args = fs.readFileSync(proc + '/cmdline', 'utf8').split('\0').filter(Boolean);
        const explicit = args.some((arg, i) => arg === '--socket-path=' + sockPath ||
          (arg === '--socket-path' && args[i + 1] === sockPath));
        const hasSocketArg = args.some(arg => arg === '--socket-path' || arg.startsWith('--socket-path='));
        if (explicit) return Promise.resolve(true);
        if (!hasSocketArg) {
          const envText = fs.readFileSync(proc + '/environ', 'utf8');
          if (envText.split('\0').includes('XDG_RUNTIME_DIR=' + path.dirname(sockPath))) {
            return Promise.resolve(true);
          }
        }
      } catch (e) { /* process exited or /proc access raced */ }
    }
  } catch (e) { /* /proc unavailable: treat socket as unverified */ }
  return Promise.resolve(false);
}

/**
 * Гарантирует рабочий (реально отвечающий) сокет ydotoold для этого контекста
 * и прописывает его в ctx.env.YDOTOOL_SOCKET. Вызывается ТОЛЬКО там, где
 * действительно нужен ввод (не из buildContext — иначе от сломанного ydotoold
 * ложится и скриншот, который к ydotool отношения не имеет).
 *
 * ydotool-клиент по умолчанию стучится в $XDG_RUNTIME_DIR/.ydotool_socket —
 * запуск ydotoold вручную с другим --socket-path (например, в $HOME) как раз
 * даёт «Connection refused» на /run/user/<uid>/.ydotool_socket.
 */
let ydotoolStarting = null; // singleton: не даём двум запросам одновременно поднимать по демону и убивать сокеты друг друга
const ydotoolPointerProfileChecks = new Map();

/**
 * Relative ydotool deltas are only predictable when KWin does not accelerate
 * its virtual pointer. Apply the flat profile to ydotool's virtual pointer
 * only; changing the user's physical mouse profile would be surprising.
 */
async function ensureYdotoolPointerProfile(ctx) {
  const key = `${ctx.sess.uid}:${ctx.env.DBUS_SESSION_BUS_ADDRESS || ctx.env.XDG_RUNTIME_DIR}`;
  const previous = ydotoolPointerProfileChecks.get(key);
  const retryAfter = previous && previous.result && previous.result.flat ? 60000 : 3000;
  if (previous && Date.now() - previous.checkedAt < retryAfter) return previous.promise || previous.result;
  if (!hasBin('busctl')) {
    const result = { flat: false, devices: 0, error: 'busctl не установлен' };
    ydotoolPointerProfileChecks.set(key, { checkedAt: Date.now(), result });
    return result;
  }
  const entry = { checkedAt: Date.now(), result: null, promise: null };
  entry.promise = (async () => {
    try {
      const { stdout } = await run('busctl', ['--user', '--no-pager', 'tree', 'org.kde.KWin'], { ...ctx.spawnOpts, timeout: 3000 });
      const paths = [...new Set(stdout.match(/\/org\/kde\/KWin\/InputDevice\/event\d+/g) || [])];
      const devices = await Promise.all(paths.map(async objectPath => {
        try {
          const { stdout: details } = await run('busctl', ['--user', '--no-pager', 'introspect', 'org.kde.KWin', objectPath, 'org.kde.KWin.InputDevice'], { ...ctx.spawnOpts, timeout: 3000 });
          const property = name => {
            const line = details.split(/\r?\n/).find(s => new RegExp(`^\\s*\\.?${name}\\s+property\\s`).test(s));
            if (!line) return null;
            const match = line.match(/\bproperty\s+\S+\s+(.*?)\s+(?:emits-change|const|readonly|writable)\b/);
            return match ? match[1].trim() : null;
          };
          return {
            name: property('name'),
            virtual: property('isVirtual') === 'true',
            pointer: property('pointer') === 'true',
            supported: property('supportsPointerAccelerationProfileFlat') === 'true',
            flat: property('pointerAccelerationProfileFlat') === 'true',
            objectPath,
          };
        } catch (e) { return null; }
      }));
      const targets = devices.filter(d => d && d.name === '"ydotoold virtual device"' && d.virtual && d.pointer && d.supported);
      let changed = 0;
      for (const device of targets) {
        if (device.flat) continue;
        await run('busctl', ['--user', 'set-property', 'org.kde.KWin', device.objectPath, 'org.kde.KWin.InputDevice', 'pointerAccelerationProfileFlat', 'b', 'true'], { ...ctx.spawnOpts, timeout: 3000 });
        changed++;
      }
      return { flat: targets.length > 0, devices: targets.length, changed };
    } catch (e) {
      return { flat: false, devices: 0, error: e.message };
    }
  })();
  ydotoolPointerProfileChecks.set(key, entry);
  entry.result = await entry.promise;
  entry.promise = null;
  return entry.result;
}

async function ensureYdotoolSocket(ctx) {
  if (ctx.type !== 'wayland') return;
  const targetUid = ctx.spawnOpts.uid !== undefined ? Number(ctx.spawnOpts.uid) : process.getuid();
  const targetGid = ctx.spawnOpts.gid !== undefined ? Number(ctx.spawnOpts.gid) : process.getgid();
  const runtimeValue = String(ctx.env.XDG_RUNTIME_DIR || '');
  if (!runtimeValue || !path.isAbsolute(runtimeValue) || !Number.isSafeInteger(targetUid) || targetUid < 0) throw new Error('У Wayland-сессии нет безопасного XDG_RUNTIME_DIR');
  const runtimeDir = path.resolve(runtimeValue);
  const runtimeStat = fs.lstatSync(runtimeDir);
  if (!runtimeStat.isDirectory() || runtimeStat.isSymbolicLink() || runtimeStat.uid !== targetUid || (runtimeStat.mode & 0o077) !== 0) {
    throw new Error('Каталог XDG_RUNTIME_DIR не принадлежит пользователю сессии или доступен другим пользователям');
  }
  let socketDir = runtimeDir;
  if (process.getuid() === 0) {
    if (!Number.isSafeInteger(targetGid) || targetGid < 0) throw new Error('Некорректная группа пользователя графической сессии');
    const rootSocketDir = '/run/nix-panel-ydotool';
    try { fs.mkdirSync(rootSocketDir, { mode: 0o755 }); }
    catch (error) { if (error.code !== 'EEXIST') throw error; }
    let baseStat = fs.lstatSync(rootSocketDir);
    if (!baseStat.isDirectory() || baseStat.isSymbolicLink() || baseStat.uid !== 0) throw new Error('Небезопасный системный каталог сокетов ydotool');
    if ((baseStat.mode & 0o777) !== 0o755 || baseStat.gid !== 0) {
      fs.chownSync(rootSocketDir, 0, 0);
      fs.chmodSync(rootSocketDir, 0o755);
      baseStat = fs.lstatSync(rootSocketDir);
    }
    if (!baseStat.isDirectory() || baseStat.isSymbolicLink() || baseStat.uid !== 0 || baseStat.gid !== 0 || (baseStat.mode & 0o777) !== 0o755) {
      throw new Error('Не удалось защитить системный каталог сокетов ydotool');
    }
    socketDir = path.join(rootSocketDir, String(targetUid));
    try { fs.mkdirSync(socketDir, { mode: 0o710 }); }
    catch (error) { if (error.code !== 'EEXIST') throw error; }
    let userSocketDirStat = fs.lstatSync(socketDir);
    if (!userSocketDirStat.isDirectory() || userSocketDirStat.isSymbolicLink() || userSocketDirStat.uid !== 0) {
      throw new Error('Небезопасный каталог сокета ydotool для пользователя');
    }
    if (userSocketDirStat.gid !== targetGid || (userSocketDirStat.mode & 0o777) !== 0o710) {
      fs.chownSync(socketDir, 0, targetGid);
      fs.chmodSync(socketDir, 0o710);
      userSocketDirStat = fs.lstatSync(socketDir);
    }
    if (!userSocketDirStat.isDirectory() || userSocketDirStat.isSymbolicLink() || userSocketDirStat.uid !== 0 || userSocketDirStat.gid !== targetGid || (userSocketDirStat.mode & 0o777) !== 0o710) {
      throw new Error('Не удалось защитить каталог сокета ydotool для пользователя');
    }
  }
  const canonical = path.join(socketDir, '.ydotool_socket');
  // Ignore YDOTOOL_SOCKET overrides and never trust a socket in shared /tmp.
  ctx.env.YDOTOOL_SOCKET = canonical;
  if (await probeSocket(canonical, targetUid)) {
    prepareYdotoolSocket(ctx, canonical);
    return ensureYdotoolPointerProfile(ctx);
  }
  if (!ydotoolStarting) {
    ydotoolStarting = startYdotoold(canonical, ctx.spawnOpts).finally(() => { ydotoolStarting = null; });
  }
  ctx.env.YDOTOOL_SOCKET = await ydotoolStarting;
  return ensureYdotoolPointerProfile(ctx);
}

function prepareYdotoolSocket(ctx, sockPath) {
  // Installed panel runs as root. Keep the uinput daemon privileged, but give
  // its private socket to the active desktop account only. lchown does not
  // follow a symlink; the daemon already creates the socket with mode 0600.
  const targetUid = ctx.spawnOpts.uid !== undefined ? Number(ctx.spawnOpts.uid) : process.getuid();
  try {
    const stat = fs.lstatSync(sockPath);
    if (!stat.isSocket() || (stat.uid !== targetUid && stat.uid !== 0) || (stat.mode & 0o077) !== 0) throw new Error('Небезопасные владелец или режим сокета');
    if (process.getuid() === 0 && stat.uid !== targetUid) fs.lchownSync(sockPath, targetUid, ctx.spawnOpts.gid);
    const verified = fs.lstatSync(sockPath);
    if (!verified.isSocket() || verified.uid !== targetUid || (verified.mode & 0o077) !== 0) throw new Error('Проверка сокета не пройдена');
  } catch (e) {
    throw new Error('Не удалось безопасно настроить сокет ydotool: ' + e.message);
  }
}

/** Убирает только зависший ydotoold, который владеет сокетом этой сессии. */
async function stopStaleYdotoold(sockPath, spawnOpts) {
  let pids = [];
  try {
    const out = (await run('pgrep', ['-x', 'ydotoold'], { env: process.env, timeout: 2000 })).stdout;
    pids = out.split(/\s+/).map(Number).filter(Boolean);
  } catch (e) {}
  const targetUid = spawnOpts.uid !== undefined ? Number(spawnOpts.uid) : process.getuid();
  const owned = [];
  for (const pid of pids) {
    if (pid === process.pid) continue;
    try {
      const status = fs.readFileSync('/proc/' + pid + '/status', 'utf8');
      const uidMatch = status.match(/^Uid:\s+(\d+)/m);
      const owner = uidMatch ? Number(uidMatch[1]) : -1;
      if (owner !== targetUid && !(process.getuid() === 0 && owner === 0)) continue;
      const args = fs.readFileSync('/proc/' + pid + '/cmdline', 'utf8').split('\0').filter(Boolean);
      const explicit = args.some((arg, i) => arg === '--socket-path=' + sockPath || (arg === '--socket-path' && args[i + 1] === sockPath));
      const hasSocketArg = args.some(arg => arg === '--socket-path' || arg.startsWith('--socket-path='));
      let usesDefault = false;
      if (!hasSocketArg) {
        const envText = fs.readFileSync('/proc/' + pid + '/environ', 'utf8');
        usesDefault = envText.split('\0').includes('XDG_RUNTIME_DIR=' + path.dirname(sockPath));
      }
      if (explicit || usesDefault) owned.push(pid);
    } catch (e) {}
  }
  for (const pid of owned) { try { process.kill(pid, 'SIGTERM'); } catch (e) {} }
  if (owned.length) await sleep(150);
  for (const pid of owned) { try { process.kill(pid, 0); process.kill(pid, 'SIGKILL'); } catch (e) {} }
}

async function startYdotoold(sockPath, spawnOpts) {
  if (!hasBin('ydotoold')) throw new Error('ydotoold не установлен (пакет ydotool)');
  await stopStaleYdotoold(sockPath, spawnOpts);
  try {
    fs.lstatSync(sockPath);
    // unlink removes the directory entry itself and never follows a symlink.
    fs.unlinkSync(sockPath);
  } catch (e) { if (e.code !== 'ENOENT') throw e; }
  // ydotoold needs /dev/uinput, which is commonly root-only. Keep it under
  // the panel's service account and assign the socket to the desktop user.
  const args = ['--socket-path=' + sockPath, '--socket-perm=0600'];
  const spawnCfg = process.getuid() === 0
    ? { env: spawnOpts.env, cwd: '/', detached: true, stdio: ['ignore', 'pipe', 'pipe'] }
    : { env: spawnOpts.env, uid: spawnOpts.uid, gid: spawnOpts.gid, cwd: '/', detached: true, stdio: ['ignore', 'pipe', 'pipe'] };
  let out = '';
  const push = d => { out = (out + d.toString()).slice(-4000); };
  let exited = null;
  const child = spawn('ydotoold', args, spawnCfg);
  child.stdout.on('data', push);
  child.stderr.on('data', push);
  child.once('error', e => { exited = { spawnError: e.message }; });
  child.once('exit', (code, signal) => { exited = exited || { code, signal }; });
  child.unref();
  // 10 секунд, а не 2 — ydotoold внутри себя дёргает xinput, чтобы проверить
  // созданное виртуальное устройство, а тот стучится в Xwayland; на KDE
  // Wayland Xwayland поднимается лениво по первому X11-клиенту, и самый
  // первый такой холодный старт может занять несколько секунд.
  for (let i = 0; i < 200; i++) {
    const targetUid = spawnOpts.uid !== undefined ? Number(spawnOpts.uid) : process.getuid();
    if (await probeSocket(sockPath, targetUid)) {
      prepareYdotoolSocket({ spawnOpts }, sockPath);
      return sockPath;
    }
    if (exited) break; // процесс уже умер — незачем дожидаться остатка времени
    await sleep(50);
  }
  if (!exited) {
    // Не бросаем зависший процесс висеть вечно — иначе с каждой неудачной
    // попыткой панель плодит новые демоны, которые никогда не убираются.
    try { process.kill(-child.pid, 'SIGKILL'); } catch (e) { try { child.kill('SIGKILL'); } catch (e2) {} }
  }
  const why = exited
    ? (exited.spawnError || `процесс завершился (код ${exited.code}, сигнал ${exited.signal || 'нет'})`)
    : 'не поднял сокет за 10 секунд — убил процесс, чтобы не плодить зависшие';
  throw new Error(`ydotoold не поднял рабочий сокет ${sockPath}: ${why}${out.trim() ? ' — вывод: ' + out.trim() : ''}`);
}

/** Список уже запущенных ydotoold (полезно найти зависшие с прошлых ручных запусков — они могут держать /dev/uinput). */
async function listYdotooldProcs() {
  try {
    const { stdout } = await run('pgrep', ['-af', 'ydotoold'], { env: process.env, timeout: 3000 });
    return stdout.trim().split('\n').filter(Boolean);
  } catch (e) {
    return []; // включая «ничего не найдено» (код 1 у pgrep) — это не ошибка
  }
}

// ---------------------------------------------------------------- screenshot

const PNG_MAGIC = Buffer.from([0x89, 0x50, 0x4e, 0x47]);

async function captureWith(ctx, tmp) {
  const errors = [];
  const o = { ...ctx.spawnOpts, timeout: 12000 };
  if (ctx.type === 'wayland') {
    const isKde = String(ctx.env.XDG_CURRENT_DESKTOP || '').toLowerCase().includes('kde') ||
      String(ctx.env.KDE_FULL_SESSION || '').toLowerCase() === 'true' ||
      /plasma/i.test(String(ctx.env.DESKTOP_SESSION || ''));
    const captureWithGrim = async () => {
      if (!hasBin('grim')) { errors.push('grim: не установлен'); return null; }
      try {
        const buf = await runBinary('grim', ['-'], o);
        if (buf.length > 100 && buf.subarray(0, 8).equals(Buffer.from([137,80,78,71,13,10,26,10]))) return { tool: 'grim', buf };
        errors.push(`grim: пустой/невалидный PNG (${buf.length} байт)`);
      } catch (e) { errors.push(e.message); }
      return null;
    };
    const captureWithSpectacle = async () => {
      const attempts = [
        ['-b', '-n', '-f', '-p', '-o', tmp],
        ['-b', '-n', '-f', '-p', '-d', '250', '-o', tmp],
      ];
      if (!hasBin('spectacle')) { errors.push('spectacle: не установлен'); return null; }
      for (const args of attempts) {
        try { await run('spectacle', args, o); const st=fs.statSync(tmp); if(st.size>0)return {tool:'spectacle'}; errors.push('spectacle: создал пустой файл'); }
        catch(e){ errors.push(e.message); }
      }
      return null;
    };
    // KWin does not expose the wlr-screencopy protocol used by grim on common
    // Plasma releases. Avoid a guaranteed failed capture before every frame.
    const captured = isKde
      ? await captureWithSpectacle() || await captureWithGrim()
      : await captureWithGrim() || await captureWithSpectacle();
    if (captured) return captured;
  } else {
    const attempts = [
      ['import', ['-window', 'root', tmp]], ['maim', [tmp]], ['scrot', ['-o', tmp]], ['spectacle', ['-b','-n','-f','-p','-o',tmp]]
    ];
    for (const [cmd,args] of attempts) {
      if (!hasBin(cmd)) { errors.push(`${cmd}: не установлен`); continue; }
      try { await run(cmd,args,o); const st=fs.statSync(tmp); if(st.size>0)return {tool:cmd}; errors.push(`${cmd}: создал пустой файл`); }
      catch(e){ errors.push(e.message); }
    }
  }
  throw new Error(errors.join(' | '));
}
async function captureScreen() {
  const ctx = await buildContext();
  const tmpDir = await fs.promises.mkdtemp(path.join(os.tmpdir(), 'nix-shot-'));
  const tmp = path.join(tmpDir, 'capture.png');
  try {
    await fs.promises.chmod(tmpDir, 0o700);
    if (ctx.spawnOpts.uid !== undefined) await fs.promises.chown(tmpDir, ctx.spawnOpts.uid, ctx.spawnOpts.gid);
    const captured = await captureWith(ctx, tmp);
    const tool = captured.tool;
    let buf = captured.buf;
    if (!buf) {
      const fd = await fs.promises.open(tmp, fs.constants.O_RDONLY | (fs.constants.O_NOFOLLOW || 0));
      try {
        const stat = await fd.stat();
        if (!stat.isFile() || (ctx.spawnOpts.uid !== undefined && stat.uid !== ctx.spawnOpts.uid)) throw new Error('Средство захвата создало небезопасный файл');
        buf = await fd.readFile();
      } finally { await fd.close(); }
    }
    if (buf.length < 8 || !buf.subarray(0, 4).equals(PNG_MAGIC)) {
      throw new Error(`${tool} записал не PNG (${buf.length} байт)`);
    }
    return buf;
  } finally {
    try { await fs.promises.rm(tmpDir, { recursive: true, force: true }); } catch (e) {}
  }
}

let inflight = null;
let lastShot = { t: 0, buf: null };
function getScreenshot() {
  if (lastShot.buf && Date.now() - lastShot.t < 30) return Promise.resolve(lastShot.buf);
  if (inflight) return inflight;
  inflight = captureScreen()
    .then(buf => { lastShot = { t: Date.now(), buf }; return buf; })
    .finally(() => { inflight = null; });
  return inflight;
}

// ---------------------------------------------------------------- input

// KeyboardEvent.key -> keysym для xdotool
const X_KEYSYM = {
  Enter: 'Return', Backspace: 'BackSpace', Tab: 'Tab', Escape: 'Escape', Delete: 'Delete', Insert: 'Insert',
  Home: 'Home', End: 'End', PageUp: 'Prior', PageDown: 'Next',
  ArrowUp: 'Up', ArrowDown: 'Down', ArrowLeft: 'Left', ArrowRight: 'Right', ' ': 'space',
};
for (let i = 1; i <= 12; i++) X_KEYSYM['F' + i] = 'F' + i;

// KeyboardEvent.key -> linux input keycode для ydotool
const LINUX_KEY = {
  Escape: 1, Backspace: 14, Tab: 15, Enter: 28, ' ': 57, Delete: 111, Insert: 110,
  Home: 102, End: 107, PageUp: 104, PageDown: 109, ArrowUp: 103, ArrowDown: 108, ArrowLeft: 105, ArrowRight: 106,
  F11: 87, F12: 88,
};
for (let i = 1; i <= 10; i++) LINUX_KEY['F' + i] = 58 + i;
'qwertyuiop'.split('').forEach((c, i) => { LINUX_KEY[c] = 16 + i; });
'asdfghjkl'.split('').forEach((c, i) => { LINUX_KEY[c] = 30 + i; });
'zxcvbnm'.split('').forEach((c, i) => { LINUX_KEY[c] = 44 + i; });
'1234567890'.split('').forEach((c, i) => { LINUX_KEY[c] = 2 + i; });
const LINUX_MOD = { ctrl: 29, shift: 42, alt: 56, meta: 125 };

const isAscii = s => /^[\x20-\x7e]*$/.test(s);
const sleep = ms => new Promise(r => setTimeout(r, ms));
// Track the target because ydotool exposes relative pointer movement. Re-homing
// to the upper-left on every hover queued many separate ydotool processes.
let waylandPointer = { initialized: false, x: 0, y: 0 };

function makeInput(ctx, cfg) {
  const o = { ...ctx.spawnOpts, timeout: 5000 };
  const scale = Number(cfg.inputScale) > 0 ? Number(cfg.inputScale) : 1;
  const sx = v => Math.round(v * scale);

  if (ctx.type === 'x11') {
    return {
      async move(x, y) { await run('xdotool', ['mousemove', String(sx(x)), String(sx(y))], o); },
      async click(btn) { await run('xdotool', ['click', String(btn)], o); },
      async dblclick(btn) { await run('xdotool', ['click', '--repeat', '2', '--delay', '60', String(btn)], o); },
      async key(key, m) {
        const mods = [];
        if (m.ctrl) mods.push('ctrl');
        if (m.alt) mods.push('alt');
        if (m.meta) mods.push('super');
        if (m.shift) mods.push('shift');
        if (key.length === 1 && !m.ctrl && !m.alt && !m.meta) return run('xdotool', ['type', '--delay', '0', '--', key], o);
        const sym = X_KEYSYM[key] || (key.length === 1 ? key.toLowerCase() : null);
        if (!sym) throw new Error('Неизвестная клавиша: ' + key);
        await run('xdotool', ['key', '--clearmodifiers', [...mods, sym].join('+')], o);
      },
      async type(text) { await run('xdotool', ['type', '--delay', '5', '--', text], o); },
    };
  }

  const absolute = cfg.waylandMove === 'absolute';
  const yd = args => run('ydotool', args, o);
  const BTN = { 1: '0xC0', 2: '0xC2', 3: '0xC1' };
  return {
    async move(x, y) {
      const tx = sx(x), ty = sx(y);
      if (absolute) {
        await yd(['mousemove', '-a', '-x', String(tx), '-y', String(ty)]);
        return;
      }
      // ydotool's relative backend has no pointer-position query. Establish a
      // known origin once per panel process, then move by the delta from the
      // last target. Re-homing on every event caused the upper-left jump and
      // a queue of separate ydotool processes (up to dozens for one movement).
      if (!waylandPointer.initialized) {
        await yd(['mousemove', '-x', '-30000', '-y', '-30000']);
        waylandPointer = { initialized: true, x: 0, y: 0 };
      }
      const dx = tx - waylandPointer.x, dy = ty - waylandPointer.y;
      if (dx || dy) await yd(['mousemove', '-x', String(dx), '-y', String(dy)]);
      waylandPointer.x = tx;
      waylandPointer.y = ty;
    },
    async click(btn) { await yd(['click', BTN[btn] || '0xC0']); },
    async dblclick(btn) { await yd(['click', BTN[btn] || '0xC0']); await sleep(60); await yd(['click', BTN[btn] || '0xC0']); },
    async key(key, m) {
      const plain = key.length === 1 && !m.ctrl && !m.alt && !m.meta;
      if (plain) return this.type(key);
      const code = LINUX_KEY[key.length === 1 ? key.toLowerCase() : key];
      if (!code) throw new Error('Неизвестная клавиша: ' + key);
      const seq = [];
      const mods = ['ctrl', 'shift', 'alt', 'meta'].filter(k => m[k]);
      mods.forEach(k => seq.push(LINUX_MOD[k] + ':1'));
      seq.push(code + ':1', code + ':0');
      mods.reverse().forEach(k => seq.push(LINUX_MOD[k] + ':0'));
      await yd(['key', ...seq]);
    },
    async type(text) {
      if (isAscii(text)) return yd(['type', '--', text]);
      if (!hasBin('wl-copy')) throw new Error('Для не-ASCII текста на Wayland нужен wl-clipboard (пакет wl-clipboard)');
      await run('wl-copy', ['--', text], { ...o, ignoreOutput: true });
      await sleep(80);
      await yd(['key', '29:1', '47:1', '47:0', '29:0']);
    },
  };
}

// ---------------------------------------------------------------- screenshot transport optimization
const imageEncoder = ['cwebp', 'magick', 'convert'].find(hasBin) || null;
let lastEncodedShot = { source: null, key: '', t: 0, value: null };
async function encodeScreenshot(buf, format='png'){
  if (!Buffer.isBuffer(buf) || !buf.length) throw new Error('Скриншот получен пустым или повреждённым');
  if (format !== 'webp' || !imageEncoder) return { buf, t: Date.now(), type: 'image/png' };
  const key = format;
  if (lastEncodedShot.source === buf && lastEncodedShot.key === key && Date.now() - lastEncodedShot.t < 100) return lastEncodedShot.value;
  try {
    let args;
    if (imageEncoder === 'cwebp') {
      args = ['-quiet', '-q', '82', '-m', '0', '-metadata', 'none', '-', '-o', '-'];
    } else {
      args = ['png:-', '-strip', '-quality', '82', '-define', 'webp:method=0'];
      args.push('webp:-');
    }
    const encoded = await runBinary(imageEncoder, args, { timeout: 12000, input: buf });
    if (!encoded.length) throw new Error('Кодировщик вернул пустой WebP');
    const value = { buf: encoded, t: Date.now(), type: 'image/webp' };
    lastEncodedShot = { source: buf, key, t: Date.now(), value };
    return value;
  } catch (e) {
    const value = { buf, t: Date.now(), type: 'image/png' };
    lastEncodedShot = { source: buf, key, t: Date.now(), value };
    return value;
  }
}

// ---------------------------------------------------------------- router

module.exports = function createRemoteRouter({ checkPerm, config = {} }) {
  const router = express.Router();
  // GUI control inherits the host user's privileges, so it is available only
  // to the installer administrator, never to users with the restricted shell.
  const guard = checkPerm('admin');

  router.get('/screenshot', guard, async (req, res) => {
    try {
      const buf = await getScreenshot();
      const format = String(req.query.format || 'png').toLowerCase() === 'webp' ? 'webp' : 'png';
      const encoded = await encodeScreenshot(buf, format);
      let srcWidth = 0, srcHeight = 0;
      try {
        if (buf.length >= 24 && buf.subarray(0,8).equals(Buffer.from([137,80,78,71,13,10,26,10]))) {
          srcWidth = buf.readUInt32BE(16); srcHeight = buf.readUInt32BE(20);
        }
      } catch (e) {}
      if (!encoded || !Buffer.isBuffer(encoded.buf) || !encoded.buf.length) throw new Error('Кодировщик не вернул изображение');
      res.set({ 'Content-Type': encoded.type, 'Cache-Control': 'no-store', 'X-Image-Bytes': String(encoded.buf.length), 'X-Image-Width': String(srcWidth || 0), 'X-Image-Height': String(srcHeight || 0) });
      res.send(encoded.buf);
    } catch (e) {
      res.status(500).json({ error: e.message });
    }
  });

  router.get('/input/status', guard, async (req, res) => {
    try {
      const ctx = await buildContext();
      if (ctx.type !== 'wayland') return res.json({ success: true, type: ctx.type, state: 'ready', mode: 'xdotool' });
      try {
        const pointerProfile = await ensureYdotoolSocket(ctx);
        return res.json({ success: true, type: 'wayland', mode: 'ydotool', state: 'ready', socket: ctx.env.YDOTOOL_SOCKET, pointerProfile });
      }
      catch (e) { return res.status(503).json({ success:false,type:'wayland',mode:'ydotool',state:'error',error:e.message }); }
    } catch (e) { res.status(500).json({success:false,error:e.message}); }
  });

  router.post('/input', guard, async (req, res) => {
    try {
      const b = req.body || {};
      const ctx = await buildContext();
      if (ctx.type === 'wayland') await ensureYdotoolSocket(ctx);
      const inp = makeInput(ctx, config);
      const int = v => { const n = Math.round(Number(v)); if (!Number.isFinite(n) || n < 0 || n > 30000) throw new Error('Некорректные координаты'); return n; };
      const btn = [1, 2, 3].includes(Number(b.button)) ? Number(b.button) : 1;
      const hasXY = b.x !== undefined && b.y !== undefined;

      switch (b.action) {
        case 'click':
        case 'dblclick':
          if (hasXY) { await inp.move(int(b.x), int(b.y)); await sleep(30); }
          await (b.action === 'click' ? inp.click(btn) : inp.dblclick(btn));
          break;
        case 'move':
          await inp.move(int(b.x), int(b.y));
          break;
        case 'key': {
          const key = String(b.key || '');
          if (!key || key.length > 20) throw new Error('Некорректная клавиша');
          await inp.key(key, { ctrl: !!b.ctrl, alt: !!b.alt, shift: !!b.shift, meta: !!b.meta });
          break;
        }
        case 'type': {
          const text = String(b.text || '');
          if (!text || text.length > 500) throw new Error('Пустой или слишком длинный текст');
          await inp.type(text);
          break;
        }
        default:
          throw new Error('Неизвестное действие');
      }
      res.json({ success: true });
    } catch (e) {
      res.status(500).json({ success: false, error: e.message });
    }
  });

  // Что именно не так на этой машине
  router.get('/diagnose', guard, async (req, res) => {
    const out = { node: { uid: process.getuid(), pid: process.pid }, tools: {}, notes: [] };
    for (const tool of ['loginctl', 'pgrep', 'grim', 'spectacle', 'import', 'maim', 'scrot', 'xdotool', 'ydotool', 'ydotoold', 'wl-copy', 'cwebp', 'magick', 'convert']) out.tools[tool] = hasBin(tool);
    out.imageEncoder = imageEncoder || 'PNG без преобразования';
    try {
      const ctx = await buildContext();
      out.session = ctx.sess;
      out.user = ctx.user;
      out.envSource = ctx.envSource || 'не найден (использованы значения по умолчанию)';
      out.env = Object.fromEntries(Object.entries(ctx.env).filter(([key]) => key !== 'PATH'));
      out.runAsUid = ctx.spawnOpts.uid !== undefined ? ctx.spawnOpts.uid : out.node.uid;
      if (ctx.type === 'wayland') {
        out.waylandInput = 'ydotool';
        out.waylandMove = config.waylandMove === 'absolute' ? 'absolute' : 'tracked';
        if (!out.tools.spectacle && !out.tools.grim) out.notes.push('Не установлены grim и spectacle — нет средства для захвата экрана.');
        if (!out.tools.ydotool || !out.tools.ydotoold) out.notes.push('Не установлен ydotool/ydotoold — управление мышью и клавиатурой не заработает.');
        const processes = await listYdotooldProcs();
        if (processes.length) out.ydotooldProcesses = processes;
        try {
          const pointerProfile = await ensureYdotoolSocket(ctx);
          out.ydotoold = { socket: ctx.env.YDOTOOL_SOCKET, alive: true };
          out.pointerProfile = pointerProfile;
          if (!pointerProfile || !pointerProfile.flat) out.notes.push('Не удалось подтвердить отключение ускорения виртуального указателя ydotool.');
        }
        catch (e) { out.ydotoold = { alive: false, error: e.message }; out.notes.push('ydotoold не запустился: ' + e.message); }
      } else {
        if (!out.tools.xdotool) out.notes.push('Не установлен xdotool — управление не заработает.');
        if (!ctx.env.XAUTHORITY) out.notes.push('XAUTHORITY не найден — возможно, X-сервер не пустит клиента.');
      }
      const started = Date.now();
      try { const buf = await captureScreen(); out.screenshot = { ok: true, ms: Date.now() - started, bytes: buf.length }; }
      catch (e) { out.screenshot = { ok: false, ms: Date.now() - started, error: e.message }; }
    } catch (e) { out.error = e.message; }
    res.json(out);
  });

  return router;
};
