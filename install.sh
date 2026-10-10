#!/usr/bin/env bash

# NIX Panel - version
PANEL_VERSION="2.2.0"
VERSION_FILE="/opt/NIX/VERSION"

# =============================================================================
# NIX PANEL v2 - Установщик для Ubuntu 24+
# =============================================================================
set -e

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
CYAN='\033[0;36m'
NC='\033[0m'
BOLD='\033[1m'

# Save script directory IMMEDIATELY — before any cd changes the working dir
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd 2>/dev/null)"
SCRIPT_DIR="${SCRIPT_DIR//$'\r'/}"
if [ -z "$SCRIPT_DIR" ] || [ "$SCRIPT_DIR" = "." ] || [[ "$SCRIPT_DIR" != /* ]]; then
    SCRIPT_DIR="$(pwd)"
fi

# =============================================================================
# FUNCTIONS
# =============================================================================
print_banner() {
    clear
    echo -e "${PURPLE}"
    echo "  ╔══════════════════════════════════════════════╗"
    echo "  ║              NIX PANEL v2.2.0                ║"
    case "$INSTALLER_LANG" in
        ru) echo "  ║             Управление сервером              ║" ;;
        en) echo "  ║             Server Management                ║" ;;
        de) echo "  ║             Serververwaltung                 ║" ;;
        fr) echo "  ║              Gestion serveur                 ║" ;;
        es) echo "  ║            Gestión del servidor              ║" ;;
        zh) echo "  ║                 服务器管理                   ║" ;;
        *) echo "  ║             Server Management                ║" ;;
    esac
    echo "  ╚══════════════════════════════════════════════╝"
    echo -e "${NC}"
    echo -e "${CYAN}  Ubuntu 24+ | Node.js | Express | Socket.IO${NC}"
    echo ""
}

print_step() {
    echo -e "\n${BLUE}┌─ ${BOLD}$(localize "Шаг") ${1}/${TOTAL_STEPS}:${NC} $(localize "$2")"
    echo -e "${BLUE}└${NC}"
}

print_info() {
    echo -e "  ${CYAN}ℹ${NC} $(localize "$1")"
}

print_ok() {
    echo -e "  ${GREEN}✓${NC} $(localize "$1")"
}

print_warn() {
    echo -e "  ${YELLOW}⚠${NC} $(localize "$1")"
}

print_err() {
    echo -e "  ${RED}✗${NC} $(localize "$1")"
}

print_question() {
    echo -e "  ${PURPLE}?${NC} $(localize "$1")"
}

# Select the installer output language and the default panel language up front.
INSTALLER_LANG="en"
PANEL_LANGUAGE="en"
localize_summary() {
    [ "$INSTALLER_LANG" = "ru" ] && { printf '%s' "$1"; return; }
    case "$INSTALLER_LANG|$1" in
      en\|"УСТАНОВКА ЗАВЕРШЕНА!") echo "INSTALLATION COMPLETE!";; de\|"УСТАНОВКА ЗАВЕРШЕНА!") echo "INSTALLATION ABGESCHLOSSEN!";; fr\|"УСТАНОВКА ЗАВЕРШЕНА!") echo "INSTALLATION TERMINÉE !";; es\|"УСТАНОВКА ЗАВЕРШЕНА!") echo "¡INSTALACIÓN COMPLETADA!";; zh\|"УСТАНОВКА ЗАВЕРШЕНА!") echo "安装完成！";;
      en\|"URL панели:") echo "Panel URL:";; de\|"URL панели:") echo "Panel-URL:";; fr\|"URL панели:") echo "URL du panneau :";; es\|"URL панели:") echo "URL del panel:";; zh\|"URL панели:") echo "面板网址：";;
      en\|"по IP") echo "by IP";; de\|"по IP") echo "über IP";; fr\|"по IP") echo "par IP";; es\|"по IP") echo "por IP";; zh\|"по IP") echo "通过 IP";;
      en\|"Админ:") echo "Admin:";; de\|"Админ:") echo "Admin:";; fr\|"Админ:") echo "Admin :";; es\|"Админ:") echo "Admin:";; zh\|"Админ:") echo "管理员：";;
      en\|"Пароль:") echo "Password:";; de\|"Пароль:") echo "Passwort:";; fr\|"Пароль:") echo "Mot de passe :";; es\|"Пароль:") echo "Contraseña:";; zh\|"Пароль:") echo "密码：";;
      en\|"РЕЗЕРВНЫЙ ПАРОЛЬ БЕЗОПАСНОСТИ:") echo "BACKUP SECURITY PASSWORD:";; de\|"РЕЗЕРВНЫЙ ПАРОЛЬ БЕЗОПАСНОСТИ:") echo "SICHERHEITS-ERSATZPASSWORT:";; fr\|"РЕЗЕРВНЫЙ ПАРОЛЬ БЕЗОПАСНОСТИ:") echo "MOT DE PASSE DE SECOURS :";; es\|"РЕЗЕРВНЫЙ ПАРОЛЬ БЕЗОПАСНОСТИ:") echo "CONTRASEÑA DE SEGURIDAD DE RESPALDO:";; zh\|"РЕЗЕРВНЫЙ ПАРОЛЬ БЕЗОПАСНОСТИ:") echo "安全恢复密码：";;
      en\|"Этот пароль будет выдан только 1 раз. Сохраните его вне сервера.") echo "This password is shown only once. Save it somewhere off the server.";; de\|"Этот пароль будет выдан только 1 раз. Сохраните его вне сервера.") echo "Dieses Passwort wird nur einmal angezeigt. Speichern Sie es außerhalb des Servers.";; fr\|"Этот пароль будет выдан только 1 раз. Сохраните его вне сервера.") echo "Ce mot de passe ne sera affiché qu’une fois. Conservez-le hors du serveur.";; es\|"Этот пароль будет выдан только 1 раз. Сохраните его вне сервера.") echo "Esta contraseña se mostrará una sola vez. Guárdala fuera del servidor.";; zh\|"Этот пароль будет выдан только 1 раз. Сохраните его вне сервера.") echo "此密码仅显示一次。请将其保存在服务器之外。";;
      en\|"Папка:") echo "Directory:";; de\|"Папка:") echo "Verzeichnis:";; fr\|"Папка:") echo "Dossier :";; es\|"Папка:") echo "Carpeta:";; zh\|"Папка:") echo "目录：";;
      en\|"Порт:") echo "Port:";; de\|"Порт:") echo "Port:";; fr\|"Порт:") echo "Port :";; es\|"Порт:") echo "Puerto:";; zh\|"Порт:") echo "端口：";;
      en\|"Лог:") echo "Log:";; de\|"Лог:") echo "Protokoll:";; fr\|"Лог:") echo "Journal :";; es\|"Лог:") echo "Registro:";; zh\|"Лог:") echo "日志：";;
      en\|"Команды:") echo "Commands:";; de\|"Команды:") echo "Befehle:";; fr\|"Команды:") echo "Commandes :";; es\|"Команды:") echo "Comandos:";; zh\|"Команды:") echo "命令：";;
      en\|"Запуск:") echo "Start:";; de\|"Запуск:") echo "Start:";; fr\|"Запуск:") echo "Démarrer :";; es\|"Запуск:") echo "Iniciar:";; zh\|"Запуск:") echo "启动：";;
      en\|"Стоп:") echo "Stop:";; de\|"Стоп:") echo "Stopp:";; fr\|"Стоп:") echo "Arrêter :";; es\|"Стоп:") echo "Detener:";; zh\|"Стоп:") echo "停止：";;
      en\|"Статус:") echo "Status:";; de\|"Статус:") echo "Status:";; fr\|"Статус:") echo "État :";; es\|"Статус:") echo "Estado:";; zh\|"Статус:") echo "状态：";;
      en\|"Логи:") echo "Logs:";; de\|"Логи:") echo "Protokolle:";; fr\|"Логи:") echo "Journaux :";; es\|"Логи:") echo "Registros:";; zh\|"Логи:") echo "日志：";;
      en\|"⚠ Сохраните логин и пароль!") echo "⚠ Save your username and password!";; de\|"⚠ Сохраните логин и пароль!") echo "⚠ Speichern Sie Benutzername und Passwort!";; fr\|"⚠ Сохраните логин и пароль!") echo "⚠ Conservez votre identifiant et votre mot de passe !";; es\|"⚠ Сохраните логин и пароль!") echo "⚠ ¡Guarda el usuario y la contraseña!";; zh\|"⚠ Сохраните логин и пароль!") echo "⚠ 请保存用户名和密码！";;
      en\|"После перезагрузки панель запустится автоматически.") echo "The panel will start automatically after reboot.";; de\|"После перезагрузки панель запустится автоматически.") echo "Das Panel startet nach einem Neustart automatisch.";; fr\|"После перезагрузки панель запустится автоматически.") echo "Le panneau démarrera automatiquement après le redémarrage.";; es\|"После перезагрузки панель запустится автоматически.") echo "El panel se iniciará automáticamente tras reiniciar.";; zh\|"После перезагрузки панель запустится автоматически.") echo "重启后面板将自动启动。";;
      en\|"Проверка файлов:") echo "File check:";; de\|"Проверка файлов:") echo "Dateiprüfung:";; fr\|"Проверка файлов:") echo "Vérification des fichiers :";; es\|"Проверка файлов:") echo "Comprobación de archivos:";; zh\|"Проверка файлов:") echo "文件检查：";;
      en\|"server.js найден") echo "server.js found";; de\|"server.js найден") echo "server.js gefunden";; fr\|"server.js найден") echo "server.js trouvé";; es\|"server.js найден") echo "server.js encontrado";; zh\|"server.js найден") echo "已找到 server.js";;
      en\|" (сохранён в users.json)") echo "(saved in users.json)";; de\|" (сохранён в users.json)") echo "(in users.json gespeichert)";; fr\|" (сохранён в users.json)") echo "(enregistré dans users.json)";; es\|" (сохранён в users.json)") echo "(guardado en users.json)";; zh\|" (сохранён в users.json)") echo "（已保存在 users.json）";;
      en\|"server.js ОТСУТСТВУЕТ! Панель не будет работать.") echo "server.js is MISSING! The panel will not work.";; de\|"server.js ОТСУТСТВУЕТ! Панель не будет работать.") echo "server.js FEHLT! Das Panel funktioniert nicht.";; fr\|"server.js ОТСУТСТВУЕТ! Панель не будет работать.") echo "server.js MANQUANT ! Le panneau ne fonctionnera pas.";; es\|"server.js ОТСУТСТВУЕТ! Панель не будет работать.") echo "¡FALTA server.js! El panel no funcionará.";; zh\|"server.js ОТСУТСТВУЕТ! Панель не будет работать.") echo "缺少 server.js！面板将无法运行。";;
      en\|"Скопируйте файлы вручную: "*) printf 'Copy the files manually: %s' "${1#Скопируйте файлы вручную: }";; de\|"Скопируйте файлы вручную: "*) printf 'Dateien manuell kopieren: %s' "${1#Скопируйте файлы вручную: }";; fr\|"Скопируйте файлы вручную : "*) printf 'Copiez les fichiers manuellement : %s' "${1#Скопируйте файлы вручную: }";; es\|"Скопируйте файлы вручную: "*) printf 'Copia los archivos manualmente: %s' "${1#Скопируйте файлы вручную: }";; zh\|"Скопируйте файлы вручную: "*) printf '请手动复制文件：%s' "${1#Скопируйте файлы вручную: }";;
      en\|"node_modules найдены") echo "node_modules found";; de\|"node_modules найдены") echo "node_modules gefunden";; fr\|"node_modules найдены") echo "node_modules trouvé";; es\|"node_modules найдены") echo "node_modules encontrado";; zh\|"node_modules найдены") echo "已找到 node_modules";;
      en\|"node_modules ОТСУТСТВУЮТ! Запустите: "*) printf 'node_modules are MISSING! Run: %s' "${1#node_modules ОТСУТСТВУЮТ! Запустите: }";; de\|"node_modules ОТСУТСТВУЮТ! Запустите: "*) printf 'node_modules FEHLEN! Ausführen: %s' "${1#node_modules ОТСУТСТВУЮТ! Запустите: }";; fr\|"node_modules ОТСУТСТВУЮТ! Запустите: "*) printf 'node_modules MANQUANT ! Exécutez : %s' "${1#node_modules ОТСУТСТВУЮТ! Запустите: }";; es\|"node_modules ОТСУТСТВУЮТ! Запустите: "*) printf 'Falta node_modules. Ejecuta: %s' "${1#node_modules ОТСУТСТВУЮТ! Запустите: }";; zh\|"node_modules ОТСУТСТВУЮТ! Запустите: "*) printf '缺少 node_modules！请运行：%s' "${1#node_modules ОТСУТСТВУЮТ! Запустите: }";;
      en\|"Панель не отвечает. Проверьте лог:") echo "The panel is not responding. Check the log:";; de\|"Панель не отвечает. Проверьте лог:") echo "Das Panel antwortet nicht. Protokoll prüfen:";; fr\|"Панель не отвечает. Проверьте лог:") echo "Le panneau ne répond pas. Consultez le journal :";; es\|"Панель не отвечает. Проверьте лог:") echo "El panel no responde. Revisa el registro:";; zh\|"Панель не отвечает. Проверьте лог:") echo "面板无响应。请查看日志：";;      en\|"Проверка панели:") echo "Panel check:";; de\|"Проверка панели:") echo "Panelprüfung:";; fr\|"Проверка панели:") echo "Vérification du panneau :";; es\|"Проверка панели:") echo "Comprobación del panel:";; zh\|"Проверка панели:") echo "面板检查：";;
      en\|"Панель работает! (попытка "*) printf 'Panel is running! (attempt %s)' "${1#*попытка }";; de\|"Панель работает! (попытка "*) printf 'Panel läuft! (Versuch %s)' "${1#*попытка }";; fr\|"Панель работает! (попытка "*) printf 'Le panneau fonctionne ! (tentative %s)' "${1#*попытка }";; es\|"Панель работает! (попытка "*) printf '¡El panel funciona! (intento %s)' "${1#*попытка }";; zh\|"Панель работает! (попытка "*) printf '面板运行正常！（第 %s 次尝试）' "${1#*попытка }";;
      *) return 1;;
    esac
}
localize() {
    local msg="$1"
    [ "$INSTALLER_LANG" = "ru" ] && { printf '%s' "$msg"; return; }
    local summary_translation; summary_translation=$(localize_summary "$msg") && { printf '%s' "$summary_translation"; return; }
    case "$INSTALLER_LANG|$msg" in
      en\|"Этот скрипт нужно запускать с правами root!") echo "Run this script as root!"; return;;
      de\|"Этот скрипт нужно запускать с правами root!") echo "Dieses Skript muss als root ausgeführt werden!"; return;;
      fr\|"Этот скрипт нужно запускать с правами root!") echo "Ce script doit être exécuté en tant que root !"; return;;
      es\|"Этот скрипт нужно запускать с правами root!") echo "¡Este script debe ejecutarse como root!"; return;;
      zh\|"Этот скрипт нужно запускать с правами root!") echo "请以 root 身份运行此脚本！"; return;;
      en\|"Используйте: sudo bash install.sh") echo "Use: sudo bash install.sh"; return;;
      de\|"Используйте: sudo bash install.sh") echo "Verwenden Sie: sudo bash install.sh"; return;;
      fr\|"Используйте: sudo bash install.sh") echo "Utilisez : sudo bash install.sh"; return;;
      es\|"Используйте: sudo bash install.sh") echo "Usa: sudo bash install.sh"; return;;
      zh\|"Используйте: sudo bash install.sh") echo "请使用：sudo bash install.sh"; return;;
      en\|"Выход.") echo "Exit."; return;;
      de\|"Выход.") echo "Beenden."; return;;
      fr\|"Выход.") echo "Quitter."; return;;
      es\|"Выход.") echo "Salir."; return;;
      zh\|"Выход.") echo "退出。"; return;;
      en\|"Копирование из текущей папки ("*) local value="${msg#Копирование из текущей папки (}"; value="${value%)*}"; printf "Copying from the current directory (%s)..." "$value"; return;;
      de\|"Копирование из текущей папки ("*) local value="${msg#Копирование из текущей папки (}"; value="${value%)*}"; printf "Kopieren aus dem aktuellen Verzeichnis (%s)..." "$value"; return;;
      fr\|"Копирование из текущей папки ("*) local value="${msg#Копирование из текущей папки (}"; value="${value%)*}"; printf "Copie depuis le dossier actuel (%s)…" "$value"; return;;
      es\|"Копирование из текущей папки ("*) local value="${msg#Копирование из текущей папки (}"; value="${value%)*}"; printf "Copiando desde la carpeta actual (%s)…" "$value"; return;;
      zh\|"Копирование из текущей папки ("*) local value="${msg#Копирование из текущей папки (}"; value="${value%)*}"; printf "正在从当前目录（%s）复制…" "$value"; return;;
      en\|"Копирование из предыдущей установки ("*) local value="${msg#Копирование из предыдущей установки (}"; value="${value%)*}"; printf "Copying from the previous installation (%s)..." "$value"; return;;
      de\|"Копирование из предыдущей установки ("*) local value="${msg#Копирование из предыдущей установки (}"; value="${value%)*}"; printf "Kopieren aus der vorherigen Installation (%s)..." "$value"; return;;
      fr\|"Копирование из предыдущей установки ("*) local value="${msg#Копирование из предыдущей установки (}"; value="${value%)*}"; printf "Copie depuis l’installation précédente (%s)…" "$value"; return;;
      es\|"Копирование из предыдущей установки ("*) local value="${msg#Копирование из предыдущей установки (}"; value="${value%)*}"; printf "Copiando desde la instalación anterior (%s)…" "$value"; return;;
      zh\|"Копирование из предыдущей установки ("*) local value="${msg#Копирование из предыдущей установки (}"; value="${value%)*}"; printf "正在从先前安装目录（%s）复制…" "$value"; return;;
      en\|Папка*не\ пуста!*) local value="${msg#Папка }"; value="${value% не пуста!}"; printf "Directory %s is not empty!" "$value"; return;;
      de\|Папка*не\ пуста!*) local value="${msg#Папка }"; value="${value% не пуста!}"; printf "Verzeichnis %s ist nicht leer!" "$value"; return;;
      fr\|Папка*не\ пуста!*) local value="${msg#Папка }"; value="${value% не пуста!}"; printf "Le dossier %s n’est pas vide !" "$value"; return;;
      es\|Папка*не\ пуста!*) local value="${msg#Папка }"; value="${value% не пуста!}"; printf "¡La carpeta %s no está vacía!" "$value"; return;;
      zh\|Папка*не\ пуста!*) local value="${msg#Папка }"; value="${value% не пуста!}"; printf "目录“%s”不为空！" "$value"; return;;
      en\|"Выберите действие:") echo "Choose an action:"; return;; de\|"Выберите действие:") echo "Aktion auswählen:"; return;; fr\|"Выберите действие:") echo "Choisir une action :"; return;; es\|"Выберите действие:") echo "Elige una acción:"; return;; zh\|"Выберите действие:") echo "选择操作："; return;;
      en\|"Управление сервером") echo "Server Management"; return;; de\|"Управление сервером") echo "Serververwaltung"; return;; fr\|"Управление сервером") echo "Gestion du serveur"; return;; es\|"Управление сервером") echo "Administración del servidor"; return;; zh\|"Управление сервером") echo "服务器管理"; return;;
      en\|"Обнаружена установка NIX Panel v"*) printf 'NIX Panel v%s installation detected' "${msg#*Panel v}"; return;; de\|"Обнаружена установка NIX Panel v"*) printf 'NIX Panel v%s-Installation erkannt' "${msg#*Panel v}"; return;; fr\|"Обнаружена установка NIX Panel v"*) printf 'Installation de NIX Panel v%s détectée' "${msg#*Panel v}"; return;; es\|"Обнаружена установка NIX Panel v"*) printf 'Se detectó una instalación de NIX Panel v%s' "${msg#*Panel v}"; return;; zh\|"Обнаружена установка NIX Panel v"*) printf '检测到 NIX Panel v%s 已安装' "${msg#*Panel v}"; return;;
      en\|"Обновление панели (данные будут сохранены)...") echo "Updating the panel (data will be preserved)..."; return;; de\|"Обновление панели (данные будут сохранены)...") echo "Panel wird aktualisiert (Daten bleiben erhalten)..."; return;; fr\|"Обновление панели (данные будут сохранены)...") echo "Mise à jour du panneau (les données seront conservées)..."; return;; es\|"Обновление панели (данные будут сохранены)...") echo "Actualizando el panel (se conservarán los datos)..."; return;; zh\|"Обновление панели (данные будут сохранены)...") echo "正在更新面板（数据将保留）…"; return;;
      en\|"Обнаружена установка в "*) printf 'Installation directory detected: %s' "${msg#Обнаружена установка в }"; return;; de\|"Обнаружена установка в "*) printf 'Installation im Verzeichnis %s erkannt' "${msg#Обнаружена установка в }"; return;; fr\|"Обнаружена установка в "*) printf 'Installation détectée dans %s' "${msg#Обнаружена установка в }"; return;; es\|"Обнаружена установка в "*) printf 'Instalación detectada en %s' "${msg#Обнаружена установка в }"; return;; zh\|"Обнаружена установка в "*) printf '检测到安装目录：%s' "${msg#Обнаружена установка в }"; return;;
      en\|"Папка установки: "*" (режим обновления)") printf 'Installation directory: %s (update mode)' "${msg#Папка установки: }" | sed 's/ (режим обновления)//'; return;;
      de\|"Папка установки: "*" (режим обновления)") printf 'Installationsordner: %s (Aktualisierungsmodus)' "${msg#Папка установки: }" | sed 's/ (режим обновления)//'; return;;
      fr\|"Папка установки: "*" (режим обновления)") printf 'Dossier d’installation : %s (mise à jour)' "${msg#Папка установки: }" | sed 's/ (режим обновления)//'; return;;
      es\|"Папка установки: "*" (режим обновления)") printf 'Carpeta de instalación: %s (actualización)' "${msg#Папка установки: }" | sed 's/ (режим обновления)//'; return;;
      zh\|"Папка установки: "*" (режим обновления)") printf '安装目录：%s（更新模式）' "${msg#Папка установки: }" | sed 's/ (режим обновления)//'; return;;
      en\|"Порт: "*" (режим обновления)") local port="${msg#Порт: }"; port="${port% (режим обновления)}"; printf 'Port: %s (update mode)' "$port"; return;;
      de\|"Порт: "*" (режим обновления)") local port="${msg#Порт: }"; port="${port% (режим обновления)}"; printf 'Port: %s (Aktualisierungsmodus)' "$port"; return;;
      fr\|"Порт: "*" (режим обновления)") local port="${msg#Порт: }"; port="${port% (режим обновления)}"; printf 'Port : %s (mise à jour)' "$port"; return;;
      es\|"Порт: "*" (режим обновления)") local port="${msg#Порт: }"; port="${port% (режим обновления)}"; printf 'Puerto: %s (actualización)' "$port"; return;;
      zh\|"Порт: "*" (режим обновления)") local port="${msg#Порт: }"; port="${port% (режим обновления)}"; printf '端口：%s（更新模式）' "$port"; return;;
      en\|"Порт для панели (Enter — оставить "*) printf 'Panel port (press Enter to keep %s)' "${msg#*оставить }"; return;;
      de\|"Порт для панели (Enter — оставить "*) printf 'Panel-Port (Enter drücken, um %s beizubehalten)' "${msg#*оставить }"; return;;
      fr\|"Порт для панели (Enter — оставить "*) printf 'Port du panneau (Entrée pour conserver %s)' "${msg#*оставить }"; return;;
      es\|"Порт для панели (Enter — оставить "*) printf 'Puerto del panel (pulsa Intro para mantener %s)' "${msg#*оставить }"; return;;
      zh\|"Порт для панели (Enter — оставить "*) printf '面板端口（按 Enter 保留 %s）' "${msg#*оставить }"; return;;
      en\|"Новый порт выбран: "*) printf 'New port selected: %s' "${msg#Новый порт выбран: }"; return;;
      de\|"Новый порт выбран: "*) printf 'Neuer Port ausgewählt: %s' "${msg#Новый порт выбран: }"; return;;
      fr\|"Новый порт выбран: "*) printf 'Nouveau port sélectionné : %s' "${msg#Новый порт выбран: }"; return;;
      es\|"Новый порт выбран: "*) printf 'Nuevo puerto seleccionado: %s' "${msg#Новый порт выбран: }"; return;;
      zh\|"Новый порт выбран: "*) printf '已选择新端口：%s' "${msg#Новый порт выбран: }"; return;;      en\|"Порт из конфига: "*) printf 'Port from config: %s' "${msg#Порт из конфига: }"; return;; de\|"Порт из конфига: "*) printf 'Port aus der Konfiguration: %s' "${msg#Порт из конфига: }"; return;; fr\|"Порт из конфига: "*) printf 'Port de la configuration : %s' "${msg#Порт из конфига: }"; return;; es\|"Порт из конфига: "*) printf 'Puerto de configuración: %s' "${msg#Порт из конфига: }"; return;; zh\|"Порт из конфига: "*) printf '配置文件中的端口：%s' "${msg#Порт из конфига: }"; return;;
      en\|"Обновление пакетов системы...") echo "Updating system packages..."; return;; de\|"Обновление пакетов системы...") echo "Systempakete werden aktualisiert..."; return;; fr\|"Обновление пакетов системы...") echo "Mise à jour des paquets système..."; return;; es\|"Обновление пакетов системы...") echo "Actualizando los paquetes del sistema..."; return;; zh\|"Обновление пакетов системы...") echo "正在更新系统软件包…"; return;;
      en\|"Установка Node.js 20.x...") echo "Installing Node.js 20.x..."; return;; de\|"Установка Node.js 20.x...") echo "Node.js 20.x wird installiert..."; return;; fr\|"Установка Node.js 20.x...") echo "Installation de Node.js 20.x..."; return;; es\|"Установка Node.js 20.x...") echo "Instalando Node.js 20.x..."; return;; zh\|"Установка Node.js 20.x...") echo "正在安装 Node.js 20.x…"; return;;
      en\|"Установка npm-зависимостей...") echo "Installing npm dependencies..."; return;; de\|"Установка npm-зависимостей...") echo "npm-Abhängigkeiten werden installiert..."; return;; fr\|"Установка npm-зависимостей...") echo "Installation des dépendances npm..."; return;; es\|"Установка npm-зависимостей...") echo "Instalando dependencias de npm..."; return;; zh\|"Установка npm-зависимостей...") echo "正在安装 npm 依赖…"; return;;
      en\|"Установка системных зависимостей...") echo "Installing system dependencies..."; return;; de\|"Установка системных зависимостей...") echo "Systemabhängigkeiten werden installiert..."; return;; fr\|"Установка системных зависимостей...") echo "Installation des dépendances système..."; return;; es\|"Установка системных зависимостей...") echo "Instalando dependencias del sistema..."; return;; zh\|"Установка системных зависимостей...") echo "正在安装系统依赖…"; return;;
      en\|"Nginx обнаружен") echo "Nginx detected"; return;; de\|"Nginx обнаружен") echo "Nginx erkannt"; return;; fr\|"Nginx обнаружен") echo "Nginx détecté"; return;; es\|"Nginx обнаружен") echo "Nginx detectado"; return;; zh\|"Nginx обнаружен") echo "已检测到 Nginx"; return;;
      en\|"Nginx пропущен") echo "Nginx skipped"; return;; de\|"Nginx пропущен") echo "Nginx übersprungen"; return;; fr\|"Nginx пропущен") echo "Nginx ignoré"; return;; es\|"Nginx пропущен") echo "Nginx omitido"; return;; zh\|"Nginx пропущен") echo "已跳过 Nginx"; return;;
      en\|"Создание конфигурации Nginx...") echo "Creating Nginx configuration..."; return;; de\|"Создание конфигурации Nginx...") echo "Nginx-Konfiguration wird erstellt..."; return;; fr\|"Создание конфигурации Nginx...") echo "Création de la configuration Nginx..."; return;; es\|"Создание конфигурации Nginx...") echo "Creando la configuración de Nginx..."; return;; zh\|"Создание конфигурации Nginx...") echo "正在创建 Nginx 配置…"; return;;
      en\|"npm-зависимости установлены") echo "npm dependencies installed"; return;; de\|"npm-зависимости установлены") echo "npm-Abhängigkeiten installiert"; return;; fr\|"npm-зависимости установлены") echo "Dépendances npm installées"; return;; es\|"npm-зависимости установлены") echo "Dependencias de npm instaladas"; return;; zh\|"npm-зависимости установлены") echo "npm 依赖已安装"; return;;
      en\|"Запуск NIX Panel...") echo "Starting NIX Panel..."; return;; de\|"Запуск NIX Panel...") echo "NIX Panel wird gestartet..."; return;; fr\|"Запуск NIX Panel...") echo "Démarrage de NIX Panel..."; return;; es\|"Запуск NIX Panel...") echo "Iniciando NIX Panel..."; return;; zh\|"Запуск NIX Panel...") echo "正在启动 NIX Panel…"; return;;
      en\|"Порт не изменён: "*) printf 'Port unchanged: %s' "${msg#Порт не изменён: }"; return;; de\|"Порт не изменён: "*) printf 'Port unverändert: %s' "${msg#Порт не изменён: }"; return;; fr\|"Порт не изменён: "*) printf 'Port inchangé : %s' "${msg#Порт не изменён: }"; return;; es\|"Порт не изменён: "*) printf 'Puerto sin cambios: %s' "${msg#Порт не изменён: }"; return;; zh\|"Порт не изменён: "*) printf '端口未更改：%s' "${msg#Порт не изменён: }"; return;;
      en\|"Порт выбран: "*) printf 'Port selected: %s' "${msg#Порт выбран: }"; return;; de\|"Порт выбран: "*) printf 'Port ausgewählt: %s' "${msg#Порт выбран: }"; return;; fr\|"Порт выбран: "*) printf 'Port sélectionné : %s' "${msg#Порт выбран: }"; return;; es\|"Порт выбран: "*) printf 'Puerto seleccionado: %s' "${msg#Порт выбран: }"; return;; zh\|"Порт выбран: "*) printf '已选择端口：%s' "${msg#Порт выбран: }"; return;;
      en\|"Панель и данные удалены") echo "Panel and data removed"; return;; de\|"Панель и данные удалены") echo "Panel und Daten entfernt"; return;; fr\|"Панель и данные удалены") echo "Panneau et données supprimés"; return;; es\|"Панель и данные удалены") echo "Panel y datos eliminados"; return;; zh\|"Панель и данные удалены") echo "面板和数据已删除"; return;;      en\|"Укажите домен или IP-адрес для доступа к панели.") echo "Enter the domain or IP address used to access the panel."; return;; de\|"Укажите домен или IP-адрес для доступа к панели.") echo "Geben Sie die Domain oder IP-Adresse für den Zugriff auf das Panel ein."; return;; fr\|"Укажите домен или IP-адрес для доступа к панели.") echo "Saisissez le domaine ou l’adresse IP pour accéder au panneau."; return;; es\|"Укажите домен или IP-адрес для доступа к панели.") echo "Introduce el dominio o la dirección IP para acceder al panel."; return;; zh\|"Укажите домен или IP-адрес для доступа к панели.") echo "请输入用于访问面板的域名或 IP 地址。"; return;;
      en\|"Если у вас есть домен, сертификат будет получен автоматически через Let's Encrypt.") echo "If you have a domain, a certificate will be obtained automatically through Let's Encrypt."; return;; de\|"Если у вас есть домен, сертификат будет получен автоматически через Let's Encrypt.") echo "Wenn Sie eine Domain haben, wird automatisch ein Zertifikat über Let's Encrypt bezogen."; return;; fr\|"Если у вас есть домен, сертификат будет получен автоматически через Let's Encrypt.") echo "Si vous avez un domaine, un certificat sera obtenu automatiquement via Let's Encrypt."; return;; es\|"Если у вас есть домен, сертификат будет получен автоматически через Let's Encrypt.") echo "Si tienes un dominio, se obtendrá un certificado automáticamente mediante Let's Encrypt."; return;; zh\|"Если у вас есть домен, сертификат будет получен автоматически через Let's Encrypt.") echo "如果您有域名，系统将通过 Let's Encrypt 自动获取证书。"; return;;
      en\|"Установите/настройте удалённое управление?") echo "Install/configure remote control?"; return;;
      en\|"Админ установщика: "*) printf 'Installer admin: %s' "${msg#Админ установщика: }"; return;; de\|"Админ установщика: "*) printf 'Installationsadministrator: %s' "${msg#Админ установщика: }"; return;; fr\|"Админ установщика: "*) printf 'Administrateur de l’installation : %s' "${msg#Админ установщика: }"; return;; es\|"Админ установщика: "*) printf 'Administrador del instalador: %s' "${msg#Админ установщика: }"; return;; zh\|"Админ установщика: "*) printf '安装管理员：%s' "${msg#Админ установщика: }"; return;;
      en\|"Вы ввели домен: "*) printf 'You entered the domain: %s' "${msg#Вы ввели домен: }"; return;; de\|"Вы ввели домен: "*) printf 'Eingegebene Domain: %s' "${msg#Вы ввели домен: }"; return;; fr\|"Вы ввели домен: "*) printf 'Domaine saisi : %s' "${msg#Вы ввели домен: }"; return;; es\|"Вы ввели домен: "*) printf 'Dominio introducido: %s' "${msg#Вы ввели домен: }"; return;; zh\|"Вы ввели домен: "*) printf '输入的域名：%s' "${msg#Вы ввели домен: }"; return;;
      en\|"Убедитесь, что домен "*" указывает на этот сервер!") printf 'Make sure the domain %s points to this server!' "${msg#Убедитесь, что домен }" | sed 's/ указывает на этот сервер!//'; return;;
      de\|"Убедитесь, что домен "*" указывает на этот сервер!") printf 'Stellen Sie sicher, dass die Domain %s auf diesen Server verweist!' "${msg#Убедитесь, что домен }" | sed 's/ указывает на этот сервер!//'; return;;
      fr\|"Убедитесь, что домен "*" указывает на этот сервер!") printf 'Vérifiez que le domaine %s pointe vers ce serveur !' "${msg#Убедитесь, что домен }" | sed 's/ указывает на этот сервер!//'; return;;
      es\|"Убедитесь, что домен "*" указывает на этот сервер!") printf 'Asegúrate de que el dominio %s apunte a este servidor.' "${msg#Убедитесь, что домен }" | sed 's/ указывает на этот сервер!//'; return;;
      zh\|"Убедитесь, что домен "*" указывает на этот сервер!") printf '请确保域名 %s 指向此服务器！' "${msg#Убедитесь, что домен }" | sed 's/ указывает на этот сервер!//'; return;;      en\|"Очистка старых npm-зависимостей...") echo "Cleaning up old npm dependencies..."; return;; de\|"Очистка старых npm-зависимостей...") echo "Alte npm-Abhängigkeiten werden bereinigt..."; return;; fr\|"Очистка старых npm-зависимостей...") echo "Nettoyage des anciennes dépendances npm..."; return;; es\|"Очистка старых npm-зависимостей...") echo "Limpiando las dependencias npm antiguas..."; return;; zh\|"Очистка старых npm-зависимостей...") echo "正在清理旧的 npm 依赖…"; return;;
      en\|"Используется IP-адрес, SSL будет пропущен") echo "Using an IP address; SSL will be skipped"; return;; de\|"Используется IP-адрес, SSL будет пропущен") echo "IP-Adresse wird verwendet; SSL wird übersprungen"; return;; fr\|"Используется IP-адрес, SSL будет пропущен") echo "Adresse IP utilisée ; SSL sera ignoré"; return;; es\|"Используется IP-адрес, SSL будет пропущен") echo "Se usará una dirección IP; se omitirá SSL"; return;; zh\|"Используется IP-адрес, SSL будет пропущен") echo "正在使用 IP 地址，将跳过 SSL"; return;;
      en\|"Для использования HTTPS вручную создайте сертификаты:") echo "To use HTTPS, create certificates manually:"; return;; de\|"Для использования HTTPS вручную создайте сертификаты:") echo "Für HTTPS müssen Zertifikate manuell erstellt werden:"; return;; fr\|"Для использования HTTPS вручную создайте сертификаты:") echo "Pour utiliser HTTPS, créez les certificats manuellement :"; return;; es\|"Для использования HTTPS вручную создайте сертификаты:") echo "Para usar HTTPS, crea los certificados manualmente:"; return;; zh\|"Для использования HTTPS вручную создайте сертификаты:") echo "如需使用 HTTPS，请手动创建证书："; return;;
      en\|"Копирование файлов панели...") echo "Copying panel files..."; return;; de\|"Копирование файлов панели...") echo "Paneldateien werden kopiert..."; return;; fr\|"Копирование файлов панели...") echo "Copie des fichiers du panneau..."; return;; es\|"Копирование файлов панели...") echo "Copiando los archivos del panel..."; return;; zh\|"Копирование файлов панели...") echo "正在复制面板文件…"; return;;
      en\|"Источник: "*) printf 'Source: %s' "${msg#Источник: }"; return;; de\|"Источник: "*) printf 'Quelle: %s' "${msg#Источник: }"; return;; fr\|"Источник: "*) printf 'Source : %s' "${msg#Источник: }"; return;; es\|"Источник: "*) printf 'Origen: %s' "${msg#Источник: }"; return;; zh\|"Источник: "*) printf '来源：%s' "${msg#Источник: }"; return;;
      en\|"Назначение: "*) printf 'Destination: %s' "${msg#Назначение: }"; return;; de\|"Назначение: "*) printf 'Ziel: %s' "${msg#Назначение: }"; return;; fr\|"Назначение: "*) printf 'Destination : %s' "${msg#Назначение: }"; return;; es\|"Назначение: "*) printf 'Destino: %s' "${msg#Назначение: }"; return;; zh\|"Назначение: "*) printf '目标位置：%s' "${msg#Назначение: }"; return;;
      en\|"Копирование из "*) printf 'Copying from %s' "${msg#Копирование из }"; return;; de\|"Копирование из "*) printf 'Kopieren aus %s' "${msg#Копирование из }"; return;; fr\|"Копирование из "*) printf 'Copie depuis %s' "${msg#Копирование из }"; return;; es\|"Копирование из "*) printf 'Copiando desde %s' "${msg#Копирование из }"; return;; zh\|"Копирование из "*) printf '正在从 %s 复制' "${msg#Копирование из }"; return;;
      en\|"Файлы скопированы из "*) printf 'Files copied from %s' "${msg#Файлы скопированы из }"; return;; de\|"Файлы скопированы из "*) printf 'Dateien kopiert aus %s' "${msg#Файлы скопированы из }"; return;; fr\|"Файлы скопированы из "*) printf 'Fichiers copiés depuis %s' "${msg#Файлы скопированы из }"; return;; es\|"Файлы скопированы из "*) printf 'Archivos copiados desde %s' "${msg#Файлы скопированы из }"; return;; zh\|"Файлы скопированы из "*) printf '文件已从 %s 复制' "${msg#Файлы скопированы из }"; return;;
      en\|"remote-portal-worker.js проверен: "*) printf 'remote-portal-worker.js verified: %s' "${msg#remote-portal-worker.js проверен: }"; return;; de\|"remote-portal-worker.js проверен: "*) printf 'remote-portal-worker.js geprüft: %s' "${msg#remote-portal-worker.js проверен: }"; return;; fr\|"remote-portal-worker.js проверен: "*) printf 'remote-portal-worker.js vérifié : %s' "${msg#remote-portal-worker.js проверен: }"; return;; es\|"remote-portal-worker.js проверен: "*) printf 'remote-portal-worker.js verificado: %s' "${msg#remote-portal-worker.js проверен: }"; return;; zh\|"remote-portal-worker.js проверен: "*) printf 'remote-portal-worker.js 已验证：%s' "${msg#remote-portal-worker.js проверен: }"; return;;
      en\|"Runtime worker: "*) printf 'Runtime worker: %s' "${msg#Runtime worker: }"; return;; de\|"Runtime worker: "*) printf 'Laufzeit-Worker: %s' "${msg#Runtime worker: }"; return;; fr\|"Runtime worker: "*) printf 'Worker d’exécution : %s' "${msg#Runtime worker: }"; return;; es\|"Runtime worker: "*) printf 'Worker de ejecución: %s' "${msg#Runtime worker: }"; return;; zh\|"Runtime worker: "*) printf '运行时 Worker：%s' "${msg#Runtime worker: }"; return;;
      en\|"Подготовка runtime-зависимостей Wayland...") echo "Preparing Wayland runtime dependencies..."; return;; de\|"Подготовка runtime-зависимостей Wayland...") echo "Wayland-Laufzeitabhängigkeiten werden vorbereitet..."; return;; fr\|"Подготовка runtime-зависимостей Wayland...") echo "Préparation des dépendances d’exécution Wayland..."; return;; es\|"Подготовка runtime-зависимостей Wayland...") echo "Preparando las dependencias de ejecución de Wayland..."; return;; zh\|"Подготовка runtime-зависимостей Wayland...") echo "正在准备 Wayland 运行时依赖…"; return;;
      en\|"Runtime dbus-next установлен") echo "Runtime dbus-next installed"; return;; de\|"Runtime dbus-next установлен") echo "Runtime-dbus-next installiert"; return;; fr\|"Runtime dbus-next установлен") echo "dbus-next d’exécution installé"; return;; es\|"Runtime dbus-next установлен") echo "dbus-next de ejecución instalado"; return;; zh\|"Runtime dbus-next установлен") echo "运行时 dbus-next 已安装"; return;;
      en\|"Проверка зависимостей...") echo "Checking dependencies..."; return;; de\|"Проверка зависимостей...") echo "Abhängigkeiten werden geprüft..."; return;; fr\|"Проверка зависимостей...") echo "Vérification des dépendances..."; return;; es\|"Проверка зависимостей...") echo "Comprobando las dependencias..."; return;; zh\|"Проверка зависимостей...") echo "正在检查依赖…"; return;;
      en\|"Зависимости обновлены") echo "Dependencies updated"; return;; de\|"Зависимости обновлены") echo "Abhängigkeiten aktualisiert"; return;; fr\|"Зависимости обновлены") echo "Dépendances mises à jour"; return;; es\|"Зависимости обновлены") echo "Dependencias actualizadas"; return;; zh\|"Зависимости обновлены") echo "依赖已更新"; return;;
      en\|"Пользователи сохранены (режим обновления)") echo "Users preserved (update mode)"; return;; de\|"Пользователи сохранены (режим обновления)") echo "Benutzer beibehalten (Aktualisierungsmodus)"; return;; fr\|"Пользователи сохранены (режим обновления)") echo "Utilisateurs conservés (mise à jour)"; return;; es\|"Пользователи сохранены (режим обновления)") echo "Usuarios conservados (actualización)"; return;; zh\|"Пользователи сохранены (режим обновления)") echo "用户已保留（更新模式）"; return;;
      en\|"Настройка файрвола...") echo "Configuring the firewall..."; return;; de\|"Настройка файрвола...") echo "Firewall wird konfiguriert..."; return;; fr\|"Настройка файрвола...") echo "Configuration du pare-feu..."; return;; es\|"Настройка файрвола...") echo "Configurando el cortafuegos..."; return;; zh\|"Настройка файрвола...") echo "正在配置防火墙…"; return;;
      en\|"Настройка UFW...") echo "Configuring UFW..."; return;; de\|"Настройка UFW...") echo "UFW wird konfiguriert..."; return;; fr\|"Настройка UFW...") echo "Configuration d’UFW..."; return;; es\|"Настройка UFW...") echo "Configurando UFW..."; return;; zh\|"Настройка UFW...") echo "正在配置 UFW…"; return;;
      en\|"UFW настроен и включен") echo "UFW configured and enabled"; return;; de\|"UFW настроен и включен") echo "UFW konfiguriert und aktiviert"; return;; fr\|"UFW настроен и включен") echo "UFW configuré et activé"; return;; es\|"UFW настроен и включен") echo "UFW configurado y activado"; return;; zh\|"UFW настроен и включен") echo "UFW 已配置并启用"; return;;
      en\|"UFW настроен") echo "UFW configured"; return;; de\|"UFW настроен") echo "UFW konfiguriert"; return;; fr\|"UFW настроен") echo "UFW configuré"; return;; es\|"UFW настроен") echo "UFW configurado"; return;; zh\|"UFW настроен") echo "UFW 已配置"; return;;
      en\|"Конфигурация создана (язык панели по умолчанию: "*) local language="${msg#*по умолчанию: }"; language="${language%)}"; printf 'Configuration created (default panel language: %s)' "$language"; return;;
      de\|"Конфигурация создана (язык панели по умолчанию: "*) local language="${msg#*по умолчанию: }"; language="${language%)}"; printf 'Konfiguration erstellt (Standardsprache des Panels: %s)' "$language"; return;;
      fr\|"Конфигурация создана (язык панели по умолчанию: "*) local language="${msg#*по умолчанию: }"; language="${language%)}"; printf 'Configuration créée (langue par défaut du panneau : %s)' "$language"; return;;
      es\|"Конфигурация создана (язык панели по умолчанию: "*) local language="${msg#*по умолчанию: }"; language="${language%)}"; printf 'Configuración creada (idioma predeterminado del panel: %s)' "$language"; return;;
      zh\|"Конфигурация создана (язык панели по умолчанию: "*) local language="${msg#*по умолчанию: }"; language="${language%)}"; printf '配置已创建（面板默认语言：%s）' "$language"; return;;
      en\|"Открытые порты: "*) printf 'Open ports: %s' "${msg#Открытые порты: }"; return;; de\|"Открытые порты: "*) printf 'Offene Ports: %s' "${msg#Открытые порты: }"; return;; fr\|"Открытые порты: "*) printf 'Ports ouverts : %s' "${msg#Открытые порты: }"; return;; es\|"Открытые порты: "*) printf 'Puertos abiertos: %s' "${msg#Открытые порты: }"; return;; zh\|"Открытые порты: "*) printf '开放端口：%s' "${msg#Открытые порты: }"; return;;      en\|"SSL пропущен") echo "SSL skipped"; return;; de\|"SSL пропущен") echo "SSL übersprungen"; return;; fr\|"SSL пропущен") echo "SSL ignoré"; return;; es\|"SSL пропущен") echo "SSL omitido"; return;; zh\|"SSL пропущен") echo "已跳过 SSL"; return;;
      en\|"Новая установка NIX Panel v"*) printf 'New NIX Panel v%s installation' "${msg#*Panel v}"; return;; de\|"Новая установка NIX Panel v"*) printf 'Neue Installation von NIX Panel v%s' "${msg#*Panel v}"; return;; fr\|"Новая установка NIX Panel v"*) printf 'Nouvelle installation de NIX Panel v%s' "${msg#*Panel v}"; return;; es\|"Новая установка NIX Panel v"*) printf 'Nueva instalación de NIX Panel v%s' "${msg#*Panel v}"; return;; zh\|"Новая установка NIX Panel v"*) printf '正在全新安装 NIX Panel v%s' "${msg#*Panel v}"; return;;
      en\|"Получение сертификата для "*"...") printf 'Obtaining a certificate for %s...' "${msg#Получение сертификата для }" | sed 's/...$//'; return;;
      de\|"Получение сертификата для "*"...") printf 'Zertifikat für %s wird bezogen...' "${msg#Получение сертификата для }" | sed 's/...$//'; return;;
      fr\|"Получение сертификата для "*"...") printf 'Obtention du certificat pour %s...' "${msg#Получение сертификата для }" | sed 's/...$//'; return;;
      es\|"Получение сертификата для "*"...") printf 'Obteniendo certificado para %s...' "${msg#Получение сертификата для }" | sed 's/...$//'; return;;
      zh\|"Получение сертификата для "*"...") printf '正在为 %s 获取证书…' "${msg#Получение сертификата для }" | sed 's/...$//'; return;;
      en\|"Текущая папка: "*) printf 'Current directory: %s' "${msg#Текущая папка: }"; return;; de\|"Текущая папка: "*) printf 'Aktuelles Verzeichnis: %s' "${msg#Текущая папка: }"; return;; fr\|"Текущая папка: "*) printf 'Dossier actuel : %s' "${msg#Текущая папка: }"; return;; es\|"Текущая папка: "*) printf 'Carpeta actual: %s' "${msg#Текущая папка: }"; return;; zh\|"Текущая папка: "*) printf '当前目录：%s' "${msg#Текущая папка: }"; return;;
      en\|"Папка скрипта: "*) printf 'Script directory: %s' "${msg#Папка скрипта: }"; return;; de\|"Папка скрипта: "*) printf 'Skriptverzeichnis: %s' "${msg#Папка скрипта: }"; return;; fr\|"Папка скрипта: "*) printf 'Dossier du script : %s' "${msg#Папка скрипта: }"; return;; es\|"Папка скрипта: "*) printf 'Carpeta del script: %s' "${msg#Папка скрипта: }"; return;; zh\|"Папка скрипта: "*) printf '脚本目录：%s' "${msg#Папка скрипта: }"; return;;
      en\|"Создание users.json с логином "*) printf 'Creating users.json for login %s' "${msg#Создание users.json с логином }"; return;;
      en\|"Определение графической подсистемы...") echo "Detecting the graphical environment..."; return;; de\|"Определение графической подсистемы...") echo "Grafische Umgebung wird erkannt..."; return;; fr\|"Определение графической подсистемы...") echo "Détection de l’environnement graphique..."; return;; es\|"Определение графической подсистемы...") echo "Detectando el entorno gráfico..."; return;; zh\|"Определение графической подсистемы...") echo "正在检测图形环境…"; return;;
      en\|"Обнаружен Wayland, устанавливаю быстрый захват grim + spectacle...") echo "Wayland detected; installing fast capture tools (grim + spectacle)..."; return;; de\|"Обнаружен Wayland, устанавливаю быстрый захват grim + spectacle...") echo "Wayland erkannt; schnelle Screenshot-Werkzeuge (grim + spectacle) werden installiert..."; return;; fr\|"Обнаружен Wayland, устанавливаю быстрый захват grim + spectacle...") echo "Wayland détecté ; installation des outils de capture rapide (grim + spectacle)..."; return;; es\|"Обнаружен Wayland, устанавливаю быстрый захват grim + spectacle...") echo "Wayland detectado; instalando herramientas de captura rápida (grim + spectacle)..."; return;; zh\|"Обнаружен Wayland, устанавливаю быстрый захват grim + spectacle...") echo "已检测到 Wayland，正在安装快速截图工具（grim + spectacle）…"; return;;
      en\|"Обнаружен X11, устанавливаю xdotool + imagemagick...") echo "X11 detected; installing xdotool + imagemagick..."; return;; de\|"Обнаружен X11, устанавливаю xdotool + imagemagick...") echo "X11 erkannt; xdotool + imagemagick werden installiert..."; return;; fr\|"Обнаружен X11, устанавливаю xdotool + imagemagick...") echo "X11 détecté ; installation de xdotool + imagemagick..."; return;; es\|"Обнаружен X11, устанавливаю xdotool + imagemagick...") echo "X11 detectado; instalando xdotool + imagemagick..."; return;; zh\|"Обнаружен X11, устанавливаю xdotool + imagemagick...") echo "已检测到 X11，正在安装 xdotool + imagemagick…"; return;;
      en\|"Графическая подсистема не обнаружена, устанавливаю Xvfb...") echo "No graphical environment detected; installing Xvfb..."; return;; de\|"Графическая подсистема не обнаружена, устанавливаю Xvfb...") echo "Keine grafische Umgebung erkannt; Xvfb wird installiert..."; return;; fr\|"Графическая подсистема не обнаружена, устанавливаю Xvfb...") echo "Aucun environnement graphique détecté ; installation de Xvfb..."; return;; es\|"Графическая подсистема не обнаружена, устанавливаю Xvfb...") echo "No se detectó un entorno gráfico; instalando Xvfb..."; return;; zh\|"Графическая подсистема не обнаружена, устанавливаю Xvfb...") echo "未检测到图形环境，正在安装 Xvfb…"; return;;
      en\|"Создание самоподписанного SSL-сертификата...") echo "Creating a self-signed SSL certificate..."; return;; de\|"Создание самоподписанного SSL-сертификата...") echo "Selbstsigniertes SSL-Zertifikat wird erstellt..."; return;; fr\|"Создание самоподписанного SSL-сертификата...") echo "Création d’un certificat SSL autosigné..."; return;; es\|"Создание самоподписанного SSL-сертификата...") echo "Creando un certificado SSL autofirmado..."; return;; zh\|"Создание самоподписанного SSL-сертификата...") echo "正在创建自签名 SSL 证书…"; return;;
      en\|"Проверка порта (обновление)") echo "Check port (update)"; return;; de\|"Проверка порта (обновление)") echo "Port prüfen (Aktualisierung)"; return;; fr\|"Проверка порта (обновление)") echo "Vérification du port (mise à jour)"; return;; es\|"Проверка порта (обновление)") echo "Comprobación del puerto (actualización)"; return;; zh\|"Проверка порта (обновление)") echo "检查端口（更新）"; return;;
      en\|"iptables обновлен") echo "iptables rules updated"; return;; de\|"iptables обновлен") echo "iptables-Regeln aktualisiert"; return;; fr\|"iptables обновлен") echo "Règles iptables mises à jour"; return;; es\|"iptables обновлен") echo "Reglas de iptables actualizadas"; return;; zh\|"iptables обновлен") echo "iptables 规则已更新"; return;;      en\|"Полная переустановка...") echo "Full reinstallation..."; return;;
      de\|"Полная переустановка...") echo "Vollständige Neuinstallation..."; return;;
      fr\|"Полная переустановка...") echo "Réinstallation complète…"; return;;
      es\|"Полная переустановка...") echo "Reinstalación completa…"; return;;
      zh\|"Полная переустановка...") echo "正在完整重新安装…"; return;;
      en\|"Удаление NIX Panel...") echo "Removing NIX Panel..."; return;;
      de\|"Удаление NIX Panel...") echo "NIX Panel wird entfernt..."; return;;
      fr\|"Удаление NIX Panel...") echo "Désinstallation de NIX Panel..."; return;;
      es\|"Удаление NIX Panel...") echo "Desinstalando NIX Panel..."; return;;
      zh\|"Удаление NIX Panel...") echo "正在卸载 NIX Panel…"; return;;
      en\|"Удалить все данные (users.json, чат и т.д.)?") echo "Delete all data (users.json, chat, etc.)?"; return;;
      de\|"Удалить все данные (users.json, чат и т.д.)?") echo "Alle Daten löschen (users.json, Chat usw.)?"; return;;
      fr\|"Удалить все данные (users.json, чат и т.д.)?") echo "Supprimer toutes les données (users.json, chat, etc.) ?"; return;;
      es\|"Удалить все данные (users.json, чат и т.д.)?") echo "¿Eliminar todos los datos (users.json, chat, etc.)?"; return;;
      zh\|"Удалить все данные (users.json, чат и т.д.)?") echo "删除所有数据（users.json、聊天记录等）？"; return;;
      en\|"Порт должен быть числом от 1 до 65535") echo "Port must be a number from 1 to 65535"; return;;
      de\|"Порт должен быть числом от 1 до 65535") echo "Der Port muss eine Zahl zwischen 1 und 65535 sein"; return;;
      fr\|"Порт должен быть числом от 1 до 65535") echo "Le port doit être un nombre compris entre 1 et 65535"; return;;
      es\|"Порт должен быть числом от 1 до 65535") echo "El puerto debe ser un número entre 1 y 65535"; return;;
      zh\|"Порт должен быть числом от 1 до 65535") echo "端口必须是 1 到 65535 之间的数字"; return;;
      en\|"Пароль:") echo "Password:"; return;;
      de\|"Пароль:") echo "Passwort:"; return;;
      fr\|"Пароль:") echo "Mot de passe :"; return;;
      es\|"Пароль:") echo "Contraseña:"; return;;
      zh\|"Пароль:") echo "密码："; return;;
      en\|"Повторите пароль:") echo "Repeat password:"; return;;
      de\|"Повторите пароль:") echo "Passwort wiederholen:"; return;;
      fr\|"Повторите пароль:") echo "Répétez le mot de passe :"; return;;
      es\|"Повторите пароль:") echo "Repite la contraseña:"; return;;
      zh\|"Повторите пароль:") echo "再次输入密码："; return;;
      en\|"OS: Не удалось определить") echo "OS: Could not determine"; return;;
      de\|"OS: Не удалось определить") echo "Betriebssystem: konnte nicht ermittelt werden"; return;;
      fr\|"OS: Не удалось определить") echo "Système : impossible à déterminer"; return;;
      es\|"OS: Не удалось определить") echo "SO: no se pudo determinar"; return;;
      zh\|"OS: Не удалось определить") echo "操作系统：无法确定"; return;;
      en\|"Придумайте логин для входа в панель.") echo "Choose a username to sign in to the panel."; return;;
      de\|"Придумайте логин для входа в панель.") echo "Legen Sie einen Benutzernamen für die Anmeldung fest."; return;;
      fr\|"Придумайте логин для входа в панель.") echo "Choisissez un identifiant pour vous connecter au panneau."; return;;
      es\|"Придумайте логин для входа в панель.") echo "Elige un nombre de usuario para iniciar sesión en el panel."; return;;
      zh\|"Придумайте логин для входа в панель.") echo "请设置用于登录面板的用户名。"; return;;
      en\|"В вашей системе установлено окружение рабочего стола / видеоадаптер?") echo "Is a desktop environment or graphics adapter installed on your system?"; return;;
      de\|"В вашей системе установлено окружение рабочего стола / видеоадаптер?") echo "Ist auf Ihrem System eine Desktopumgebung oder ein Grafikadapter installiert?"; return;;
      fr\|"В вашей системе установлено окружение рабочего стола / видеоадаптер?") echo "Un environnement de bureau ou une carte graphique est-il installé sur votre système ?"; return;;
      es\|"В вашей системе установлено окружение рабочего стола / видеоадаптер?") echo "¿Hay un entorno de escritorio o un adaptador gráfico instalado en el sistema?"; return;;
      zh\|"В вашей системе установлено окружение рабочего стола / видеоадаптер?") echo "您的系统是否安装了桌面环境或图形适配器？"; return;;
      en\|"Если да — панель сможет показывать и управлять экраном сервера.") echo "If so, the panel can display and control the server screen."; return;;
      de\|"Если да — панель сможет показывать и управлять экраном сервера.") echo "Dann kann das Panel den Serverbildschirm anzeigen und steuern."; return;;
      fr\|"Если да — панель сможет показывать и управлять экраном сервера.") echo "Dans ce cas, le panneau pourra afficher et contrôler l’écran du serveur."; return;;
      es\|"Если да — панель сможет показывать и управлять экраном сервера.") echo "En ese caso, el panel podrá mostrar y controlar la pantalla del servidor."; return;;
      zh\|"Если да — панель сможет показывать и управлять экраном сервера.") echo "如果是，面板便可显示并控制服务器屏幕。"; return;;
      en\|"Потребуются пакеты:") echo "Required packages:"; return;;
      de\|"Потребуются пакеты:") echo "Benötigte Pakete:"; return;;
      fr\|"Потребуются пакеты:") echo "Paquets requis :"; return;;
      es\|"Потребуются пакеты:") echo "Paquetes necesarios:"; return;;
      zh\|"Потребуются пакеты:") echo "所需软件包："; return;;
      en\|"Wayland (KDE/Plasma): spectacle (скриншоты); ввод — через портал") echo "Wayland (KDE/Plasma): spectacle (screenshots); input through the portal"; return;;
      de\|"Wayland (KDE/Plasma): spectacle (скриншоты); ввод — через портал") echo "Wayland (KDE/Plasma): spectacle (Screenshots); Eingabe über das Portal"; return;;
      fr\|"Wayland (KDE/Plasma): spectacle (скриншоты); ввод — через портал") echo "Wayland (KDE/Plasma) : spectacle (captures d’écran) ; saisie via le portail"; return;;
      es\|"Wayland (KDE/Plasma): spectacle (скриншоты); ввод — через портал") echo "Wayland (KDE/Plasma): spectacle (capturas); entrada mediante el portal"; return;;
      zh\|"Wayland (KDE/Plasma): spectacle (скриншоты); ввод — через портал") echo "Wayland（KDE/Plasma）：spectacle（截图）；通过门户控制输入"; return;;
      en\|"org.freedesktop.portal.RemoteDesktop, без ydotool/uinput") echo "org.freedesktop.portal.RemoteDesktop; no ydotool/uinput"; return;;
      de\|"org.freedesktop.portal.RemoteDesktop, без ydotool/uinput") echo "org.freedesktop.portal.RemoteDesktop; kein ydotool/uinput"; return;;
      fr\|"org.freedesktop.portal.RemoteDesktop, без ydotool/uinput") echo "org.freedesktop.portal.RemoteDesktop ; sans ydotool/uinput"; return;;
      es\|"org.freedesktop.portal.RemoteDesktop, без ydotool/uinput") echo "org.freedesktop.portal.RemoteDesktop, sin ydotool/uinput"; return;;
      zh\|"org.freedesktop.portal.RemoteDesktop, без ydotool/uinput") echo "org.freedesktop.portal.RemoteDesktop；无需 ydotool/uinput"; return;;
      en\|"X11: xdotool, imagemagick, x11-utils") echo "X11: xdotool, imagemagick, x11-utils"; return;;
      de\|"X11: xdotool, imagemagick, x11-utils") echo "X11: xdotool, imagemagick, x11-utils"; return;;
      fr\|"X11: xdotool, imagemagick, x11-utils") echo "X11 : xdotool, imagemagick, x11-utils"; return;;
      es\|"X11: xdotool, imagemagick, x11-utils") echo "X11: xdotool, imagemagick, x11-utils"; return;;
      zh\|"X11: xdotool, imagemagick, x11-utils") echo "X11：xdotool、imagemagick、x11-utils"; return;;
      en\|"Без GUI: Xvfb (виртуальный экран)") echo "No GUI: Xvfb (virtual display)"; return;;
      de\|"Без GUI: Xvfb (виртуальный экран)") echo "Ohne GUI: Xvfb (virtuelle Anzeige)"; return;;
      fr\|"Без GUI: Xvfb (виртуальный экран)") echo "Sans interface graphique : Xvfb (écran virtuel)"; return;;
      es\|"Без GUI: Xvfb (виртуальный экран)") echo "Sin interfaz gráfica: Xvfb (pantalla virtual)"; return;;
      zh\|"Без GUI: Xvfb (виртуальный экран)") echo "无图形界面：Xvfb（虚拟显示器）"; return;;
      en\|"Как проверить:") echo "How to check:"; return;;
      de\|"Как проверить:") echo "So prüfen Sie es:"; return;;
      fr\|"Как проверить:") echo "Comment vérifier :"; return;;
      es\|"Как проверить:") echo "Cómo comprobarlo:"; return;;
      zh\|"Как проверить:") echo "检查方法："; return;;
      en\|"KDE/Plasma (Wayland) — ответьте Y, установит spectacle + dbus-next") echo "KDE/Plasma (Wayland): answer Y to install spectacle + dbus-next"; return;;
      de\|"KDE/Plasma (Wayland) — ответьте Y, установит spectacle + dbus-next") echo "KDE/Plasma (Wayland): Y eingeben, um spectacle + dbus-next zu installieren"; return;;
      fr\|"KDE/Plasma (Wayland) — ответьте Y, установит spectacle + dbus-next") echo "KDE/Plasma (Wayland) : répondez Y pour installer spectacle + dbus-next"; return;;
      es\|"KDE/Plasma (Wayland) — ответьте Y, установит spectacle + dbus-next") echo "KDE/Plasma (Wayland): responde Y para instalar spectacle + dbus-next"; return;;
      zh\|"KDE/Plasma (Wayland) — ответьте Y, установит spectacle + dbus-next") echo "KDE/Plasma（Wayland）：输入 Y 安装 spectacle + dbus-next"; return;;
      en\|"X11 / монитор — ответьте Y, установит xdotool + imagemagick") echo "X11 / monitor: answer Y to install xdotool + imagemagick"; return;;
      de\|"X11 / монитор — ответьте Y, установит xdotool + imagemagick") echo "X11 / Monitor: Y eingeben, um xdotool + imagemagick zu installieren"; return;;
      fr\|"X11 / монитор — ответьте Y, установит xdotool + imagemagick") echo "X11 / écran : répondez Y pour installer xdotool + imagemagick"; return;;
      es\|"X11 / монитор — ответьте Y, установит xdotool + imagemagick") echo "X11 / monitor: responde Y para instalar xdotool + imagemagick"; return;;
      zh\|"X11 / монитор — ответьте Y, установит xdotool + imagemagick") echo "X11 / 显示器：输入 Y 安装 xdotool + imagemagick"; return;;
      en\|"VPS без GUI — установит Xvfb (виртуальный экран)") echo "VPS without a GUI: installs Xvfb (virtual display)"; return;;
      de\|"VPS без GUI — установит Xvfb (виртуальный экран)") echo "VPS ohne GUI: installiert Xvfb (virtuelle Anzeige)"; return;;
      fr\|"VPS без GUI — установит Xvfb (виртуальный экран)") echo "VPS sans interface graphique : installe Xvfb (écran virtuel)"; return;;
      es\|"VPS без GUI — установит Xvfb (виртуальный экран)") echo "VPS sin interfaz gráfica: instala Xvfb (pantalla virtual)"; return;;
      zh\|"VPS без GUI — установит Xvfb (виртуальный экран)") echo "无图形界面的 VPS：安装 Xvfb（虚拟显示器）"; return;;
      en\|"Не уверены — ответьте N (можно включить позже)") echo "Not sure? Answer N; you can enable it later"; return;;
      de\|"Не уверены — ответьте N (можно включить позже)") echo "Unsicher? N eingeben; Sie können es später aktivieren"; return;;
      fr\|"Не уверены — ответьте N (можно включить позже)") echo "En cas de doute, répondez N (activation possible plus tard)"; return;;
      es\|"Не уверены — ответьте N (можно включить позже)") echo "¿No estás seguro? Responde N; puedes activarlo más tarde"; return;;
      zh\|"Не уверены — ответьте N (можно включить позже)") echo "不确定？输入 N（之后仍可启用）"; return;;
      en\|"На Wayland при первом реальном использовании ввода KDE может один раз") echo "On Wayland, the first use of KDE input may trigger a one-time system prompt."; return;;
      de\|"На Wayland при первом реальном использовании ввода KDE может один раз") echo "Unter Wayland kann bei der ersten KDE-Eingabe einmalig ein Systemdialog erscheinen."; return;;
      fr\|"На Wayland при первом реальном использовании ввода KDE может один раз") echo "Sous Wayland, la première utilisation de la saisie KDE peut afficher une boîte de dialogue système."; return;;
      es\|"На Wayland при первом реальном использовании ввода KDE может один раз") echo "En Wayland, el primer uso de la entrada de KDE puede mostrar un aviso del sistema."; return;;
      zh\|"На Wayland при первом реальном использовании ввода KDE может один раз") echo "在 Wayland 下，首次使用 KDE 输入时可能会出现一次系统提示。"; return;;
      en\|"показать системный диалог «Разрешить приложению управлять вводом?» — панель") echo "“Allow the application to control input?” The panel will"; return;;
      de\|"показать системный диалог «Разрешить приложению управлять вводом?» — панель") echo "«Autoriser l’application à contrôler la saisie ?» Le panneau"; return;;
      fr\|"показать системный диалог «Разрешить приложению управлять вводом?» — панель") echo "« Autoriser l’application à contrôler la saisie ? » Le panneau"; return;;
      es\|"показать системный диалог «Разрешить приложению управлять вводом?» — панель") echo "«¿Permitir que la aplicación controle la entrada?» El panel"; return;;
      zh\|"показать системный диалог «Разрешить приложению управлять вводом?» — панель") echo "“允许此应用控制输入吗？”面板将"; return;;
      en\|"сама попробует предавторизоваться без диалога (нужна Plasma 6.3+), но если") echo "try to pre-authorize without a prompt (Plasma 6.3+ required). If that fails,"; return;;
      de\|"сама попробует предавторизоваться без диалога (нужна Plasma 6.3+), но если") echo "essaiera de préautoriser sans dialogue (Plasma 6.3+ requis). En cas d’échec,"; return;;
      fr\|"сама попробует предавторизоваться без диалога (нужна Plasma 6.3+), но если") echo "intentará autorizarse sin el diálogo (se requiere Plasma 6.3+). Si falla,"; return;;
      es\|"сама попробует предавторизоваться без диалога (нужна Plasma 6.3+), но если") echo "tenterá autorizarse sin aviso (requiere Plasma 6.3+). Si no funciona,"; return;;
      zh\|"сама попробует предавторизоваться без диалога (нужна Plasma 6.3+), но если") echo "尝试在不显示对话框的情况下预先授权（需要 Plasma 6.3+）。如果失败，"; return;;
      en\|"это не сработает, диалог придётся один раз подтвердить вручную.") echo "confirm the prompt manually once."; return;;
      de\|"это не сработает, диалог придётся один раз подтвердить вручную.") echo "müssen Sie den Dialog einmal manuell bestätigen."; return;;
      fr\|"это не сработает, диалог придётся один раз подтвердить вручную.") echo "vous devrez confirmer le dialogue une fois manuellement."; return;;
      es\|"это не сработает, диалог придётся один раз подтвердить вручную.") echo "deberás confirmar el aviso manualmente una vez."; return;;
      zh\|"это не сработает, диалог придётся один раз подтвердить вручную.") echo "您需要手动确认一次该提示。"; return;;
      en\|"Xvfb уже установлен") echo "Xvfb is already installed"; return;;
      de\|"Xvfb уже установлен") echo "Xvfb ist bereits installiert"; return;;
      fr\|"Xvfb уже установлен") echo "Xvfb est déjà installé"; return;;
      es\|"Xvfb уже установлен") echo "Xvfb ya está instalado"; return;;
      zh\|"Xvfb уже установлен") echo "Xvfb 已安装"; return;;
      en\|"Удалённое управление включено") echo "Remote control is enabled"; return;;
      de\|"Удалённое управление включено") echo "Fernsteuerung ist aktiviert"; return;;
      fr\|"Удалённое управление включено") echo "Le contrôle à distance est activé"; return;;
      es\|"Удалённое управление включено") echo "El control remoto está activado"; return;;
      zh\|"Удалённое управление включено") echo "远程控制已启用"; return;;
      en\|"Самоподписанный сертификат создан") echo "Self-signed certificate created"; return;;
      de\|"Самоподписанный сертификат создан") echo "Selbstsigniertes Zertifikat erstellt"; return;;
      fr\|"Самоподписанный сертификат создан") echo "Certificat autosigné créé"; return;;
      es\|"Самоподписанный сертификат создан") echo "Certificado autofirmado creado"; return;;
      zh\|"Самоподписанный сертификат создан") echo "自签名证书已创建"; return;;
      en\|"Порт "*" свободен") local port="${msg#Порт }"; port="${port% свободен}"; printf "Port %s is available" "$port"; return;;
      de\|"Порт "*" свободен") local port="${msg#Порт }"; port="${port% свободен}"; printf "Port %s ist verfügbar" "$port"; return;;
      fr\|"Порт "*" свободен") local port="${msg#Порт }"; port="${port% свободен}"; printf "Le port %s est disponible" "$port"; return;;
      es\|"Порт "*" свободен") local port="${msg#Порт }"; port="${port% свободен}"; printf "El puerto %s está disponible" "$port"; return;;
      zh\|"Порт "*" свободен") local port="${msg#Порт }"; port="${port% свободен}"; printf "端口 %s 可用" "$port"; return;;
      de\|"Конфигурация создана (язык панели по умолчанию: "*) local language="${msg#*по умолчанию: }"; language="${language%)}"; printf "Konfiguration erstellt (Standardsprache des Panels: %s)" "$language"; return;;
      fr\|"Конфигурация создана (язык панели по умолчанию: "*) local language="${msg#*по умолчанию: }"; language="${language%)}"; printf "Configuration créée (langue par défaut du panneau : %s)" "$language"; return;;
      es\|"Конфигурация создана (язык панели по умолчанию: "*) local language="${msg#*по умолчанию: }"; language="${language%)}"; printf "Configuración creada (idioma predeterminado del panel: %s)" "$language"; return;;
      zh\|"Конфигурация создана (язык панели по умолчанию: "*) local language="${msg#*по умолчанию: }"; language="${language%)}"; printf "配置已创建（面板默认语言：%s）" "$language"; return;;
      en\|"Nginx настроен") echo 'Nginx configured'; return;;
      de\|"Nginx настроен") echo 'Nginx konfiguriert'; return;;
      fr\|"Nginx настроен") echo 'Nginx configuré'; return;;
      es\|"Nginx настроен") echo 'Nginx configurado'; return;;
      zh\|"Nginx настроен") echo 'Nginx 已配置'; return;;
      en\|"Nginx не установлен") echo 'Nginx is not installed'; return;;
      de\|"Nginx не установлен") echo 'Nginx ist nicht installiert'; return;;
      fr\|"Nginx не установлен") echo 'Nginx n’est pas installé'; return;;
      es\|"Nginx не установлен") echo 'Nginx no está instalado'; return;;
      zh\|"Nginx не установлен") echo '尚未安装 Nginx'; return;;
      en\|"Node.js не установлен. Устанавливаю вручную...") echo 'Node.js is not installed. Installing manually...'; return;;
      de\|"Node.js не установлен. Устанавливаю вручную...") echo 'Node.js ist nicht installiert. Manuelle Installation...'; return;;
      fr\|"Node.js не установлен. Устанавливаю вручную...") echo 'Node.js n’est pas installé. Installation manuelle…'; return;;
      es\|"Node.js не установлен. Устанавливаю вручную...") echo 'Node.js no está instalado. Instalándolo manualmente…'; return;;
      zh\|"Node.js не установлен. Устанавливаю вручную...") echo '未安装 Node.js，正在手动安装…'; return;;
      en\|"NodeSource недоступен, устанавливаю из репозитория Ubuntu...") echo 'NodeSource unavailable; installing from the Ubuntu repository...'; return;;
      de\|"NodeSource недоступен, устанавливаю из репозитория Ubuntu...") echo 'NodeSource nicht verfügbar; Installation aus dem Ubuntu-Repository...'; return;;
      fr\|"NodeSource недоступен, устанавливаю из репозитория Ubuntu...") echo 'NodeSource indisponible ; installation depuis le dépôt Ubuntu…'; return;;
      es\|"NodeSource недоступен, устанавливаю из репозитория Ubuntu...") echo 'NodeSource no disponible; instalando desde el repositorio de Ubuntu…'; return;;
      zh\|"NodeSource недоступен, устанавливаю из репозитория Ubuntu...") echo 'NodeSource 不可用，正在从 Ubuntu 软件源安装…'; return;;
      en\|"SSL-сертификат получен!") echo 'SSL certificate obtained!'; return;;
      de\|"SSL-сертификат получен!") echo 'SSL-Zertifikat erhalten!'; return;;
      fr\|"SSL-сертификат получен!") echo 'Certificat SSL obtenu !'; return;;
      es\|"SSL-сертификат получен!") echo '¡Certificado SSL obtenido!'; return;;
      zh\|"SSL-сертификат получен!") echo 'SSL 证书已获取！'; return;;
      en\|"SSL-сертификаты установлены") echo 'SSL certificates installed'; return;;
      de\|"SSL-сертификаты установлены") echo 'SSL-Zertifikate installiert'; return;;
      fr\|"SSL-сертификаты установлены") echo 'Certificats SSL installés'; return;;
      es\|"SSL-сертификаты установлены") echo 'Certificados SSL instalados'; return;;
      zh\|"SSL-сертификаты установлены") echo 'SSL 证书已安装'; return;;
      en\|"UFW не установлен") echo 'UFW is not installed'; return;;
      de\|"UFW не установлен") echo 'UFW ist nicht installiert'; return;;
      fr\|"UFW не установлен") echo 'UFW n’est pas installé'; return;;
      es\|"UFW не установлен") echo 'UFW no está instalado'; return;;
      zh\|"UFW не установлен") echo '尚未安装 UFW'; return;;
      en\|"dbus-next (портал ввода) ставится вместе с остальными npm-зависимостями на шаге 4") echo 'dbus-next (input portal) is installed with the other npm dependencies in step 4'; return;;
      de\|"dbus-next (портал ввода) ставится вместе с остальными npm-зависимостями на шаге 4") echo 'dbus-next (Eingabeportal) wird zusammen mit den übrigen npm-Abhängigkeiten in Schritt 4 installiert'; return;;
      fr\|"dbus-next (портал ввода) ставится вместе с остальными npm-зависимостями на шаге 4") echo 'dbus-next (portail de saisie) sera installé avec les autres dépendances npm à l’étape 4'; return;;
      es\|"dbus-next (портал ввода) ставится вместе с остальными npm-зависимостями на шаге 4") echo 'dbus-next (portal de entrada) se instala junto con las demás dependencias npm en el paso 4'; return;;
      zh\|"dbus-next (портал ввода) ставится вместе с остальными npm-зависимостями на шаге 4") echo 'dbus-next（输入门户）将在步骤 4 与其他 npm 依赖项一起安装'; return;;
      en\|"npm install завершился с ошибкой:") echo 'npm install failed:'; return;;
      de\|"npm install завершился с ошибкой:") echo 'npm install ist fehlgeschlagen:'; return;;
      fr\|"npm install завершился с ошибкой:") echo 'Échec de npm install :'; return;;
      es\|"npm install завершился с ошибкой:") echo 'npm install falló:'; return;;
      zh\|"npm install завершился с ошибкой:") echo 'npm install 失败：'; return;;
      en\|"remote-portal-worker.js восстановлен") echo 'remote-portal-worker.js restored'; return;;
      de\|"remote-portal-worker.js восстановлен") echo 'remote-portal-worker.js wiederhergestellt'; return;;
      fr\|"remote-portal-worker.js восстановлен") echo 'remote-portal-worker.js restauré'; return;;
      es\|"remote-portal-worker.js восстановлен") echo 'remote-portal-worker.js restaurado'; return;;
      zh\|"remote-portal-worker.js восстановлен") echo 'remote-portal-worker.js 已恢复'; return;;
      en\|"remote-portal-worker.js отсутствует — восстанавливаю встроенную копию...") echo 'remote-portal-worker.js is missing — restoring the bundled copy...'; return;;
      de\|"remote-portal-worker.js отсутствует — восстанавливаю встроенную копию...") echo 'remote-portal-worker.js fehlt — integrierte Kopie wird wiederhergestellt...'; return;;
      fr\|"remote-portal-worker.js отсутствует — восстанавливаю встроенную копию...") echo 'remote-portal-worker.js absent — restauration de la copie intégrée…'; return;;
      es\|"remote-portal-worker.js отсутствует — восстанавливаю встроенную копию...") echo 'Falta remote-portal-worker.js; restaurando la copia incluida…'; return;;
      zh\|"remote-portal-worker.js отсутствует — восстанавливаю встроенную копию...") echo '缺少 remote-portal-worker.js，正在恢复内置副本…'; return;;
      en\|"server.js НЕ найден в папке скрипта") echo 'server.js was NOT found in the script directory'; return;;
      de\|"server.js НЕ найден в папке скрипта") echo 'server.js wurde NICHT im Skriptverzeichnis gefunden'; return;;
      fr\|"server.js НЕ найден в папке скрипта") echo 'server.js INTROUVABLE dans le dossier du script'; return;;
      es\|"server.js НЕ найден в папке скрипта") echo 'No se encontró server.js en la carpeta del script'; return;;
      zh\|"server.js НЕ найден в папке скрипта") echo '脚本目录中未找到 server.js'; return;;
      en\|"server.js есть в папке скрипта") echo 'server.js found in the script directory'; return;;
      de\|"server.js есть в папке скрипта") echo 'server.js im Skriptverzeichnis gefunden'; return;;
      fr\|"server.js есть в папке скрипта") echo 'server.js trouvé dans le dossier du script'; return;;
      es\|"server.js есть в папке скрипта") echo 'server.js encontrado en la carpeta del script'; return;;
      zh\|"server.js есть в папке скрипта") echo '脚本目录中已找到 server.js'; return;;
      en\|"Автоматическое получение не удалось. Попробуйте вручную:") echo 'Automatic certificate setup failed. Try manually:'; return;;
      de\|"Автоматическое получение не удалось. Попробуйте вручную:") echo 'Automatische Zertifikatsbeschaffung fehlgeschlagen. Manuell versuchen:'; return;;
      fr\|"Автоматическое получение не удалось. Попробуйте вручную:") echo 'Échec de l’obtention automatique. Essayez manuellement :'; return;;
      es\|"Автоматическое получение не удалось. Попробуйте вручную:") echo 'No se pudo obtener el certificado automáticamente. Inténtalo manualmente:'; return;;
      zh\|"Автоматическое получение не удалось. Попробуйте вручную:") echo '自动获取证书失败。请尝试手动操作：'; return;;
      en\|"Безопасное обновление невозможно: резервный ключ безопасности отсутствует.") echo 'Safe update is unavailable: the backup security key is missing.'; return;;
      de\|"Безопасное обновление невозможно: резервный ключ безопасности отсутствует.") echo 'Sicheres Update nicht möglich: Der Sicherheits-Ersatzschlüssel fehlt.'; return;;
      fr\|"Безопасное обновление невозможно: резервный ключ безопасности отсутствует.") echo 'Mise à jour sécurisée impossible : la clé de secours est manquante.'; return;;
      es\|"Безопасное обновление невозможно: резервный ключ безопасности отсутствует.") echo 'No se puede actualizar de forma segura: falta la clave de respaldo.'; return;;
      zh\|"Безопасное обновление невозможно: резервный ключ безопасности отсутствует.") echo '无法安全更新：缺少安全备份密钥。'; return;;
      en\|"Версии ниже 2.1.9 не имеют одноразового резервного пароля и защиты целостности администраторов.") echo 'Versions earlier than 2.1.9 lack a one-time backup password and administrator integrity protection.'; return;;
      de\|"Версии ниже 2.1.9 не имеют одноразового резервного пароля и защиты целостности администраторов.") echo 'Versionen vor 2.1.9 verfügen weder über ein einmaliges Ersatzpasswort noch über Integritätsschutz für Administratoren.'; return;;
      fr\|"Версии ниже 2.1.9 не имеют одноразового резервного пароля и защиты целостности администраторов.") echo 'Les versions antérieures à 2.1.9 ne disposent ni du mot de passe de secours à usage unique ni de la protection d’intégrité des administrateurs.'; return;;
      es\|"Версии ниже 2.1.9 не имеют одноразового резервного пароля и защиты целостности администраторов.") echo 'Las versiones anteriores a 2.1.9 no incluyen contraseña de respaldo de un solo uso ni protección de integridad de administradores.'; return;;
      zh\|"Версии ниже 2.1.9 не имеют одноразового резервного пароля и защиты целостности администраторов.") echo '2.1.9 之前的版本没有一次性备用密码和管理员完整性保护。'; return;;
      en\|"Порт не найден в старом конфиге.") echo 'Port was not found in the previous configuration.'; return;;
      de\|"Порт не найден в старом конфиге.") echo 'Port in der alten Konfiguration nicht gefunden.'; return;;
      fr\|"Порт не найден в старом конфиге.") echo 'Port introuvable dans l’ancienne configuration.'; return;;
      es\|"Порт не найден в старом конфиге.") echo 'No se encontró el puerto en la configuración anterior.'; return;;
      zh\|"Порт не найден в старом конфиге.") echo '旧配置中未找到端口。'; return;;
      en\|"Нужно выбрать новый порт — Enter оставить нельзя.") echo 'Choose a new port; you cannot press Enter to keep the current one.'; return;;
      de\|"Нужно выбрать новый порт — Enter оставить нельзя.") echo 'Wählen Sie einen neuen Port. Enter kann hier nicht zum Beibehalten verwendet werden.'; return;;
      fr\|"Нужно выбрать новый порт — Enter оставить нельзя.") echo 'Choisissez un nouveau port ; vous ne pouvez pas appuyer sur Entrée pour conserver l’ancien.'; return;;
      es\|"Нужно выбрать новый порт — Enter оставить нельзя.") echo 'Elige un puerto nuevo; no puedes pulsar Intro para mantener el actual.'; return;;
      zh\|"Нужно выбрать новый порт — Enter оставить нельзя.") echo '必须选择新端口，不能按 Enter 保留当前端口。'; return;;
      en\|"Не удалось установить Node.js. Установите вручную:") echo 'Could not install Node.js. Install it manually:'; return;;
      de\|"Не удалось установить Node.js. Установите вручную:") echo 'Node.js konnte nicht installiert werden. Bitte manuell installieren:'; return;;
      fr\|"Не удалось установить Node.js. Установите вручную:") echo 'Impossible d’installer Node.js. Installez-le manuellement :'; return;;
      es\|"Не удалось установить Node.js. Установите вручную:") echo 'No se pudo instalar Node.js. Instálalo manualmente:'; return;;
      zh\|"Не удалось установить Node.js. Установите вручную:") echo '无法安装 Node.js。请手动安装：'; return;;
      en\|"Не удалось установить runtime dbus-next") echo 'Could not install the dbus-next runtime'; return;;
      de\|"Не удалось установить runtime dbus-next") echo 'dbus-next-Laufzeit konnte nicht installiert werden'; return;;
      fr\|"Не удалось установить runtime dbus-next") echo 'Impossible d’installer l’environnement dbus-next'; return;;
      es\|"Не удалось установить runtime dbus-next") echo 'No se pudo instalar el runtime de dbus-next'; return;;
      zh\|"Не удалось установить runtime dbus-next") echo '无法安装 dbus-next 运行时'; return;;
      en\|"Путь к сертификату (.crt/.pem)") echo 'Certificate file path (.crt/.pem)'; return;;
      de\|"Путь к сертификату (.crt/.pem)") echo 'Pfad zur Zertifikatsdatei (.crt/.pem)'; return;;
      fr\|"Путь к сертификату (.crt/.pem)") echo 'Chemin du certificat (.crt/.pem)'; return;;
      es\|"Путь к сертификату (.crt/.pem)") echo 'Ruta del certificado (.crt/.pem)'; return;;
      zh\|"Путь к сертификату (.crt/.pem)") echo '证书文件路径（.crt/.pem）'; return;;
      en\|"Путь к приватному ключу (.key)") echo 'Private key file path (.key)'; return;;
      de\|"Путь к приватному ключу (.key)") echo 'Pfad zur privaten Schlüsseldatei (.key)'; return;;
      fr\|"Путь к приватному ключу (.key)") echo 'Chemin de la clé privée (.key)'; return;;
      es\|"Путь к приватному ключу (.key)") echo 'Ruta de la clave privada (.key)'; return;;
      zh\|"Путь к приватному ключу (.key)") echo '私钥文件路径（.key）'; return;;
      en\|"Путь должен быть абсолютным (начинаться с /). Пример: /opt/nix-panel") echo 'Path must be absolute (start with /). Example: /opt/nix-panel'; return;;
      de\|"Путь должен быть абсолютным (начинаться с /). Пример: /opt/nix-panel") echo 'Der Pfad muss absolut sein (mit / beginnen). Beispiel: /opt/nix-panel'; return;;
      fr\|"Путь должен быть абсолютным (начинаться с /). Пример: /opt/nix-panel") echo 'Le chemin doit être absolu (commencer par /). Exemple : /opt/nix-panel'; return;;
      es\|"Путь должен быть абсолютным (начинаться с /). Пример: /opt/nix-panel") echo 'La ruta debe ser absoluta (empezar por /). Ejemplo: /opt/nix-panel'; return;;
      zh\|"Путь должен быть абсолютным (начинаться с /). Пример: /opt/nix-panel") echo '路径必须是绝对路径（以 / 开头）。示例：/opt/nix-panel'; return;;
      en\|"Резервный пароль безопасности сгенерирован") echo 'Backup security password generated'; return;;
      de\|"Резервный пароль безопасности сгенерирован") echo 'Sicherheits-Ersatzpasswort erstellt'; return;;
      fr\|"Резервный пароль безопасности сгенерирован") echo 'Mot de passe de secours généré'; return;;
      es\|"Резервный пароль безопасности сгенерирован") echo 'Contraseña de respaldo generada'; return;;
      zh\|"Резервный пароль безопасности сгенерирован") echo '安全备用密码已生成'; return;;
      en\|"Рекомендуется Ubuntu 24+, но продолжаем...") echo 'Ubuntu 24+ is recommended, but continuing...'; return;;
      de\|"Рекомендуется Ubuntu 24+, но продолжаем...") echo 'Ubuntu 24+ wird empfohlen. Installation wird fortgesetzt...'; return;;
      fr\|"Рекомендуется Ubuntu 24+, но продолжаем...") echo 'Ubuntu 24+ est recommandé, mais l’installation continue…'; return;;
      es\|"Рекомендуется Ubuntu 24+, но продолжаем...") echo 'Se recomienda Ubuntu 24+, pero se continuará…'; return;;
      zh\|"Рекомендуется Ubuntu 24+, но продолжаем...") echo '建议使用 Ubuntu 24+，继续安装…'; return;;
      en\|"Сервис systemd создан и включен") echo 'systemd service created and enabled'; return;;
      de\|"Сервис systemd создан и включен") echo 'systemd-Dienst erstellt und aktiviert'; return;;
      fr\|"Сервис systemd создан и включен") echo 'Service systemd créé et activé'; return;;
      es\|"Сервис systemd создан и включен") echo 'Servicio systemd creado y habilitado'; return;;
      zh\|"Сервис systemd создан и включен") echo 'systemd 服务已创建并启用'; return;;
      en\|"Сертификаты найдены") echo 'Certificates found'; return;;
      de\|"Сертификаты найдены") echo 'Zertifikate gefunden'; return;;
      fr\|"Сертификаты найдены") echo 'Certificats trouvés'; return;;
      es\|"Сертификаты найдены") echo 'Certificados encontrados'; return;;
      zh\|"Сертификаты найдены") echo '已找到证书'; return;;
      en\|"Продолжаем... Панель может не работать.") echo 'Continuing... The panel may not work.'; return;;
      de\|"Продолжаем... Панель может не работать.") echo 'Fortfahren... Das Panel funktioniert möglicherweise nicht.'; return;;
      fr\|"Продолжаем... Панель может не работать.") echo 'Poursuite… Le panneau risque de ne pas fonctionner.'; return;;
      es\|"Продолжаем... Панель может не работать.") echo 'Continuando… Es posible que el panel no funcione.'; return;;
      zh\|"Продолжаем... Панель может не работать.") echo '继续安装…面板可能无法运行。'; return;;
      en\|"Продолжить?") echo 'Continue?'; return;;
      de\|"Продолжить?") echo 'Fortfahren?'; return;;
      fr\|"Продолжить?") echo 'Continuer ?'; return;;
      es\|"Продолжить?") echo '¿Continuar?'; return;;
      zh\|"Продолжить?") echo '继续？'; return;;
      en\|"Продолжить установку без копирования файлов?") echo 'Continue installation without copying the panel files?'; return;;
      de\|"Продолжить установку без копирования файлов?") echo 'Installation ohne Kopieren der Paneldateien fortsetzen?'; return;;
      fr\|"Продолжить установку без копирования файлов?") echo 'Continuer sans copier les fichiers du panneau ?'; return;;
      es\|"Продолжить установку без копирования файлов?") echo '¿Continuar la instalación sin copiar los archivos del panel?'; return;;
      zh\|"Продолжить установку без копирования файлов?") echo '不复制面板文件并继续安装？'; return;;
      en\|"Установить Nginx?") echo 'Install Nginx?'; return;;
      de\|"Установить Nginx?") echo 'Nginx installieren?'; return;;
      fr\|"Установить Nginx?") echo 'Installer Nginx ?'; return;;
      es\|"Установить Nginx?") echo '¿Instalar Nginx?'; return;;
      zh\|"Установить Nginx?") echo '安装 Nginx？'; return;;
      en\|"Установить UFW?") echo 'Install UFW?'; return;;
      de\|"Установить UFW?") echo 'UFW installieren?'; return;;
      fr\|"Установить UFW?") echo 'Installer UFW ?'; return;;
      es\|"Установить UFW?") echo '¿Instalar UFW?'; return;;
      zh\|"Установить UFW?") echo '安装 UFW？'; return;;
      en\|"Обнаружена стандартная конфигурация Nginx") echo 'Default Nginx configuration detected'; return;;
      de\|"Обнаружена стандартная конфигурация Nginx") echo 'Standardmäßige Nginx-Konfiguration erkannt'; return;;
      fr\|"Обнаружена стандартная конфигурация Nginx") echo 'Configuration Nginx par défaut détectée'; return;;
      es\|"Обнаружена стандартная конфигурация Nginx") echo 'Se detectó la configuración predeterminada de Nginx'; return;;
      zh\|"Обнаружена стандартная конфигурация Nginx") echo '检测到 Nginx 默认配置'; return;;
      en\|"Ошибка в конфигурации nginx. Проверьте: nginx -t") echo 'Nginx configuration error. Check with: nginx -t'; return;;
      de\|"Ошибка в конфигурации nginx. Проверьте: nginx -t") echo 'Fehler in der Nginx-Konfiguration. Prüfen mit: nginx -t'; return;;
      fr\|"Ошибка в конфигурации nginx. Проверьте: nginx -t") echo 'Erreur de configuration Nginx. Vérifiez avec : nginx -t'; return;;
      es\|"Ошибка в конфигурации nginx. Проверьте: nginx -t") echo 'Error en la configuración de Nginx. Comprueba con: nginx -t'; return;;
      zh\|"Ошибка в конфигурации nginx. Проверьте: nginx -t") echo 'Nginx 配置错误。请运行：nginx -t'; return;;
      en\|"Убедитесь, что install.sh находится в папке с server.js") echo 'Make sure install.sh is in the same directory as server.js'; return;;
      de\|"Убедитесь, что install.sh находится в папке с server.js") echo 'Stellen Sie sicher, dass install.sh im selben Verzeichnis wie server.js liegt'; return;;
      fr\|"Убедитесь, что install.sh находится в папке с server.js") echo 'Vérifiez que install.sh se trouve dans le même dossier que server.js'; return;;
      es\|"Убедитесь, что install.sh находится в папке с server.js") echo 'Asegúrate de que install.sh esté en la misma carpeta que server.js'; return;;
      zh\|"Убедитесь, что install.sh находится в папке с server.js") echo '请确认 install.sh 与 server.js 位于同一目录'; return;;
      en\|"Не удалось найти файлы панели!") echo 'Panel files could not be found!'; return;;
      de\|"Не удалось найти файлы панели!") echo 'Paneldateien wurden nicht gefunden!'; return;;
      fr\|"Не удалось найти файлы панели!") echo 'Fichiers du panneau introuvables !'; return;;
      es\|"Не удалось найти файлы панели!") echo '¡No se encontraron los archivos del panel!'; return;;
      zh\|"Не удалось найти файлы панели!") echo '未找到面板文件！'; return;;
      en\|"КРИТИЧЕСКАЯ ОШИБКА: не удалось создать users.json!") echo 'CRITICAL ERROR: could not create users.json!'; return;;
      de\|"КРИТИЧЕСКАЯ ОШИБКА: не удалось создать users.json!") echo 'KRITISCHER FEHLER: users.json konnte nicht erstellt werden!'; return;;
      fr\|"КРИТИЧЕСКАЯ ОШИБКА: не удалось создать users.json!") echo 'ERREUR CRITIQUE : impossible de créer users.json !'; return;;
      es\|"КРИТИЧЕСКАЯ ОШИБКА: не удалось создать users.json!") echo 'ERROR CRÍTICO: no se pudo crear users.json.'; return;;
      zh\|"КРИТИЧЕСКАЯ ОШИБКА: не удалось создать users.json!") echo '严重错误：无法创建 users.json！'; return;;
      en\|"Не удалось восстановить remote-portal-worker.js") echo 'Could not restore remote-portal-worker.js'; return;;
      de\|"Не удалось восстановить remote-portal-worker.js") echo 'remote-portal-worker.js konnte nicht wiederhergestellt werden'; return;;
      fr\|"Не удалось восстановить remote-portal-worker.js") echo 'Impossible de restaurer remote-portal-worker.js'; return;;
      es\|"Не удалось восстановить remote-portal-worker.js") echo 'No se pudo restaurar remote-portal-worker.js'; return;;
      zh\|"Не удалось восстановить remote-portal-worker.js") echo '无法恢复 remote-portal-worker.js'; return;;
      en\|"Не удалось доустановить зависимости после копирования файлов — панель может не запуститься.") echo 'Could not install remaining dependencies after copying files; the panel may not start.'; return;;
      de\|"Не удалось доустановить зависимости после копирования файлов — панель может не запуститься.") echo 'Weitere Abhängigkeiten konnten nach dem Kopieren nicht installiert werden; das Panel startet möglicherweise nicht.'; return;;
      fr\|"Не удалось доустановить зависимости после копирования файлов — панель может не запуститься.") echo 'Impossible d’installer les dépendances restantes après la copie ; le panneau risque de ne pas démarrer.'; return;;
      es\|"Не удалось доустановить зависимости после копирования файлов — панель может не запуститься.") echo 'No se pudieron instalar las dependencias restantes tras copiar los archivos; el panel podría no iniciarse.'; return;;
      zh\|"Не удалось доустановить зависимости после копирования файлов — панель может не запуститься.") echo '复制文件后仍有依赖项未能安装，面板可能无法启动。'; return;;
      en\|"Критическая ошибка: remote-portal-worker.js отсутствует после копирования.") echo 'Critical error: remote-portal-worker.js is missing after copying.'; return;;
      de\|"Критическая ошибка: remote-portal-worker.js отсутствует после копирования.") echo 'Kritischer Fehler: remote-portal-worker.js fehlt nach dem Kopieren.'; return;;
      fr\|"Критическая ошибка: remote-portal-worker.js отсутствует после копирования.") echo 'Erreur critique : remote-portal-worker.js est absent après la copie.'; return;;
      es\|"Критическая ошибка: remote-portal-worker.js отсутствует после копирования.") echo 'Error crítico: falta remote-portal-worker.js después de copiar los archivos.'; return;;
      zh\|"Критическая ошибка: remote-portal-worker.js отсутствует после копирования.") echo '严重错误：复制后仍缺少 remote-portal-worker.js。'; return;;
      en\|"Критическая ошибка: не найден исходный remote-portal-worker.js для runtime-копии") echo 'Critical error: source remote-portal-worker.js for the runtime copy was not found'; return;;
      de\|"Критическая ошибка: не найден исходный remote-portal-worker.js для runtime-копии") echo 'Kritischer Fehler: Quelldatei remote-portal-worker.js für die Laufzeitkopie fehlt'; return;;
      fr\|"Критическая ошибка: не найден исходный remote-portal-worker.js для runtime-копии") echo 'Erreur critique : fichier source remote-portal-worker.js introuvable pour la copie runtime'; return;;
      es\|"Критическая ошибка: не найден исходный remote-portal-worker.js для runtime-копии") echo 'Error crítico: no se encontró el remote-portal-worker.js de origen para la copia runtime'; return;;
      zh\|"Критическая ошибка: не найден исходный remote-portal-worker.js для runtime-копии") echo '严重错误：未找到运行时副本所需的源文件 remote-portal-worker.js'; return;;
      en\|"Панель всё равно будет обновлена, users.json не изменяется.") echo 'The panel will still be updated; users.json will not be changed.'; return;;
      de\|"Панель всё равно будет обновлена, users.json не изменяется.") echo 'Das Panel wird trotzdem aktualisiert; users.json bleibt unverändert.'; return;;
      fr\|"Панель всё равно будет обновлена, users.json не изменяется.") echo 'Le panneau sera quand même mis à jour ; users.json ne sera pas modifié.'; return;;
      es\|"Панель всё равно будет обновлена, users.json не изменяется.") echo 'El panel se actualizará de todos modos; users.json no se modificará.'; return;;
      zh\|"Панель всё равно будет обновлена, users.json не изменяется.") echo '面板仍会更新；users.json 不会更改。'; return;;
      en\|"Не удалось однозначно определить учётную запись админа установщика.") echo 'Could not identify the installer administrator account.'; return;;
      de\|"Не удалось однозначно определить учётную запись админа установщика.") echo 'Installations-Administratorkonto konnte nicht eindeutig ermittelt werden.'; return;;
      fr\|"Не удалось однозначно определить учётную запись админа установщика.") echo 'Impossible d’identifier le compte administrateur de l’installation.'; return;;
      es\|"Не удалось однозначно определить учётную запись админа установщика.") echo 'No se pudo identificar la cuenta de administrador del instalador.'; return;;
      zh\|"Не удалось однозначно определить учётную запись админа установщика.") echo '无法确定安装程序管理员账户。'; return;;
      en\|"Нажмите Enter чтобы продолжить...") echo 'Press Enter to continue...'; return;;
      de\|"Нажмите Enter чтобы продолжить...") echo 'Zum Fortfahren Enter drücken...'; return;;
      fr\|"Нажмите Enter чтобы продолжить...") echo 'Appuyez sur Entrée pour continuer...'; return;;
      es\|"Нажмите Enter чтобы продолжить...") echo 'Pulsa Intro para continuar...'; return;;
      zh\|"Нажмите Enter чтобы продолжить...") echo '按 Enter 键继续…'; return;;
      en\|"Папка не найдена") echo 'Directory not found'; return;;
      de\|"Папка не найдена") echo 'Verzeichnis nicht gefunden'; return;;
      fr\|"Папка не найдена") echo 'Dossier introuvable'; return;;
      es\|"Папка не найдена") echo 'No se encontró la carpeta'; return;;
      zh\|"Папка не найдена") echo '未找到目录'; return;;
      en\|"Пользователь "*" создан") local value="${msg#Пользователь }"; value="${value% создан}"; printf 'User %s created' "$value"; return;;
      de\|"Пользователь "*" создан") local value="${msg#Пользователь }"; value="${value% создан}"; printf 'Benutzer %s erstellt' "$value"; return;;
      fr\|"Пользователь "*" создан") local value="${msg#Пользователь }"; value="${value% создан}"; printf 'Utilisateur %s créé' "$value"; return;;
      es\|"Пользователь "*" создан") local value="${msg#Пользователь }"; value="${value% создан}"; printf 'Usuario %s creado' "$value"; return;;
      zh\|"Пользователь "*" создан") local value="${msg#Пользователь }"; value="${value% создан}"; printf '用户 %s 已创建' "$value"; return;;
      en\|"Папка создана: "*) local value="${msg#Папка создана: }"; printf 'Directory created: %s' "$value"; return;;
      de\|"Папка создана: "*) local value="${msg#Папка создана: }"; printf 'Verzeichnis erstellt: %s' "$value"; return;;
      fr\|"Папка создана: "*) local value="${msg#Папка создана: }"; printf 'Dossier créé : %s' "$value"; return;;
      es\|"Папка создана: "*) local value="${msg#Папка создана: }"; printf 'Carpeta creada: %s' "$value"; return;;
      zh\|"Папка создана: "*) local value="${msg#Папка создана: }"; printf '目录已创建：%s' "$value"; return;;
      en\|"Файлы уже на месте в "*) local value="${msg#Файлы уже на месте в }"; printf 'Panel files are already in %s' "$value"; return;;
      de\|"Файлы уже на месте в "*) local value="${msg#Файлы уже на месте в }"; printf 'Dateien befinden sich bereits in %s' "$value"; return;;
      fr\|"Файлы уже на месте в "*) local value="${msg#Файлы уже на месте в }"; printf 'Les fichiers sont déjà dans %s' "$value"; return;;
      es\|"Файлы уже на месте в "*) local value="${msg#Файлы уже на месте в }"; printf 'Los archivos ya están en %s' "$value"; return;;
      zh\|"Файлы уже на месте в "*) local value="${msg#Файлы уже на месте в }"; printf '面板文件已位于 %s' "$value"; return;;
      en\|"Файлы восстановлены из "*) local value="${msg#Файлы восстановлены из }"; printf 'Files restored from %s' "$value"; return;;
      de\|"Файлы восстановлены из "*) local value="${msg#Файлы восстановлены из }"; printf 'Dateien aus %s wiederhergestellt' "$value"; return;;
      fr\|"Файлы восстановлены из "*) local value="${msg#Файлы восстановлены из }"; printf 'Fichiers restaurés depuis %s' "$value"; return;;
      es\|"Файлы восстановлены из "*) local value="${msg#Файлы восстановлены из }"; printf 'Archivos restaurados desde %s' "$value"; return;;
      zh\|"Файлы восстановлены из "*) local value="${msg#Файлы восстановлены из }"; printf '已从 %s 恢复文件' "$value"; return;;
      en\|"Или вручную скопируйте файлы в "*) local value="${msg#Или вручную скопируйте файлы в }"; printf 'Or copy the files to %s manually' "$value"; return;;
      de\|"Или вручную скопируйте файлы в "*) local value="${msg#Или вручную скопируйте файлы в }"; printf 'Oder kopieren Sie die Dateien manuell nach %s' "$value"; return;;
      fr\|"Или вручную скопируйте файлы в "*) local value="${msg#Или вручную скопируйте файлы в }"; printf 'Ou copiez les fichiers manuellement vers %s' "$value"; return;;
      es\|"Или вручную скопируйте файлы в "*) local value="${msg#Или вручную скопируйте файлы в }"; printf 'O copia los archivos manualmente a %s' "$value"; return;;
      zh\|"Или вручную скопируйте файлы в "*) local value="${msg#Или вручную скопируйте файлы в }"; printf '或手动将文件复制到 %s' "$value"; return;;
      en\|"Полный лог: "*) local value="${msg#Полный лог: }"; printf 'Full log: %s' "$value"; return;;
      de\|"Полный лог: "*) local value="${msg#Полный лог: }"; printf 'Vollständiges Protokoll: %s' "$value"; return;;
      fr\|"Полный лог: "*) local value="${msg#Полный лог: }"; printf 'Journal complet : %s' "$value"; return;;
      es\|"Полный лог: "*) local value="${msg#Полный лог: }"; printf 'Registro completo: %s' "$value"; return;;
      zh\|"Полный лог: "*) local value="${msg#Полный лог: }"; printf '完整日志：%s' "$value"; return;;
      en\|"Версия "*" сохранена") local value="${msg#Версия }"; value="${value% сохранена}"; printf 'Version %s saved' "$value"; return;;
      de\|"Версия "*" сохранена") local value="${msg#Версия }"; value="${value% сохранена}"; printf 'Version %s gespeichert' "$value"; return;;
      fr\|"Версия "*" сохранена") local value="${msg#Версия }"; value="${value% сохранена}"; printf 'Version %s enregistrée' "$value"; return;;
      es\|"Версия "*" сохранена") local value="${msg#Версия }"; value="${value% сохранена}"; printf 'Versión %s guardada' "$value"; return;;
      zh\|"Версия "*" сохранена") local value="${msg#Версия }"; value="${value% сохранена}"; printf '版本 %s 已保存' "$value"; return;;
      en\|"Безопасное обновление с версии "*" невозможно.") local value="${msg#Безопасное обновление с версии }"; value="${value% невозможно.}"; printf 'Safe update from version %s is unavailable.' "$value"; return;;
      de\|"Безопасное обновление с версии "*" невозможно.") local value="${msg#Безопасное обновление с версии }"; value="${value% невозможно.}"; printf 'Ein sicheres Update von Version %s ist nicht möglich.' "$value"; return;;
      fr\|"Безопасное обновление с версии "*" невозможно.") local value="${msg#Безопасное обновление с версии }"; value="${value% невозможно.}"; printf 'La mise à jour sécurisée depuis la version %s est impossible.' "$value"; return;;
      es\|"Безопасное обновление с версии "*" невозможно.") local value="${msg#Безопасное обновление с версии }"; value="${value% невозможно.}"; printf 'No se puede actualizar de forma segura desde la versión %s.' "$value"; return;;
      zh\|"Безопасное обновление с версии "*" невозможно.") local value="${msg#Безопасное обновление с версии }"; value="${value% невозможно.}"; printf '无法从版本 %s 安全更新。' "$value"; return;;
      en\|"Порт "*" свободен") local value="${msg#Порт }"; value="${value% свободен}"; printf "Port %s is available" "$value"; return;;
      de\|"Порт "*" свободен") local value="${msg#Порт }"; value="${value% свободен}"; printf "Port %s ist verfügbar" "$value"; return;;
      fr\|"Порт "*" свободен") local value="${msg#Порт }"; value="${value% свободен}"; printf "Le port %s est disponible" "$value"; return;;
      es\|"Порт "*" свободен") local value="${msg#Порт }"; value="${value% свободен}"; printf "El puerto %s está disponible" "$value"; return;;
      zh\|"Порт "*" свободен") local value="${msg#Порт }"; value="${value% свободен}"; printf "端口 %s 可用" "$value"; return;;
      en\|"Порт "*" находится в чёрном списке, выберите другой") local value="${msg#Порт }"; value="${value% находится в чёрном списке, выберите другой}"; printf "Port %s is blocked; choose another" "$value"; return;;
      de\|"Порт "*" находится в чёрном списке, выберите другой") local value="${msg#Порт }"; value="${value% находится в чёрном списке, выберите другой}"; printf "Port %s ist gesperrt. Wählen Sie einen anderen." "$value"; return;;
      fr\|"Порт "*" находится в чёрном списке, выберите другой") local value="${msg#Порт }"; value="${value% находится в чёрном списке, выберите другой}"; printf "Le port %s est bloqué ; choisissez-en un autre" "$value"; return;;
      es\|"Порт "*" находится в чёрном списке, выберите другой") local value="${msg#Порт }"; value="${value% находится в чёрном списке, выберите другой}"; printf "El puerto %s está bloqueado; elige otro" "$value"; return;;
      zh\|"Порт "*" находится в чёрном списке, выберите другой") local value="${msg#Порт }"; value="${value% находится в чёрном списке, выберите другой}"; printf "端口 %s 已被禁用，请选择其他端口" "$value"; return;;
      en\|"Текущий порт "*" находится в чёрном списке.") local value="${msg#Текущий порт }"; value="${value% находится в чёрном списке.}"; printf "Current port %s is blocked." "$value"; return;;
      de\|"Текущий порт "*" находится в чёрном списке.") local value="${msg#Текущий порт }"; value="${value% находится в чёрном списке.}"; printf "Der aktuelle Port %s ist gesperrt." "$value"; return;;
      fr\|"Текущий порт "*" находится в чёрном списке.") local value="${msg#Текущий порт }"; value="${value% находится в чёрном списке.}"; printf "Le port actuel %s est bloqué." "$value"; return;;
      es\|"Текущий порт "*" находится в чёрном списке.") local value="${msg#Текущий порт }"; value="${value% находится в чёрном списке.}"; printf "El puerto actual %s está bloqueado." "$value"; return;;
      zh\|"Текущий порт "*" находится в чёрном списке.") local value="${msg#Текущий порт }"; value="${value% находится в чёрном списке.}"; printf "当前端口 %s 已被禁用。" "$value"; return;;
      en\|"Папка '"*"' не пуста!") local value="${msg#Папка '}"; value="${value%' не пуста!}"; printf "Directory '%s' is not empty!" "$value"; return;;
      de\|"Папка '"*"' не пуста!") local value="${msg#Папка '}"; value="${value%' не пуста!}"; printf "Verzeichnis '%s' ist nicht leer!" "$value"; return;;
      fr\|"Папка '"*"' не пуста!") local value="${msg#Папка '}"; value="${value%' не пуста!}"; printf "Le dossier '%s' n’est pas vide !" "$value"; return;;
      es\|"Папка '"*"' не пуста!") local value="${msg#Папка '}"; value="${value%' не пуста!}"; printf "¡La carpeta '%s' no está vacía!" "$value"; return;;
      zh\|"Папка '"*"' не пуста!") local value="${msg#Папка '}"; value="${value%' не пуста!}"; printf "目录“%s”不为空！" "$value"; return;;
      en\|"Введите новый порт") echo "Enter a new port"; return;;
      de\|"Введите новый порт") echo "Neuen Port eingeben"; return;;
      fr\|"Введите новый порт") echo "Saisissez un nouveau port"; return;;
      es\|"Введите новый порт") echo "Introduce un puerto nuevo"; return;;
      zh\|"Введите новый порт") echo "输入新端口"; return;;
      en\|"Данные сохранены в /opt/NIX/") echo "Data saved in /opt/NIX/"; return;;
      de\|"Данные сохранены в /opt/NIX/") echo "Daten gespeichert in /opt/NIX/"; return;;
      fr\|"Данные сохранены в /opt/NIX/") echo "Données enregistrées dans /opt/NIX/"; return;;
      es\|"Данные сохранены в /opt/NIX/") echo "Datos guardados en /opt/NIX/"; return;;
      zh\|"Данные сохранены в /opt/NIX/") echo "数据已保存至 /opt/NIX/"; return;;
      en\|"Для максимальной безопасности выполните полную переустановку NIX Panel 2.1.9+. Данные можно сохранить отдельно.") echo "For maximum security, reinstall NIX Panel 2.1.9 or later. Save the data separately."; return;;
      de\|"Для максимальной безопасности выполните полную переустановку NIX Panel 2.1.9+. Данные можно сохранить отдельно.") echo "Für maximale Sicherheit installieren Sie NIX Panel 2.1.9 oder höher neu. Sichern Sie die Daten separat."; return;;
      fr\|"Для максимальной безопасности выполните полную переустановку NIX Panel 2.1.9+. Данные можно сохранить отдельно.") echo "Pour une sécurité maximale, réinstallez NIX Panel 2.1.9 ou une version ultérieure. Sauvegardez les données séparément."; return;;
      es\|"Для максимальной безопасности выполните полную переустановку NIX Panel 2.1.9+. Данные можно сохранить отдельно.") echo "Para máxima seguridad, reinstala NIX Panel 2.1.9 o posterior. Guarda los datos por separado."; return;;
      zh\|"Для максимальной безопасности выполните полную переустановку NIX Panel 2.1.9+. Данные можно сохранить отдельно.") echo "为确保最高安全性，请重新安装 NIX Panel 2.1.9 或更高版本，并单独备份数据。"; return;;
      en\|"Для этой установки требуется полная переустановка NIX Panel 2.1.9 с сохранением данных отдельно.") echo "This installation requires a full reinstall of NIX Panel 2.1.9; save the data separately."; return;;
      de\|"Для этой установки требуется полная переустановка NIX Panel 2.1.9 с сохранением данных отдельно.") echo "Für diese Installation ist eine vollständige Neuinstallation von NIX Panel 2.1.9 erforderlich. Sichern Sie die Daten separat."; return;;
      fr\|"Для этой установки требуется полная переустановка NIX Panel 2.1.9 с сохранением данных отдельно.") echo "Cette installation nécessite une réinstallation complète de NIX Panel 2.1.9 ; sauvegardez les données séparément."; return;;
      es\|"Для этой установки требуется полная переустановка NIX Panel 2.1.9 с сохранением данных отдельно.") echo "Esta instalación requiere reinstalar NIX Panel 2.1.9 por completo; guarda los datos por separado."; return;;
      zh\|"Для этой установки требуется полная переустановка NIX Panel 2.1.9 с сохранением данных отдельно.") echo "此安装需要完整重新安装 NIX Panel 2.1.9；请单独备份数据。"; return;;
      en\|"Скрипт запущен из "*) local value="${msg#Скрипт запущен из }"; value="${value% — файлы уже на месте}"; printf "Script launched from %s — files are already in place" "$value"; return;;
      de\|"Скрипт запущен из "*) local value="${msg#Скрипт запущен из }"; value="${value% — файлы уже на месте}"; printf "Skript aus %s gestartet — Dateien sind bereits vorhanden" "$value"; return;;
      fr\|"Скрипт запущен из "*) local value="${msg#Скрипт запущен из }"; value="${value% — файлы уже на месте}"; printf "Script lancé depuis %s — les fichiers sont déjà en place" "$value"; return;;
      es\|"Скрипт запущен из "*) local value="${msg#Скрипт запущен из }"; value="${value% — файлы уже на месте}"; printf "Script iniciado desde %s; los archivos ya están en su sitio" "$value"; return;;
      zh\|"Скрипт запущен из "*) local value="${msg#Скрипт запущен из }"; value="${value% — файлы уже на месте}"; printf "脚本从 %s 启动，文件已就位" "$value"; return;;
      en\|"Создание users.json с логином "*) local value="${msg#Создание users.json с логином }"; printf "Creating users.json for login %s..." "$value"; return;;
      de\|"Создание users.json с логином "*) local value="${msg#Создание users.json с логином }"; printf "users.json für Benutzer %s wird erstellt..." "$value"; return;;
      fr\|"Создание users.json с логином "*) local value="${msg#Создание users.json с логином }"; printf "Création de users.json pour l’identifiant %s…" "$value"; return;;
      es\|"Создание users.json с логином "*) local value="${msg#Создание users.json с логином }"; printf "Creando users.json para el usuario %s…" "$value"; return;;
      zh\|"Создание users.json с логином "*) local value="${msg#Создание users.json с логином }"; printf "正在为用户 %s 创建 users.json…" "$value"; return;;
      en\|"Копирование из текущей папки ("*) local value="${msg#Копирование из текущей папки (}"; value="${value%)*}"; printf "Copying from the current directory (%s)..." "$value"; return;;
      de\|"Копирование из текущей папки ("*) local value="${msg#Копирование из текущей папки (}"; value="${value%)*}"; printf "Kopieren aus dem aktuellen Verzeichnis (%s)..." "$value"; return;;
      fr\|"Копирование из текущей папки ("*) local value="${msg#Копирование из текущей папки (}"; value="${value%)*}"; printf "Copie depuis le dossier actuel (%s)…" "$value"; return;;
      es\|"Копирование из текущей папки ("*) local value="${msg#Копирование из текущей папки (}"; value="${value%)*}"; printf "Copiando desde la carpeta actual (%s)…" "$value"; return;;
      zh\|"Копирование из текущей папки ("*) local value="${msg#Копирование из текущей папки (}"; value="${value%)*}"; printf "正在从当前目录（%s）复制…" "$value"; return;;
      en\|"Копирование из предыдущей установки ("*) local value="${msg#Копирование из предыдущей установки (}"; value="${value%)*}"; printf "Copying from the previous installation (%s)..." "$value"; return;;
      de\|"Копирование из предыдущей установки ("*) local value="${msg#Копирование из предыдущей установки (}"; value="${value%)*}"; printf "Kopieren aus der vorherigen Installation (%s)..." "$value"; return;;
      fr\|"Копирование из предыдущей установки ("*) local value="${msg#Копирование из предыдущей установки (}"; value="${value%)*}"; printf "Copie depuis l’installation précédente (%s)…" "$value"; return;;
      es\|"Копирование из предыдущей установки ("*) local value="${msg#Копирование из предыдущей установки (}"; value="${value%)*}"; printf "Copiando desde la instalación anterior (%s)…" "$value"; return;;
      zh\|"Копирование из предыдущей установки ("*) local value="${msg#Копирование из предыдущей установки (}"; value="${value%)*}"; printf "正在从先前安装目录（%s）复制…" "$value"; return;;
      en\|"NIX Panel запущен (PID: "*) local value="${msg#NIX Panel запущен (PID: }"; value="${value%)}"; printf "NIX Panel started (PID: %s)" "$value"; return;;
      de\|"NIX Panel запущен (PID: "*) local value="${msg#NIX Panel запущен (PID: }"; value="${value%)}"; printf "NIX Panel gestartet (PID: %s)" "$value"; return;;
      fr\|"NIX Panel запущен (PID: "*) local value="${msg#NIX Panel запущен (PID: }"; value="${value%)}"; printf "NIX Panel démarré (PID : %s)" "$value"; return;;
      es\|"NIX Panel запущен (PID: "*) local value="${msg#NIX Panel запущен (PID: }"; value="${value%)}"; printf "NIX Panel iniciado (PID: %s)" "$value"; return;;
      zh\|"NIX Panel запущен (PID: "*) local value="${msg#NIX Panel запущен (PID: }"; value="${value%)}"; printf "NIX Panel 已启动（PID：%s）" "$value"; return;;
      en\|"Критическая ошибка: runtime worker не установлен: "*) printf "Critical error: runtime worker was not installed: %s" "${msg#Критическая ошибка: runtime worker не установлен: }"; return;;
      de\|"Критическая ошибка: runtime worker не установлен: "*) printf "Kritischer Fehler: Laufzeit-Worker wurde nicht installiert: %s" "${msg#Критическая ошибка: runtime worker не установлен: }"; return;;
      fr\|"Критическая ошибка: runtime worker не установлен: "*) printf "Erreur critique : worker runtime non installé : %s" "${msg#Критическая ошибка: runtime worker не установлен: }"; return;;
      es\|"Критическая ошибка: runtime worker не установлен: "*) printf "Error crítico: no se instaló el worker runtime: %s" "${msg#Критическая ошибка: runtime worker не установлен: }"; return;;
      zh\|"Критическая ошибка: runtime worker не установлен: "*) printf "严重错误：未安装运行时 worker：%s" "${msg#Критическая ошибка: runtime worker не установлен: }"; return;;
      en\|"Ошибка запуска! Проверьте лог: "*) printf "Startup failed! Check the log: %s" "${msg#Ошибка запуска! Проверьте лог: }"; return;;
      de\|"Ошибка запуска! Проверьте лог: "*) printf "Start fehlgeschlagen! Protokoll prüfen: %s" "${msg#Ошибка запуска! Проверьте лог: }"; return;;
      fr\|"Ошибка запуска! Проверьте лог: "*) printf "Échec du démarrage ! Consultez le journal : %s" "${msg#Ошибка запуска! Проверьте лог: }"; return;;
      es\|"Ошибка запуска! Проверьте лог: "*) printf "Error al iniciar. Consulta el registro: %s" "${msg#Ошибка запуска! Проверьте лог: }"; return;;
      zh\|"Ошибка запуска! Проверьте лог: "*) printf "启动失败！请查看日志：%s" "${msg#Ошибка запуска! Проверьте лог: }"; return;;
      en\|"Папка "*" не пуста!") local value="${msg#Папка }"; value="${value% не пуста!}"; printf "Directory %s is not empty!" "$value"; return;;
      de\|"Папка "*" не пуста!") local value="${msg#Папка }"; value="${value% не пуста!}"; printf "Verzeichnis %s ist nicht leer!" "$value"; return;;
      fr\|"Папка "*" не пуста!") local value="${msg#Папка }"; value="${value% не пуста!}"; printf "Le dossier %s n’est pas vide !" "$value"; return;;
      es\|"Папка "*" не пуста!") local value="${msg#Папка }"; value="${value% не пуста!}"; printf "¡La carpeta %s no está vacía!" "$value"; return;;
      zh\|"Папка "*" не пуста!") local value="${msg#Папка }"; value="${value% не пуста!}"; printf "目录“%s”不为空！" "$value"; return;;
      en\|"Порт "*" уже занят (PID: "*"), выберите другой") local rest="${msg#Порт }"; local port="${rest%% *}"; local pid="${msg#*(PID: }"; pid="${pid%%)*}"; printf "Port %s is already in use (PID: %s); choose another" "$port" "$pid"; return;;
      de\|"Порт "*" уже занят (PID: "*"), выберите другой") local rest="${msg#Порт }"; local port="${rest%% *}"; local pid="${msg#*(PID: }"; pid="${pid%%)*}"; printf "Port %s wird bereits verwendet (PID: %s). Wählen Sie einen anderen." "$port" "$pid"; return;;
      fr\|"Порт "*" уже занят (PID: "*"), выберите другой") local rest="${msg#Порт }"; local port="${rest%% *}"; local pid="${msg#*(PID: }"; pid="${pid%%)*}"; printf "Le port %s est déjà utilisé (PID : %s) ; choisissez-en un autre" "$port" "$pid"; return;;
      es\|"Порт "*" уже занят (PID: "*"), выберите другой") local rest="${msg#Порт }"; local port="${rest%% *}"; local pid="${msg#*(PID: }"; pid="${pid%%)*}"; printf "El puerto %s ya está ocupado (PID: %s); elige otro" "$port" "$pid"; return;;
      zh\|"Порт "*" уже занят (PID: "*"), выберите другой") local rest="${msg#Порт }"; local port="${rest%% *}"; local pid="${msg#*(PID: }"; pid="${pid%%)*}"; printf "端口 %s 已被占用（PID：%s），请选择其他端口" "$port" "$pid"; return;;
      en\|"Порт "*" занят (PID: "*"), выберите другой") local rest="${msg#Порт }"; local port="${rest%% *}"; local pid="${msg#*(PID: }"; pid="${pid%%)*}"; printf "Port %s is in use (PID: %s); choose another" "$port" "$pid"; return;;
      de\|"Порт "*" занят (PID: "*"), выберите другой") local rest="${msg#Порт }"; local port="${rest%% *}"; local pid="${msg#*(PID: }"; pid="${pid%%)*}"; printf "Port %s ist belegt (PID: %s). Wählen Sie einen anderen." "$port" "$pid"; return;;
      fr\|"Порт "*" занят (PID: "*"), выберите другой") local rest="${msg#Порт }"; local port="${rest%% *}"; local pid="${msg#*(PID: }"; pid="${pid%%)*}"; printf "Le port %s est occupé (PID : %s) ; choisissez-en un autre" "$port" "$pid"; return;;
      es\|"Порт "*" занят (PID: "*"), выберите другой") local rest="${msg#Порт }"; local port="${rest%% *}"; local pid="${msg#*(PID: }"; pid="${pid%%)*}"; printf "El puerto %s está ocupado (PID: %s); elige otro" "$port" "$pid"; return;;
      zh\|"Порт "*" занят (PID: "*"), выберите другой") local rest="${msg#Порт }"; local port="${rest%% *}"; local pid="${msg#*(PID: }"; pid="${pid%%)*}"; printf "端口 %s 已被占用（PID：%s），请选择其他端口" "$port" "$pid"; return;;
    esac
    case "$INSTALLER_LANG|$msg" in
      en\|"Порт должен быть числом от 1 до 65535") echo "Port must be a number from 1 to 65535";; de\|"Порт должен быть числом от 1 до 65535") echo "Der Port muss eine Zahl von 1 bis 65535 sein";; fr\|"Порт должен быть числом от 1 до 65535") echo "Le port doit être un nombre entre 1 et 65535";; es\|"Порт должен быть числом от 1 до 65535") echo "El puerto debe ser un número entre 1 y 65535";; zh\|"Порт должен быть числом от 1 до 65535") echo "端口必须是 1 到 65535 之间的数字";;
      en\|"Логин должен быть минимум 3 символа") echo "Username must be at least 3 characters";; de\|"Логин должен быть минимум 3 символа") echo "Der Benutzername muss mindestens 3 Zeichen lang sein";; fr\|"Логин должен быть минимум 3 символа") echo "L’identifiant doit contenir au moins 3 caractères";; es\|"Логин должен быть минимум 3 символа") echo "El usuario debe tener al menos 3 caracteres";; zh\|"Логин должен быть минимум 3 символа") echo "用户名至少需要 3 个字符";;
      en\|"Пароль должен быть минимум 6 символов") echo "Password must be at least 6 characters";; de\|"Пароль должен быть минимум 6 символов") echo "Das Passwort muss mindestens 6 Zeichen lang sein";; fr\|"Пароль должен быть минимум 6 символов") echo "Le mot de passe doit contenir au moins 6 caractères";; es\|"Пароль должен быть минимум 6 символов") echo "La contraseña debe tener al menos 6 caracteres";; zh\|"Пароль должен быть минимум 6 символов") echo "密码至少需要 6 个字符";;
      en\|"Этот порт зарезервирован для другой службы, пожалуйста выберите другой") echo "This port is reserved for another service. Choose a different port.";; de\|"Этот порт зарезервирован для другой службы, пожалуйста выберите другой") echo "Dieser Port ist für einen anderen Dienst reserviert. Wählen Sie einen anderen Port.";; fr\|"Этот порт зарезервирован для другой службы, пожалуйста выберите другой") echo "Ce port est réservé à un autre service. Choisissez-en un autre.";; es\|"Этот порт зарезервирован для другой службы, пожалуйста выберите другой") echo "Este puerto está reservado para otro servicio. Elige otro.";; zh\|"Этот порт зарезервирован для другой службы, пожалуйста выберите другой") echo "此端口已为其他服务保留，请选择其他端口。";;
      en\|"Файлы сертификатов не найдены") echo "Certificate files were not found";; de\|"Файлы сертификатов не найдены") echo "Zertifikatsdateien nicht gefunden";; fr\|"Файлы сертификатов не найдены") echo "Fichiers de certificat introuvables";; es\|"Файлы сертификатов не найдены") echo "No se encontraron los archivos de certificado";; zh\|"Файлы сертификатов не найдены") echo "未找到证书文件";;
      en\|"Панель не запустится без зависимостей — проверьте лог выше.") echo "The panel cannot start without its dependencies. Check the log above.";; de\|"Панель не запустится без зависимостей — проверьте лог выше.") echo "Das Panel kann ohne Abhängigkeiten nicht starten. Prüfen Sie das Protokoll oben.";; fr\|"Панель не запустится без зависимостей — проверьте лог выше.") echo "Le panneau ne peut pas démarrer sans ses dépendances. Consultez le journal ci-dessus.";; es\|"Панель не запустится без зависимостей — проверьте лог выше.") echo "El panel no puede iniciarse sin dependencias. Revisa el registro anterior.";; zh\|"Панель не запустится без зависимостей — проверьте лог выше.") echo "缺少依赖项，面板无法启动。请查看上方日志。";;
      en\|"Установить/настроить удалённое управление?") echo "Install/configure remote control?";; de\|"Установить/настроить удалённое управление?") echo "Fernsteuerung installieren/konfigurieren?";; fr\|"Установить/настроить удалённое управление?") echo "Installer/configurer le contrôle à distance ?";; es\|"Установить/настроить удалённое управление?") echo "¿Instalar/configurar el control remoto?";; zh\|"Установить/настроить удалённое управление?") echo "安装/配置远程控制？";;
      en\|"Установить Xvfb (виртуальный экран)?") echo "Install Xvfb (virtual display)?";; de\|"Установить Xvfb (виртуальный экран)?") echo "Xvfb (virtuelle Anzeige) installieren?";; fr\|"Установить Xvfb (виртуальный экран)?") echo "Installer Xvfb (écran virtuel) ?";; es\|"Установить Xvfb (виртуальный экран)?") echo "¿Instalar Xvfb (pantalla virtual)?";; zh\|"Установить Xvfb (виртуальный экран)?") echo "安装 Xvfb（虚拟显示器）？";;
      en\|"Продолжить установку без исправления (не рекомендуется)?") echo "Continue without fixing the issue (not recommended)?";; de\|"Продолжить установку без исправления (не рекомендуется)?") echo "Ohne Behebung fortfahren (nicht empfohlen)?";; fr\|"Продолжить установку без исправления (не рекомендуется)?") echo "Continuer sans corriger (déconseillé) ?";; es\|"Продолжить установку без исправления (не рекомендуется)?") echo "¿Continuar sin corregirlo (no recomendado)?";; zh\|"Продолжить установку без исправления (не рекомендуется)?") echo "不修复问题并继续安装（不建议）？";;
      en\|"Конфигурация создана (язык панели по умолчанию: "*) printf 'Configuration created (default panel language: %s)' "${msg#*языку панели по умолчанию: }";;
      en\|"Версия "*" сохранена") printf 'Version %s saved' "${msg#Версия }";;
      en\|Шаг) echo "Step";; de\|Шаг) echo "Schritt";; fr\|Шаг) echo "Étape";; es\|Шаг) echo "Paso";; zh\|Шаг) echo "步骤";;
      en\|"Установить заново (удалит старую версию)") echo "Reinstall (removes the current version)";;
      de\|"Установить заново (удалит старую версию)") echo "Neu installieren (entfernt die aktuelle Version)";;
      fr\|"Установить заново (удалит старую версию)") echo "Réinstaller (supprime la version actuelle)";;
      es\|"Установить заново (удалит старую версию)") echo "Reinstalar (elimina la versión actual)";;
      zh\|"Установить заново (удалит старую версию)") echo "重新安装（删除当前版本）";;
      en\|"Обновить (сохранит данные)") echo "Update (keeps your data)";;
      de\|"Обновить (сохранит данные)") echo "Aktualisieren (Daten bleiben erhalten)";;
      fr\|"Обновить (сохранит данные)") echo "Mettre à jour (conserve les données)";;
      es\|"Обновить (сохранит данные)") echo "Actualizar (conserva los datos)";;
      zh\|"Обновить (сохранит данные)") echo "更新（保留数据）";;
      en\|"Удалить панель") echo "Uninstall the panel";; de\|"Удалить панель") echo "Panel deinstallieren";; fr\|"Удалить панель") echo "Désinstaller le panneau";; es\|"Удалить панель") echo "Desinstalar el panel";; zh\|"Удалить панель") echo "卸载面板";;
      en\|"Очистить и установить в эту папку") echo "Clear and install in this folder";; de\|"Очистить и установить в эту папку") echo "Ordner leeren und hier installieren";; fr\|"Очистить и установить в эту папку") echo "Vider et installer dans ce dossier";; es\|"Очистить и установить в эту папку") echo "Vaciar e instalar en esta carpeta";; zh\|"Очистить и установить в эту папку") echo "清空并安装到此目录";;
      en\|"Выбрать другую папку") echo "Choose another folder";; de\|"Выбрать другую папку") echo "Anderen Ordner auswählen";; fr\|"Выбрать другую папку") echo "Choisir un autre dossier";; es\|"Выбрать другую папку") echo "Elegir otra carpeta";; zh\|"Выбрать другую папку") echo "选择其他目录";;
      en\|"Выйти из установки") echo "Exit installer";; de\|"Выйти из установки") echo "Installation beenden";; fr\|"Выйти из установки") echo "Quitter l’installation";; es\|"Выйти из установки") echo "Salir del instalador";; zh\|"Выйти из установки") echo "退出安装程序";;
      en\|"Заменить конфигурацию Nginx (рекомендуется)") echo "Replace the Nginx configuration (recommended)";; de\|"Заменить конфигурацию Nginx (рекомендуется)") echo "Nginx-Konfiguration ersetzen (empfohlen)";; fr\|"Заменить конфигурацию Nginx (рекомендуется)") echo "Remplacer la configuration Nginx (recommandé)";; es\|"Заменить конфигурацию Nginx (рекомендуется)") echo "Reemplazar la configuración de Nginx (recomendado)";; zh\|"Заменить конфигурацию Nginx (рекомендуется)") echo "替换 Nginx 配置（推荐）";;
      en\|"Полная переустановка Nginx") echo "Reinstall Nginx completely";; de\|"Полная переустановка Nginx") echo "Nginx vollständig neu installieren";; fr\|"Полная переустановка Nginx") echo "Réinstaller complètement Nginx";; es\|"Полная переустановка Nginx") echo "Reinstalar Nginx por completo";; zh\|"Полная переустановка Nginx") echo "完全重新安装 Nginx";;
      en\|"Пропустить настройку Nginx") echo "Skip Nginx setup";; de\|"Пропустить настройку Nginx") echo "Nginx-Konfiguration überspringen";; fr\|"Пропустить настройку Nginx") echo "Ignorer la configuration de Nginx";; es\|"Пропустить настройку Nginx") echo "Omitir la configuración de Nginx";; zh\|"Пропустить настройку Nginx") echo "跳过 Nginx 配置";;
      en\|"Получить SSL-сертификат через Let's Encrypt (рекомендуется)") echo "Get an SSL certificate with Let's Encrypt (recommended)";; de\|"Получить SSL-сертификат через Let's Encrypt (рекомендуется)") echo "SSL-Zertifikat über Let's Encrypt beziehen (empfohlen)";; fr\|"Получить SSL-сертификат через Let's Encrypt (рекомендуется)") echo "Obtenir un certificat SSL avec Let's Encrypt (recommandé)";; es\|"Получить SSL-сертификат через Let's Encrypt (рекомендуется)") echo "Obtener un certificado SSL con Let's Encrypt (recomendado)";; zh\|"Получить SSL-сертификат через Let's Encrypt (рекомендуется)") echo "通过 Let's Encrypt 获取 SSL 证书（推荐）";;
      en\|"Указать свои SSL-сертификаты") echo "Use your own SSL certificates";; de\|"Указать свои SSL-сертификаты") echo "Eigene SSL-Zertifikate verwenden";; fr\|"Указать свои SSL-сертификаты") echo "Utiliser ses propres certificats SSL";; es\|"Указать свои SSL-сертификаты") echo "Usar tus propios certificados SSL";; zh\|"Указать свои SSL-сертификаты") echo "使用自己的 SSL 证书";;
      en\|"Пропустить SSL (будет HTTP)") echo "Skip SSL (HTTP will be used)";; de\|"Пропустить SSL (будет HTTP)") echo "SSL überspringen (HTTP wird verwendet)";; fr\|"Пропустить SSL (будет HTTP)") echo "Ignorer SSL (HTTP sera utilisé)";; es\|"Пропустить SSL (будет HTTP)") echo "Omitir SSL (se usará HTTP)";; zh\|"Пропустить SSL (будет HTTP)") echo "跳过 SSL（将使用 HTTP）";;
      en\|"Проверьте адрес перед переходом.") echo "Check the address before continuing.";;
      en\|"Ваш выбор [1/2/3]:") echo "Your choice [1/2/3]: ";; de\|"Ваш выбор [1/2/3]:") echo "Ihre Auswahl [1/2/3]: ";; fr\|"Ваш выбор [1/2/3]:") echo "Votre choix [1/2/3] : ";; es\|"Ваш выбор [1/2/3]:") echo "Tu elección [1/2/3]: ";; zh\|"Ваш выбор [1/2/3]:") echo "请选择 [1/2/3]：";;
      en\|"Выберите действие:") echo "Choose an action:";; de\|"Выберите действие:") echo "Aktion auswählen:";; fr\|"Выберите действие:") echo "Choisir une action :";; es\|"Выберите действие:") echo "Selecciona una acción:";; zh\|"Выберите действие:") echo "选择操作：";;
      en\|"Введите пароль") echo "Enter password";; de\|"Введите пароль") echo "Passwort eingeben";; fr\|"Введите пароль") echo "Saisissez le mot de passe";; es\|"Введите пароль") echo "Introduce la contraseña";; zh\|"Введите пароль") echo "输入密码";;
      en\|"Введите логин") echo "Enter username";; de\|"Введите логин") echo "Benutzernamen eingeben";; fr\|"Введите логин") echo "Saisissez l’identifiant";; es\|"Введите логин") echo "Introduce el usuario";; zh\|"Введите логин") echo "输入用户名";;
      en\|"Домен или IP") echo "Domain or IP address";; de\|"Домен или IP") echo "Domain oder IP-Adresse";; fr\|"Домен или IP") echo "Domaine ou adresse IP";; es\|"Домен или IP") echo "Dominio o dirección IP";; zh\|"Домен или IP") echo "域名或 IP 地址";;
      en\|"Придумайте логин для входа в панель.") echo "Choose a username to sign in to the panel.";; de\|"Придумайте логин для входа в панель.") echo "Legen Sie einen Benutzernamen für die Anmeldung fest.";; fr\|"Придумайте логин для входа в панель.") echo "Choisissez un identifiant pour vous connecter au panneau.";; es\|"Придумайте логин для входа в панель.") echo "Elige un usuario para iniciar sesión en el panel.";; zh\|"Придумайте логин для входа в панель.") echo "请设置用于登录面板的用户名。";;
      en\|"Пароль должен быть надежным!") echo "Choose a strong password!";; de\|"Пароль должен быть надежным!") echo "Wählen Sie ein sicheres Passwort!";; fr\|"Пароль должен быть надежным!") echo "Choisissez un mot de passe robuste !";; es\|"Пароль должен быть надежным!") echo "Elige una contraseña segura.";; zh\|"Пароль должен быть надежным!") echo "请设置高强度密码！";;
      en\|"Пароли не совпадают!") echo "Passwords do not match!";; de\|"Пароли не совпадают!") echo "Die Passwörter stimmen nicht überein!";; fr\|"Пароли не совпадают!") echo "Les mots de passe ne correspondent pas !";; es\|"Пароли не совпадают!") echo "¡Las contraseñas no coinciden!";; zh\|"Пароли не совпадают!") echo "两次输入的密码不一致！";;
      en\|"Нажмите Enter чтобы выйти...") echo "Press Enter to exit...";; de\|"Нажмите Enter чтобы выйти...") echo "Zum Beenden Enter drücken...";; fr\|"Нажмите Enter чтобы выйти...") echo "Appuyez sur Entrée pour quitter...";; es\|"Нажмите Enter чтобы выйти...") echo "Pulsa Intro para salir...";; zh\|"Нажмите Enter чтобы выйти...") echo "按 Enter 键退出…";;      en\|*) case "$msg" in "Выберите действие") echo "Choose an action";; "Проверка системы") echo "System check";; "Выбор папки установки") echo "Choose the installation folder";; "Выбор порта") echo "Choose a port";; "Установка зависимостей") echo "Install dependencies";; "Настройка Nginx") echo "Configure Nginx";; "Создание логина") echo "Create username";; "Создание пароля") echo "Create password";; "Настройка домена и SSL") echo "Configure domain and SSL";; "Удалённое управление") echo "Remote control";; "Введите путь установки") echo "Enter installation path";; "Введите порт для панели") echo "Enter panel port";; "Введите новый порт") echo "Enter a new port";; "Введите логин") echo "Enter username";; "Логин") echo "Username";; "Пароль") echo "Password";; "Повторите пароль") echo "Repeat password";; "Домен или IP") echo "Domain or IP address";; "Порт для панели (Enter — оставить "*) printf 'Panel port (press Enter to keep %s)' "${msg#*оставить }";; "Установить Nginx?") echo "Install Nginx?";; "Установить UFW?") echo "Install UFW?";; "Продолжить?") echo "Continue?";; "Нажмите Enter чтобы продолжить...") echo "Press Enter to continue...";; "Установить заново (удалит старую версию)") echo "Reinstall (removes the current version)";; "Обновить (сохранит данные)") echo "Update (keeps your data)";; "Удалить панель") echo "Uninstall the panel";; "Новая установка NIX Panel v"*) echo "New NIX Panel installation v${msg##*v}";; "Панель и данные удалены") echo "Panel and data removed";; "Данные сохранены в /opt/NIX/") echo "Data kept in /opt/NIX/";; *) printf '%s' "$msg";; esac ;;
      de\|*) case "$msg" in "Выберите действие") echo "Aktion auswählen";; "Проверка системы") echo "Systemprüfung";; "Выбор папки установки") echo "Installationsordner auswählen";; "Выбор порта") echo "Port auswählen";; "Установка зависимостей") echo "Abhängigkeiten installieren";; "Настройка Nginx") echo "Nginx konfigurieren";; "Создание логина") echo "Anmeldenamen erstellen";; "Создание пароля") echo "Passwort erstellen";; "Настройка домена и SSL") echo "Domain und SSL konfigurieren";; "Удалённое управление") echo "Fernsteuerung";; "Путь должен быть абсолютным (начинаться с /). Пример: /opt/nix-panel") echo "Der Pfad muss absolut sein (mit / beginnen). Beispiel: /opt/nix-panel";; "Введите путь установки") echo "Installationspfad eingeben";; "Введите порт для панели") echo "Panel-Port eingeben";; "Логин") echo "Benutzername";; "Пароль") echo "Passwort";; "Повторите пароль") echo "Passwort wiederholen";; "Язык панели по умолчанию") echo "Standardsprache des Panels";; *) printf '%s' "$msg";; esac ;;
      fr\|*) case "$msg" in "Выберите действие") echo "Choisir une action";; "Проверка системы") echo "Vérification du système";; "Выбор папки установки") echo "Choisir le dossier d’installation";; "Выбор порта") echo "Choisir le port";; "Установка зависимостей") echo "Installer les dépendances";; "Настройка Nginx") echo "Configurer Nginx";; "Создание логина") echo "Créer un identifiant";; "Создание пароля") echo "Créer un mot de passe";; "Настройка домена и SSL") echo "Configurer le domaine et SSL";; "Удалённое управление") echo "Contrôle à distance";; "Путь должен быть абсолютным (начинаться с /). Пример: /opt/nix-panel") echo "Le chemin doit être absolu (commencer par /). Exemple : /opt/nix-panel";; "Введите путь установки") echo "Saisissez le chemin d’installation";; "Введите порт для панели") echo "Saisissez le port du panneau";; "Логин") echo "Identifiant";; "Пароль") echo "Mot de passe";; "Повторите пароль") echo "Répétez le mot de passe";; *) printf '%s' "$msg";; esac ;;
      es\|*) case "$msg" in "Выберите действие") echo "Selecciona una acción";; "Проверка системы") echo "Comprobación del sistema";; "Выбор папки установки") echo "Selecciona la carpeta de instalación";; "Выбор порта") echo "Selecciona el puerto";; "Установка зависимостей") echo "Instalación de dependencias";; "Настройка Nginx") echo "Configurar Nginx";; "Создание логина") echo "Crear usuario";; "Создание пароля") echo "Crear contraseña";; "Настройка домена и SSL") echo "Configurar dominio y SSL";; "Удалённое управление") echo "Control remoto";; "Путь должен быть абсолютным (начинаться с /). Пример: /opt/nix-panel") echo "La ruta debe ser absoluta (empezar por /). Ejemplo: /opt/nix-panel";; "Введите путь установки") echo "Introduce la ruta de instalación";; "Введите порт для панели") echo "Introduce el puerto del panel";; "Логин") echo "Usuario";; "Пароль") echo "Contraseña";; "Повторите пароль") echo "Repite la contraseña";; *) printf '%s' "$msg";; esac ;;
      zh\|*) case "$msg" in "Выберите действие") echo "选择操作";; "Проверка системы") echo "检查系统";; "Выбор папки установки") echo "选择安装目录";; "Выбор порта") echo "选择端口";; "Установка зависимостей") echo "安装依赖项";; "Настройка Nginx") echo "配置 Nginx";; "Создание логина") echo "创建登录用户名";; "Создание пароля") echo "创建密码";; "Настройка домена и SSL") echo "配置域名和 SSL";; "Удалённое управление") echo "远程控制";; "Путь должен быть абсолютным (начинаться с /). Пример: /opt/nix-panel") echo "路径必须是绝对路径（以 / 开头）。示例：/opt/nix-panel";; "Введите путь установки") echo "输入安装路径";; "Введите порт для панели") echo "输入面板端口";; "Логин") echo "用户名";; "Пароль") echo "密码";; "Повторите пароль") echo "再次输入密码";; *) printf '%s' "$msg";; esac ;;
    esac
}

choose_language() {
    clear
    echo -e "${PURPLE}"
    echo "  ╔══════════════════════════════════════════════╗"
    echo "  ║              NIX PANEL v2.2.0                ║"
    echo "  ║             Server Management                ║"
    echo "  ╚══════════════════════════════════════════════╝"
    echo -e "${NC}"
    echo
    echo "Choose the installer and panel language / Выберите язык установщика и панели:"
    echo "1) Русский"
    echo "2) English"
    echo "3) Deutsch"
    echo "4) Français"
    echo "5) Español"
    echo "6) 简体中文"
    local choice
    while true; do
        printf "\nLanguage / Язык [1-6] (default 2): "
        read_from_tty choice
        choice="${choice//$'\r'/}"
        case "$choice" in
            "") INSTALLER_LANG="en"; break ;;
            1) INSTALLER_LANG="ru"; break ;;
            2) INSTALLER_LANG="en"; break ;;
            3) INSTALLER_LANG="de"; break ;;
            4) INSTALLER_LANG="fr"; break ;;
            5) INSTALLER_LANG="es"; break ;;
            6) INSTALLER_LANG="zh"; break ;;
            *) echo "Invalid choice. Enter one digit from 1 to 6, or press Enter for English." ;;
        esac
    done
    PANEL_LANGUAGE="$INSTALLER_LANG"
}

# npm install с честной проверкой кода возврата (просто "| tail" его теряет —
# статус пайпа берётся от tail, а не от npm, поэтому ошибка молча тонет).
# Полный лог всегда пишется в /tmp/nix-npm-install.log; на экран — только
# хвост, но при неудаче показываем последние строки РЕАЛЬНОЙ ошибки.
npm_install_checked() {
    local log="/tmp/nix-npm-install.log"

    print_info "Очистка старых npm-зависимостей..."
    rm -rf node_modules package-lock.json

    if npm install --omit=dev --no-audit --no-fund > "$log" 2>&1; then
        return 0
    fi

    print_err "npm install завершился с ошибкой:"
    tail -40 "$log"
    print_err "Полный лог: $log"
    return 1
}

check_root() {
    if [ "$EUID" -ne 0 ]; then
        echo -e "\n${RED}${BOLD}$(localize "Этот скрипт нужно запускать с правами root!")${NC}"
        echo -e "  ${YELLOW}$(localize "Используйте: sudo bash install.sh")${NC}\n"
        exit 1
    fi
}

# Read from terminal even when script is piped
TTY="/dev/tty"
if [ ! -e "$TTY" ]; then
    TTY="/dev/stdin"
fi

read_from_tty() {
    read -r "$@" < "$TTY"
}

press_enter() {
    echo ""
    print_question "Нажмите Enter чтобы продолжить..."
    read_from_tty
}

get_input() {
    local prompt="$1"
    local default="$2"
    local var
    if [ -n "$default" ]; then
        printf "  ${PURPLE}?${NC} %s [${default}]: " "$(localize "$prompt")" >&2
    else
        printf "  ${PURPLE}?${NC} %s: " "$(localize "$prompt")" >&2
    fi
    read_from_tty var
    var="${var//$'\r'/}"
    if [ -z "$var" ] && [ -n "$default" ]; then
        echo "$default"
    else
        echo "$var"
    fi
}

confirm() {
    local prompt="$1"
    local default="${2:-y}"
    local yn
    if [ "$default" = "y" ]; then
        printf "  ${PURPLE}?${NC} %s [Y/n]: " "$(localize "$prompt")" >&2
    else
        printf "  ${PURPLE}?${NC} %s [y/N]: " "$(localize "$prompt")" >&2
    fi
    read_from_tty yn
    yn="${yn//$'\r'/}"
    if [ -z "$yn" ]; then
        yn="$default"
    fi
    case "$yn" in
        [Yy]* ) return 0 ;;
        * ) return 1 ;;
    esac
}

# =============================================================================
# PORT VALIDATION
# =============================================================================
# Ports reserved for system services / commonly blocked by browsers.
# This list is used both on fresh installation and during updates.
BLOCKED_PORTS="1 7 9 11 13 15 17 19 20 21 22 23 25 37 42 43 53 69 77 79 87 95 101 102 103 104 109 110 111 113 115 117 119 123 135 139 143 179 389 427 465 512 513 514 515 526 530 531 532 540 548 554 556 563 587 601 636 989 990 993 995 1719 1720 1723 2049 3659 4045 5060 5061 6000 6566 6665 6666 6667 6668 6669 6679 6697 10080"

port_is_blocked() {
    local port="$1"
    [[ " $BLOCKED_PORTS " == *" $port "* ]]
}

# Compare dotted numeric versions: returns success when $1 < $2.
# Kept POSIX/Bash-only so the installer works before any dependencies are installed.
version_lt() {
    local a="${1#v}" b="${2#v}"
    local IFS=.
    local -a av bv
    read -r -a av <<< "$a"
    read -r -a bv <<< "$b"
    local i x y
    for i in 0 1 2 3; do
        x="${av[$i]:-0}"; y="${bv[$i]:-0}"
        x=$((10#$x)) 2>/dev/null || x=0
        y=$((10#$y)) 2>/dev/null || y=0
        if (( x < y )); then return 0; fi
        if (( x > y )); then return 1; fi
    done
    return 1
}

# =============================================================================
# ACCOUNT IDENTITY HELPERS
# =============================================================================
detect_installer_admin() {
    local users_file="$1"
    [ -f "$users_file" ] || return 0

    python3 - "$users_file" <<'PY'
import json
import sys

path = sys.argv[1]

try:
    with open(path, 'r', encoding='utf-8') as f:
        users = json.load(f)
except Exception:
    sys.exit(0)

# New format: explicit installer marker.
for login, user in users.items():
    if isinstance(user, dict) and user.get("accountType") == "installer_admin":
        print(login)
        sys.exit(0)

# Backward compatibility: if exactly one admin exists in an old users.json,
# it is the only account that can be identified as the installer admin.
admins = [
    login for login, user in users.items()
    if isinstance(user, dict) and user.get("role") == "admin"
]
if len(admins) == 1:
    print(admins[0])
    sys.exit(0)

# Legacy default account name.
if isinstance(users.get("admin"), dict) and users["admin"].get("role") == "admin":
    print("admin")
PY
}


# =============================================================================
# MAIN INSTALLATION
# =============================================================================
TOTAL_STEPS=9

check_root
choose_language

# Check OS
print_banner
print_step 1 "Проверка системы"
if [ -f /etc/os-release ]; then
    . /etc/os-release
    echo -e "  ${GREEN}OS:${NC} $NAME $VERSION_ID"
else
    echo -e "  ${YELLOW}$(localize "OS: Не удалось определить")${NC}"
fi

# Check Ubuntu 24+
if [ -n "$VERSION_ID" ] && [[ "$VERSION_ID" < "24" ]]; then
    print_warn "Рекомендуется Ubuntu 24+, но продолжаем..."
fi

# Check architecture
ARCH=$(uname -m)
echo -e "  ${GREEN}Arch:${NC} $ARCH"
echo -e "  ${GREEN}Host:${NC} $(hostname)"

# =============================================================================
# STEP 0: Choose action
# =============================================================================
echo ""
print_step 0 "Выберите действие"

# Check for existing installation
EXISTING_VERSION=""
if [ -f "$VERSION_FILE" ]; then
    EXISTING_VERSION=$(cat "$VERSION_FILE")
fi

if [ -n "$EXISTING_VERSION" ]; then
    echo ""
    print_info "Обнаружена установка NIX Panel v$EXISTING_VERSION"
    echo ""
    echo "  1) $(localize "Установить заново (удалит старую версию)")"
    echo "  2) $(localize "Обновить (сохранит данные)")"
    echo "  3) $(localize "Удалить панель")"
    echo ""
    printf "  %s" "$(localize "Ваш выбор [1/2/3]:")"
    read_from_tty ACTION_CHOICE
    ACTION_CHOICE="${ACTION_CHOICE//$'\r'/}"
    
    case "$ACTION_CHOICE" in
        3)
            echo ""
            print_warn "Удаление NIX Panel..."
            systemctl stop nix-panel.service 2>/dev/null || true
            systemctl disable nix-panel.service 2>/dev/null || true
            rm -f /etc/systemd/system/nix-panel.service
            systemctl daemon-reload 2>/dev/null || true
            # Remove nginx config
            rm -f /etc/nginx/sites-enabled/nix-panel
            rm -f /etc/nginx/sites-available/nix-panel
            systemctl reload nginx 2>/dev/null || true
            # Ask about data
            if confirm "Удалить все данные (users.json, чат и т.д.)?"; then
                rm -rf /opt/NIX/
                print_ok "Панель и данные удалены"
            else
                print_warn "Данные сохранены в /opt/NIX/"
            fi
            exit 0
            ;;
        2)
            if version_lt "$EXISTING_VERSION" "2.1.9"; then
                print_err "Безопасное обновление с версии $EXISTING_VERSION невозможно."
                print_err "Версии ниже 2.1.9 не имеют одноразового резервного пароля и защиты целостности администраторов."
                print_warn "Для максимальной безопасности выполните полную переустановку NIX Panel 2.1.9+. Данные можно сохранить отдельно."
                exit 1
            fi
            # A 2.1.9+ install is only considered safely updatable when the
            # one-time recovery secret actually exists. Do not silently create
            # a new secret during update: that would weaken the guarantee that
            # the displayed password was issued only once.
            if [ ! -s "/opt/NIX/data/security.json" ] || ! grep -q '"backupPasswordHash"' "/opt/NIX/data/security.json" 2>/dev/null; then
                print_err "Безопасное обновление невозможно: резервный ключ безопасности отсутствует."
                print_warn "Для этой установки требуется полная переустановка NIX Panel 2.1.9 с сохранением данных отдельно."
                exit 1
            fi
            print_info "Обновление панели (данные будут сохранены)..."
            SKIP_USER_STEPS=true
            # Auto-detect install dir from VERSION_FILE location
            if [ -f "$VERSION_FILE" ]; then
                INSTALL_DIR=$(dirname "$VERSION_FILE")
                print_info "Обнаружена установка в $INSTALL_DIR"
            fi
            # Read existing config for port
            if [ -f "$INSTALL_DIR/nix-config.json" ]; then
                OLD_PORT=$(grep -oP '"port":\s*\K\d+' "$INSTALL_DIR/nix-config.json" 2>/dev/null || echo "")
                if [ -n "$OLD_PORT" ]; then
                    PORT=$OLD_PORT
                    print_info "Порт из конфига: $PORT"
                fi
            fi

            # In update mode allow changing the panel port.
            # Enter = keep the current port. If the old port is on the blacklist,
            # the script forces the user to choose a different one.
            print_step 3 "Проверка порта (обновление)"
            if [ -n "$OLD_PORT" ] && ! port_is_blocked "$OLD_PORT"; then
                while true; do
                    NEW_PORT=$(get_input "Порт для панели (Enter — оставить $OLD_PORT)" "")
                    NEW_PORT="${NEW_PORT//$'\r'/}"

                    if [ -z "$NEW_PORT" ]; then
                        PORT="$OLD_PORT"
                        print_ok "Порт не изменён: $PORT"
                        break
                    fi

                    if ! [[ "$NEW_PORT" =~ ^[0-9]+$ ]] || [ "$NEW_PORT" -lt 1 ] || [ "$NEW_PORT" -gt 65535 ]; then
                        print_err "Порт должен быть числом от 1 до 65535"
                        continue
                    fi

                    if port_is_blocked "$NEW_PORT"; then
                        print_err "Порт $NEW_PORT находится в чёрном списке, выберите другой"
                        continue
                    fi

                    if [ "$NEW_PORT" = "$OLD_PORT" ]; then
                        PORT="$OLD_PORT"
                        print_ok "Порт не изменён: $PORT"
                        break
                    fi

                    if ss -tlnp | grep -q ":$NEW_PORT "; then
                        NEW_PORT_PID=$(ss -tlnp | grep ":$NEW_PORT " | grep -oP 'pid=\K\d+' | head -1)
                        print_err "Порт $NEW_PORT уже занят (PID: ${NEW_PORT_PID:-неизвестен}), выберите другой"
                        continue
                    fi

                    PORT="$NEW_PORT"
                    print_ok "Новый порт выбран: $PORT"
                    break
                done
            elif [ -n "$OLD_PORT" ]; then
                print_warn "Текущий порт $OLD_PORT находится в чёрном списке."
                print_warn "Нужно выбрать новый порт — Enter оставить нельзя."
                while true; do
                    NEW_PORT=$(get_input "Введите новый порт" "")
                    NEW_PORT="${NEW_PORT//$'\r'/}"

                    if ! [[ "$NEW_PORT" =~ ^[0-9]+$ ]] || [ "$NEW_PORT" -lt 1 ] || [ "$NEW_PORT" -gt 65535 ]; then
                        print_err "Порт должен быть числом от 1 до 65535"
                        continue
                    fi

                    if port_is_blocked "$NEW_PORT"; then
                        print_err "Порт $NEW_PORT находится в чёрном списке, выберите другой"
                        continue
                    fi

                    if ss -tlnp | grep -q ":$NEW_PORT "; then
                        NEW_PORT_PID=$(ss -tlnp | grep ":$NEW_PORT " | grep -oP 'pid=\K\d+' | head -1)
                        print_err "Порт $NEW_PORT уже занят (PID: ${NEW_PORT_PID:-неизвестен}), выберите другой"
                        continue
                    fi

                    PORT="$NEW_PORT"
                    print_ok "Новый порт выбран: $PORT"
                    break
                done
            else
                print_warn "Порт не найден в старом конфиге."
                while true; do
                    NEW_PORT=$(get_input "Введите порт для панели" "8081")
                    NEW_PORT="${NEW_PORT//$'\r'/}"

                    if ! [[ "$NEW_PORT" =~ ^[0-9]+$ ]] || [ "$NEW_PORT" -lt 1 ] || [ "$NEW_PORT" -gt 65535 ]; then
                        print_err "Порт должен быть числом от 1 до 65535"
                        continue
                    fi

                    if port_is_blocked "$NEW_PORT"; then
                        print_err "Порт $NEW_PORT находится в чёрном списке, выберите другой"
                        continue
                    fi

                    if ss -tlnp | grep -q ":$NEW_PORT "; then
                        NEW_PORT_PID=$(ss -tlnp | grep ":$NEW_PORT " | grep -oP 'pid=\K\d+' | head -1)
                        print_err "Порт $NEW_PORT уже занят (PID: ${NEW_PORT_PID:-неизвестен}), выберите другой"
                        continue
                    fi

                    PORT="$NEW_PORT"
                    print_ok "Порт выбран: $PORT"
                    break
                done
            fi
            # In update mode: just copy files, don't clear anything
            ;;
        1|*)
            print_warn "Полная переустановка..."
            systemctl stop nix-panel.service 2>/dev/null || true
            # Remove everything except data directory. A full reinstall also creates a fresh one-time backup secret.
            find /opt/NIX/ -maxdepth 1 -not -name 'data' -not -name '/opt/NIX' -exec rm -rf {} + 2>/dev/null || true
            rm -f /opt/NIX/data/security.json /opt/NIX/data/security-events.json 2>/dev/null || true
            ;;
    esac
else
    print_info "Новая установка NIX Panel v$PANEL_VERSION"
    echo ""
fi

# =============================================================================
# STEP 2: Выбор папки установки
# =============================================================================
if [ "$SKIP_USER_STEPS" != "true" ]; then
print_step 2 "Выбор папки установки"

DEFAULT_DIR="/opt/nix-panel"
if [ -n "$INSTALL_DIR" ] && [ -d "$INSTALL_DIR" ]; then
    DEFAULT_DIR="$INSTALL_DIR"
fi

while true; do
    INSTALL_DIR=$(get_input "Введите путь установки" "$DEFAULT_DIR")
    INSTALL_DIR="${INSTALL_DIR//$'\r'/}"
    # Строго: только абсолютные пути (начинающиеся с /)
    if [[ "$INSTALL_DIR" != /* ]]; then
        print_err "Путь должен быть абсолютным (начинаться с /). Пример: /opt/nix-panel"
        continue
    fi

    if [ -d "$INSTALL_DIR" ] && [ "$(ls -A "$INSTALL_DIR" 2>/dev/null | head -5)" ]; then
        print_warn "Папка '$INSTALL_DIR' не пуста!"
        echo "  $(localize "Выберите действие:")"
        echo "    1) $(localize "Очистить и установить в эту папку")"
        echo "    2) $(localize "Выбрать другую папку")"
        echo "    3) $(localize "Выйти из установки")"
        printf "  %s" "$(localize "Ваш выбор [1/2/3]:")"
        read_from_tty choice
        choice="${choice//$'\r'/}"
        case "$choice" in
            1)
                # Проверяем, не запущен ли скрипт из той же папки
                if [ "$SCRIPT_DIR" = "$INSTALL_DIR" ]; then
                    print_ok "Скрипт запущен из $INSTALL_DIR — файлы уже на месте"
                else
                    rm -rf "$INSTALL_DIR"/* "$INSTALL_DIR"/.* 2>/dev/null || true
                    mkdir -p "$INSTALL_DIR"
                fi
                break
                ;;
            2) continue ;;
            3) echo "$(localize "Выход.")"; exit 0 ;;
        esac
    else
        mkdir -p "$INSTALL_DIR"
        print_ok "Папка создана: $INSTALL_DIR"
        break
    fi
done
else
    print_step 2 "Выбор папки установки"
    print_info "Папка установки: $INSTALL_DIR (режим обновления)"
fi

# =============================================================================
# STEP 3: Выбор порта
# =============================================================================
if [ "$SKIP_USER_STEPS" != "true" ]; then
print_step 3 "Выбор порта"

DEFAULT_PORT="${OLD_PORT:-8081}"

while true; do
    PORT=$(get_input "Введите порт для панели" "$DEFAULT_PORT")
    PORT="${PORT//$'\r'/}"

    # Validate port
    if ! [[ "$PORT" =~ ^[0-9]+$ ]] || [ "$PORT" -lt 1 ] || [ "$PORT" -gt 65535 ]; then
        print_err "Порт должен быть числом от 1 до 65535"
        continue
    fi

    # Blocked ports (browsers block these, reserved for system services)
    if port_is_blocked "$PORT"; then
        print_err "Этот порт зарезервирован для другой службы, пожалуйста выберите другой"
        continue
    fi

    # Check if port is in use
    if ss -tlnp | grep -q ":$PORT "; then
        PORT_PID=$(ss -tlnp | grep ":$PORT " | grep -oP 'pid=\K\d+' | head -1)
        PORT_PROC=$(ss -tlnp | grep ":$PORT " | grep -oP 'users:\(\("\K[^"]+' | head -1)
        
        print_err "Порт $PORT занят (PID: $PORT_PID), выберите другой"
        continue
    else
        print_ok "Порт $PORT свободен"
        break
    fi
done
else
    print_step 3 "Выбор порта"
    print_info "Порт: $PORT (режим обновления)"
fi

# =============================================================================
# STEP 4: Установка зависимостей
# =============================================================================
print_step 4 "Установка зависимостей"

# Update system
print_info "Обновление пакетов системы..."
apt-get update -qq 2>/dev/null || true

# Install Node.js if not present
if ! command -v node &>/dev/null; then
    print_info "Установка Node.js 20.x..."
    curl -fsSL https://deb.nodesource.com/setup_20.x | bash - 2>/dev/null || {
        print_warn "NodeSource недоступен, устанавливаю из репозитория Ubuntu..."
        apt-get install -y nodejs npm 2>/dev/null || true
    }
    apt-get install -y nodejs 2>/dev/null || true
fi

# Check Node.js version
if command -v node &>/dev/null; then
    NODE_VER=$(node -v)
    print_ok "Node.js: $NODE_VER"
else
    print_err "Node.js не установлен. Устанавливаю вручную..."
    apt-get install -y nodejs npm 2>/dev/null || true
    if ! command -v node &>/dev/null; then
        print_err "Не удалось установить Node.js. Установите вручную:"
        echo "  curl -fsSL https://deb.nodesource.com/setup_20.x | sudo bash -"
        echo "  sudo apt-get install -y nodejs"
        exit 1
    fi
fi

# Install system dependencies
print_info "Установка системных зависимостей..."
apt-get install -y \
    git curl wget \
    build-essential \
    ufw iptables \
    wakeonlan \
    certbot python3-certbot-nginx \
    nginx \
    wl-clipboard \
    ydotool xdotool 2>/dev/null || true

# Install npm packages
print_info "Установка npm-зависимостей..."
cd "$INSTALL_DIR"

# Create package.json
cat > package.json << 'EOF'
{
  "name": "nix-panel",
  "version": "2.2.0",
  "description": "NIX Server Management Panel",
  "main": "server.js",
  "scripts": {
    "start": "node server.js",
    "restart": "pkill -f 'node server.js' || true; node server.js &"
  },
  "dependencies": {
    "express": "^4.18.2",
    "express-session": "^1.18.0",
    "socket.io": "^4.7.4",
    "systeminformation": "^5.22.0",
    "@homebridge/node-pty-prebuilt-multiarch": "^0.14.1",
    "adm-zip": "^0.5.16",
    "multer": "^1.4.5-lts.1",
    "cors": "^2.8.5",
    "dbus-next": "^0.10.2",
    "mammoth": "^1.12.3",
    "html-to-docx": "^1.8.0",
    "xlsx": "^0.18.5"
  }
}
EOF


if npm_install_checked; then
    print_ok "npm-зависимости установлены"
else
    print_err "Панель не запустится без зависимостей — проверьте лог выше."
    if ! confirm "Продолжить установку без исправления (не рекомендуется)?"; then
        exit 1
    fi
fi

# =============================================================================
# STEP 5: Настройка Nginx
# =============================================================================
print_step 5 "Настройка Nginx"

NGINX_SETUP=false
if command -v nginx &>/dev/null; then
    print_info "Nginx обнаружен"

    if [ -f /etc/nginx/sites-enabled/default ]; then
        print_warn "Обнаружена стандартная конфигурация Nginx"
        echo "  $(localize "Выберите действие:")"
        echo "    1) $(localize "Заменить конфигурацию Nginx (рекомендуется)")"
        echo "    2) $(localize "Полная переустановка Nginx")"
        echo "    3) $(localize "Пропустить настройку Nginx")"
        printf "  %s" "$(localize "Ваш выбор [1/2/3]:")"
        read_from_tty nginx_choice
        nginx_choice="${nginx_choice//$'\r'/}"
        case "$nginx_choice" in
            1) NGINX_SETUP=true ;;
            2)
                apt-get purge -y nginx nginx-common 2>/dev/null || true
                apt-get install -y nginx 2>/dev/null || true
                NGINX_SETUP=true
                ;;
            3) print_info "Nginx пропущен" ;;
        esac
    else
        NGINX_SETUP=true
    fi
else
    print_warn "Nginx не установлен"
    if confirm "Установить Nginx?"; then
        apt-get install -y nginx 2>/dev/null || true
        NGINX_SETUP=true
    else
        print_info "Nginx пропущен"
    fi
fi

if [ "$NGINX_SETUP" = true ]; then
    print_info "Создание конфигурации Nginx..."
    # We'll create it after we know the domain
fi

# =============================================================================
# STEP 6: Логин
# =============================================================================
if [ "$SKIP_USER_STEPS" != "true" ]; then
    print_step 6 "Создание логина"

    print_info "Придумайте логин для входа в панель."

    while true; do
        ADMIN_LOGIN=$(get_input "Логин" "admin")
        ADMIN_LOGIN="${ADMIN_LOGIN//$'\r'/}"

        if [ ${#ADMIN_LOGIN} -lt 3 ]; then
            print_err "Логин должен быть минимум 3 символа"
            continue
        fi
        break
    done
else
    # In update mode, identify the installer-created admin instead of assuming
    # that the login is literally "admin".
    ADMIN_LOGIN=$(detect_installer_admin "$INSTALL_DIR/data/users.json" 2>/dev/null || true)
    if [ -n "$ADMIN_LOGIN" ]; then
        print_info "Админ установщика: $ADMIN_LOGIN"
    else
        ADMIN_LOGIN="не определён"
        print_warn "Не удалось однозначно определить учётную запись админа установщика."
        print_warn "Панель всё равно будет обновлена, users.json не изменяется."
    fi
    ADMIN_PASS=""
fi

# =============================================================================
# STEP 7: Пароль
# =============================================================================
if [ "$SKIP_USER_STEPS" != "true" ]; then
    print_step 7 "Создание пароля"

    print_warn "Пароль должен быть надежным!"

    while true; do
        # 2. Для пароля используем нативный read -rs. 
        # Флаг -r читает сырые данные, -s скрывает ввод с экрана.
        # Выводим вопрос напрямую в консоль (>&2)
        printf "  ? %s " "$(localize "Пароль:")" >&2
        read -rs ADMIN_PASS < /dev/tty
        echo >&2 # Делаем перенос строки, так как скрытый ввод его не делает

        ADMIN_PASS="${ADMIN_PASS//$'\r'/}"
        
        if [ ${#ADMIN_PASS} -lt 6 ]; then
            print_err "Пароль должен быть минимум 6 символов"
            continue
        fi
        
        printf "  ? %s " "$(localize "Повторите пароль:")" >&2
        read -rs ADMIN_PASS2 < /dev/tty
        echo >&2

        ADMIN_PASS2="${ADMIN_PASS2//$'\r'/}"

        if [ "$ADMIN_PASS" != "$ADMIN_PASS2" ]; then
            print_err "Пароли не совпадают!"
            continue
        fi
        break
    done
fi

# =============================================================================
# STEP 8: Домен/IP и SSL
# =============================================================================
print_step 8 "Настройка домена и SSL"

echo -e "  ${CYAN}$(localize "Укажите домен или IP-адрес для доступа к панели.")${NC}"
echo -e "  ${YELLOW}$(localize "Если у вас есть домен, сертификат будет получен автоматически через Let's Encrypt.")${NC}\n"

DOMAIN_OR_IP=$(get_input "Домен или IP" "$(curl -4 -s ifconfig.me 2>/dev/null || hostname -I | awk '{print $1}')")

USE_SSL=false
SSL_CERT=""
SSL_KEY=""

if [[ "$DOMAIN_OR_IP" =~ \. ]] && ! [[ "$DOMAIN_OR_IP" =~ ^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$ ]] && ! [[ "$DOMAIN_OR_IP" =~ ^[0-9a-fA-F:]+$ ]]; then
    echo ""
    print_info "Вы ввели домен: $DOMAIN_OR_IP"
    echo "  $(localize "Выберите действие:")"
    echo "    1) $(localize "Получить SSL-сертификат через Let's Encrypt (рекомендуется)")"
    echo "    2) $(localize "Указать свои SSL-сертификаты")"
    echo "    3) $(localize "Пропустить SSL (будет HTTP)")"
    printf "  %s" "$(localize "Ваш выбор [1/2/3]:")"
        read_from_tty ssl_choice
        ssl_choice="${ssl_choice//$'\r'/}"

    case "$ssl_choice" in
        1)
            echo ""
            print_info "Получение сертификата для $DOMAIN_OR_IP..."
            print_info "Убедитесь, что домен $DOMAIN_OR_IP указывает на этот сервер!"
            if confirm "Продолжить?"; then
                # Create nginx config first for certbot
                cat > /etc/nginx/sites-available/nix-panel << EOF
server {
    listen 80;
    server_name $DOMAIN_OR_IP;
    location / {
        proxy_pass http://127.0.0.1:$PORT;
        proxy_http_version 1.1;
        proxy_set_header Upgrade \$http_upgrade;
        proxy_set_header Connection "upgrade";
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto \$scheme;
    }
}
EOF
                ln -sf /etc/nginx/sites-available/nix-panel /etc/nginx/sites-enabled/ 2>/dev/null || true
                nginx -t 2>/dev/null && systemctl reload nginx 2>/dev/null || true

                certbot --nginx -d "$DOMAIN_OR_IP" --non-interactive --agree-tos --email "admin@$DOMAIN_OR_IP" 2>/dev/null || {
                    print_warn "Автоматическое получение не удалось. Попробуйте вручную:"
                    echo "  sudo certbot --nginx -d $DOMAIN_OR_IP"
                    USE_SSL=false
                }

                if [ -f "/etc/letsencrypt/live/$DOMAIN_OR_IP/fullchain.pem" ]; then
                    USE_SSL=true
                    SSL_CERT="/etc/letsencrypt/live/$DOMAIN_OR_IP/fullchain.pem"
                    SSL_KEY="/etc/letsencrypt/live/$DOMAIN_OR_IP/privkey.pem"
                    print_ok "SSL-сертификат получен!"
                fi
            fi
            ;;
        2)
            SSL_CERT=$(get_input "Путь к сертификату (.crt/.pem)" "")
            SSL_KEY=$(get_input "Путь к приватному ключу (.key)" "")
            if [ -f "$SSL_CERT" ] && [ -f "$SSL_KEY" ]; then
                USE_SSL=true
                print_ok "Сертификаты найдены"
            else
                print_err "Файлы сертификатов не найдены"
                USE_SSL=false
            fi
            ;;
        3)
            print_info "SSL пропущен"
            ;;
    esac
else
    print_info "Используется IP-адрес, SSL будет пропущен"
    print_info "Для использования HTTPS вручную создайте сертификаты:"
    echo "  sudo openssl req -x509 -nodes -days 365 -newkey rsa:2048 -keyout server.key -out server.crt"
fi

# =============================================================================
# Ensure the Wayland portal worker exists even when install.sh itself is run from /opt/NIX.
# Older upgrades could have copied install.sh without the separate worker file.
ensure_portal_worker() {
    local target="$INSTALL_DIR/remote-portal-worker.js"
    [ -s "$target" ] && return 0

    if [ "$SCRIPT_DIR" != "$INSTALL_DIR" ] && [ -s "$SCRIPT_DIR/remote-portal-worker.js" ]; then
        cp "$SCRIPT_DIR/remote-portal-worker.js" "$target" && chmod 755 "$target" && return 0
    fi

    print_warn "remote-portal-worker.js отсутствует — восстанавливаю встроенную копию..."
    local tmp="$target.tmp.$$"
    cat <<'NIX_PORTAL_WORKER_B64' | base64 -d > "$tmp"
IyEvdXNyL2Jpbi9lbnYgbm9kZQondXNlIHN0cmljdCc7Ci8qKgogKiDQktC+0YDQutC10YAg0LLQstC+0LTQsCDQvNGL0YjQuC/QutC70LDQstC40LDRgtGD0YDRiyDQvdCwIEtERSBXYXlsYW5kINGH0LXRgNC10LcKICogb3JnLmZyZWVkZXNrdG9wLnBvcnRhbC5SZW1vdGVEZXNrdG9wIOKAlCDQstC80LXRgdGC0L4geWRvdG9vbC91aW5wdXQuCiAqCiAqINCe0JHQr9CX0JDQnSDQt9Cw0L/Rg9GB0LrQsNGC0YzRgdGPINC+0YIg0L/QvtC70YzQt9C+0LLQsNGC0LXQu9GPINCz0YDQsNGE0LjRh9C10YHQutC+0Lkg0YHQtdGB0YHQuNC4ICjQvdC1INC+0YIgcm9vdCDRh9C10YDQtdC3CiAqINCz0L7Qu9GL0Lkgc2V0dWlkKSDigJQg0YHQtdGB0YHQuNC+0L3QvdCw0Y8g0YjQuNC90LAgRC1CdXMg0L/RgNC+0LLQtdGA0Y/QtdGCINGA0LXQsNC70YzQvdGL0LkgdWlkINC/0L7QtNC60LvRjtGH0LDRji0KICog0YnQtdCz0L7RgdGPINC/0YDQvtGG0LXRgdGB0LAg0YfQtdGA0LXQtyBTT19QRUVSQ1JFRCwg0YTQsNC50LvQvtCy0YvQtSDQv9GA0LDQstCwINGC0YPRgiDQvdC4INC/0YDQuCDRh9GR0Lwg0Lggcm9vdAogKiDQuNGFINC+0LHQvtC50YLQuCDQvdC1INC80L7QttC10YIuINCg0L7QtNC40YLQtdC70YwgKHJlbW90ZS5qcykg0L7QsdGP0LfQsNC9INGB0YLQsNGA0YLQvtCy0LDRgtGMINGN0YLQvtGCINGE0LDQudC7CiAqINGH0LXRgNC10LcgYHJ1bnVzZXIgLXUgPHVzZXI+IC0tYCwg0L3QtSDQv9GA0L7RgdGC0L4g0YHQviDRgdC80LXQvdC+0LkgdWlkL2dpZC4KICoKICog0J/RgNC+0YLQvtC60L7QuyDRgSDRgNC+0LTQuNGC0LXQu9C10Lwg4oCUINC/0L7RgdGC0YDQvtGH0L3Ri9C5IEpTT046CiAqICAg0YDQvtC00LjRgtC10LvRjCAtPiDQstC+0YDQutC10YA6CiAqICAgICB7ImlkIjoxLCJjbWQiOiJtb3ZlIiwiZHgiOjEwLCJkeSI6LTR9CiAqICAgICB7ImlkIjoyLCJjbWQiOiJidXR0b24iLCJjb2RlIjoyNzIsInByZXNzZWQiOnRydWV9CiAqICAgICB7ImlkIjozLCJjbWQiOiJrZXkiLCJjb2RlIjozMCwicHJlc3NlZCI6dHJ1ZX0KICogICDQstC+0YDQutC10YAgLT4g0YDQvtC00LjRgtC10LvRjDoKICogICAgIHsiZXZlbnQiOiJhd2FpdGluZy1hdXRoIn0gICAgIOKAlCDQv9C+0YDRgtCw0Lsg0LbQtNGR0YIg0LrQu9C40LrQsCAi0KDQsNC30YDQtdGI0LjRgtGMIiDQsiBHVUkKICogICAgIHsiZXZlbnQiOiJyZWFkeSJ9ICAgICAgICAgICAgIOKAlCDRgdC10YHRgdC40Y8g0L/QvtC00L3Rj9GC0LAsINC80L7QttC90L4g0YHQu9Cw0YLRjCDQutC+0LzQsNC90LTRiwogKiAgICAgeyJldmVudCI6ImZhdGFsIiwiZXJyb3IiOiLigKYifSDigJQg0LLQvtGA0LrQtdGAINC90LUg0YHQvNC+0LMg0YHRgtCw0YDRgtC+0LLQsNGC0Ywg0LLQvtC+0LHRidC1CiAqICAgICB7ImlkIjoxLCJvayI6dHJ1ZX0KICogICAgIHsiaWQiOjIsIm9rIjpmYWxzZSwiZXJyb3IiOiLigKYifQogKi8KCmxldCBkYnVzOwp0cnkgewogIGRidXMgPSByZXF1aXJlKCdkYnVzLW5leHQnKTsKfSBjYXRjaCAoZSkgewogIHNlbmQoeyBldmVudDogJ2ZhdGFsJywgZXJyb3I6ICfQv9Cw0LrQtdGCIGRidXMtbmV4dCDQvdC1INGD0YHRgtCw0L3QvtCy0LvQtdC9IChucG0gaW5zdGFsbCBkYnVzLW5leHQg0LIg0L/QsNC/0LrQtSDQv9Cw0L3QtdC70LgpJyB9KTsKICBwcm9jZXNzLmV4aXQoMSk7Cn0KY29uc3QgVmFyaWFudCA9IGRidXMuVmFyaWFudDsKCmNvbnN0IFBPUlRBTF9ERVNUID0gJ29yZy5mcmVlZGVza3RvcC5wb3J0YWwuRGVza3RvcCc7CmNvbnN0IFBPUlRBTF9QQVRIID0gJy9vcmcvZnJlZWRlc2t0b3AvcG9ydGFsL2Rlc2t0b3AnOwpjb25zdCBUT0tFTl9GSUxFID0gcHJvY2Vzcy5lbnYuUE9SVEFMX1RPS0VOX0ZJTEUKICB8fCByZXF1aXJlKCdwYXRoJykuam9pbihwcm9jZXNzLmVudi5IT01FIHx8ICcvdG1wJywgJy5uaXgtcGFuZWwtcG9ydGFsLXRva2VuJyk7CgpsZXQgc2VxID0gMDsKY29uc3QgdW5pcSA9IHByZWZpeCA9PiBgbml4cGFuZWxfJHtwcmVmaXh9XyR7RGF0ZS5ub3coKX1fJHtzZXErK31gOwpmdW5jdGlvbiBzZW5kKG9iaikgeyBwcm9jZXNzLnN0ZG91dC53cml0ZShKU09OLnN0cmluZ2lmeShvYmopICsgJ1xuJyk7IH0KCi8qKiDQltC00ZHRgiDRgdC40LPQvdCw0LsgUmVzcG9uc2Ug0L3QsCDQvtCx0YrQtdC60YLQtSDQt9Cw0L/RgNC+0YHQsCDQuCDQstC+0LfQstGA0LDRidCw0LXRgiDQtdCz0L4gcmVzdWx0cyAo0YPQttC1INCx0LXQtyBWYXJpYW50LdC+0LHRkdGA0YLQvtC6KS4gKi8KZnVuY3Rpb24gd2FpdFJlc3BvbnNlKGJ1cywgcmVxdWVzdFBhdGgpIHsKICByZXR1cm4gbmV3IFByb21pc2UoYXN5bmMgKHJlc29sdmUsIHJlamVjdCkgPT4gewogICAgbGV0IGlmYWNlOwogICAgdHJ5IHsKICAgICAgY29uc3Qgb2JqID0gYXdhaXQgYnVzLmdldFByb3h5T2JqZWN0KFBPUlRBTF9ERVNULCByZXF1ZXN0UGF0aCk7CiAgICAgIGlmYWNlID0gb2JqLmdldEludGVyZmFjZSgnb3JnLmZyZWVkZXNrdG9wLnBvcnRhbC5SZXF1ZXN0Jyk7CiAgICB9IGNhdGNoIChlKSB7IHJldHVybiByZWplY3QoZSk7IH0KICAgIGNvbnN0IHRpbWVyID0gc2V0VGltZW91dCgoKSA9PiByZWplY3QobmV3IEVycm9yKCfQv9C+0YDRgtCw0Lsg0L3QtSDQvtGC0LLQtdGC0LjQuyDQt9CwIDUg0LzQuNC90YPRgicpKSwgNSAqIDYwICogMTAwMCk7CiAgICBpZmFjZS5vbmNlKCdSZXNwb25zZScsIChjb2RlLCByZXN1bHRzKSA9PiB7CiAgICAgIGNsZWFyVGltZW91dCh0aW1lcik7CiAgICAgIGlmIChjb2RlICE9PSAwKSByZXR1cm4gcmVqZWN0KG5ldyBFcnJvcihjb2RlID09PSAxID8gJ9C/0L7Qu9GM0LfQvtCy0LDRgtC10LvRjCDQvtGC0LrQu9C+0L3QuNC7INC30LDQv9GA0L7RgSDQsiDQtNC40LDQu9C+0LPQtScgOiBg0L/QvtGA0YLQsNC7INCy0LXRgNC90YPQuyDQutC+0LQgJHtjb2RlfWApKTsKICAgICAgY29uc3QgcGxhaW4gPSB7fTsKICAgICAgZm9yIChjb25zdCBrIGluIHJlc3VsdHMpIHBsYWluW2tdID0gcmVzdWx0c1trXSAmJiAndmFsdWUnIGluIHJlc3VsdHNba10gPyByZXN1bHRzW2tdLnZhbHVlIDogcmVzdWx0c1trXTsKICAgICAgcmVzb2x2ZShwbGFpbik7CiAgICB9KTsKICB9KTsKfQoKLyoqIEJlc3QtZWZmb3J0INC/0YDQtdC00LDQstGC0L7RgNC40LfQsNGG0LjRjyDRh9C10YDQtdC3INGC0LDQsdC70LjRhtGDIGtkZS1hdXRob3JpemVkIChQbGFzbWEgNi4zKykuINCd0LUg0LrRgNC40YLQuNGH0L3Qviwg0LXRgdC70Lgg0L3QtSDQstGL0LnQtNC10YIuICovCmFzeW5jIGZ1bmN0aW9uIHRyeVByZUF1dGhvcml6ZShidXMpIHsKICB0cnkgewogICAgLy8gUGVybWlzc2lvblN0b3JlIOKAlCDQvtGC0LTQtdC70YzQvdC+0LUgd2VsbC1rbm93biDQuNC80Y8g0YjQuNC90YssINCd0JUg0YLQviDQttC1INGB0LDQvNC+0LUsINGH0YLQvgogICAgLy8g0L7RgdC90L7QstC90L7QuSBvcmcuZnJlZWRlc2t0b3AucG9ydGFsLkRlc2t0b3AuCiAgICBjb25zdCBvYmogPSBhd2FpdCBidXMuZ2V0UHJveHlPYmplY3QoJ29yZy5mcmVlZGVza3RvcC5pbXBsLnBvcnRhbC5QZXJtaXNzaW9uU3RvcmUnLCAnL29yZy9mcmVlZGVza3RvcC9pbXBsL3BvcnRhbC9QZXJtaXNzaW9uU3RvcmUnKTsKICAgIGNvbnN0IGlmYWNlID0gb2JqLmdldEludGVyZmFjZSgnb3JnLmZyZWVkZXNrdG9wLmltcGwucG9ydGFsLlBlcm1pc3Npb25TdG9yZScpOwogICAgLy8gdGFibGUsIGNyZWF0ZSwgaWQsIGFwcF9pZCAo0L/Rg9GB0YLQviA9IMKr0L3QtdC40LfQstC10YHRgtC90L7QtSDRhdC+0YHRgi3Qv9GA0LjQu9C+0LbQtdC90LjQtcK7KSwgcGVybWlzc2lvbnMKICAgIGF3YWl0IGlmYWNlLlNldFBlcm1pc3Npb24oJ2tkZS1hdXRob3JpemVkJywgdHJ1ZSwgJ3JlbW90ZS1kZXNrdG9wJywgJycsIFsneWVzJ10pOwogICAgcmV0dXJuIHRydWU7CiAgfSBjYXRjaCAoZSkgewogICAgcmV0dXJuIGZhbHNlOyAvLyDRgdGC0LDRgNCw0Y8gUGxhc21hINCx0LXQtyDRjdGC0L7QuSDRgtCw0LHQu9C40YbRiywg0LjQu9C4INC/0YDQsNCyINC90LXRgiDigJQg0L3QuNGH0LXQs9C+INGB0YLRgNCw0YjQvdC+0LPQvgogIH0KfQoKZnVuY3Rpb24gbG9hZFRva2VuKCkgewogIHRyeSB7IHJldHVybiByZXF1aXJlKCdmcycpLnJlYWRGaWxlU3luYyhUT0tFTl9GSUxFLCAndXRmOCcpLnRyaW0oKSB8fCBudWxsOyB9IGNhdGNoIChlKSB7IHJldHVybiBudWxsOyB9Cn0KZnVuY3Rpb24gc2F2ZVRva2VuKHRvaykgewogIHRyeSB7IHJlcXVpcmUoJ2ZzJykud3JpdGVGaWxlU3luYyhUT0tFTl9GSUxFLCB0b2ssIHsgbW9kZTogMG82MDAgfSk7IH0gY2F0Y2ggKGUpIHsgLyog0L3QtSDQutGA0LjRgtC40YfQvdC+ICovIH0KfQoKYXN5bmMgZnVuY3Rpb24gbWFpbigpIHsKICBjb25zdCBidXNBZGRyZXNzID0gcHJvY2Vzcy5lbnYuREJVU19TRVNTSU9OX0JVU19BRERSRVNTOwogIGlmICghYnVzQWRkcmVzcykgeyBzZW5kKHsgZXZlbnQ6ICdmYXRhbCcsIGVycm9yOiAn0L3QtdGCIERCVVNfU0VTU0lPTl9CVVNfQUREUkVTUyDQsiDQvtC60YDRg9C20LXQvdC40LgnIH0pOyBwcm9jZXNzLmV4aXQoMSk7IH0KICBjb25zdCBidXMgPSBkYnVzLnNlc3Npb25CdXMoeyBidXNBZGRyZXNzIH0pOwogIGJ1cy5vbignZXJyb3InLCAoKSA9PiB7fSk7IC8vINC90LUg0YDQvtC90Y/QtdC8INC/0YDQvtGG0LXRgdGBINC90LAg0YTQvtC90L7QstGL0YUg0L7RiNC40LHQutCw0YUg0YHQvtC10LTQuNC90LXQvdC40Y8KCiAgY29uc3QgcG9ydGFsT2JqID0gYXdhaXQgYnVzLmdldFByb3h5T2JqZWN0KFBPUlRBTF9ERVNULCBQT1JUQUxfUEFUSCk7CiAgY29uc3QgcmQgPSBwb3J0YWxPYmouZ2V0SW50ZXJmYWNlKCdvcmcuZnJlZWRlc2t0b3AucG9ydGFsLlJlbW90ZURlc2t0b3AnKTsKCiAgYXdhaXQgdHJ5UHJlQXV0aG9yaXplKGJ1cyk7CgogIC8vIDEpIENyZWF0ZVNlc3Npb24KICBjb25zdCBjcmVhdGVSZXFQYXRoID0gYXdhaXQgcmQuQ3JlYXRlU2Vzc2lvbih7IHNlc3Npb25faGFuZGxlX3Rva2VuOiBuZXcgVmFyaWFudCgncycsIHVuaXEoJ2hhbmRsZScpKSB9KTsKICBjb25zdCBjcmVhdGVSZXN1bHQgPSBhd2FpdCB3YWl0UmVzcG9uc2UoYnVzLCBjcmVhdGVSZXFQYXRoKTsKICBjb25zdCBzZXNzaW9uSGFuZGxlID0gY3JlYXRlUmVzdWx0LnNlc3Npb25faGFuZGxlOwogIGlmICghc2Vzc2lvbkhhbmRsZSkgdGhyb3cgbmV3IEVycm9yKCfQv9C+0YDRgtCw0Lsg0L3QtSDQstC10YDQvdGD0Lsgc2Vzc2lvbl9oYW5kbGUnKTsKCiAgLy8gMikgU2VsZWN0RGV2aWNlcyDigJQg0LrQu9Cw0LLQuNCw0YLRg9GA0LAoMSkgKyDRg9C60LDQt9Cw0YLQtdC70YwoMiksINGBINC/0L7Qv9GL0YLQutC+0Lkg0L/QtdGA0LXQuNGB0L/QvtC70YzQt9C+0LLQsNGC0Ywg0YHQvtGF0YDQsNC90ZHQvdC90YvQuSByZXN0b3JlX3Rva2VuCiAgY29uc3Qgc2F2ZWRUb2tlbiA9IGxvYWRUb2tlbigpOwogIGNvbnN0IHNlbGVjdE9wdGlvbnMgPSB7CiAgICB0eXBlczogbmV3IFZhcmlhbnQoJ3UnLCAzKSwKICAgIHBlcnNpc3RfbW9kZTogbmV3IFZhcmlhbnQoJ3UnLCAyKSwgLy8gMiA9INC/0L7QvNC90LjRgtGMLCDQv9C+0LrQsCDRj9Cy0L3QviDQvdC1INC+0YLQt9C+0LLRg9GCCiAgfTsKICBpZiAoc2F2ZWRUb2tlbikgc2VsZWN0T3B0aW9ucy5yZXN0b3JlX3Rva2VuID0gbmV3IFZhcmlhbnQoJ3MnLCBzYXZlZFRva2VuKTsKICBjb25zdCBzZWxlY3RSZXFQYXRoID0gYXdhaXQgcmQuU2VsZWN0RGV2aWNlcyhzZXNzaW9uSGFuZGxlLCBzZWxlY3RPcHRpb25zKTsKICBhd2FpdCB3YWl0UmVzcG9uc2UoYnVzLCBzZWxlY3RSZXFQYXRoKTsKCiAgLy8gMykgU3RhcnQg4oCUINCy0L7RgiDRgtGD0YIg0LzQvtC20LXRgiDQv9C+0LrQsNC30LDRgtGM0YHRjyDQtNC40LDQu9C+0LMsINC10YHQu9C4INC90Lgg0L/RgNC10LTQsNCy0YLQvtGA0LjQt9Cw0YbQuNGPLAogIC8vINC90LggcmVzdG9yZV90b2tlbiDQvdC1INGB0YDQsNCx0L7RgtCw0LvQuC4KICBzZW5kKHsgZXZlbnQ6ICdhd2FpdGluZy1hdXRoJyB9KTsKICBjb25zdCBzdGFydFJlcVBhdGggPSBhd2FpdCByZC5TdGFydChzZXNzaW9uSGFuZGxlLCAnJywge30pOwogIGNvbnN0IHN0YXJ0UmVzdWx0ID0gYXdhaXQgd2FpdFJlc3BvbnNlKGJ1cywgc3RhcnRSZXFQYXRoKTsKICBpZiAoc3RhcnRSZXN1bHQucmVzdG9yZV90b2tlbikgc2F2ZVRva2VuKHN0YXJ0UmVzdWx0LnJlc3RvcmVfdG9rZW4pOwoKICBzZW5kKHsgZXZlbnQ6ICdyZWFkeScgfSk7CgogIC8vIDQpINCe0LHRi9GH0L3Ri9C1INC60L7QvNCw0L3QtNGLINGBINGN0YLQvtCz0L4g0LzQvtC80LXQvdGC0LAKICBjb25zdCByZWFkbGluZSA9IHJlcXVpcmUoJ3JlYWRsaW5lJyk7CiAgY29uc3QgcmwgPSByZWFkbGluZS5jcmVhdGVJbnRlcmZhY2UoeyBpbnB1dDogcHJvY2Vzcy5zdGRpbiB9KTsKICBybC5vbignbGluZScsIGFzeW5jIGxpbmUgPT4gewogICAgbGV0IG1zZzsKICAgIHRyeSB7IG1zZyA9IEpTT04ucGFyc2UobGluZSk7IH0gY2F0Y2ggKGUpIHsgcmV0dXJuOyB9CiAgICB0cnkgewogICAgICBzd2l0Y2ggKG1zZy5jbWQpIHsKICAgICAgICBjYXNlICdtb3ZlJzoKICAgICAgICAgIGF3YWl0IHJkLk5vdGlmeVBvaW50ZXJNb3Rpb24oc2Vzc2lvbkhhbmRsZSwge30sIE51bWJlcihtc2cuZHgpIHx8IDAsIE51bWJlcihtc2cuZHkpIHx8IDApOwogICAgICAgICAgYnJlYWs7CiAgICAgICAgY2FzZSAnYnV0dG9uJzoKICAgICAgICAgIGF3YWl0IHJkLk5vdGlmeVBvaW50ZXJCdXR0b24oc2Vzc2lvbkhhbmRsZSwge30sIE51bWJlcihtc2cuY29kZSksIG1zZy5wcmVzc2VkID8gMSA6IDApOwogICAgICAgICAgYnJlYWs7CiAgICAgICAgY2FzZSAna2V5JzoKICAgICAgICAgIGF3YWl0IHJkLk5vdGlmeUtleWJvYXJkS2V5Y29kZShzZXNzaW9uSGFuZGxlLCB7fSwgTnVtYmVyKG1zZy5jb2RlKSwgbXNnLnByZXNzZWQgPyAxIDogMCk7CiAgICAgICAgICBicmVhazsKICAgICAgICBkZWZhdWx0OgogICAgICAgICAgdGhyb3cgbmV3IEVycm9yKCfQvdC10LjQt9Cy0LXRgdGC0L3QsNGPINC60L7QvNCw0L3QtNCwINCy0L7RgNC60LXRgNCwOiAnICsgbXNnLmNtZCk7CiAgICAgIH0KICAgICAgc2VuZCh7IGlkOiBtc2cuaWQsIG9rOiB0cnVlIH0pOwogICAgfSBjYXRjaCAoZSkgewogICAgICBzZW5kKHsgaWQ6IG1zZy5pZCwgb2s6IGZhbHNlLCBlcnJvcjogZS5tZXNzYWdlIH0pOwogICAgfQogIH0pOwp9CgptYWluKCkuY2F0Y2goZSA9PiB7IHNlbmQoeyBldmVudDogJ2ZhdGFsJywgZXJyb3I6IGUubWVzc2FnZSB9KTsgcHJvY2Vzcy5leGl0KDEpOyB9KTsK
NIX_PORTAL_WORKER_B64
    if [ -s "$tmp" ]; then
        mv "$tmp" "$target"
        chmod 755 "$target"
        print_ok "remote-portal-worker.js восстановлен"
        return 0
    fi
    rm -f "$tmp"
    print_err "Не удалось восстановить remote-portal-worker.js"
    return 1
}

ensure_portal_worker || exit 1

# COPY FILES
# =============================================================================
echo ""
print_info "Копирование файлов панели..."

print_info "Источник: $SCRIPT_DIR"
print_info "Назначение: $INSTALL_DIR"

COPY_OK=false

# Strategy 0: Files already in place (script running from install dir)
if [ "$SCRIPT_DIR" = "$INSTALL_DIR" ] && [ -f "$INSTALL_DIR/server.js" ]; then
    print_ok "Файлы уже на месте в $INSTALL_DIR"
    COPY_OK=true
fi

# Strategy 1: Copy from script directory (if different from install dir)
if [ "$COPY_OK" != "true" ] && [ "$SCRIPT_DIR" != "$INSTALL_DIR" ]; then
    print_info "Копирование из $SCRIPT_DIR ..."
    # Copy everything except node_modules (to avoid huge transfers)
    shopt -s nullglob
    for item in "$SCRIPT_DIR"/*; do
        basename_item=$(basename "$item")
        # Skip . .. and node_modules
        [ "$basename_item" = "." ] && continue
        [ "$basename_item" = ".." ] && continue
        [ "$basename_item" = "node_modules" ] && continue
        [ "$basename_item" = "install.sh" ] && continue
        # package.json/-lock не трогаем: шаг 4 уже написал верный, а
        # старый файл из источника может затереть его и молча вернуть
        # неполный набор зависимостей.
        [ "$basename_item" = "package.json" ] && continue
        [ "$basename_item" = "package-lock.json" ] && continue
        [ "$SKIP_USER_STEPS" = "true" ] && [ "$basename_item" = "data" ] && continue
        cp -r "$item" "$INSTALL_DIR/" 2>&1 || true
    done
    if [ -f "$INSTALL_DIR/server.js" ]; then
        ensure_portal_worker || exit 1
        COPY_OK=true
        print_ok "Файлы скопированы из $SCRIPT_DIR"
    fi
fi

# Strategy 2: Copy from the current working directory (if script was piped)
if [ "$COPY_OK" != "true" ]; then
    CWD="$(pwd)"
    if [ "$CWD" != "$INSTALL_DIR" ] && [ -f "$CWD/server.js" ]; then
        print_info "Копирование из текущей папки ($CWD) ..."
        shopt -s nullglob
        for item in "$CWD"/*; do
            basename_item=$(basename "$item")
            [ "$basename_item" = "." ] && continue
            [ "$basename_item" = ".." ] && continue
            [ "$basename_item" = "node_modules" ] && continue
            [ "$basename_item" = "install.sh" ] && continue
            [ "$basename_item" = "package.json" ] && continue
            [ "$basename_item" = "package-lock.json" ] && continue
            [ "$SKIP_USER_STEPS" = "true" ] && [ "$basename_item" = "data" ] && continue
            cp -r "$item" "$INSTALL_DIR/" 2>&1 || true
        done
        if [ -f "$INSTALL_DIR/server.js" ]; then
            COPY_OK=true
            print_ok "Файлы скопированы из $CWD"
        fi
    fi
fi

# Strategy 3: Copy from /opt/NIX or /opt/nix-panel (previous installation)
if [ "$COPY_OK" != "true" ]; then
    for src_dir in /opt/NIX /opt/nix-panel /root/nix-panel; do
        if [ "$src_dir" != "$INSTALL_DIR" ] && [ -f "$src_dir/server.js" ]; then
            print_info "Копирование из предыдущей установки ($src_dir) ..."
            shopt -s nullglob
            for item in "$src_dir"/*; do
                basename_item=$(basename "$item")
                [ "$basename_item" = "node_modules" ] && continue
                [ "$basename_item" = "install.sh" ] && continue
                [ "$basename_item" = "package.json" ] && continue
                [ "$basename_item" = "package-lock.json" ] && continue
                cp -r "$item" "$INSTALL_DIR/" 2>&1 || true
            done
            if [ -f "$INSTALL_DIR/server.js" ]; then
                COPY_OK=true
                print_ok "Файлы восстановлены из $src_dir"
                break
            fi
        fi
    done
fi

# Final check
if [ "$COPY_OK" != "true" ]; then
    print_err "Не удалось найти файлы панели!"
    print_err "Убедитесь, что install.sh находится в папке с server.js"
    print_err "Или вручную скопируйте файлы в $INSTALL_DIR"
    echo ""
    print_info "Текущая папка: $(pwd)"
    print_info "Папка скрипта: $SCRIPT_DIR"
    echo ""
    ls -la "$SCRIPT_DIR"/server.js 2>/dev/null && print_ok "server.js есть в папке скрипта" || print_err "server.js НЕ найден в папке скрипта"
    echo ""
    if confirm "Продолжить установку без копирования файлов?"; then
        print_warn "Продолжаем... Панель может не работать."
    else
        exit 1
    fi
fi

# Final deployment invariant: the portal worker is a required runtime file.
# Verify it AFTER all copy strategies, because an old installation may have
# overwritten or omitted it even when server.js was present.
if [ "$COPY_OK" = "true" ]; then
    ensure_portal_worker || exit 1
    if [ ! -s "$INSTALL_DIR/remote-portal-worker.js" ]; then
        print_err "Критическая ошибка: remote-portal-worker.js отсутствует после копирования."
        exit 1
    fi
    chmod 755 "$INSTALL_DIR/remote-portal-worker.js" 2>/dev/null || true
    print_ok "remote-portal-worker.js проверен: $INSTALL_DIR/remote-portal-worker.js"

    # The protected /opt/NIX tree is intentionally not traversable by ordinary
    # OS users. The Wayland worker, however, must execute as the graphical
    # session user (e.g. elaut), so keep a dedicated root-owned runtime copy
    # outside the protected panel tree. This avoids MODULE_NOT_FOUND caused by
    # EACCES on /opt/NIX when Node runs under runuser.
    REMOTE_RUNTIME_DIR="/usr/local/lib/nix-panel"
    REMOTE_RUNTIME_WORKER="$REMOTE_RUNTIME_DIR/remote-portal-worker.js"
    install -d -o root -g root -m 755 "$REMOTE_RUNTIME_DIR"
    cp -f "$INSTALL_DIR/remote-portal-worker.js" "$REMOTE_RUNTIME_WORKER"
    chown root:root "$REMOTE_RUNTIME_WORKER" 2>/dev/null || true
    chmod 755 "$REMOTE_RUNTIME_WORKER" 2>/dev/null || true
    if [ ! -s "$REMOTE_RUNTIME_WORKER" ]; then
        print_err "Критическая ошибка: runtime worker не установлен: $REMOTE_RUNTIME_WORKER"
        exit 1
    fi
    print_ok "Runtime worker: $REMOTE_RUNTIME_WORKER"

    # dbus-next is resolved relative to the runtime worker. The protected
    # /opt/NIX/node_modules tree is intentionally not readable by the GUI user,
    # so provide a small dedicated runtime dependency tree outside /opt/NIX.
    # This avoids a misleading "dbus-next is not installed" error when the
    # worker is launched through runuser as the graphical session user.
    print_info "Подготовка runtime-зависимостей Wayland..."
    if npm install --prefix "$REMOTE_RUNTIME_DIR" --no-save --no-package-lock --omit=dev --no-audit --no-fund dbus-next@^0.10.2 >/tmp/nix-runtime-npm.log 2>&1; then
        chown -R root:root "$REMOTE_RUNTIME_DIR/node_modules" 2>/dev/null || true
        find "$REMOTE_RUNTIME_DIR/node_modules" -type d -exec chmod 755 {} + 2>/dev/null || true
        find "$REMOTE_RUNTIME_DIR/node_modules" -type f -exec chmod 644 {} + 2>/dev/null || true
        print_ok "Runtime dbus-next установлен"
    else
        print_err "Не удалось установить runtime dbus-next"
        tail -30 /tmp/nix-runtime-npm.log 2>/dev/null || true
        exit 1
    fi
fi

# Re-run npm install to ensure dependencies are correct after file copy
if [ "$COPY_OK" = "true" ]; then
    print_info "Проверка зависимостей..."
    cd "$INSTALL_DIR"
    if [ -f "$INSTALL_DIR/package.json" ]; then
        if npm_install_checked; then
            print_ok "Зависимости обновлены"
        else
            print_err "Не удалось доустановить зависимости после копирования файлов — панель может не запуститься."
        fi
    fi
fi

# =============================================================================
# CREATE DATA DIRECTORY
# =============================================================================
mkdir -p "$INSTALL_DIR/data"

if [ "$SKIP_USER_STEPS" != "true" ]; then
    print_info "Создание users.json с логином '$ADMIN_LOGIN'..."
    printf '{"%s":{"password":"%s","role":"admin","accountType":"installer_admin","permissions":{"filesRead":true,"filesDelete":true,"filesArchive":true,"filesClipboard":true,"filesUpload":true,"filesDownload":true,"tasks":true,"console":true,"power":true,"chatRead":true,"chatWrite":true,"chatUpload":true,"chatAdmin":true,"admin":true,"aiUse":true,"aiAdmin":true,"buttonsGlobal":true}}}\n' "$ADMIN_LOGIN" "$ADMIN_PASS" > "$INSTALL_DIR/data/users.json"
    if grep -q "$ADMIN_LOGIN" "$INSTALL_DIR/data/users.json"; then
        print_ok "Пользователь $ADMIN_LOGIN создан"
    else
        print_err "КРИТИЧЕСКАЯ ОШИБКА: не удалось создать users.json!"
        exit 1
    fi

    # One-time 35-character emergency backup password. Only its SHA-256 hash is stored.
    BACKUP_PASSWORD=$(LC_ALL=C tr -dc 'A-Za-z0-9' </dev/urandom | head -c 35)
    BACKUP_SALT=$(openssl rand -hex 16)
    BACKUP_HASH=$(printf '%s%s' "$BACKUP_SALT" "$BACKUP_PASSWORD" | sha256sum | awk '{print $1}')
    printf '{"version":1,"locked":false,"reason":null,"salt":"%s","backupPasswordHash":"%s","createdAt":"%s"}\n' "$BACKUP_SALT" "$BACKUP_HASH" "$(date -Iseconds)" > "$INSTALL_DIR/data/security.json"
    chmod 600 "$INSTALL_DIR/data/security.json"
    print_ok "Резервный пароль безопасности сгенерирован"
else
    print_info "Пользователи сохранены (режим обновления)"
fi

# =============================================================================
# STEP 9: Рабочий стол (удалённое управление)
# =============================================================================
if [ "$SKIP_USER_STEPS" != "true" ]; then
echo ""
print_step 9 "Удалённое управление"

echo -e "  ${CYAN}$(localize "В вашей системе установлено окружение рабочего стола / видеоадаптер?")${NC}"
echo -e "  ${YELLOW}$(localize "Если да — панель сможет показывать и управлять экраном сервера.")${NC}"
echo -e "  ${YELLOW}$(localize "Потребуются пакеты:")${NC}"
echo -e "    ${CYAN}•${NC} $(localize "Wayland (KDE/Plasma): spectacle (скриншоты); ввод — через портал")"
echo -e "      $(localize "org.freedesktop.portal.RemoteDesktop, без ydotool/uinput")"
echo -e "    ${CYAN}•${NC} $(localize "X11: xdotool, imagemagick, x11-utils")"
echo -e "    ${CYAN}•${NC} $(localize "Без GUI: Xvfb (виртуальный экран)")"
echo ""
echo -e "  ${PURPLE}$(localize "Как проверить:")${NC}"
echo -e "    ${CYAN}•${NC} $(localize "KDE/Plasma (Wayland) — ответьте Y, установит spectacle + dbus-next")"
echo -e "    ${CYAN}•${NC} $(localize "X11 / монитор — ответьте Y, установит xdotool + imagemagick")"
echo -e "    ${CYAN}•${NC} $(localize "VPS без GUI — установит Xvfb (виртуальный экран)")"
echo -e "    ${CYAN}•${NC} $(localize "Не уверены — ответьте N (можно включить позже)")"
echo ""
echo -e "  ${YELLOW}$(localize "На Wayland при первом реальном использовании ввода KDE может один раз")"
echo -e "  $(localize "показать системный диалог «Разрешить приложению управлять вводом?» — панель")"
echo -e "  $(localize "сама попробует предавторизоваться без диалога (нужна Plasma 6.3+), но если")"
echo -e "  $(localize "это не сработает, диалог придётся один раз подтвердить вручную.")${NC}"
echo ""
if confirm "Установить/настроить удалённое управление?"; then
    print_info "Определение графической подсистемы..."
    # Check Wayland
    if [ -n "$WAYLAND_DISPLAY" ] || [ -n "$XDG_SESSION_TYPE" ] && [ "$XDG_SESSION_TYPE" = "wayland" ]; then
        print_info "Обнаружен Wayland, устанавливаю быстрый захват grim + spectacle..."
        apt-get install -y spectacle grim 2>/dev/null || true
        print_ok "dbus-next (портал ввода) ставится вместе с остальными npm-зависимостями на шаге 4"
    elif [ -n "$DISPLAY" ]; then
        print_info "Обнаружен X11, устанавливаю xdotool + imagemagick..."
        apt-get install -y xdotool imagemagick x11-utils 2>/dev/null || true
    else
        print_info "Графическая подсистема не обнаружена, устанавливаю Xvfb..."
        apt-get install -y xvfb xdotool 2>/dev/null || true
    fi
    if command -v Xvfb &>/dev/null || command -v xvfb-run &>/dev/null; then
        print_ok "Xvfb уже установлен"
    else
        if confirm "Установить Xvfb (виртуальный экран)?"; then
            apt-get install -y xvfb 2>/dev/null || true
        fi
    fi
    print_ok "Удалённое управление включено"
fi
fi

# Create SSL certificate if needed
if [ "$USE_SSL" = true ]; then
    if [ -f "$SSL_CERT" ] && [ -f "$SSL_KEY" ]; then
        cp "$SSL_CERT" "$INSTALL_DIR/server.crt" 2>/dev/null || true
        cp "$SSL_KEY" "$INSTALL_DIR/server.key" 2>/dev/null || true
        print_ok "SSL-сертификаты установлены"
    fi
elif [ ! -f "$INSTALL_DIR/server.crt" ] && [ ! -f "$INSTALL_DIR/server.key" ]; then
    print_info "Создание самоподписанного SSL-сертификата..."
    openssl req -x509 -nodes -days 365 -newkey rsa:2048 \
        -keyout "$INSTALL_DIR/server.key" \
        -out "$INSTALL_DIR/server.crt" \
        -subj "/CN=$DOMAIN_OR_IP" 2>/dev/null || true
    print_ok "Самоподписанный сертификат создан"
fi

# Create config
SESSION_SECRET=""
if [ "$SKIP_USER_STEPS" = "true" ] && [ -f "$INSTALL_DIR/nix-config.json" ]; then
    SESSION_SECRET=$(grep -oP '"sessionSecret"\s*:\s*"\K[^"]+' "$INSTALL_DIR/nix-config.json" 2>/dev/null || true)
fi
if [ -z "$SESSION_SECRET" ]; then SESSION_SECRET=$(openssl rand -hex 48); fi

# Язык панели по умолчанию — по локали системы (при обновлении сохраняем то,
# что уже выбрано в текущем конфиге, не сбрасываем на повторных запусках).
if [ "$SKIP_USER_STEPS" = "true" ] && [ -f "$INSTALL_DIR/nix-config.json" ]; then
    EXISTING_PANEL_LANGUAGE=$(grep -oP '"language"\s*:\s*"\K[^"]+' "$INSTALL_DIR/nix-config.json" 2>/dev/null || true)
    [ -n "$EXISTING_PANEL_LANGUAGE" ] && PANEL_LANGUAGE="$EXISTING_PANEL_LANGUAGE"
fi
cat > "$INSTALL_DIR/nix-config.json" << EOF
{
  "port": $PORT,
  "startPath": "/",
  "dataDir": "$INSTALL_DIR/data",
  "sessionSecret": "$SESSION_SECRET",
  "language": "$PANEL_LANGUAGE"
}
EOF
print_ok "Конфигурация создана (язык панели по умолчанию: $PANEL_LANGUAGE)"

# =============================================================================
# FIREWALL SETUP
# =============================================================================
echo ""
print_info "Настройка файрвола..."

# UFW
if command -v ufw &>/dev/null; then
    print_info "Настройка UFW..."
    # Не сбрасываем существующие правила UFW — сохраняем текущую конфигурацию.
    ufw default deny incoming >/dev/null 2>&1 || true
    ufw default allow outgoing >/dev/null 2>&1 || true
    ufw allow ssh >/dev/null 2>&1 || true
    ufw allow "$PORT/tcp" >/dev/null 2>&1 || true
    ufw allow 80/tcp >/dev/null 2>&1 || true
    ufw allow 443/tcp >/dev/null 2>&1 || true
    ufw --force enable >/dev/null 2>&1 || true
    print_ok "UFW настроен и включен"
    echo "  $(localize "Открытые порты: SSH, $PORT, 80, 443")"
else
    print_warn "UFW не установлен"
    if confirm "Установить UFW?"; then
        apt-get install -y ufw 2>/dev/null || true
        # После установки не сбрасываем существующую конфигурацию UFW.
        ufw default deny incoming >/dev/null 2>&1 || true
        ufw default allow outgoing >/dev/null 2>&1 || true
        ufw allow ssh >/dev/null 2>&1 || true
        ufw allow "$PORT/tcp" >/dev/null 2>&1 || true
        ufw allow 80/tcp >/dev/null 2>&1 || true
        ufw allow 443/tcp >/dev/null 2>&1 || true
        ufw --force enable >/dev/null 2>&1 || true
        print_ok "UFW настроен"
    fi
fi

# iptables as fallback
if command -v iptables &>/dev/null; then
    iptables -C INPUT -p tcp --dport "$PORT" -j ACCEPT 2>/dev/null || {
        iptables -A INPUT -p tcp --dport "$PORT" -j ACCEPT 2>/dev/null || true
        iptables -A INPUT -p tcp --dport 80 -j ACCEPT 2>/dev/null || true
        iptables -A INPUT -p tcp --dport 443 -j ACCEPT 2>/dev/null || true
    }
    print_ok "iptables обновлен"
fi

# Protect the installation directory from ordinary OS users as a second layer
# in addition to the server-side file-manager checks. The panel itself runs as root.
chown -R root:root "$INSTALL_DIR" 2>/dev/null || true
# Panel-created OS-level console sessions run as nobody. Do not let them traverse
# or read the panel installation directly; Node (the service) runs as root.
find "$INSTALL_DIR" -type d -exec chmod 750 {} + 2>/dev/null || true
find "$INSTALL_DIR" -type f -exec chmod 640 {} + 2>/dev/null || true
chmod 750 "$INSTALL_DIR" 2>/dev/null || true
chmod 700 "$INSTALL_DIR/data" 2>/dev/null || true
chmod 600 "$INSTALL_DIR/data/security.json" 2>/dev/null || true

# Re-deploy the Wayland worker after permission hardening. The panel tree is
# intentionally protected from ordinary users, while this dedicated runtime
# copy must remain executable by the graphical session user.
REMOTE_RUNTIME_DIR="/usr/local/lib/nix-panel"
REMOTE_RUNTIME_WORKER="$REMOTE_RUNTIME_DIR/remote-portal-worker.js"
install -d -o root -g root -m 755 "$REMOTE_RUNTIME_DIR"
if [ -s "$INSTALL_DIR/remote-portal-worker.js" ]; then
    install -o root -g root -m 755 "$INSTALL_DIR/remote-portal-worker.js" "$REMOTE_RUNTIME_WORKER"
else
    print_err "Критическая ошибка: не найден исходный remote-portal-worker.js для runtime-копии"
    exit 1
fi

# =============================================================================
# START SERVICE
# =============================================================================
echo ""
print_info "Запуск NIX Panel..."

cd "$INSTALL_DIR"

# Stop systemd service first to prevent auto-restart
systemctl stop nix-panel.service 2>/dev/null || true
sleep 1

# Kill any existing instance
pkill -f "node.*server.js" 2>/dev/null || true
fuser -k "$PORT"/tcp 2>/dev/null || true
lsof -ti :"$PORT" 2>/dev/null | xargs kill -9 2>/dev/null || true
sleep 2

# Start the panel
nohup node server.js > "$INSTALL_DIR/nix-panel.log" 2>&1 &
PANEL_PID=$!
echo $PANEL_PID > "$INSTALL_DIR/panel.pid"

# Wait for it to start
sleep 2
if kill -0 "$PANEL_PID" 2>/dev/null; then
    print_ok "NIX Panel запущен (PID: $PANEL_PID)"
else
    print_err "Ошибка запуска! Проверьте лог: $INSTALL_DIR/nix-panel.log"
    cat "$INSTALL_DIR/nix-panel.log" | tail -20
    exit 1
fi

# Create systemd service
cat > /etc/systemd/system/nix-panel.service << EOF
[Unit]
Description=NIX Server Management Panel
After=network.target

[Service]
Type=simple
User=root
WorkingDirectory=$INSTALL_DIR
ExecStart=/usr/bin/node $INSTALL_DIR/server.js
Restart=always
RestartSec=5
Environment=NODE_ENV=production
Environment=NIX_REMOTE_WORKER=/usr/local/lib/nix-panel/remote-portal-worker.js

[Install]
WantedBy=multi-user.target
EOF

systemctl daemon-reload 2>/dev/null || true
systemctl enable nix-panel.service 2>/dev/null || true
print_ok "Сервис systemd создан и включен"

# =============================================================================
# NGINX FINAL SETUP
# =============================================================================
if [ "$NGINX_SETUP" = true ]; then
    if [ -n "$DOMAIN_OR_IP" ]; then
        cat > /etc/nginx/sites-available/nix-panel << EOF
server {
    listen 80;
    server_name $DOMAIN_OR_IP;

    location / {
        proxy_pass http://127.0.0.1:$PORT;
        proxy_http_version 1.1;
        proxy_set_header Upgrade \$http_upgrade;
        proxy_set_header Connection "upgrade";
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto \$scheme;
        proxy_read_timeout 86400s;
        proxy_send_timeout 86400s;
    }
}

server {
    listen 443 ssl http2;
    server_name $DOMAIN_OR_IP;

    ssl_certificate $INSTALL_DIR/server.crt;
    ssl_certificate_key $INSTALL_DIR/server.key;

    location / {
        proxy_pass http://127.0.0.1:$PORT;
        proxy_http_version 1.1;
        proxy_set_header Upgrade \$http_upgrade;
        proxy_set_header Connection "upgrade";
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto \$scheme;
        proxy_read_timeout 86400s;
        proxy_send_timeout 86400s;
    }
}
EOF
        # Remove default nginx config to prevent conflicts
        rm -f /etc/nginx/sites-enabled/default 2>/dev/null || true
        ln -sf /etc/nginx/sites-available/nix-panel /etc/nginx/sites-enabled/ 2>/dev/null || true
        if nginx -t 2>&1; then
            systemctl reload nginx 2>/dev/null || true
            print_ok "Nginx настроен"
        else
            print_warn "Ошибка в конфигурации nginx. Проверьте: nginx -t"
        fi
    fi
fi

# Save version
echo "$PANEL_VERSION" > "$VERSION_FILE"
print_ok "Версия $PANEL_VERSION сохранена"

# =============================================================================
# SUMMARY
# =============================================================================
clear
echo -e "${GREEN}${BOLD}"
echo "  ╔══════════════════════════════════════════════╗"
echo "  ║         $(localize_summary "УСТАНОВКА ЗАВЕРШЕНА!")                 ║"
echo "  ╚══════════════════════════════════════════════╝"
echo -e "${NC}"

# Get IP
IP=$(curl -4 -s ifconfig.me 2>/dev/null || hostname -I | awk '{print $1}')
PROTO="http"
if [ -f "$INSTALL_DIR/server.crt" ]; then
    PROTO="https"
fi

echo -e "  ${BOLD}$(localize_summary "URL панели:")${NC}"
echo -e "    ${CYAN}${PROTO}://${DOMAIN_OR_IP}:${PORT}${NC}"
if [ -n "$DOMAIN_OR_IP" ] && [ "$DOMAIN_OR_IP" != "$IP" ]; then
    echo -e "    ${CYAN}${PROTO}://${IP}:${PORT}${NC} ($(localize_summary "по IP"))"
fi
echo ""
echo -e "  ${BOLD}$(localize_summary "Админ:")${NC}      $ADMIN_LOGIN"
if [ "$SKIP_USER_STEPS" != "true" ]; then
    echo -e "  ${BOLD}$(localize_summary "Пароль:")${NC}    $ADMIN_PASS"
    echo ""
    echo -e "  ${RED}${BOLD}$(localize_summary "РЕЗЕРВНЫЙ ПАРОЛЬ БЕЗОПАСНОСТИ:")${NC}"
    echo -e "  ${YELLOW}${BOLD}$BACKUP_PASSWORD${NC}"
    echo -e "  ${YELLOW}$(localize_summary "Этот пароль будет выдан только 1 раз. Сохраните его вне сервера.")${NC}"
else
    echo -e "  ${BOLD}$(localize_summary "Пароль:")${NC}    $(localize_summary " (сохранён в users.json)")"
fi
echo ""
echo -e "  ${BOLD}$(localize_summary "Папка:")${NC}     $INSTALL_DIR"
echo -e "  ${BOLD}$(localize_summary "Порт:")${NC}      $PORT"
echo -e "  ${BOLD}$(localize_summary "Лог:")${NC}       $INSTALL_DIR/nix-panel.log"
echo ""
echo -e "  ${BOLD}$(localize_summary "Команды:")${NC}"
echo -e "    $(localize_summary "Запуск:")    ${YELLOW}systemctl start nix-panel${NC}"
echo -e "    $(localize_summary "Стоп:")      ${YELLOW}systemctl stop nix-panel${NC}"
echo -e "    $(localize_summary "Статус:")    ${YELLOW}systemctl status nix-panel${NC}"
echo -e "    $(localize_summary "Логи:")      ${YELLOW}journalctl -u nix-panel -f${NC}"
echo ""
echo -e "  ${YELLOW}${BOLD}$(localize_summary "⚠ Сохраните логин и пароль!")${NC}"
echo -e "  ${YELLOW}$(localize_summary "После перезагрузки панель запустится автоматически.")${NC}"
echo ""

# Final check
echo -e "  ${BOLD}$(localize_summary "Проверка файлов:")${NC}"
if [ -f "$INSTALL_DIR/server.js" ]; then
    echo -e "    ${GREEN}✓${NC} $(localize_summary "server.js найден")"
else
    echo -e "    ${RED}✗${NC} $(localize_summary "server.js ОТСУТСТВУЕТ! Панель не будет работать.")"
    echo -e "    $(localize_summary "Скопируйте файлы вручную: cp -r ${SCRIPT_DIR}/* $INSTALL_DIR/")"
fi
if [ -d "$INSTALL_DIR/node_modules" ]; then
    echo -e "    ${GREEN}✓${NC} $(localize_summary "node_modules найдены")"
else
    echo -e "    ${RED}✗${NC} $(localize_summary "node_modules ОТСУТСТВУЮТ! Запустите: cd $INSTALL_DIR && npm install")"
fi
echo ""

# Check if panel responds (with retries)
echo -e "  ${BOLD}$(localize_summary "Проверка панели:")${NC}"
for i in 1 2 3 4 5; do
    if curl -sk "https://127.0.0.1:$PORT" >/dev/null 2>&1 || curl -s "http://127.0.0.1:$PORT" >/dev/null 2>&1; then
        echo -e "    ${GREEN}✓${NC} $(localize_summary "Панель работает! (попытка $i)")"
        break
    fi
    if [ "$i" -lt 5 ]; then
        sleep 1
    fi
done
if ! curl -sk "https://127.0.0.1:$PORT" >/dev/null 2>&1 && ! curl -s "http://127.0.0.1:$PORT" >/dev/null 2>&1; then
    print_warn "Панель не отвечает. Проверьте лог:"
    echo "  tail -f $INSTALL_DIR/nix-panel.log"
fi

echo ""
print_question "Нажмите Enter чтобы выйти..."
read_from_tty
