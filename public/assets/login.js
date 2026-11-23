'use strict';

const LOGIN_I18N = {
  ru: { language: 'Язык', errorMsg: 'Неверный логин или пароль', loginLabel: 'Логин', loginPh: 'Введите логин', passLabel: 'Пароль', passPh: 'Введите пароль', btn: 'Войти', loading: 'Выполняется вход…', footer: 'NIX Panel · управление сервером', title: 'Вход | NIX Panel', welcome: 'С возвращением', description: 'Войдите в защищённую панель управления вашим сервером.', brandCaption: 'Сервер под контролем', brandText: 'Файлы, процессы, терминал и удалённый рабочий стол в одном интерфейсе.', feature1: 'Мониторинг в реальном времени', feature2: 'Гранулярные права доступа', feature3: 'Защищённые сессии' },
  en: { language: 'Language', errorMsg: 'Invalid username or password', loginLabel: 'Username', loginPh: 'Enter your username', passLabel: 'Password', passPh: 'Enter your password', btn: 'Sign in', loading: 'Signing in…', footer: 'NIX Panel · server management', title: 'Sign in | NIX Panel', welcome: 'Welcome back', description: 'Sign in to the secure control panel for your server.', brandCaption: 'Your server, under control', brandText: 'Files, processes, terminal and remote desktop in one interface.', feature1: 'Real-time monitoring', feature2: 'Granular access control', feature3: 'Protected sessions' },
  de: { language: 'Sprache', errorMsg: 'Ungültiger Benutzername oder ungültiges Passwort', loginLabel: 'Benutzername', loginPh: 'Benutzername eingeben', passLabel: 'Passwort', passPh: 'Passwort eingeben', btn: 'Anmelden', loading: 'Anmeldung…', footer: 'NIX Panel · Serververwaltung', title: 'Anmelden | NIX Panel', welcome: 'Willkommen zurück', description: 'Melden Sie sich bei der sicheren Verwaltungsoberfläche Ihres Servers an.', brandCaption: 'Ihr Server unter Kontrolle', brandText: 'Dateien, Prozesse, Terminal und Remote-Desktop in einer Oberfläche.', feature1: 'Echtzeit-Monitoring', feature2: 'Granulare Zugriffsrechte', feature3: 'Geschützte Sitzungen' },
  fr: { language: 'Langue', errorMsg: 'Nom d’utilisateur ou mot de passe incorrect', loginLabel: 'Nom d’utilisateur', loginPh: 'Saisissez votre identifiant', passLabel: 'Mot de passe', passPh: 'Saisissez votre mot de passe', btn: 'Se connecter', loading: 'Connexion…', footer: 'NIX Panel · gestion du serveur', title: 'Connexion | NIX Panel', welcome: 'Bon retour', description: 'Connectez-vous au panneau de contrôle sécurisé de votre serveur.', brandCaption: 'Votre serveur sous contrôle', brandText: 'Fichiers, processus, terminal et bureau distant dans une seule interface.', feature1: 'Supervision en temps réel', feature2: 'Droits d’accès granulaires', feature3: 'Sessions protégées' },
  es: { language: 'Idioma', errorMsg: 'Usuario o contraseña incorrectos', loginLabel: 'Usuario', loginPh: 'Introduce tu usuario', passLabel: 'Contraseña', passPh: 'Introduce tu contraseña', btn: 'Iniciar sesión', loading: 'Iniciando sesión…', footer: 'NIX Panel · administración del servidor', title: 'Iniciar sesión | NIX Panel', welcome: 'Bienvenido de nuevo', description: 'Accede al panel de control seguro de tu servidor.', brandCaption: 'Tu servidor bajo control', brandText: 'Archivos, procesos, terminal y escritorio remoto en una sola interfaz.', feature1: 'Monitorización en tiempo real', feature2: 'Permisos de acceso granulares', feature3: 'Sesiones protegidas' },
  zh: { language: '语言', errorMsg: '用户名或密码错误', loginLabel: '用户名', loginPh: '输入用户名', passLabel: '密码', passPh: '输入密码', btn: '登录', loading: '正在登录…', footer: 'NIX Panel · 服务器管理', title: '登录 | NIX Panel', welcome: '欢迎回来', description: '登录到安全的服务器管理面板。', brandCaption: '掌控您的服务器', brandText: '在一个界面中管理文件、进程、终端和远程桌面。', feature1: '实时监控', feature2: '精细的访问权限', feature3: '受保护的会话' }
};
let currentLanguage = 'ru';

function applyLoginLang(selected) {
  const candidate = selected || (navigator.language || 'ru').slice(0, 2).toLowerCase();
  currentLanguage = LOGIN_I18N[candidate] ? candidate : 'en';
  const dictionary = LOGIN_I18N[currentLanguage];
  document.getElementById('language').value = currentLanguage;
  try { localStorage.setItem('nix-language', currentLanguage); } catch (error) {}
  document.querySelectorAll('[data-t]').forEach(element => {
    if (dictionary[element.dataset.t]) element.textContent = dictionary[element.dataset.t];
  });
  document.querySelectorAll('[data-t-placeholder]').forEach(element => {
    if (dictionary[element.dataset.tPlaceholder]) element.placeholder = dictionary[element.dataset.tPlaceholder];
  });
  document.title = dictionary.title;
  document.documentElement.lang = currentLanguage;
}

