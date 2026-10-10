#!/usr/bin/env node
'use strict';
/**
 * Воркер ввода мыши/клавиатуры на KDE Wayland через
 * org.freedesktop.portal.RemoteDesktop — вместо ydotool/uinput.
 *
 * ОБЯЗАН запускаться от пользователя графической сессии (не от root через
 * голый setuid) — сессионная шина D-Bus проверяет реальный uid подключаю-
 * щегося процесса через SO_PEERCRED, файловые права тут ни при чём и root
 * их обойти не может. Родитель (remote.js) обязан стартовать этот файл
 * через `runuser -u <user> --`, не просто со сменой uid/gid.
 *
 * Протокол с родителем — построчный JSON:
 *   родитель -> воркер:
 *     {"id":1,"cmd":"move","dx":10,"dy":-4}
 *     {"id":2,"cmd":"button","code":272,"pressed":true}
 *     {"id":3,"cmd":"key","code":30,"pressed":true}
 *   воркер -> родитель:
 *     {"event":"awaiting-auth"}     — портал ждёт клика "Разрешить" в GUI
 *     {"event":"ready"}             — сессия поднята, можно слать команды
 *     {"event":"fatal","error":"…"} — воркер не смог стартовать вообще
 *     {"id":1,"ok":true}
 *     {"id":2,"ok":false,"error":"…"}
 */

let dbus;
try {
  dbus = require('dbus-next');
} catch (e) {
  send({ event: 'fatal', error: 'пакет dbus-next не установлен (npm install dbus-next в папке панели)' });
  process.exit(1);
}
const Variant = dbus.Variant;

const PORTAL_DEST = 'org.freedesktop.portal.Desktop';
const PORTAL_PATH = '/org/freedesktop/portal/desktop';
const TOKEN_FILE = process.env.PORTAL_TOKEN_FILE
  || require('path').join(process.env.HOME || '/tmp', '.nix-panel-portal-token');

let seq = 0;
const uniq = prefix => `nixpanel_${prefix}_${Date.now()}_${seq++}`;
function send(obj) { process.stdout.write(JSON.stringify(obj) + '\n'); }

/** Ждёт сигнал Response на объекте запроса и возвращает его results (уже без Variant-обёрток). */
function waitResponse(bus, requestPath) {
  return new Promise(async (resolve, reject) => {
    let iface;
    try {
      const obj = await bus.getProxyObject(PORTAL_DEST, requestPath);
      iface = obj.getInterface('org.freedesktop.portal.Request');
    } catch (e) { return reject(e); }
    const timer = setTimeout(() => reject(new Error('портал не ответил за 5 минут')), 5 * 60 * 1000);
    iface.once('Response', (code, results) => {
      clearTimeout(timer);
      if (code !== 0) return reject(new Error(code === 1 ? 'пользователь отклонил запрос в диалоге' : `портал вернул код ${code}`));
      const plain = {};
      for (const k in results) plain[k] = results[k] && 'value' in results[k] ? results[k].value : results[k];
      resolve(plain);
    });
  });
}

/** Best-effort предавторизация через таблицу kde-authorized (Plasma 6.3+). Не критично, если не выйдет. */
async function tryPreAuthorize(bus) {
  try {
    // PermissionStore — отдельное well-known имя шины, НЕ то же самое, что
    // основной org.freedesktop.portal.Desktop.
    const obj = await bus.getProxyObject('org.freedesktop.impl.portal.PermissionStore', '/org/freedesktop/impl/portal/PermissionStore');
    const iface = obj.getInterface('org.freedesktop.impl.portal.PermissionStore');
    // table, create, id, app_id (пусто = «неизвестное хост-приложение»), permissions
    await iface.SetPermission('kde-authorized', true, 'remote-desktop', '', ['yes']);
    return true;
  } catch (e) {
    return false; // старая Plasma без этой таблицы, или прав нет — ничего страшного
  }
}

function loadToken() {
  try { return require('fs').readFileSync(TOKEN_FILE, 'utf8').trim() || null; } catch (e) { return null; }
}
function saveToken(tok) {
  try { require('fs').writeFileSync(TOKEN_FILE, tok, { mode: 0o600 }); } catch (e) { /* не критично */ }
}

async function main() {
  const busAddress = process.env.DBUS_SESSION_BUS_ADDRESS;
  if (!busAddress) { send({ event: 'fatal', error: 'нет DBUS_SESSION_BUS_ADDRESS в окружении' }); process.exit(1); }
  const bus = dbus.sessionBus({ busAddress });
  bus.on('error', () => {}); // не роняем процесс на фоновых ошибках соединения

  const portalObj = await bus.getProxyObject(PORTAL_DEST, PORTAL_PATH);
  const rd = portalObj.getInterface('org.freedesktop.portal.RemoteDesktop');

  await tryPreAuthorize(bus);

  // 1) CreateSession
  const createReqPath = await rd.CreateSession({ session_handle_token: new Variant('s', uniq('handle')) });
  const createResult = await waitResponse(bus, createReqPath);
  const sessionHandle = createResult.session_handle;
  if (!sessionHandle) throw new Error('портал не вернул session_handle');

  // 2) SelectDevices — клавиатура(1) + указатель(2), с попыткой переиспользовать сохранённый restore_token
  const savedToken = loadToken();
  const selectOptions = {
    types: new Variant('u', 3),
    persist_mode: new Variant('u', 2), // 2 = помнить, пока явно не отзовут
  };
  if (savedToken) selectOptions.restore_token = new Variant('s', savedToken);
  const selectReqPath = await rd.SelectDevices(sessionHandle, selectOptions);
  await waitResponse(bus, selectReqPath);

  // 3) Start — вот тут может показаться диалог, если ни предавторизация,
  // ни restore_token не сработали.
  send({ event: 'awaiting-auth' });
  const startReqPath = await rd.Start(sessionHandle, '', {});
  const startResult = await waitResponse(bus, startReqPath);
  if (startResult.restore_token) saveToken(startResult.restore_token);

  send({ event: 'ready' });

  // 4) Обычные команды с этого момента
  const readline = require('readline');
  const rl = readline.createInterface({ input: process.stdin });
  rl.on('line', async line => {
    let msg;
    try { msg = JSON.parse(line); } catch (e) { return; }
    try {
      switch (msg.cmd) {
        case 'move':
          await rd.NotifyPointerMotion(sessionHandle, {}, Number(msg.dx) || 0, Number(msg.dy) || 0);
          break;
        case 'button':
          await rd.NotifyPointerButton(sessionHandle, {}, Number(msg.code), msg.pressed ? 1 : 0);
          break;
        case 'key':
          await rd.NotifyKeyboardKeycode(sessionHandle, {}, Number(msg.code), msg.pressed ? 1 : 0);
          break;
        default:
          throw new Error('неизвестная команда воркера: ' + msg.cmd);
      }
      send({ id: msg.id, ok: true });
    } catch (e) {
      send({ id: msg.id, ok: false, error: e.message });
    }
  });
}

main().catch(e => { send({ event: 'fatal', error: e.message }); process.exit(1); });
