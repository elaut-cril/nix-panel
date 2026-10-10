# NIX Panel

NIX Panel is a self-hosted web interface for managing a Linux server. It brings file management, system monitoring, chat, a terminal, and optional remote desktop control together in one browser-based panel.

> **Version:** 2.2.0

## Features

- **File manager:** browse server disks and directories; upload, download, preview, edit, rename, copy, move, archive, extract, and delete files, subject to the signed-in account's permissions.
- **Office files:** preview documents and presentations through LibreOffice; view and edit spreadsheet cell data in the built-in table editor. LibreOffice is optional and can be installed from the panel by an administrator.
- **System dashboard and task manager:** view CPU, memory, disk, network, GPU (when available), and process information; terminate processes when permitted.
- **User and permission management:** create and remove panel accounts, change passwords, and grant individual capabilities for files, chat, AI, terminal, power controls, and other panel features.
- **Chat:** exchange messages and files with other panel users, with per-user chat colors and configurable chat settings.
- **AI chat:** connect a configured OpenAI- or Anthropic-protocol provider, choose a model and API endpoint, and optionally enable image analysis. Two independent context options are available and disabled by default: include a configurable number of recent human chat messages with author names, or retain a configurable per-user history of previous AI questions and answers. AI tools can be scoped to a working directory; full-server access is reserved for the installer administrator.
- **Terminal:** use a browser-based shell. The installer administrator receives the administrative shell; panel-created users' shells run as the unprivileged `nobody` account.
- **Remote desktop:** view and control a graphical Linux session when the required desktop and input components are available. KDE/Wayland may require an approval in the graphical session. A virtual display can be used on headless servers.
- **Wake-on-LAN:** save devices and send wake packets to them.
- **Personalization:** choose a language and theme, create custom themes, set chat colors, and add panel buttons.
- **Security controls:** authenticated sessions, capability checks, failed-login throttling and event logging, and an emergency panel lock.

The interface offers Russian, English, German, French, Spanish, and Simplified Chinese. Each account can select its own language.

## Requirements

- A Linux server. **Ubuntu 24 or newer is recommended** by the installer; other distributions are not guaranteed.
- Root access for installation. The installer configures a `systemd` service and may install system packages or modify firewall rules if you choose those options.
- Node.js 20.x and npm. The installer installs Node.js 20.x and the panel's npm dependencies.
- A browser that supports modern JavaScript and WebSockets.
- Optional: Nginx and a domain name for reverse proxy and TLS setup; LibreOffice for Office previews; a graphical session or Xvfb and the relevant desktop packages for remote desktop.

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

- **AI:** an administrator must configure the provider protocol, provider/model ID, base URL, API key, and model. Image analysis depends on provider support and the vision option. Human chat context and per-user AI conversation history can be enabled and sized independently in AI settings.
- **Remote desktop:** remote control requires a usable graphical session. Wayland portal access may ask for approval on the server's desktop. Headless systems need the virtual display option selected during setup.
- **Office previews:** LibreOffice must be installed. An administrator can install it from the panel where supported.
- **Wake-on-LAN:** the target device and network must support Wake-on-LAN, and the server must be able to send the packet to that network.

## Data and configuration

The installer writes `nix-config.json` in the installation directory. It contains the panel port, data directory, default language, and session secret. By default, the data directory is `<installation-directory>/data` and holds account records, chat messages and uploads, themes, buttons, AI settings and per-user AI conversation history, security state, and Wake-on-LAN devices.

Back up the configuration and data directory before upgrading, reinstalling, or changing the server. Treat them as sensitive: they may contain account credentials, an AI provider API key, session secrets, and uploaded files.

## Security

NIX Panel is a privileged server administration tool. The installer runs it as root, so an exposed or compromised installer-administrator account can affect the whole server. Use strong unique passwords, use HTTPS for access over untrusted networks, restrict network access, and grant panel-created accounts only the permissions they need. File-management permissions can allow broad changes to the server filesystem. Remote desktop and AI server tools also grant powerful capabilities.

Panel-created users' terminal sessions run as `nobody`; this does not make the other panel features unprivileged. Review the permission assignments and keep the server and its dependencies updated.

## Running manually

For development or a manual launch, install the dependencies in the project directory and start the server:

```bash
npm install
npm start
```

The server reads `nix-config.json` from its own directory. Without an installer-generated configuration and `users.json`, it uses port `8081`, stores data in `./data`, and falls back to the development credentials `admin` / `admin`. Do not expose that setup to a network; use the installer to create production credentials and configure the service.

## License

NIX Panel is distributed under the MIT License. See [LICENSE](LICENSE).
