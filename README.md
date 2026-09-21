# 🐧 Linux Technician Toolkit PRO

A single-file, menu-driven shell script for Linux technicians, sysadmins, and power users. You get admin consoles, system reports, repair tools, network diagnostics, package management, security checks, and power/boot options from one colored terminal menu.

No installation, no dependencies beyond bash and standard coreutils. Just download and run.

![Platform](https://img.shields.io/badge/platform-Linux-FCC624?logo=linux&logoColor=black)
![Language](https://img.shields.io/badge/language-Bash-4EAA25?logo=gnubash&logoColor=white)
![Distros](https://img.shields.io/badge/distros-apt%20%7C%20dnf%20%7C%20pacman%20%7C%20zypper%20%7C%20apk-blue)
![License](https://img.shields.io/badge/license-MIT-green)

---

## One edition, not two

The sister project, [WindowsTechToolKit](https://github.com/), ships two `.bat` files because Windows elevation is all-or-nothing: a script either runs as Administrator for its whole lifetime or it doesn't, so a "no-admin" edition has to be a separately maintained file with the admin-only tools stripped out.

Linux doesn't work that way. `sudo` is granted per-command, not per-process, so a single script can run perfectly well as a standard user and simply ask for your password the moment you pick an action that actually needs root — package installs, service restarts, network resets, and so on. Everything else (system info, monitoring, most network diagnostics, user-scope cleanup) just runs, no prompt at all. That's what `linuxtechtoolkit.sh` does: one file, works for root or a standard user, asks for `sudo` only when an action genuinely requires it.

---

## ✨ Features

- **Distro-aware.** Detects your package manager (`apt`, `dnf`, `yum`, `pacman`, `zypper`, `apk`) on startup and every package-related tool adapts automatically — no per-distro forks to maintain.
- **Colored, categorized menus.** Nine sections keep 70+ tools easy to find.
- **Safety prompts.** Anything destructive asks you to type `YES` before running.
- **Live system monitor.** Launches `btop` or `htop` if you have one installed; otherwise falls back to a built-in, dependency-free dashboard driven straight from `/proc` — CPU, RAM, and per-disk usage bars, live network throughput, and a top-processes table, refreshing about once a second.
- **Saved reports.** Reports are saved with timestamps to `~/TechToolkit_Reports`.
- **Activity log.** Every action is recorded in `toolkit_log.txt` in that same folder.
- **Graceful degradation.** Optional tools (`smartctl`, `speedtest`, `rkhunter`, `nmcli`, ...) are detected on the fly; if one's missing, the toolkit offers to install it through your distro's package manager instead of just failing.
- **No elevation dance.** Never re-execs itself, never needs a UAC-style relaunch — see above.

## 📋 Menu Overview

### Live System Monitor
- Prefers `btop`, then `htop`, if either is installed.
- Otherwise uses the built-in monitor: color-coded bars for CPU and RAM, a bar per mounted disk (not just `/`), live download/upload throughput plus IP/gateway for the default route interface, and a top-5-by-CPU process table. Pure `/proc` and `ss`/`ip` parsing — nothing to install.

### 1. Admin Consoles
Root shell, interactive service manager, live log viewer (`journalctl -f`), user management, process manager (`htop`/`top`), disk manager, cron/systemd-timer listing, package-manager GUI, and network manager TUI/GUI (`nmtui`).

### 2. System Info & Reports
Quick summary (OS, kernel, CPU, RAM, disks, uptime, GPU), full system report (saved as `.txt`), battery health (laptops), installed-packages list (saved as `.txt`), disk SMART health, critical errors from the last 24 hours (`journalctl -p 3`), failed systemd units, and boot-time analysis (`systemd-analyze blame`).

### 3. Repair & Maintenance
Fix broken packages, full system update, rebuild initramfs, update GRUB config, schedule an fsck on next boot, disk SMART self-test, reset failed systemd units, restart a specific service, rebuild DKMS kernel modules (NVIDIA/VirtualBox-style out-of-tree drivers), and create a system snapshot (`timeshift`/`snapper` if available).

### 4. Network Tools
One-click diagnosis (router/internet/DNS), IP configuration, public IP, flush DNS cache, release & renew DHCP lease, ping, traceroute (`mtr` if available), saved Wi-Fi networks, active connections (saved to a file), full network reset, **show saved Wi-Fi passwords**, internet speed test (Ookla CLI or `speedtest-cli`, auto-installed on first use), configure a static or DHCP IP via `nmcli`, and firewall status.

### 5. Package Management
Check for updates, update & upgrade everything, clean cache/autoremove, install, search, remove, and list explicitly-installed (top-level) packages — all through whichever package manager your distro actually uses.

### 6. Security Tools *(no Windows equivalent — added because it matters more on Linux, especially for anything internet-facing)*
Firewall enable/disable, listening ports with owning processes, pending security updates, an SSH `sshd_config` audit (flags `PermitRootLogin yes` and password-only auth), failed login attempts, users holding UID 0 or sudo/wheel membership, a rootkit scan (`rkhunter`/`chkrootkit`), and a world-writable-files scan across key system directories.

### 7. Cleanup
Temp files (`/tmp` + `~/.cache`), package cache/autoremove, systemd journal vacuum, empty trash, remove old kernels, Docker/Podman prune, and thumbnail cache.

### 8. Power & Boot
Reboot into firmware (BIOS/UEFI) setup, boot into rescue/emergency mode, set the default boot target (graphical vs. multi-user — the closest Linux equivalent to toggling Windows Safe Mode), suspend/hibernate, restart, and shut down.

## 🚀 Getting Started

```bash
git clone <this repo>
cd LinuxTechToolKit-
chmod +x linuxtechtoolkit.sh
./linuxtechtoolkit.sh
```

Or run it directly without cloning:

```bash
bash linuxtechtoolkit.sh
```

No `sudo` needed to launch it — you'll only be prompted for your password the first time you pick a menu option that actually requires root.

## 🖥️ Requirements

- Bash 4 or newer (ships by default on every current Linux distribution)
- Standard coreutils, `iproute2`, and `procps` (present on virtually every install)
- Optional, and only needed by specific tools: `sudo`, `curl`, `smartmontools` (SMART health), `speedtest-cli` or Ookla's `speedtest` CLI, `NetworkManager`/`nmcli`, `rkhunter` or `chkrootkit`, `htop`/`btop`, `timeshift`/`snapper`. The toolkit detects each one at the point of use and offers to install it through your package manager if it's missing.

Tested against Debian/Ubuntu (`apt`), Fedora (`dnf`), and Arch (`pacman`) containers; `zypper` and `apk` code paths are implemented against their documented CLIs but weren't tested against a live openSUSE/Alpine system.

## ⚠️ Disclaimer

Some tools make system-level changes — full network reset, filesystem checks, GRUB regeneration, package removal, rescue-mode boots. Each one asks for confirmation first. Still, **take a snapshot (Repair & Maintenance → Create system snapshot) before making major changes**, and use this toolkit at your own risk. The author is not responsible for data loss or system issues.

The **Show saved Wi-Fi passwords** tool prints stored network passwords in plain text to the terminal. Be mindful of who can see the screen (or a screen recording/share) when you use it.

## 🤝 Contributing

Suggestions and improvements are welcome:

1. Fork the repository.
2. Create a branch with `git checkout -b feature/new-tool`.
3. Commit your changes and open a Pull Request.

The script is intentionally a single file — keep new tools consistent with the existing menu/function structure (`<section>_<action>` function names, `run_priv` for anything needing root, `confirm` before anything destructive).

## 📄 License

This project is licensed under the [MIT License](LICENSE).
