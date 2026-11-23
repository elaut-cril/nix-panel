# NIX Panel

NIX Panel is a self-hosted web interface for managing a Linux server. It brings file management, system monitoring, chat, a terminal, and optional remote desktop control together in one browser-based panel.

> **Version:** 2.2.1

## Features

- **File manager:** browse server disks and directories; upload, download, preview, edit, rename, copy, move, archive, extract, and delete files, subject to the signed-in account's permissions. Administrators can optionally enable bounded, asynchronous directory-size calculation.
- **Office files:** preview documents and presentations through LibreOffice; view and edit spreadsheet cell data in the built-in table editor. LibreOffice is optional and can be installed from the panel by an administrator.
- **System dashboard and task manager:** view CPU, memory, disk, network, GPU (when available), and process information; inspect per-process details and terminate processes when permitted.
- **User and permission management:** create and remove panel accounts, change passwords, and grant individual capabilities for files, chat, AI, terminal, power controls, and other panel features.
- **Chat:** exchange messages and files with other panel users, with per-user chat colors, configurable chat settings, sanitized Markdown, and copyable code blocks. Images, videos, and other files can be uploaded, selected from the server, or pasted into the message input with `Ctrl+V`.
- **AI chat:** connect a configured OpenAI- or Anthropic-protocol provider, choose a model and API endpoint, and optionally enable image analysis. Two independent context options are available and disabled by default: include a configurable number of recent human chat messages with author names, or retain a configurable per-user history of previous AI questions and answers. AI tools can be scoped to a working directory; full-server access is reserved for the installer administrator.
- **Terminal:** use a browser-based shell. The installer administrator receives the administrative shell; panel-created users' shells run as the unprivileged `nobody` account.
- **Remote desktop:** view and control an active Linux desktop. KDE/Wayland uses `ydotool` for input and efficiently compressed WebP frames when the encoder is installed; the installer can add the required input and screen-capture tools. A virtual display can be used on headless servers. The installer administrator can optionally set a custom GUI launch command in **Settings → Remote desktop**. An empty command keeps the standard display-manager startup. Custom commands run as root through `/bin/bash -lc`; use `runuser -u USERNAME -- command` when a desktop must start as a regular user.
- **Wake-on-LAN:** save devices and send wake packets to them.
- **Personalization:** choose a language and theme, create or edit custom themes with file-selection colors tied to each theme, set chat colors, and add panel buttons.
- **Security controls:** scrypt password hashes with an 8-character minimum for new passwords, optional TOTP two-factor authentication, persistent expiring sessions, capability checks, same-origin mutation checks, failed-login throttling, sanitized Office previews, role-scoped Socket.IO events, and an emergency panel lock.

The interface offers Russian, English, German, French, Spanish, and Simplified Chinese. Each account can select its own language.

## Requirements

- A Linux server. **Ubuntu 24 or newer is recommended** by the installer; other distributions are not guaranteed.
- Root access for installation. The installer configures a `systemd` service and may install system packages or modify firewall rules if you choose those options.
- Node.js 22.12 or newer and npm. The installer installs Node.js 22.x and the panel's npm dependencies.
- A browser that supports modern JavaScript and WebSockets.
- Optional: Nginx and a domain name for reverse proxy and TLS setup; LibreOffice for Office previews; a graphical session or Xvfb for remote desktop. On KDE/Wayland, choose the remote desktop option in the installer to install `ydotool`, `wl-clipboard`, `grim`, `spectacle`, ImageMagick, and the WebP encoder.

## Installation

Run the installer as root on the server. Choose the installer and default panel language, installation directory, port, administrator credentials, and optional components when prompted.

```bash
git clone https://github.com/elaut-cril/nix-panel.git
cd nix-panel
sudo bash install.sh
```
### Updating or reinstalling

Run the installer again and select the requested action. The update option is designed to preserve panel data and is restricted for older or incomplete security configurations. A reinstall removes the existing application; back up your data separately before choosing it.

## Using the panel

Open the URL and port reported by the installer, then sign in with the administrator account created during setup. Create separate accounts for other people and grant only the permissions they need.

Some features need additional configuration:

- **Two-factor authentication:** open **Settings → Two-factor authentication**, confirm your password, scan the QR code with Google Authenticator or another TOTP app, and enter the generated six-digit code. Disabling requires the current password and authenticator code. The installer administrator can reset 2FA for another account from user management. TOTP secrets are encrypted at rest using the session secret.
- **HTTPS redirection:** when valid `server.crt` and `server.key` files are present, the panel uses HTTPS. Production installations also redirect HTTP requests to HTTPS with status 308, listening on port 80 by default. The installer enables this explicitly with `httpRedirect: true` and `httpRedirectPort: 80`. Set `httpRedirect: false` to disable it or choose another `httpRedirectPort`. An optional `publicHost` can pin the redirect hostname.

- **AI:** an administrator must configure the provider protocol, provider/model ID, base URL, API key, and model. Image analysis depends on provider support and the vision option. Human chat context and per-user AI conversation history can be enabled and sized independently in AI settings.
- **Remote desktop:** remote control requires an active graphical session. Wayland input is sent through `ydotool`; the daemon needs access to `/dev/uinput`, which the installer enables. Headless systems need the virtual display option selected during setup.
- **Office previews:** LibreOffice must be installed. An administrator can install it from the panel where supported.
- **Wake-on-LAN:** the target device and network must support Wake-on-LAN, and the server must be able to send the packet to that network.

## Data and configuration

The installer writes `nix-config.json` in the installation directory. It contains the panel port, data directory, default language, and session secret. By default, the data directory is `<installation-directory>/data` and holds account records, chat messages and uploads, themes, buttons, AI settings and per-user AI conversation history, security state, and Wake-on-LAN devices.

Back up the configuration and data directory before upgrading, reinstalling, or changing the server. Treat them as sensitive: they may contain account credentials, an AI provider API key, session secrets, and uploaded files.

## Security

NIX Panel is a privileged server administration tool. The installer runs it as root, so an exposed or compromised installer-administrator account can affect the whole server. Use strong unique passwords, use HTTPS for access over untrusted networks, restrict network access, and grant panel-created accounts only the permissions they need. File-management permissions can allow broad changes to the server filesystem. Remote desktop and AI server tools also grant powerful capabilities.

Panel-created users' terminal sessions run as `nobody`; this does not make the other panel features unprivileged. Review the permission assignments and keep the server and its dependencies updated.

## Running manually

For development or a manual launch, install the locked dependencies, run the checks, and start the server:

```bash
npm ci
npm run check
npm start
```

The server reads `nix-config.json` from its own directory. A local installation without that file listens only on `127.0.0.1:8081`, stores data in `./data`, and generates a random administrator password and recovery password on first launch. The initial values are printed to the console; no `admin` / `admin` fallback is available. Production mode requires an installer-generated configuration and account data.

For an isolated WSL development runtime without installing Node.js or changing system services, run from the project directory inside WSL:

```bash
bash work/wsl-bootstrap.sh
bash work/wsl-start.sh
```

The scripts use `work/wsl-node` and `work/wsl-runtime`, copy only application source files, and leave existing accounts, certificates, and `data/` untouched.

## License

NIX Panel is distributed under the MIT License. See [LICENSE](LICENSE).
