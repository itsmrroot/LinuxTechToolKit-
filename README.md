# 🐧 Linux Technician Toolkit PRO

A single-file, menu-driven shell script for Linux technicians, sysadmins, and power users. You get admin consoles, system reports, repair tools, network diagnostics, package management, security checks, and power/boot options from one colored terminal menu.

No installation, no dependencies beyond bash and standard coreutils. Just download and run.

![Platform](https://img.shields.io/badge/platform-Linux-FCC624?logo=linux&logoColor=black)
![Language](https://img.shields.io/badge/language-Bash-4EAA25?logo=gnubash&logoColor=white)
![Distros](https://img.shields.io/badge/distros-apt%20%7C%20dnf%20%7C%20pacman%20%7C%20zypper%20%7C%20apk-blue)
![Menus](https://img.shields.io/badge/menus-EN%20%7C%20DE-6f42c1)
![License](https://img.shields.io/badge/license-MIT-green)

---

## One edition, not two

The sister project, [WindowsTechToolKit](https://github.com/), ships two `.bat` files because Windows elevation is all-or-nothing: a script either runs as Administrator for its whole lifetime or it doesn't, so a "no-admin" edition has to be a separately maintained file with the admin-only tools stripped out.

Linux doesn't work that way. `sudo` is granted per-command, not per-process, so a single script can run perfectly well as a standard user and simply ask for your password the moment you pick an action that actually needs root — package installs, service restarts, network resets, and so on. Everything else (system info, monitoring, most network diagnostics, user-scope cleanup) just runs, no prompt at all. That's what `linuxtechtoolkit.sh` does: one file, works for root or a standard user, asks for `sudo` only when an action genuinely requires it.

---

## ✨ Features

- **Multi-language menus.** On launch, pick English or Deutsch; every menu, item label, and navigation prompt (Back/Exit/Press Enter/confirmation) is shown in that language for the rest of the session.
- **Distro-aware.** Detects your package manager (`apt`, `dnf`, `yum`, `pacman`, `zypper`, `apk`) on startup and every package-related tool adapts automatically — no per-distro forks to maintain.
- **Colored, categorized menus.** Nine sections keep 90+ tools easy to find.
- **Safety prompts.** Anything destructive asks you to type `YES` before running.
- **Live system monitor.** Launches `btop` or `htop` if you have one installed; otherwise falls back to a built-in, dependency-free dashboard driven straight from `/proc` — CPU, RAM, and per-disk usage bars, live network throughput, and a top-processes table, refreshing about once a second.
- **Saved reports.** Reports are saved with timestamps to `~/TechToolkit_Reports`.
- **Activity log.** Every action is recorded in `toolkit_log.txt` in that same folder.
- **Graceful degradation.** Optional tools (`smartctl`, `speedtest`, `rkhunter`, `nmcli`, ...) are detected on the fly; if one's missing, the toolkit offers to install it through your distro's package manager instead of just failing.
- **No elevation dance.** Never re-execs itself, never needs a UAC-style relaunch — see above.
- **Container/VM aware.** Detects when it's running virtualized (`systemd-detect-virt`) and flags menu items — GRUB, DKMS, firmware reboot — that won't apply there.
- **Self-updating.** Checks GitHub for a newer release on demand and can replace itself in place.
- **Scriptable.** `--quick-summary`, `--check-updates`, `--version`, and `--help` flags work outside the interactive menu, for cron jobs or other scripts.

## 📋 Menu Overview

### Live System Monitor
- Prefers `btop`, then `htop`, if either is installed.
- Otherwise uses the built-in monitor: color-coded bars for CPU and RAM, a bar per mounted disk (not just `/`), live download/upload throughput plus IP/gateway for the default route interface, and a top-5-by-CPU process table. Pure `/proc` and `ss`/`ip` parsing — nothing to install.

### 1. Admin Consoles
Root shell, interactive service manager, live log viewer (`journalctl -f`), user management, process manager (`htop`/`top`), disk manager, cron/systemd-timer listing, package-manager GUI, and network manager TUI/GUI (`nmtui`).

### 2. System Info & Reports
Quick summary (OS, kernel, CPU, RAM, disks, uptime, GPU, virtualization type, SELinux/AppArmor status), full system report (saved as `.txt`), battery health (laptops), installed-packages list (saved as `.txt`), disk SMART health, critical errors from the last 24 hours (`journalctl -p 3`), failed systemd units, boot-time analysis (`systemd-analyze blame`), and disk encryption (LUKS) status.

### 3. Repair & Maintenance
Fix broken packages, full system update, rebuild initramfs, update GRUB config, schedule an fsck on next boot, disk SMART self-test, reset failed systemd units, restart a specific service, rebuild DKMS kernel modules (NVIDIA/VirtualBox-style out-of-tree drivers), create a system snapshot (`timeshift`/`snapper` if available), and back up/extract key config files (`/etc`, crontabs, package list — secrets like `/etc/shadow` and private keys are deliberately excluded).

### 4. Network Tools
One-click diagnosis (router/internet/DNS), IP configuration, public IP, flush DNS cache, release & renew DHCP lease, ping, traceroute (`mtr` if available), saved Wi-Fi networks, active connections (saved to a file), full network reset, **show saved Wi-Fi passwords**, internet speed test (Ookla CLI or `speedtest-cli`, auto-installed on first use), configure a static or DHCP IP via `nmcli`, and firewall status.

### 5. Package Management
Check for updates, update & upgrade everything, clean cache/autoremove, install, search, remove, and list explicitly-installed (top-level) packages — all through whichever package manager your distro actually uses.

### 6. Security Tools *(no Windows equivalent — added because it matters more on Linux, especially for anything internet-facing)*
Firewall enable/disable, listening ports with owning processes, pending security updates, an SSH `sshd_config` audit (flags `PermitRootLogin yes` and password-only auth), failed login attempts, users holding UID 0 or sudo/wheel membership, a rootkit scan (`rkhunter`/`chkrootkit`), a world-writable-files scan, **Fail2ban status with ban/unban an IP**, a **Lynis security audit** (0–100 hardening index, offered install if missing), **kernel (sysctl) hardening** — view current vs. recommended values for ASLR, ICMP redirects, SYN cookies, etc., apply a baseline with one confirm, and revert from an automatic backup — **SELinux/AppArmor status**, and **disk/USB encryption** — LUKS-encrypt a disk or USB drive (with a typed device-path confirmation and a guard against touching whatever holds your root filesystem), unlock/decrypt an encrypted disk, and lock it again.

### 7. Cleanup
Temp files (`/tmp` + `~/.cache`), package cache/autoremove, systemd journal vacuum, empty trash, remove old kernels, Docker/Podman prune, thumbnail cache, and an interactive disk-usage browser (`ncdu` if installed, else a built-in top-20-biggest-folders fallback) for "what's eating my disk?".

### 8. Power & Boot
Reboot into firmware (BIOS/UEFI) setup, boot into rescue/emergency mode, set the default boot target (graphical vs. multi-user — the closest Linux equivalent to toggling Windows Safe Mode), suspend/hibernate, restart, and shut down.

## 🌐 Languages

The first screen asks you to pick a language:

| # | Language |
|---|---|
| 1 | English |
| 2 | Deutsch |

The choice applies for the rest of that session — every menu title, item label, and navigation prompt (`Back`/`Exit`/`Press Enter to continue`/confirmations) is shown in that language. In German, the confirmation word for destructive actions is `JA` instead of `YES`.

**Scope, deliberately:** only the toolkit's own menus and navigation chrome are translated — the same choice [WindowsTechToolKit](https://github.com/) makes for its three languages. The screen you land on after picking a menu item (its title, explanatory text, and anything printed by a native Linux tool like `systemctl`, `journalctl`, or `ip a`) stays in English. Translating every one of the hundreds of scattered per-action messages would be a much larger and more error-prone effort for comparatively little benefit, given that output is dominated by native command output anyway.

`--quick-summary`, `--check-updates`, `--version`, and `--help` skip the language prompt entirely and always run in English, since they're meant for non-interactive/scripted use.

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

### Command-line flags

The interactive menu is the default, but a few flags work outside it:

```bash
./linuxtechtoolkit.sh --quick-summary   # print the quick system summary and exit (cron-friendly)
./linuxtechtoolkit.sh --check-updates   # check GitHub for a newer release and exit
./linuxtechtoolkit.sh --version         # print the toolkit version and exit
./linuxtechtoolkit.sh --help            # usage
```

## 🖥️ Requirements

- Bash 4 or newer (ships by default on every current Linux distribution)
- Standard coreutils, `iproute2`, and `procps` (present on virtually every install)
- Optional, and only needed by specific tools: `sudo`, `curl`, `smartmontools` (SMART health), `speedtest-cli` or Ookla's `speedtest` CLI, `NetworkManager`/`nmcli`, `rkhunter`/`chkrootkit`, `fail2ban`, `lynis`, `ncdu`, `cryptsetup`, `htop`/`btop`, `timeshift`/`snapper`. The toolkit detects each one at the point of use and offers to install it through your package manager if it's missing.

Tested against Debian/Ubuntu (`apt`), Fedora (`dnf`), and Arch (`pacman`) containers; `zypper` and `apk` code paths are implemented against their documented CLIs but weren't tested against a live openSUSE/Alpine system.

## ⚠️ Disclaimer

Some tools make system-level changes — full network reset, filesystem checks, GRUB regeneration, package removal, rescue-mode boots. Each one asks for confirmation first. Still, **take a snapshot (Repair & Maintenance → Create system snapshot) before making major changes**, and use this toolkit at your own risk. The author is not responsible for data loss or system issues.

The **Show saved Wi-Fi passwords** tool prints stored network passwords in plain text to the terminal. Be mindful of who can see the screen (or a screen recording/share) when you use it.

The **kernel (sysctl) hardening** baseline deliberately excludes `net.ipv4.ip_forward` and other context-dependent settings that routers, Docker hosts, and VPN boxes legitimately need enabled — it only touches settings that are safe defaults on virtually any machine, and it backs up whatever was there before so you can revert with one confirm.

The **backup key config files** tool excludes `/etc/shadow`, `/etc/gshadow`, SSH host private keys, and any `*.key`/`*.pem` files by design — it's a config snapshot for disaster recovery, not a credentials backup.

The **Encrypt a disk / USB drive** tool runs `cryptsetup luksFormat`, which destroys all existing data on the target device. It refuses to touch whatever device holds your root filesystem and requires you to type the exact device path back before proceeding, but there's no undo once you confirm — double-check you've picked the right device.

## 🤝 Contributing

Suggestions and improvements are welcome:

1. Fork the repository.
2. Create a branch with `git checkout -b feature/new-tool`.
3. Commit your changes and open a Pull Request.

The script is intentionally a single file — keep new tools consistent with the existing menu/function structure (`<section>_<action>` function names, `run_priv` for anything needing root, `confirm` before anything destructive).

## 📄 License

This project is licensed under the [MIT License](LICENSE).