function showError(message) {
  const error = document.getElementById('error');
  error.textContent = message || LOGIN_I18N[currentLanguage].errorMsg;
  error.hidden = false;
}

Object.assign(LOGIN_I18N.ru, { twoFactorLabel: 'Код из Authenticator', twoFactorPh: '6 цифр', twoFactorHint: 'Откройте приложение и введите текущий код.', confirm: 'Подтвердить', back: 'Назад' });
Object.assign(LOGIN_I18N.en, { twoFactorLabel: 'Authenticator code', twoFactorPh: '6 digits', twoFactorHint: 'Open your authenticator app and enter the current code.', confirm: 'Verify', back: 'Back' });
Object.assign(LOGIN_I18N.de, { twoFactorLabel: 'Authenticator-Code', twoFactorPh: '6 Ziffern', twoFactorHint: 'Öffnen Sie die Authenticator-App und geben Sie den aktuellen Code ein.', confirm: 'Bestätigen', back: 'Zurück' });
Object.assign(LOGIN_I18N.fr, { twoFactorLabel: 'Code Authenticator', twoFactorPh: '6 chiffres', twoFactorHint: 'Ouvrez votre application et saisissez le code actuel.', confirm: 'Confirmer', back: 'Retour' });
Object.assign(LOGIN_I18N.es, { twoFactorLabel: 'Código de Authenticator', twoFactorPh: '6 dígitos', twoFactorHint: 'Abra la aplicación e introduzca el código actual.', confirm: 'Confirmar', back: 'Volver' });
Object.assign(LOGIN_I18N.zh, { twoFactorLabel: '身份验证器验证码', twoFactorPh: '6 位数字', twoFactorHint: '打开验证器应用并输入当前验证码。', confirm: '确认', back: '返回' });

let twoFactorToken = '';
function setTwoFactorStep(active) {
  document.getElementById('loginField').hidden = active;
  document.getElementById('passwordField').hidden = active;
  document.getElementById('twoFactorField').hidden = !active;
  document.getElementById('credentialsBack').hidden = !active;
  document.getElementById('login').required = !active;
  document.getElementById('password').required = !active;
  document.getElementById('twoFactorCode').required = active;
  document.getElementById('error').hidden = true;
  document.querySelector('#loginButton [data-t="btn"]').textContent = LOGIN_I18N[currentLanguage][active ? 'confirm' : 'btn'];
  if (active) document.getElementById('twoFactorCode').focus();
}
async function doLogin(event) {
  event.preventDefault();
  const button = document.getElementById('loginButton');
  const passwordInput = document.getElementById('password');
  const error = document.getElementById('error');
  const secondFactor = !!twoFactorToken;
  error.hidden = true;
  button.disabled = true;
  button.dataset.loading = 'true';
  button.querySelector('[data-t="btn"]').textContent = LOGIN_I18N[currentLanguage].loading;
  const controller = new AbortController();
  const timeout = setTimeout(() => controller.abort(), 12000);
  try {
    const response = await fetch(secondFactor ? '/api/login/2fa' : '/api/login', {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify(secondFactor
        ? { token: twoFactorToken, code: document.getElementById('twoFactorCode').value.trim() }
        : { login: document.getElementById('login').value.trim(), password: passwordInput.value }),
      signal: controller.signal
    });
    const data = await response.json().catch(() => ({}));
    if (response.ok && data.requiresTwoFactor && data.token) {
      twoFactorToken = String(data.token);
      passwordInput.value = '';
      setTwoFactorStep(true);
      return;
    }
    if (!response.ok) {
      showError(data.message || data.error || LOGIN_I18N[currentLanguage].errorMsg);
      if (secondFactor) document.getElementById('twoFactorCode').select();
      else passwordInput.select();
      return;
    }
    twoFactorToken = '';
    window.location.replace('/');
  } catch (requestError) {
    showError(requestError.name === 'AbortError' ? 'Сервер не отвечает. Проверьте соединение.' : requestError.message);
  } finally {
    clearTimeout(timeout);
    button.disabled = false;
    button.dataset.loading = 'false';
    button.querySelector('[data-t="btn"]').textContent = LOGIN_I18N[currentLanguage][twoFactorToken ? 'confirm' : 'btn'];
  }
}

try { applyLoginLang(localStorage.getItem('nix-language') || undefined); } catch (error) { applyLoginLang(); }
document.getElementById('language').addEventListener('change', event => applyLoginLang(event.target.value));
document.getElementById('loginForm').addEventListener('submit', doLogin);
document.getElementById('credentialsBack').addEventListener('click', () => {
  twoFactorToken = '';
  document.getElementById('twoFactorCode').value = '';
  setTwoFactorStep(false);
  document.getElementById('login').focus();
});
document.getElementById('twoFactorCode').addEventListener('input', event => {
  event.target.value = event.target.value.replace(/\D/g, '').slice(0, 6);
});
