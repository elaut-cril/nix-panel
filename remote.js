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
const { spawn, execFileSync } = require('child_process');
const net = require('net');

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
    if (input != null) child.stdin.end(input);
  });
}


async function runBinary(cmd, args, opts = {}) {
  const { env, uid, gid, timeout = 8000 } = opts;
  return new Promise((resolve, reject) => {
    let chunks = [], err = '', done = false, child;
    const finish = (errObj, value) => { if (done) return; done = true; clearTimeout(timer); errObj ? reject(errObj) : resolve(value); };
    try {
      child = spawn(cmd, args, { env, uid, gid, cwd: '/', stdio: ['ignore', 'pipe', 'pipe'] });
    } catch (e) { return reject(e); }
    const timer = setTimeout(() => { try { child.kill('SIGKILL'); } catch (e) {} finish(new Error(`${cmd}: не ответил за ${timeout} мс`)); }, timeout);
    child.stdout.on('data', d => chunks.push(Buffer.from(d)));
    child.stderr.on('data', d => { err += d.toString(); });
    child.on('error', e => finish(e.code === 'ENOENT' ? new Error(`${cmd}: не установлен`) : e));
    child.on('close', code => code === 0 ? finish(null, Buffer.concat(chunks)) : finish(new Error(`${cmd} завершился с кодом ${code}: ${(err || '').trim().slice(0,400) || 'без вывода'}`)));
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

/** Живой ли unix-сокет по указанному пути (реально принимает соединения). */
function probeSocket(sockPath) {
  return new Promise(resolve => {
    const s = net.createConnection(sockPath);
    const done = ok => { s.destroy(); resolve(ok); };
    s.once('connect', () => done(true));
    s.once('error', () => done(false));
    s.setTimeout(500, () => done(false));
  });
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
async function ensureYdotoolSocket(ctx) {
  if (ctx.type !== 'wayland') return;
  const canonical = path.join(ctx.env.XDG_RUNTIME_DIR, '.ydotool_socket');
  const candidates = [ctx.env.YDOTOOL_SOCKET, canonical, '/tmp/.ydotool_socket'].filter(Boolean);
  for (const p of candidates) {
    if (await probeSocket(p)) { ctx.env.YDOTOOL_SOCKET = p; return; }
  }
  if (!ydotoolStarting) {
    ydotoolStarting = startYdotoold(canonical, ctx.user, ctx.spawnOpts).finally(() => { ydotoolStarting = null; });
  }
  ctx.env.YDOTOOL_SOCKET = await ydotoolStarting;
}

/** Если ydotoold ещё не запущен (или его сокет мёртв) — поднимаем сами, от пользователя сессии. */
async function stopStaleYdotoold(user) {
  // Если рабочего сокета нет, оставшиеся ydotoold только мешают новому демону
  // открыть /dev/uinput. Чистим процессы именно перед новым стартом.
  let pids = [];
  try {
    const out = (await run('pgrep', ['-x', 'ydotoold'], { env: process.env, timeout: 2000 })).stdout;
    pids = out.split(/\s+/).map(Number).filter(Boolean);
  } catch (e) {}
  for (const pid of pids) {
    if (pid === process.pid) continue;
    try {
      const st = fs.readFileSync(`/proc/${pid}/status`, 'utf8');
      const m = st.match(/^Uid:\s+(\d+)/m);
      const owner = m ? Number(m[1]) : -1;
      // Панель запускается от root в штатной установке. В таком режиме
      // старый root-демон тоже может держать /dev/uinput, поэтому если
      // сокет нерабочий, безопаснее завершить именно stale ydotoold.
      if (owner === Number(spawnOpts.uid) || owner === 0 || (user && owner < 0)) {
        try { process.kill(pid, 'SIGTERM'); } catch (e) {}
      }
    } catch (e) {}
  }
  if (pids.length) await sleep(150);
  for (const pid of pids) {
    try { process.kill(pid, 0); process.kill(pid, 'SIGKILL'); } catch (e) {}
  }
}

async function startYdotoold(sockPath, user, spawnOpts) {
  if (!hasBin('ydotoold')) throw new Error('ydotoold не установлен (пакет ydotool)');
  await stopStaleYdotoold(user);
  if (fs.existsSync(sockPath)) {
    // Мёртвый файл сокета — ydotoold откажется забиндиться на существующий
    // путь, надо убрать его перед новым запуском.
    try { fs.unlinkSync(sockPath); } catch (e) { /* не наш файл/нет прав — пусть падает дальше сам */ }
  }
  // Переключение пользователя через голый uid/gid (как для остальных команд
  // панели) НЕ подтягивает дополнительные группы — в частности "input", без
  // которой открыть /dev/uinput нельзя ("Permission denied"). Из логин-шелла
  // работает, потому что группы там выставляет PAM. runuser/sudo делают
  // privilege drop так же, как логин, с полным набором групп пользователя —
  // используем их, если панель вообще меняет пользователя (т.е. запущена от
  // root); если панель и так уже работает от нужного юзера — переключать
  // некого, группы у неё и так свои.
  const needSwitch = spawnOpts.uid !== undefined;
  const wrapperBin = needSwitch ? (hasBin('runuser') ? 'runuser' : hasBin('sudo') ? 'sudo' : null) : null;
  const cmd = wrapperBin || 'ydotoold';
  const args = wrapperBin
    ? ['-u', user, '--', 'ydotoold', '--socket-path=' + sockPath]
    : ['--socket-path=' + sockPath];
  // Полное окружение сессии (DISPLAY/WAYLAND_DISPLAY/DBUS_SESSION_BUS_ADDRESS
  // и т.д.) нужно передавать в обоих случаях — обёртка меняет только
  // пользователя и группы, а не то, что видит сам ydotoold. Без шины/дисплея
  // он не падает с ошибкой, а просто зависает на инициализации.
  const spawnCfg = wrapperBin
    ? { env: spawnOpts.env, cwd: '/', detached: true, stdio: ['ignore', 'pipe', 'pipe'] }
    : { env: spawnOpts.env, uid: spawnOpts.uid, gid: spawnOpts.gid, cwd: '/', detached: true, stdio: ['ignore', 'pipe', 'pipe'] };
  let out = '';
  const push = d => { out = (out + d.toString()).slice(-4000); };
  let exited = null;
  const child = spawn(cmd, args, spawnCfg);
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
    if (await probeSocket(sockPath)) return sockPath;
    if (exited) break; // процесс уже умер — незачем дожидаться остатка времени
    await sleep(50);
  }
  if (!exited) {
    // Не бросаем зависший процесс висеть вечно — иначе с каждой неудачной
    // попыткой панель плодит новые runuser+ydotoold, которые никогда не убираются.
    try { process.kill(-child.pid, 'SIGKILL'); } catch (e) { try { child.kill('SIGKILL'); } catch (e2) {} }
  }
  const why = exited
    ? (exited.spawnError || `процесс завершился (код ${exited.code}, сигнал ${exited.signal || 'нет'})`)
    : 'не поднял сокет за 10 секунд — убил процесс, чтобы не плодить зависшие';
  const hint = needSwitch && !wrapperBin
    ? ' (нет ни runuser, ни sudo — переключение на пользователя шло только по uid/gid, без групп; поставь util-linux/sudo)'
    : '';
  throw new Error(`ydotoold не поднял рабочий сокет ${sockPath}: ${why}${out.trim() ? ' — вывод: ' + out.trim() : ''}${hint}`);
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
    // Prefer grim when available: it talks to the Wayland compositor directly
    // and avoids starting Spectacle for every frame. KDE/KWin installations
    // that do not expose screencopy simply fall back to Spectacle.
    if (hasBin('grim')) {
      try {
        const buf = await runBinary('grim', ['-'], o);
        if (buf.length > 100 && buf.subarray(0, 8).equals(Buffer.from([137,80,78,71,13,10,26,10]))) return { tool: 'grim', buf };
        errors.push(`grim: пустой/невалидный PNG (${buf.length} байт)`);
      } catch (e) { errors.push(e.message); }
    } else errors.push('grim: не установлен');
    const attempts = [
      ['spectacle', ['-b', '-n', '-f', '-o', tmp]],
      ['spectacle', ['-b', '-n', '-f', '-d', '250', '-o', tmp]],
    ];
    for (const [cmd,args] of attempts) {
      if (!hasBin(cmd)) { errors.push(`${cmd}: не установлен`); continue; }
      try { await run(cmd,args,o); const st=fs.statSync(tmp); if(st.size>0)return {tool:cmd}; errors.push(`${cmd}: создал пустой файл`); }
      catch(e){ errors.push(e.message); }
    }
  } else {
    const attempts = [
      ['import', ['-window', 'root', tmp]], ['maim', [tmp]], ['scrot', ['-o', tmp]], ['spectacle', ['-b','-n','-f','-o',tmp]]
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
  const tmp = path.join(os.tmpdir(), `nix-shot-${process.pid}-${Date.now()}.png`);
  try {
    const captured = await captureWith(ctx, tmp);
    const tool = captured.tool;
    const buf = captured.buf || fs.readFileSync(tmp);
    if (buf.length < 8 || !buf.subarray(0, 4).equals(PNG_MAGIC)) {
      throw new Error(`${tool} записал не PNG (${buf.length} байт)`);
    }
    return buf;
  } finally {
    fs.unlink(tmp, () => {});
  }
}

let inflight = null;
let lastShot = { t: 0, buf: null };
function getScreenshot() {
  if (lastShot.buf && Date.now() - lastShot.t < 150) return Promise.resolve(lastShot.buf);
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

// ---------------------------------------------------------------- portal (RemoteDesktop) ввод для Wayland
//
// Вместо ydotool/uinput — org.freedesktop.portal.RemoteDesktop, D-Bus-интерфейс,
// которым KWin двигает курсор напрямую, без uinput/udev/xinput. Живёт как
// отдельный персистентный процесс remote-portal-worker.js, обязательно от
// пользователя сессии (не root+setuid — сессионная шина D-Bus проверяет
// реальный uid через SO_PEERCRED, тут нужен настоящий privilege drop, как
// делает runuser). Общение с ним — построчный JSON по stdin/stdout.

const SYM_KEY = { '-': 12, '=': 13, '[': 26, ']': 27, ';': 39, "'": 40, '`': 41, '\\': 43, ',': 51, '.': 52, '/': 53 };
const SHIFT_MAP = {
  '!': '1', '@': '2', '#': '3', '$': '4', '%': '5', '^': '6', '&': '7', '*': '8', '(': '9', ')': '0',
  '_': '-', '+': '=', '{': '[', '}': ']', ':': ';', '"': "'", '~': '`', '|': '\\', '<': ',', '>': '.', '?': '/',
};
/** Символ US-раскладки -> {code, shift}. null, если не печатается напрямую (нужен буфер обмена). */
function charToKey(ch) {
  if (ch >= 'a' && ch <= 'z') return { code: LINUX_KEY[ch], shift: false };
  if (ch >= 'A' && ch <= 'Z') return { code: LINUX_KEY[ch.toLowerCase()], shift: true };
  if (ch === ' ') return { code: 57, shift: false };
  if (LINUX_KEY[ch] !== undefined) return { code: LINUX_KEY[ch], shift: false }; // цифры
  if (SYM_KEY[ch] !== undefined) return { code: SYM_KEY[ch], shift: false };
  if (SHIFT_MAP[ch] !== undefined) {
    const base = SHIFT_MAP[ch];
    const code = LINUX_KEY[base] !== undefined ? LINUX_KEY[base] : SYM_KEY[base];
    return code !== undefined ? { code, shift: true } : null;
  }
  return null;
}

let portalWorker = null; // { child, user, state, pending: Map, nextId }

function ensurePortalWorkerFile(workerPath) {
  try {
    if (fs.existsSync(workerPath) && fs.statSync(workerPath).size > 1000) return true;
    // Self-heal a partial/old installation: the worker is bundled into remote.js.
    const bundled = 'IyEvdXNyL2Jpbi9lbnYgbm9kZQondXNlIHN0cmljdCc7Ci8qKgogKiDQktC+0YDQutC10YAg0LLQstC+0LTQsCDQvNGL0YjQuC/QutC70LDQstC40LDRgtGD0YDRiyDQvdCwIEtERSBXYXlsYW5kINGH0LXRgNC10LcKICogb3JnLmZyZWVkZXNrdG9wLnBvcnRhbC5SZW1vdGVEZXNrdG9wIOKAlCDQstC80LXRgdGC0L4geWRvdG9vbC91aW5wdXQuCiAqCiAqINCe0JHQr9CX0JDQnSDQt9Cw0L/Rg9GB0LrQsNGC0YzRgdGPINC+0YIg0L/QvtC70YzQt9C+0LLQsNGC0LXQu9GPINCz0YDQsNGE0LjRh9C10YHQutC+0Lkg0YHQtdGB0YHQuNC4ICjQvdC1INC+0YIgcm9vdCDRh9C10YDQtdC3CiAqINCz0L7Qu9GL0Lkgc2V0dWlkKSDigJQg0YHQtdGB0YHQuNC+0L3QvdCw0Y8g0YjQuNC90LAgRC1CdXMg0L/RgNC+0LLQtdGA0Y/QtdGCINGA0LXQsNC70YzQvdGL0LkgdWlkINC/0L7QtNC60LvRjtGH0LDRji0KICog0YnQtdCz0L7RgdGPINC/0YDQvtGG0LXRgdGB0LAg0YfQtdGA0LXQtyBTT19QRUVSQ1JFRCwg0YTQsNC50LvQvtCy0YvQtSDQv9GA0LDQstCwINGC0YPRgiDQvdC4INC/0YDQuCDRh9GR0Lwg0Lggcm9vdAogKiDQuNGFINC+0LHQvtC50YLQuCDQvdC1INC80L7QttC10YIuINCg0L7QtNC40YLQtdC70YwgKHJlbW90ZS5qcykg0L7QsdGP0LfQsNC9INGB0YLQsNGA0YLQvtCy0LDRgtGMINGN0YLQvtGCINGE0LDQudC7CiAqINGH0LXRgNC10LcgYHJ1bnVzZXIgLXUgPHVzZXI+IC0tYCwg0L3QtSDQv9GA0L7RgdGC0L4g0YHQviDRgdC80LXQvdC+0LkgdWlkL2dpZC4KICoKICog0J/RgNC+0YLQvtC60L7QuyDRgSDRgNC+0LTQuNGC0LXQu9C10Lwg4oCUINC/0L7RgdGC0YDQvtGH0L3Ri9C5IEpTT046CiAqICAg0YDQvtC00LjRgtC10LvRjCAtPiDQstC+0YDQutC10YA6CiAqICAgICB7ImlkIjoxLCJjbWQiOiJtb3ZlIiwiZHgiOjEwLCJkeSI6LTR9CiAqICAgICB7ImlkIjoyLCJjbWQiOiJidXR0b24iLCJjb2RlIjoyNzIsInByZXNzZWQiOnRydWV9CiAqICAgICB7ImlkIjozLCJjbWQiOiJrZXkiLCJjb2RlIjozMCwicHJlc3NlZCI6dHJ1ZX0KICogICDQstC+0YDQutC10YAgLT4g0YDQvtC00LjRgtC10LvRjDoKICogICAgIHsiZXZlbnQiOiJhd2FpdGluZy1hdXRoIn0gICAgIOKAlCDQv9C+0YDRgtCw0Lsg0LbQtNGR0YIg0LrQu9C40LrQsCAi0KDQsNC30YDQtdGI0LjRgtGMIiDQsiBHVUkKICogICAgIHsiZXZlbnQiOiJyZWFkeSJ9ICAgICAgICAgICAgIOKAlCDRgdC10YHRgdC40Y8g0L/QvtC00L3Rj9GC0LAsINC80L7QttC90L4g0YHQu9Cw0YLRjCDQutC+0LzQsNC90LTRiwogKiAgICAgeyJldmVudCI6ImZhdGFsIiwiZXJyb3IiOiLigKYifSDigJQg0LLQvtGA0LrQtdGAINC90LUg0YHQvNC+0LMg0YHRgtCw0YDRgtC+0LLQsNGC0Ywg0LLQvtC+0LHRidC1CiAqICAgICB7ImlkIjoxLCJvayI6dHJ1ZX0KICogICAgIHsiaWQiOjIsIm9rIjpmYWxzZSwiZXJyb3IiOiLigKYifQogKi8KCmxldCBkYnVzOwp0cnkgewogIGRidXMgPSByZXF1aXJlKCdkYnVzLW5leHQnKTsKfSBjYXRjaCAoZSkgewogIHNlbmQoeyBldmVudDogJ2ZhdGFsJywgZXJyb3I6ICfQv9Cw0LrQtdGCIGRidXMtbmV4dCDQvdC1INGD0YHRgtCw0L3QvtCy0LvQtdC9IChucG0gaW5zdGFsbCBkYnVzLW5leHQg0LIg0L/QsNC/0LrQtSDQv9Cw0L3QtdC70LgpJyB9KTsKICBwcm9jZXNzLmV4aXQoMSk7Cn0KY29uc3QgVmFyaWFudCA9IGRidXMuVmFyaWFudDsKCmNvbnN0IFBPUlRBTF9ERVNUID0gJ29yZy5mcmVlZGVza3RvcC5wb3J0YWwuRGVza3RvcCc7CmNvbnN0IFBPUlRBTF9QQVRIID0gJy9vcmcvZnJlZWRlc2t0b3AvcG9ydGFsL2Rlc2t0b3AnOwpjb25zdCBUT0tFTl9GSUxFID0gcHJvY2Vzcy5lbnYuUE9SVEFMX1RPS0VOX0ZJTEUKICB8fCByZXF1aXJlKCdwYXRoJykuam9pbihwcm9jZXNzLmVudi5IT01FIHx8ICcvdG1wJywgJy5uaXgtcGFuZWwtcG9ydGFsLXRva2VuJyk7CgpsZXQgc2VxID0gMDsKY29uc3QgdW5pcSA9IHByZWZpeCA9PiBgbml4cGFuZWxfJHtwcmVmaXh9XyR7RGF0ZS5ub3coKX1fJHtzZXErK31gOwpmdW5jdGlvbiBzZW5kKG9iaikgeyBwcm9jZXNzLnN0ZG91dC53cml0ZShKU09OLnN0cmluZ2lmeShvYmopICsgJ1xuJyk7IH0KCi8qKiDQltC00ZHRgiDRgdC40LPQvdCw0LsgUmVzcG9uc2Ug0L3QsCDQvtCx0YrQtdC60YLQtSDQt9Cw0L/RgNC+0YHQsCDQuCDQstC+0LfQstGA0LDRidCw0LXRgiDQtdCz0L4gcmVzdWx0cyAo0YPQttC1INCx0LXQtyBWYXJpYW50LdC+0LHRkdGA0YLQvtC6KS4gKi8KZnVuY3Rpb24gd2FpdFJlc3BvbnNlKGJ1cywgcmVxdWVzdFBhdGgpIHsKICByZXR1cm4gbmV3IFByb21pc2UoYXN5bmMgKHJlc29sdmUsIHJlamVjdCkgPT4gewogICAgbGV0IGlmYWNlOwogICAgdHJ5IHsKICAgICAgY29uc3Qgb2JqID0gYXdhaXQgYnVzLmdldFByb3h5T2JqZWN0KFBPUlRBTF9ERVNULCByZXF1ZXN0UGF0aCk7CiAgICAgIGlmYWNlID0gb2JqLmdldEludGVyZmFjZSgnb3JnLmZyZWVkZXNrdG9wLnBvcnRhbC5SZXF1ZXN0Jyk7CiAgICB9IGNhdGNoIChlKSB7IHJldHVybiByZWplY3QoZSk7IH0KICAgIGNvbnN0IHRpbWVyID0gc2V0VGltZW91dCgoKSA9PiByZWplY3QobmV3IEVycm9yKCfQv9C+0YDRgtCw0Lsg0L3QtSDQvtGC0LLQtdGC0LjQuyDQt9CwIDUg0LzQuNC90YPRgicpKSwgNSAqIDYwICogMTAwMCk7CiAgICBpZmFjZS5vbmNlKCdSZXNwb25zZScsIChjb2RlLCByZXN1bHRzKSA9PiB7CiAgICAgIGNsZWFyVGltZW91dCh0aW1lcik7CiAgICAgIGlmIChjb2RlICE9PSAwKSByZXR1cm4gcmVqZWN0KG5ldyBFcnJvcihjb2RlID09PSAxID8gJ9C/0L7Qu9GM0LfQvtCy0LDRgtC10LvRjCDQvtGC0LrQu9C+0L3QuNC7INC30LDQv9GA0L7RgSDQsiDQtNC40LDQu9C+0LPQtScgOiBg0L/QvtGA0YLQsNC7INCy0LXRgNC90YPQuyDQutC+0LQgJHtjb2RlfWApKTsKICAgICAgY29uc3QgcGxhaW4gPSB7fTsKICAgICAgZm9yIChjb25zdCBrIGluIHJlc3VsdHMpIHBsYWluW2tdID0gcmVzdWx0c1trXSAmJiAndmFsdWUnIGluIHJlc3VsdHNba10gPyByZXN1bHRzW2tdLnZhbHVlIDogcmVzdWx0c1trXTsKICAgICAgcmVzb2x2ZShwbGFpbik7CiAgICB9KTsKICB9KTsKfQoKLyoqIEJlc3QtZWZmb3J0INC/0YDQtdC00LDQstGC0L7RgNC40LfQsNGG0LjRjyDRh9C10YDQtdC3INGC0LDQsdC70LjRhtGDIGtkZS1hdXRob3JpemVkIChQbGFzbWEgNi4zKykuINCd0LUg0LrRgNC40YLQuNGH0L3Qviwg0LXRgdC70Lgg0L3QtSDQstGL0LnQtNC10YIuICovCmFzeW5jIGZ1bmN0aW9uIHRyeVByZUF1dGhvcml6ZShidXMpIHsKICB0cnkgewogICAgLy8gUGVybWlzc2lvblN0b3JlIOKAlCDQvtGC0LTQtdC70YzQvdC+0LUgd2VsbC1rbm93biDQuNC80Y8g0YjQuNC90YssINCd0JUg0YLQviDQttC1INGB0LDQvNC+0LUsINGH0YLQvgogICAgLy8g0L7RgdC90L7QstC90L7QuSBvcmcuZnJlZWRlc2t0b3AucG9ydGFsLkRlc2t0b3AuCiAgICBjb25zdCBvYmogPSBhd2FpdCBidXMuZ2V0UHJveHlPYmplY3QoJ29yZy5mcmVlZGVza3RvcC5pbXBsLnBvcnRhbC5QZXJtaXNzaW9uU3RvcmUnLCAnL29yZy9mcmVlZGVza3RvcC9pbXBsL3BvcnRhbC9QZXJtaXNzaW9uU3RvcmUnKTsKICAgIGNvbnN0IGlmYWNlID0gb2JqLmdldEludGVyZmFjZSgnb3JnLmZyZWVkZXNrdG9wLmltcGwucG9ydGFsLlBlcm1pc3Npb25TdG9yZScpOwogICAgLy8gdGFibGUsIGNyZWF0ZSwgaWQsIGFwcF9pZCAo0L/Rg9GB0YLQviA9IMKr0L3QtdC40LfQstC10YHRgtC90L7QtSDRhdC+0YHRgi3Qv9GA0LjQu9C+0LbQtdC90LjQtcK7KSwgcGVybWlzc2lvbnMKICAgIGF3YWl0IGlmYWNlLlNldFBlcm1pc3Npb24oJ2tkZS1hdXRob3JpemVkJywgdHJ1ZSwgJ3JlbW90ZS1kZXNrdG9wJywgJycsIFsneWVzJ10pOwogICAgcmV0dXJuIHRydWU7CiAgfSBjYXRjaCAoZSkgewogICAgcmV0dXJuIGZhbHNlOyAvLyDRgdGC0LDRgNCw0Y8gUGxhc21hINCx0LXQtyDRjdGC0L7QuSDRgtCw0LHQu9C40YbRiywg0LjQu9C4INC/0YDQsNCyINC90LXRgiDigJQg0L3QuNGH0LXQs9C+INGB0YLRgNCw0YjQvdC+0LPQvgogIH0KfQoKZnVuY3Rpb24gbG9hZFRva2VuKCkgewogIHRyeSB7IHJldHVybiByZXF1aXJlKCdmcycpLnJlYWRGaWxlU3luYyhUT0tFTl9GSUxFLCAndXRmOCcpLnRyaW0oKSB8fCBudWxsOyB9IGNhdGNoIChlKSB7IHJldHVybiBudWxsOyB9Cn0KZnVuY3Rpb24gc2F2ZVRva2VuKHRvaykgewogIHRyeSB7IHJlcXVpcmUoJ2ZzJykud3JpdGVGaWxlU3luYyhUT0tFTl9GSUxFLCB0b2ssIHsgbW9kZTogMG82MDAgfSk7IH0gY2F0Y2ggKGUpIHsgLyog0L3QtSDQutGA0LjRgtC40YfQvdC+ICovIH0KfQoKYXN5bmMgZnVuY3Rpb24gbWFpbigpIHsKICBjb25zdCBidXNBZGRyZXNzID0gcHJvY2Vzcy5lbnYuREJVU19TRVNTSU9OX0JVU19BRERSRVNTOwogIGlmICghYnVzQWRkcmVzcykgeyBzZW5kKHsgZXZlbnQ6ICdmYXRhbCcsIGVycm9yOiAn0L3QtdGCIERCVVNfU0VTU0lPTl9CVVNfQUREUkVTUyDQsiDQvtC60YDRg9C20LXQvdC40LgnIH0pOyBwcm9jZXNzLmV4aXQoMSk7IH0KICBjb25zdCBidXMgPSBkYnVzLnNlc3Npb25CdXMoeyBidXNBZGRyZXNzIH0pOwogIGJ1cy5vbignZXJyb3InLCAoKSA9PiB7fSk7IC8vINC90LUg0YDQvtC90Y/QtdC8INC/0YDQvtGG0LXRgdGBINC90LAg0YTQvtC90L7QstGL0YUg0L7RiNC40LHQutCw0YUg0YHQvtC10LTQuNC90LXQvdC40Y8KCiAgY29uc3QgcG9ydGFsT2JqID0gYXdhaXQgYnVzLmdldFByb3h5T2JqZWN0KFBPUlRBTF9ERVNULCBQT1JUQUxfUEFUSCk7CiAgY29uc3QgcmQgPSBwb3J0YWxPYmouZ2V0SW50ZXJmYWNlKCdvcmcuZnJlZWRlc2t0b3AucG9ydGFsLlJlbW90ZURlc2t0b3AnKTsKCiAgYXdhaXQgdHJ5UHJlQXV0aG9yaXplKGJ1cyk7CgogIC8vIDEpIENyZWF0ZVNlc3Npb24KICBjb25zdCBjcmVhdGVSZXFQYXRoID0gYXdhaXQgcmQuQ3JlYXRlU2Vzc2lvbih7IHNlc3Npb25faGFuZGxlX3Rva2VuOiBuZXcgVmFyaWFudCgncycsIHVuaXEoJ2hhbmRsZScpKSB9KTsKICBjb25zdCBjcmVhdGVSZXN1bHQgPSBhd2FpdCB3YWl0UmVzcG9uc2UoYnVzLCBjcmVhdGVSZXFQYXRoKTsKICBjb25zdCBzZXNzaW9uSGFuZGxlID0gY3JlYXRlUmVzdWx0LnNlc3Npb25faGFuZGxlOwogIGlmICghc2Vzc2lvbkhhbmRsZSkgdGhyb3cgbmV3IEVycm9yKCfQv9C+0YDRgtCw0Lsg0L3QtSDQstC10YDQvdGD0Lsgc2Vzc2lvbl9oYW5kbGUnKTsKCiAgLy8gMikgU2VsZWN0RGV2aWNlcyDigJQg0LrQu9Cw0LLQuNCw0YLRg9GA0LAoMSkgKyDRg9C60LDQt9Cw0YLQtdC70YwoMiksINGBINC/0L7Qv9GL0YLQutC+0Lkg0L/QtdGA0LXQuNGB0L/QvtC70YzQt9C+0LLQsNGC0Ywg0YHQvtGF0YDQsNC90ZHQvdC90YvQuSByZXN0b3JlX3Rva2VuCiAgY29uc3Qgc2F2ZWRUb2tlbiA9IGxvYWRUb2tlbigpOwogIGNvbnN0IHNlbGVjdE9wdGlvbnMgPSB7CiAgICB0eXBlczogbmV3IFZhcmlhbnQoJ3UnLCAzKSwKICAgIHBlcnNpc3RfbW9kZTogbmV3IFZhcmlhbnQoJ3UnLCAyKSwgLy8gMiA9INC/0L7QvNC90LjRgtGMLCDQv9C+0LrQsCDRj9Cy0L3QviDQvdC1INC+0YLQt9C+0LLRg9GCCiAgfTsKICBpZiAoc2F2ZWRUb2tlbikgc2VsZWN0T3B0aW9ucy5yZXN0b3JlX3Rva2VuID0gbmV3IFZhcmlhbnQoJ3MnLCBzYXZlZFRva2VuKTsKICBjb25zdCBzZWxlY3RSZXFQYXRoID0gYXdhaXQgcmQuU2VsZWN0RGV2aWNlcyhzZXNzaW9uSGFuZGxlLCBzZWxlY3RPcHRpb25zKTsKICBhd2FpdCB3YWl0UmVzcG9uc2UoYnVzLCBzZWxlY3RSZXFQYXRoKTsKCiAgLy8gMykgU3RhcnQg4oCUINCy0L7RgiDRgtGD0YIg0LzQvtC20LXRgiDQv9C+0LrQsNC30LDRgtGM0YHRjyDQtNC40LDQu9C+0LMsINC10YHQu9C4INC90Lgg0L/RgNC10LTQsNCy0YLQvtGA0LjQt9Cw0YbQuNGPLAogIC8vINC90LggcmVzdG9yZV90b2tlbiDQvdC1INGB0YDQsNCx0L7RgtCw0LvQuC4KICBzZW5kKHsgZXZlbnQ6ICdhd2FpdGluZy1hdXRoJyB9KTsKICBjb25zdCBzdGFydFJlcVBhdGggPSBhd2FpdCByZC5TdGFydChzZXNzaW9uSGFuZGxlLCAnJywge30pOwogIGNvbnN0IHN0YXJ0UmVzdWx0ID0gYXdhaXQgd2FpdFJlc3BvbnNlKGJ1cywgc3RhcnRSZXFQYXRoKTsKICBpZiAoc3RhcnRSZXN1bHQucmVzdG9yZV90b2tlbikgc2F2ZVRva2VuKHN0YXJ0UmVzdWx0LnJlc3RvcmVfdG9rZW4pOwoKICBzZW5kKHsgZXZlbnQ6ICdyZWFkeScgfSk7CgogIC8vIDQpINCe0LHRi9GH0L3Ri9C1INC60L7QvNCw0L3QtNGLINGBINGN0YLQvtCz0L4g0LzQvtC80LXQvdGC0LAKICBjb25zdCByZWFkbGluZSA9IHJlcXVpcmUoJ3JlYWRsaW5lJyk7CiAgY29uc3QgcmwgPSByZWFkbGluZS5jcmVhdGVJbnRlcmZhY2UoeyBpbnB1dDogcHJvY2Vzcy5zdGRpbiB9KTsKICBybC5vbignbGluZScsIGFzeW5jIGxpbmUgPT4gewogICAgbGV0IG1zZzsKICAgIHRyeSB7IG1zZyA9IEpTT04ucGFyc2UobGluZSk7IH0gY2F0Y2ggKGUpIHsgcmV0dXJuOyB9CiAgICB0cnkgewogICAgICBzd2l0Y2ggKG1zZy5jbWQpIHsKICAgICAgICBjYXNlICdtb3ZlJzoKICAgICAgICAgIGF3YWl0IHJkLk5vdGlmeVBvaW50ZXJNb3Rpb24oc2Vzc2lvbkhhbmRsZSwge30sIE51bWJlcihtc2cuZHgpIHx8IDAsIE51bWJlcihtc2cuZHkpIHx8IDApOwogICAgICAgICAgYnJlYWs7CiAgICAgICAgY2FzZSAnYnV0dG9uJzoKICAgICAgICAgIGF3YWl0IHJkLk5vdGlmeVBvaW50ZXJCdXR0b24oc2Vzc2lvbkhhbmRsZSwge30sIE51bWJlcihtc2cuY29kZSksIG1zZy5wcmVzc2VkID8gMSA6IDApOwogICAgICAgICAgYnJlYWs7CiAgICAgICAgY2FzZSAna2V5JzoKICAgICAgICAgIGF3YWl0IHJkLk5vdGlmeUtleWJvYXJkS2V5Y29kZShzZXNzaW9uSGFuZGxlLCB7fSwgTnVtYmVyKG1zZy5jb2RlKSwgbXNnLnByZXNzZWQgPyAxIDogMCk7CiAgICAgICAgICBicmVhazsKICAgICAgICBkZWZhdWx0OgogICAgICAgICAgdGhyb3cgbmV3IEVycm9yKCfQvdC10LjQt9Cy0LXRgdGC0L3QsNGPINC60L7QvNCw0L3QtNCwINCy0L7RgNC60LXRgNCwOiAnICsgbXNnLmNtZCk7CiAgICAgIH0KICAgICAgc2VuZCh7IGlkOiBtc2cuaWQsIG9rOiB0cnVlIH0pOwogICAgfSBjYXRjaCAoZSkgewogICAgICBzZW5kKHsgaWQ6IG1zZy5pZCwgb2s6IGZhbHNlLCBlcnJvcjogZS5tZXNzYWdlIH0pOwogICAgfQogIH0pOwp9CgptYWluKCkuY2F0Y2goZSA9PiB7IHNlbmQoeyBldmVudDogJ2ZhdGFsJywgZXJyb3I6IGUubWVzc2FnZSB9KTsgcHJvY2Vzcy5leGl0KDEpOyB9KTsK';
    fs.writeFileSync(workerPath, Buffer.from(bundled, 'base64'), {mode: 0o755});
    return fs.existsSync(workerPath) && fs.statSync(workerPath).size > 1000;
  } catch (e) {
    return false;
  }
}

function getPortalWorkerInfo(workerPath) {
  const runtimeNodeModules = path.join(path.dirname(workerPath), 'node_modules');
  let exists = false, bytes = 0;
  try { exists = fs.existsSync(workerPath); bytes = exists ? fs.statSync(workerPath).size : 0; } catch (_) {}
  return { path: workerPath, exists, bytes, node: process.execPath, runtimeNodeModules, dbusNext: fs.existsSync(path.join(runtimeNodeModules, 'dbus-next', 'package.json')) };
}

function spawnPortalWorker(ctx) {
  const w = { child: null, user: ctx.user, state: 'starting', pending: new Map(), nextId: 1, fatalError: null };
  const workerPath = process.env.NIX_REMOTE_WORKER && path.isAbsolute(process.env.NIX_REMOTE_WORKER)
    ? process.env.NIX_REMOTE_WORKER
    : '/usr/local/lib/nix-panel/remote-portal-worker.js';
  if (!ensurePortalWorkerFile(workerPath)) {
    w.state = 'dead';
    w.fatalError = `Не удалось подготовить worker: ${workerPath}`;
    return w;
  }
  // Never start a child process against a path that disappeared between the
  // self-heal check and spawn. This also makes the actual deployment failure
  // visible instead of producing a misleading Node MODULE_NOT_FOUND later.
  try {
    const st = fs.statSync(workerPath);
    if (!st.isFile() || st.size < 1000) throw new Error('worker имеет неверный размер');
    fs.chmodSync(workerPath, 0o755);
  } catch (e) {
    w.state = 'dead';
    w.fatalError = `Worker недоступен перед запуском: ${workerPath}: ${e.message}`;
    return w;
  }
  const nodeBin = fs.existsSync('/usr/bin/node') ? '/usr/bin/node' : process.execPath;
  const runtimeNodeModules = path.join(path.dirname(workerPath), 'node_modules');
  const args = ['-u', ctx.user, '--', nodeBin, workerPath];
  const child = spawn('runuser', args, {
    env: { ...process.env, ...ctx.env, NODE_PATH: runtimeNodeModules, PATH: ctx.env.PATH || process.env.PATH || '/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin' },
    cwd: __dirname, detached: true, stdio: ['pipe', 'pipe', 'pipe'],
  });
  w.child = child;
  child.unref();

  let buf = '';
  child.stdout.on('data', d => {
    buf += d.toString();
    let idx;
    while ((idx = buf.indexOf('\n')) >= 0) {
      const line = buf.slice(0, idx); buf = buf.slice(idx + 1);
      if (!line.trim()) continue;
      let msg; try { msg = JSON.parse(line); } catch (e) { continue; }
      if (msg.event === 'ready') { w.state = 'ready'; }
      else if (msg.event === 'awaiting-auth') { w.state = 'awaiting-auth'; }
      else if (msg.event === 'fatal') {
        w.state = 'dead'; w.fatalError = msg.error;
        for (const p of w.pending.values()) p.reject(new Error(msg.error));
        w.pending.clear();
      } else if (msg.id !== undefined) {
        const p = w.pending.get(msg.id);
        if (p) { w.pending.delete(msg.id); msg.ok ? p.resolve() : p.reject(new Error(msg.error || 'ошибка воркера портала')); }
      }
    }
  });
  let stderrBuf = '';
  child.stderr.on('data', d => { stderrBuf = (stderrBuf + d.toString()).slice(-2000); });
  child.once('exit', (code, signal) => {
    w.state = 'dead';
    const detail = stderrBuf.trim();
    w.fatalError = w.fatalError || `воркер завершился (код ${code}, сигнал ${signal || 'нет'})${detail ? ' — ' + detail : ''} [path=${workerPath}, exists=${fs.existsSync(workerPath)}, node=${nodeBin}]`;
    for (const p of w.pending.values()) p.reject(new Error(w.fatalError));
    w.pending.clear();
    if (portalWorker === w) portalWorker = null;
  });
  child.once('error', e => {
    w.state = 'dead'; w.fatalError = e.message;
    if (portalWorker === w) portalWorker = null;
  });
  return w;
}

/** Возвращает актуальный воркер (переиспользуя живой), поднимая новый при необходимости. */
function getPortalWorker(ctx) {
  if (portalWorker && portalWorker.state !== 'dead' && portalWorker.user === ctx.user) return portalWorker;
  portalWorker = spawnPortalWorker(ctx);
  return portalWorker;
}

function portalSend(worker, cmd) {
  if (worker.state === 'dead') return Promise.reject(new Error(worker.fatalError || 'воркер портала не запущен'));
  if (worker.state !== 'ready') {
    return Promise.reject(new Error(
      worker.state === 'awaiting-auth'
        ? 'Портал KDE ждёт подтверждения (диалог «Разрешить управление вводом» на самом экране, или предавторизация ещё не сработала) — попробуйте через несколько секунд'
        : 'Портал ещё запускается — попробуйте через пару секунд'
    ));
  }
  const id = worker.nextId++;
  return new Promise((resolve, reject) => {
    worker.pending.set(id, { resolve, reject });
    worker.child.stdin.write(JSON.stringify({ id, ...cmd }) + '\n');
  });
}

const PORTAL_BTN = { 1: 272, 2: 274, 3: 273 }; // left, middle, right — BTN_LEFT/MIDDLE/RIGHT (evdev)

function makePortalInput(ctx, cfg) {
  const scale = Number(cfg.inputScale) > 0 ? Number(cfg.inputScale) : 1;
  const sx = v => Math.round(v * scale);
  const cursor = { x: null, y: null }; // последняя известная (масштабированная) позиция курсора
  const w = () => getPortalWorker(ctx);

  async function moveAbs(x, y) {
    const tx = sx(x), ty = sx(y);
    if (cursor.x === null) {
      // Прижимаем к (0,0), как раньше делали с ydotool-homing — компенсирует
      // то, что мы не знаем, где курсор был до первого нашего движения.
      await portalSend(w(), { cmd: 'move', dx: -30000, dy: -30000 });
      cursor.x = 0; cursor.y = 0;
    }
    await portalSend(w(), { cmd: 'move', dx: tx - cursor.x, dy: ty - cursor.y });
    cursor.x = tx; cursor.y = ty;
  }
  async function pressRelease(code) {
    await portalSend(w(), { cmd: 'key', code, pressed: true });
    await portalSend(w(), { cmd: 'key', code, pressed: false });
  }
  async function clickBtn(btn) {
    const code = PORTAL_BTN[btn] || PORTAL_BTN[1];
    await portalSend(w(), { cmd: 'button', code, pressed: true });
    await portalSend(w(), { cmd: 'button', code, pressed: false });
  }

  return {
    async move(x, y) { await moveAbs(x, y); },
    async click(btn) { await clickBtn(btn); },
    async dblclick(btn) { await clickBtn(btn); await sleep(60); await clickBtn(btn); },
    async key(key, m) {
      const plain = key.length === 1 && !m.ctrl && !m.alt && !m.meta;
      if (plain) return this.type(key);
      const mapped = key.length === 1 ? charToKey(key) : null;
      const code = mapped ? mapped.code : LINUX_KEY[key];
      if (!code) throw new Error('Неизвестная клавиша: ' + key);
      const mods = ['ctrl', 'shift', 'alt', 'meta'].filter(k => m[k]);
      if (mapped && mapped.shift && !mods.includes('shift')) mods.push('shift');
      for (const mk of mods) await portalSend(w(), { cmd: 'key', code: LINUX_MOD[mk], pressed: true });
      await pressRelease(code);
      for (const mk of mods.slice().reverse()) await portalSend(w(), { cmd: 'key', code: LINUX_MOD[mk], pressed: false });
    },
    async type(text) {
      for (const ch of text) {
        const k = charToKey(ch);
        if (!k) {
          // Символ вне US-раскладки (кириллица и т.п.) — через буфер обмена, как и на ydotool.
          if (!hasBin('wl-copy')) throw new Error('Для не-ASCII текста на Wayland нужен wl-clipboard (пакет wl-clipboard)');
          await run('wl-copy', ['--', ch], { env: ctx.env, uid: ctx.spawnOpts.uid, gid: ctx.spawnOpts.gid, timeout: 5000, ignoreOutput: true });
          await sleep(80);
          await portalSend(w(), { cmd: 'key', code: LINUX_MOD.ctrl, pressed: true });
          await pressRelease(47); // V
          await portalSend(w(), { cmd: 'key', code: LINUX_MOD.ctrl, pressed: false });
          continue;
        }
        if (k.shift) await portalSend(w(), { cmd: 'key', code: LINUX_MOD.shift, pressed: true });
        await pressRelease(k.code);
        if (k.shift) await portalSend(w(), { cmd: 'key', code: LINUX_MOD.shift, pressed: false });
      }
    },
  };
}

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
        if (m.shift) mods.push('shift');   // сюда доходят только спецклавиши и комбинации с ctrl/alt/meta
        if (key.length === 1 && !m.ctrl && !m.alt && !m.meta) {
          return run('xdotool', ['type', '--delay', '0', '--', key], o);      // печатные символы, в т.ч. кириллица
        }
        const sym = X_KEYSYM[key] || (key.length === 1 ? key.toLowerCase() : null);
        if (!sym) throw new Error('Неизвестная клавиша: ' + key);
        await run('xdotool', ['key', '--clearmodifiers', [...mods, sym].join('+')], o);
      },
      async type(text) { await run('xdotool', ['type', '--delay', '5', '--', text], o); },
    };
  }

  // ---- Wayland: portal is the primary input backend. It is the native KDE
  // RemoteDesktop API and does not depend on /dev/uinput or ydotoold.
  // ydotool remains available as an explicit fallback via nix-config.json.
  const wantYdotool = cfg.waylandInput === 'ydotool' && !ctx.__ydotoolUnavailable;
  if (!wantYdotool) {
    return makePortalInput(ctx, cfg);
  }

  // ---- Wayland, legacy: ydotool ≥ 1.0 + запущенный ydotoold
  // ydotool не умеет по-настоящему абсолютное позиционирование: его `--absolute`
  // сам внутри реализован как «прыжок в угол + относительный сдвиг», и на многих
  // связках ydotool/libinput этот сдвиг применяется некорректно — курсор остаётся
  // в углу независимо от переданных координат (см. ReimuNotMoe/ydotool issue #250).
  // Поэтому теперь по умолчанию делаем тот же трюк САМИ (homing), явно, шагами —
  // это не хуже встроенного `-a` и на практике оказывается надёжнее.
  // Чтобы вернуть старое поведение (сырой `ydotool mousemove -a`), укажи в
  // nix-config.json: "remote": { "waylandMove": "absolute" }.
  const homing = cfg.waylandMove !== 'absolute';
  const yd = args => run('ydotool', args, o);
  const BTN = { 1: '0xC0', 2: '0xC2', 3: '0xC1' }; // left, middle, right
  return {
    async move(x, y) {
      if (homing) {
        // Шаг 1: гарантированно прижимаем курсор к (0,0) — один огромный
        // относительный сдвиг всегда упирается в край экрана, тут ускорение
        // курсора не имеет значения (результат один и тот же в любом случае).
        await yd(['mousemove', '-x', '-30000', '-y', '-30000']);
        // Шаг 2: едем к цели небольшими относительными шагами, а не одним
        // огромным прыжком. Один большой синтетический сдвиг libinput может
        // трактовать как «очень быстрое» движение и исказить его акселерацией
        // указателя (issue ReimuNotMoe/ydotool#250) — короткие шаги остаются
        // в линейной части кривой ускорения и в сумме дают точный результат.
        const tx = sx(x), ty = sx(y);
        const STEP = 50;
        const steps = Math.max(1, Math.ceil(Math.max(Math.abs(tx), Math.abs(ty)) / STEP));
        for (let i = 1; i <= steps; i++) {
          const px = Math.round(tx * (i - 1) / steps), py = Math.round(ty * (i - 1) / steps);
          const nx = Math.round(tx * i / steps), ny = Math.round(ty * i / steps);
          await yd(['mousemove', '-x', String(nx - px), '-y', String(ny - py)]);
        }
      } else {
        await yd(['mousemove', '-a', '-x', String(sx(x)), '-y', String(sx(y))]);
      }
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
      mods.forEach(k => seq.push(`${LINUX_MOD[k]}:1`));
      seq.push(`${code}:1`, `${code}:0`);
      mods.reverse().forEach(k => seq.push(`${LINUX_MOD[k]}:0`));
      await yd(['key', ...seq]);
    },
    async type(text) {
      if (isAscii(text)) return yd(['type', '--', text]);
      // ydotool печатает только ASCII (раскладка US). Юникод — через буфер обмена + Ctrl+V.
      if (!hasBin('wl-copy')) {
        throw new Error('Для не-ASCII текста на Wayland нужен wl-clipboard (пакет wl-clipboard)');
      }
      await run('wl-copy', ['--', text], { ...o, ignoreOutput: true });
      await sleep(80);
      await yd(['key', '29:1', '47:1', '47:0', '29:0']);
    },
  };
}

// ---------------------------------------------------------------- screenshot transport optimization
let imageConvert = null;
try {
  for (const b of ['magick','convert']) {
    try { execFileSync('sh',['-lc',`command -v ${b}`],{stdio:'ignore'}); imageConvert=b; break; } catch(e) {}
  }
} catch(e) {}
const encodedShotCache = new Map();
function encodeScreenshot(buf, format='png', quality=68, maxWidth=1920){
  if (!Buffer.isBuffer(buf) || !buf.length) throw new Error('Скриншот получен пустым или повреждённым');
  const key=`${format}|${quality}|${maxWidth}|${buf.length}|${buf.subarray(0,16).toString('hex')}`;
  const hit=encodedShotCache.get(key);
  if(hit && Date.now()-hit.t<150) return hit;
  if(format==='png' || !imageConvert){
    const out={buf,t:Date.now(),type:'image/png'};encodedShotCache.set(key,out);return out;
  }
  const inFile=path.join(os.tmpdir(),`nix-shot-enc-${process.pid}-${Date.now()}.png`);
  const ext=format==='webp'?'webp':'jpg';
  const outFile=path.join(os.tmpdir(),`nix-shot-enc-${process.pid}-${Date.now()}.${ext}`);
  try{
    fs.writeFileSync(inFile,buf);
    const args=[inFile,'-strip'];
    if(maxWidth>0) args.push('-resize',`${Math.max(320,Math.round(maxWidth))}x>`);
    if(ext==='webp') args.push('-quality',String(Math.max(35,Math.min(90,quality))),outFile);
    else args.push('-quality',String(Math.max(35,Math.min(90,quality))),outFile);
    execFileSync(imageConvert,args,{timeout:10000,stdio:'ignore'});
    const b=fs.readFileSync(outFile);
    const out={buf:b,t:Date.now(),type:ext==='webp'?'image/webp':'image/jpeg'};encodedShotCache.set(key,out);return out;
  } catch(e){
    const out={buf,t:Date.now(),type:'image/png'};encodedShotCache.set(key,out);return out;
  } finally {try{fs.unlinkSync(inFile)}catch(e){} try{fs.unlinkSync(outFile)}catch(e){}}
}

// ---------------------------------------------------------------- router

module.exports = function createRemoteRouter({ checkPerm, config = {} }) {
  const router = express.Router();
  const guard = checkPerm('console');

  router.get('/screenshot', guard, async (req, res) => {
    try {
      const buf = await getScreenshot();
      const format = String(req.query.format || 'png').toLowerCase() === 'webp' ? 'webp' : 'png';
      const quality = Number(req.query.quality) || 68;
      const maxWidth = Number(req.query.maxWidth) || 1920;
      const encoded = encodeScreenshot(buf, format, quality, maxWidth);
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
      const mode = config.waylandInput === 'ydotool' ? 'ydotool' : 'portal';
      if (mode === 'ydotool') {
        try { await ensureYdotoolSocket(ctx); return res.json({ success: true, type: 'wayland', mode, state: 'ready', socket: ctx.env.YDOTOOL_SOCKET }); }
        catch (e) { return res.status(503).json({ success:false,type:'wayland',mode,state:'error',error:e.message }); }
      }
      const worker = getPortalWorker(ctx);
      for (let i=0;i<80 && worker.state==='starting';i++) await sleep(50);
      return res.json({ success: worker.state==='ready', type:'wayland', mode:'portal', state:worker.state, error:worker.fatalError||null });
    } catch (e) { res.status(500).json({success:false,error:e.message}); }
  });

  router.post('/input', guard, async (req, res) => {
    try {
      const b = req.body || {};
      const ctx = await buildContext();
      if (ctx.type === 'wayland' && config.waylandInput === 'ydotool') {
        await ensureYdotoolSocket(ctx);
      }
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
    for (const t of ['loginctl', 'pgrep', 'grim', 'spectacle', 'import', 'maim', 'scrot', 'xdotool', 'ydotool', 'ydotoold', 'wl-copy', 'runuser', 'sudo'])
      out.tools[t] = hasBin(t);
    try {
      require.resolve('dbus-next');
      out.tools['dbus-next (npm)'] = true;
    } catch (e) {
      const runtimeDbus = '/usr/local/lib/nix-panel/node_modules/dbus-next/package.json';
      out.tools['dbus-next (npm)'] = fs.existsSync(runtimeDbus);
      if (out.tools['dbus-next (npm)']) out.notes.push('dbus-next найден в runtime-каталоге Wayland.');
    }
    try {
      const ctx = await buildContext();
      out.session = ctx.sess;
      out.user = ctx.user;
      out.envSource = ctx.envSource || 'не найден (использованы значения по умолчанию)';
      out.env = Object.fromEntries(Object.entries(ctx.env).filter(([k]) => k !== 'PATH'));
      out.runAsUid = ctx.spawnOpts.uid !== undefined ? ctx.spawnOpts.uid : out.node.uid;
      if (ctx.type === 'wayland') {
        const inputMode = config.waylandInput || 'portal';
        out.waylandInput = inputMode === 'ydotool'
          ? 'ydotool (явно включён в конфиге)'
          : 'portal (KDE RemoteDesktop, основной режим)';
        if (!out.tools.spectacle && !out.tools.grim) out.notes.push('Нет grim и spectacle — скриншот на KDE Wayland невозможен.');
        if (inputMode === 'ydotool') {
          out.waylandMove = config.waylandMove === 'absolute'
            ? 'absolute (сырой ydotool --absolute, известно что промахивается на многих версиях)'
            : 'homing (прижим к (0,0) + шаги до цели, режим по умолчанию)';
          if (!out.tools.ydotool) {
            out.notes.push('Нет ydotool — управление мышью/клавиатурой не заработает.');
          } else {
            const procs = await listYdotooldProcs();
            if (procs.length) out.ydotooldProcesses = procs;
            if (procs.length > 1) out.notes.push('Запущено больше одного ydotoold — старые (например, с ручных запусков) стоит убить: они могли забрать /dev/uinput и не пускать новый.');
            try {
              await ensureYdotoolSocket(ctx);
              out.ydotoold = { socket: ctx.env.YDOTOOL_SOCKET, alive: true };
            } catch (e) {
              out.ydotoold = { alive: false, error: e.message };
              out.notes.push('ydotoold не поднялся: ' + e.message);
            }
          }
        } else if (!out.tools['dbus-next (npm)']) {
          out.notes.push('Не установлен npm-пакет dbus-next — портал ввода работать не будет (npm install dbus-next в папке панели).');
        } else {
          const workerPath = process.env.NIX_REMOTE_WORKER && path.isAbsolute(process.env.NIX_REMOTE_WORKER)
    ? process.env.NIX_REMOTE_WORKER
    : '/usr/local/lib/nix-panel/remote-portal-worker.js';
          out.portalWorker = getPortalWorkerInfo(workerPath);
          // Поднимаем/переиспользуем воркер и коротко ждём, чтобы диагностика
          // застала актуальное состояние, а не только "ещё запускается".
          const worker = getPortalWorker(ctx);
          for (let i = 0; i < 60 && worker.state === 'starting'; i++) await sleep(50);
          out.portal = { state: worker.state };
          if (worker.state === 'dead') { out.portal.error = worker.fatalError; out.notes.push('Воркер портала упал: ' + worker.fatalError); }
          if (worker.state === 'awaiting-auth') out.notes.push('Портал ждёт подтверждения в GUI (или предавторизация не сработала — нужна Plasma 6.3+).');
        }
      } else {
        if (!out.tools.xdotool) out.notes.push('Нет xdotool — управление не заработает.');
        if (!ctx.env.XAUTHORITY) out.notes.push('XAUTHORITY не найден — возможно, X-сервер не пустит клиента.');
      }
      const t0 = Date.now();
      try {
        const buf = await captureScreen();
        out.screenshot = { ok: true, ms: Date.now() - t0, bytes: buf.length };
      } catch (e) {
        out.screenshot = { ok: false, ms: Date.now() - t0, error: e.message };
      }
    } catch (e) {
      out.error = e.message;
    }
    res.json(out);
  });

  return router;
};
