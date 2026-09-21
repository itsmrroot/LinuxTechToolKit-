#!/usr/bin/env bash
# ============================================================
#  LINUX TECHNICIAN TOOLKIT PRO
#  Powered by BASHAR SALMO
#  A single-file, menu-driven admin console for Linux techs,
#  sysadmins and power users: system info, repair, network,
#  package management, security and cleanup tools.
#  No installation - just `bash linuxtechtoolkit.sh` (or ./linuxtechtoolkit.sh).
#  Requires bash 4+ (ships on every current distro) and coreutils.
#  Uses `sudo` per-action rather than relaunching itself elevated -
#  that's the idiomatic model on Linux, unlike Windows UAC, so a
#  single edition covers both root and standard-user sessions:
#  actions that need root just prompt for sudo when you pick them.
# ============================================================

set -uo pipefail

# ---- Guard: needs bash 4+ for associative arrays ----
if [ -z "${BASH_VERSINFO:-}" ] || [ "${BASH_VERSINFO[0]}" -lt 4 ]; then
    echo "This toolkit requires bash 4 or newer. You're running: $($0 --version 2>/dev/null | head -1 || echo unknown)" >&2
    echo "On macOS, install a newer bash with: brew install bash" >&2
    exit 1
fi

# ============================================================
#  COLORS
# ============================================================
if [ -t 1 ]; then
    C_CYAN=$'\033[96m'; C_YEL=$'\033[93m'; C_GRN=$'\033[92m'
    C_RED=$'\033[91m'; C_WHT=$'\033[97m'; C_DIM=$'\033[90m'
    C_BOLD=$'\033[1m'; C_RST=$'\033[0m'
else
    C_CYAN=""; C_YEL=""; C_GRN=""; C_RED=""; C_WHT=""; C_DIM=""; C_BOLD=""; C_RST=""
fi

# ============================================================
#  GLOBALS
# ============================================================
TOOLKIT_VERSION="1.2.0"
GITHUB_REPO="itsmrroot/LinuxTechToolKit-"
REPORT_DIR="${HOME}/TechToolkit_Reports"
LOG_FILE="${REPORT_DIR}/toolkit_log.txt"
IS_ROOT=0
[ "$(id -u)" -eq 0 ] && IS_ROOT=1
PKG_MANAGER=""
DISTRO_NAME="Unknown"
DISTRO_ID="unknown"
LANG_CHOICE="EN"

mkdir -p "$REPORT_DIR" 2>/dev/null

# ============================================================
#  TRANSLATIONS (menu chrome: titles, item labels, navigation prompts)
# ============================================================
# Scope, deliberately: the menu structure and common navigation prompts are
# fully bilingual. Deep per-action output (diagnostic text, confirmation
# messages inside individual tools, and native command output like
# `systemctl`/`journalctl`) stays in English - translating every one of the
# hundreds of scattered messages would be a much larger, more error-prone
# effort for comparatively little benefit, since that output is dominated by
# native Linux tool output anyway. This mirrors WindowsTechToolKit's own
# scoping: only the toolkit's own menus/prompts are translated.

declare -A T_EN=(
    [SELECT]="Select an option: "
    [BACK]="Back"
    [EXIT]="Exit"
    [PRESS_ENTER]="Press Enter to continue..."
    [INVALID]="Invalid option. Try again."
    [WARNING]="WARNING:"
    [CONFIRM_WORD]="YES"
    [CONFIRM_PROMPT]="Type %s to continue:"
    [CANCELLED]="Cancelled."
    [HOST_LABEL]="Host:"
    [USER_LABEL]="User:"
    [STDUSER_TAG]=" [standard user - sudo used per action]"

    [MAIN_TITLE]="Main Menu"
    [MAIN_1]="Admin Consoles"
    [MAIN_2]="System Info & Reports"
    [MAIN_3]="Repair & Maintenance"
    [MAIN_4]="Network Tools"
    [MAIN_5]="Package Management"
    [MAIN_6]="Security Tools"
    [MAIN_7]="Cleanup"
    [MAIN_8]="Power & Boot"
    [MAIN_9]="Live System Monitor"
    [MAIN_10]="Open Reports Folder"
    [MAIN_11]="Check for Toolkit Updates"

    [SI_TITLE]="System Info & Reports"
    [SI_1]="Quick system summary"
    [SI_2]="Full system report          (saved as .txt)"
    [SI_3]="Battery health report       (laptops)"
    [SI_4]="Installed packages list     (saved as .txt)"
    [SI_5]="Disk health (SMART)"
    [SI_6]="Critical errors, last 24h"
    [SI_7]="Failed systemd units"
    [SI_8]="Boot time analysis"
    [SI_9]="Disk encryption (LUKS) status"

    [RM_TITLE]="Repair & Maintenance"
    [RM_VIRT_NOTE]="Note: running inside %s - bootloader/initramfs/DKMS tools below likely won't apply."
    [RM_1]="Fix broken packages          (dpkg --configure -a / fix-broken)"
    [RM_2]="Full system update"
    [RM_3]="Rebuild initramfs / initrd"
    [RM_4]="Update bootloader (GRUB) config"
    [RM_5]="Schedule filesystem check on next boot"
    [RM_6]="Disk SMART self-test"
    [RM_7]="Reset failed systemd units"
    [RM_8]="Restart a specific service"
    [RM_9]="Rebuild DKMS kernel modules"
    [RM_10]="Create system snapshot / restore point"
    [RM_11]="Backup key config files      (/etc, crontabs, package list)"
    [RM_12]="Extract a config backup for review"

    [NT_TITLE]="Network Tools"
    [NT_1]="One-click diagnosis          (router / internet / DNS)"
    [NT_2]="IP configuration"
    [NT_3]="Public IP"
    [NT_4]="Flush DNS cache"
    [NT_5]="Release and renew IP"
    [NT_6]="Ping"
    [NT_7]="Traceroute"
    [NT_8]="Saved Wi-Fi networks"
    [NT_9]="Active connections           (saved to a file)"
    [NT_10]="Full network reset"
    [NT_11]="Show saved Wi-Fi passwords"
    [NT_12]="Internet speed test"
    [NT_13]="Configure IP address         (DHCP / static)"
    [NT_14]="Firewall status"

    [ST_TITLE]="Security Tools"
    [ST_1]="Firewall enable / disable"
    [ST_2]="Listening ports & owning processes"
    [ST_3]="Check for pending updates"
    [ST_4]="SSH configuration audit"
    [ST_5]="Failed login attempts"
    [ST_6]="Users with superuser (UID 0) rights"
    [ST_7]="Rootkit scan               (rkhunter / chkrootkit)"
    [ST_8]="World-writable files scan"
    [ST_9]="Fail2ban status & ban/unban an IP"
    [ST_10]="Lynis security audit       (hardening index 0-100)"
    [ST_11]="Kernel (sysctl) hardening  (view / apply baseline)"
    [ST_12]="SELinux / AppArmor status"

    [PM_TITLE]="Package Management"
    [PM_ON]="on"
    [PM_1]="Check for updates"
    [PM_2]="Update & upgrade everything"
    [PM_3]="Clean package cache / autoremove"
    [PM_4]="Install a package"
    [PM_5]="Search for a package"
    [PM_6]="Remove a package"
    [PM_7]="List explicitly installed packages (top-level, not deps)"

    [CL_TITLE]="Cleanup"
    [CL_1]="Clean temp files             (/tmp + ~/.cache)"
    [CL_2]="Package cache / autoremove"
    [CL_3]="Vacuum systemd journal"
    [CL_4]="Empty trash"
    [CL_5]="Remove old kernels"
    [CL_6]="Docker / Podman cleanup"
    [CL_7]="Clear thumbnail cache"
    [CL_8]="Find what's using disk space (ncdu-style browser)"

    [PW_TITLE]="Power & Boot"
    [PW_VIRT_NOTE]="Note: running inside %s - firmware setup and rescue-mode reboots likely won't apply."
    [PW_1]="Reboot into firmware (BIOS/UEFI) setup"
    [PW_2]="Boot into rescue / emergency mode"
    [PW_3]="Set default boot target             (GUI on/off)"
    [PW_4]="Suspend / hibernate"
    [PW_5]="Restart"
    [PW_6]="Shut down"

    [AC_TITLE]="Admin Consoles"
    [AC_1]="Root shell                   (sudo -i)"
    [AC_2]="Service manager (systemctl status, interactive)"
    [AC_3]="Live log viewer              (journalctl -f)"
    [AC_4]="User management              (list / add / passwd)"
    [AC_5]="Process manager              (htop/top)"
    [AC_6]="Disk manager                 (lsblk / GNOME Disks if available)"
    [AC_7]="Cron / scheduled tasks       (crontab -l, systemd timers)"
    [AC_8]="Package manager GUI          (if installed)"
    [AC_9]="Network manager TUI/GUI      (nmtui / nm-connection-editor)"
)

declare -A T_DE=(
    [SELECT]="Option auswählen: "
    [BACK]="Zurück"
    [EXIT]="Beenden"
    [PRESS_ENTER]="Weiter mit der Eingabetaste..."
    [INVALID]="Ungültige Option. Bitte erneut versuchen."
    [WARNING]="WARNUNG:"
    [CONFIRM_WORD]="JA"
    [CONFIRM_PROMPT]="Zum Fortfahren %s eingeben:"
    [CANCELLED]="Abgebrochen."
    [HOST_LABEL]="Host:"
    [USER_LABEL]="Benutzer:"
    [STDUSER_TAG]=" [Standardbenutzer - sudo je Aktion]"

    [MAIN_TITLE]="Hauptmenü"
    [MAIN_1]="Admin-Konsolen"
    [MAIN_2]="Systeminfo & Berichte"
    [MAIN_3]="Reparatur & Wartung"
    [MAIN_4]="Netzwerk-Tools"
    [MAIN_5]="Paketverwaltung"
    [MAIN_6]="Sicherheits-Tools"
    [MAIN_7]="Bereinigung"
    [MAIN_8]="Energie & Start"
    [MAIN_9]="Live-Systemmonitor"
    [MAIN_10]="Berichtsordner öffnen"
    [MAIN_11]="Nach Toolkit-Updates suchen"

    [SI_TITLE]="Systeminfo & Berichte"
    [SI_1]="Kurze Systemübersicht"
    [SI_2]="Vollständiger Systembericht  (als .txt gespeichert)"
    [SI_3]="Akku-Gesundheitsbericht      (Laptops)"
    [SI_4]="Liste installierter Pakete   (als .txt gespeichert)"
    [SI_5]="Festplattengesundheit (SMART)"
    [SI_6]="Kritische Fehler, letzte 24h"
    [SI_7]="Fehlgeschlagene systemd-Units"
    [SI_8]="Startzeitanalyse"
    [SI_9]="Festplattenverschlüsselung (LUKS)-Status"

    [RM_TITLE]="Reparatur & Wartung"
    [RM_VIRT_NOTE]="Hinweis: läuft in %s - Bootloader-/initramfs-/DKMS-Tools unten greifen vermutlich nicht."
    [RM_1]="Defekte Pakete reparieren    (dpkg --configure -a / fix-broken)"
    [RM_2]="Vollständiges Systemupdate"
    [RM_3]="initramfs / initrd neu erstellen"
    [RM_4]="Bootloader-Konfiguration (GRUB) aktualisieren"
    [RM_5]="Dateisystemprüfung beim nächsten Start planen"
    [RM_6]="SMART-Selbsttest der Festplatte"
    [RM_7]="Fehlgeschlagene systemd-Units zurücksetzen"
    [RM_8]="Einen bestimmten Dienst neu starten"
    [RM_9]="DKMS-Kernelmodule neu erstellen"
    [RM_10]="Systemschnappschuss / Wiederherstellungspunkt erstellen"
    [RM_11]="Wichtige Konfigurationsdateien sichern   (/etc, Crontabs, Paketliste)"
    [RM_12]="Konfigurationssicherung zur Prüfung entpacken"

    [NT_TITLE]="Netzwerk-Tools"
    [NT_1]="Ein-Klick-Diagnose          (Router / Internet / DNS)"
    [NT_2]="IP-Konfiguration"
    [NT_3]="Öffentliche IP"
    [NT_4]="DNS-Cache leeren"
    [NT_5]="IP freigeben und erneuern"
    [NT_6]="Ping"
    [NT_7]="Traceroute"
    [NT_8]="Gespeicherte WLAN-Netzwerke"
    [NT_9]="Aktive Verbindungen         (in Datei gespeichert)"
    [NT_10]="Vollständiger Netzwerk-Reset"
    [NT_11]="Gespeicherte WLAN-Passwörter anzeigen"
    [NT_12]="Internet-Geschwindigkeitstest"
    [NT_13]="IP-Adresse konfigurieren    (DHCP / statisch)"
    [NT_14]="Firewall-Status"

    [ST_TITLE]="Sicherheits-Tools"
    [ST_1]="Firewall aktivieren / deaktivieren"
    [ST_2]="Offene Ports & zugehörige Prozesse"
    [ST_3]="Nach ausstehenden Updates suchen"
    [ST_4]="SSH-Konfigurationsprüfung"
    [ST_5]="Fehlgeschlagene Anmeldeversuche"
    [ST_6]="Benutzer mit Superuser-Rechten (UID 0)"
    [ST_7]="Rootkit-Scan                (rkhunter / chkrootkit)"
    [ST_8]="Scan nach world-writable Dateien"
    [ST_9]="Fail2ban-Status & IP sperren/entsperren"
    [ST_10]="Lynis-Sicherheitsaudit      (Härtungsindex 0-100)"
    [ST_11]="Kernel-Härtung (sysctl)     (anzeigen / Basis anwenden)"
    [ST_12]="SELinux-/AppArmor-Status"

    [PM_TITLE]="Paketverwaltung"
    [PM_ON]="auf"
    [PM_1]="Nach Updates suchen"
    [PM_2]="Alles aktualisieren"
    [PM_3]="Paket-Cache leeren / Autoremove"
    [PM_4]="Ein Paket installieren"
    [PM_5]="Nach einem Paket suchen"
    [PM_6]="Ein Paket entfernen"
    [PM_7]="Explizit installierte Pakete auflisten (nicht Abhängigkeiten)"

    [CL_TITLE]="Bereinigung"
    [CL_1]="Temporäre Dateien bereinigen (/tmp + ~/.cache)"
    [CL_2]="Paket-Cache / Autoremove"
    [CL_3]="systemd-Journal bereinigen"
    [CL_4]="Papierkorb leeren"
    [CL_5]="Alte Kernel entfernen"
    [CL_6]="Docker-/Podman-Bereinigung"
    [CL_7]="Vorschaubilder-Cache leeren"
    [CL_8]="Speicherplatzbelegung analysieren (ncdu-ähnlicher Browser)"

    [PW_TITLE]="Energie & Start"
    [PW_VIRT_NOTE]="Hinweis: läuft in %s - Firmware-Setup und Rescue-Modus-Neustarts greifen vermutlich nicht."
    [PW_1]="Neustart ins Firmware-Setup (BIOS/UEFI)"
    [PW_2]="Start im Rescue-/Emergency-Modus"
    [PW_3]="Standard-Boot-Ziel festlegen        (GUI an/aus)"
    [PW_4]="Standby / Ruhezustand"
    [PW_5]="Neu starten"
    [PW_6]="Herunterfahren"

    [AC_TITLE]="Admin-Konsolen"
    [AC_1]="Root-Shell                   (sudo -i)"
    [AC_2]="Dienste-Manager (systemctl status, interaktiv)"
    [AC_3]="Live-Log-Anzeige             (journalctl -f)"
    [AC_4]="Benutzerverwaltung           (auflisten / hinzufügen / Passwort)"
    [AC_5]="Prozess-Manager              (htop/top)"
    [AC_6]="Datenträgerverwaltung        (lsblk / GNOME Disks falls vorhanden)"
    [AC_7]="Cron / geplante Aufgaben     (crontab -l, systemd-Timer)"
    [AC_8]="Paketverwaltungs-GUI         (falls installiert)"
    [AC_9]="Netzwerkmanager TUI/GUI      (nmtui / nm-connection-editor)"
)

# t <key> -- looks up KEY in the active language table, falling back to
# English, then to the raw key itself if somehow missing from both.
t() {
    local key="$1" val=""
    if [ "$LANG_CHOICE" = "DE" ]; then val="${T_DE[$key]:-}"; fi
    if [ -z "$val" ]; then val="${T_EN[$key]:-$key}"; fi
    printf '%s' "$val"
}

# select_language -- shown once at startup for the interactive menu path only
select_language() {
    while true; do
        clear_screen
        printf '%s\n' "${C_CYAN}══════════════════════════════════════════════════════════════════${C_RST}"
        printf '%s\n' "${C_WHT}${C_BOLD}                 LINUX TECHNICIAN TOOLKIT  PRO${C_RST}"
        printf '%s\n\n' "${C_CYAN}══════════════════════════════════════════════════════════════════${C_RST}"
        printf ' %s  Choose your language / Sprache wählen%s\n\n' "${C_YEL}" "${C_RST}"
        printf ' %s[1]%s  English\n' "${C_YEL}" "${C_RST}"
        printf ' %s[2]%s  Deutsch\n\n' "${C_YEL}" "${C_RST}"
        local choice=""
        read -r -p " Select / Auswahl: " choice || { clear_screen; exit 0; }
        case "$choice" in
            1) LANG_CHOICE="EN"; return ;;
            2) LANG_CHOICE="DE"; return ;;
            *) printf '%s\n' "${C_RED}Invalid option. / Ungültige Option.${C_RST}"; sleep 1 ;;
        esac
    done
}

# ============================================================
#  HELPERS
# ============================================================

log_action() {
    printf '[%s] %s\n' "$(date '+%Y-%m-%d %H:%M:%S')" "$1" >> "$LOG_FILE" 2>/dev/null
}

stamp() { date '+%Y-%m-%d_%H%M%S'; }

pause() {
    printf '\n%s' "${C_DIM}$(t PRESS_ENTER)${C_RST} "
    read -r _
}

invalid_choice() {
    printf '%s\n' "${C_RED}$(t INVALID)${C_RST}"
    sleep 1
}

# confirm "message" -> returns 0 if user typed the language's confirm word, 1 otherwise
confirm() {
    printf '\n%s\n' "${C_RED}$(t WARNING)${C_RST} $1"
    local word; word=$(t CONFIRM_WORD)
    local prompt; prompt=$(printf "$(t CONFIRM_PROMPT)" "$word")
    local ans=""
    read -r -p "$prompt " ans
    if [ "$ans" = "$word" ]; then
        return 0
    fi
    printf '%s\n' "${C_DIM}$(t CANCELLED)${C_RST}"
    sleep 1
    return 1
}

header() {
    clear_screen
    printf '%s\n' "${C_CYAN}══════════════════════════════════════════════════════════════════${C_RST}"
    printf '%s\n' "${C_WHT}${C_BOLD}                 LINUX TECHNICIAN TOOLKIT  PRO${C_RST}"
    printf '%s\n' "${C_DIM}                      powered by Bashar Salmo${C_RST}"
    printf '%s\n' "${C_CYAN}══════════════════════════════════════════════════════════════════${C_RST}"
    printf '%s' "${C_DIM}  $(t HOST_LABEL) $(get_hostname)   $(t USER_LABEL) $(whoami)"
    if [ "$IS_ROOT" -eq 1 ]; then
        printf '%s' "${C_GRN} [root]${C_DIM}"
    else
        printf '%s' "${C_YEL}$(t STDUSER_TAG)${C_DIM}"
    fi
    printf '   %s\n' "$(date '+%Y-%m-%d %H:%M')${C_RST}"
    printf '%s\n\n' "${C_YEL}  >> $1${C_RST}"
}

# run_priv <description-log> <command...>  -- runs with sudo if not root
run_priv() {
    local desc="$1"; shift
    # Call sites write the command as if typing it themselves, "sudo cmd ...";
    # normalize that here so we never double up on sudo, and root sessions
    # without a sudo binary installed still work.
    [ "${1:-}" = "sudo" ] && shift
    if [ "$IS_ROOT" -eq 1 ]; then
        "$@"
    else
        if ! command -v sudo >/dev/null 2>&1; then
            printf '%s\n' "${C_RED}This action needs root and 'sudo' isn't installed.${C_RST}"
            return 1
        fi
        sudo "$@"
    fi
    local rc=$?
    log_action "$desc (rc=$rc)"
    return $rc
}

need_cmd() {
    command -v "$1" >/dev/null 2>&1
}

# clear_screen -- works even on minimal images without ncurses' `clear` installed
clear_screen() {
    if need_cmd clear; then
        clear
    else
        printf '\033[H\033[2J\033[3J'
    fi
}

# get_hostname -- works even without the `hostname` binary installed
get_hostname() {
    if need_cmd hostname; then
        hostname
    elif [ -r /proc/sys/kernel/hostname ]; then
        cat /proc/sys/kernel/hostname
    elif need_cmd uname; then
        uname -n
    else
        printf '%s' "${HOSTNAME:-unknown}"
    fi
}

# detect_virt -- "none" on bare metal, else the virt/container type (kvm, docker, lxc, ...)
detect_virt() {
    if need_cmd systemd-detect-virt; then
        systemd-detect-virt 2>/dev/null
    elif [ -f /.dockerenv ]; then
        echo "docker"
    elif grep -qa 'container=lxc' /proc/1/environ 2>/dev/null; then
        echo "lxc"
    elif [ -r /proc/cpuinfo ] && grep -qi 'hypervisor' /proc/cpuinfo 2>/dev/null; then
        echo "vm"
    else
        echo "none"
    fi
}

# open_path <path> -- best-effort "open in file manager" across desktops
open_path() {
    if need_cmd xdg-open; then xdg-open "$1" >/dev/null 2>&1 &
    elif need_cmd nautilus; then nautilus "$1" >/dev/null 2>&1 &
    elif need_cmd dolphin; then dolphin "$1" >/dev/null 2>&1 &
    else printf '%s\n' "${C_DIM}(No graphical file manager found; path is: $1)${C_RST}"
    fi
}

# open_text <file> -- best-effort viewer for a saved report
open_text() {
    if [ -n "${VISUAL:-}" ]; then "$VISUAL" "$1"
    elif [ -n "${EDITOR:-}" ]; then "$EDITOR" "$1"
    elif need_cmd xdg-open && [ -n "${DISPLAY:-}${WAYLAND_DISPLAY:-}" ]; then xdg-open "$1" >/dev/null 2>&1 &
    # A pager reads its own navigation keystrokes from stdin, so only use one
    # when stdin is actually a terminal - otherwise it would hang (or, when
    # fed scripted input, silently eat keystrokes meant for our own menus).
    elif [ -t 0 ] && [ -n "${PAGER:-}" ] && need_cmd "$PAGER"; then "$PAGER" "$1"
    elif [ -t 0 ] && need_cmd less; then less "$1"
    elif [ -t 0 ] && need_cmd more; then more "$1"
    else cat "$1"
    fi
}

# ============================================================
#  DISTRO / PACKAGE MANAGER DETECTION
# ============================================================
detect_distro() {
    # Parsed field-by-field (not sourced) so os-release's own NAME/VERSION/ID
    # variables can never clobber this script's globals of the same name.
    if [ -r /etc/os-release ]; then
        DISTRO_NAME=$(awk -F= '/^PRETTY_NAME=/{gsub(/"/,"",$2); print $2; exit}' /etc/os-release)
        DISTRO_ID=$(awk -F= '/^ID=/{gsub(/"/,"",$2); print $2; exit}' /etc/os-release)
        DISTRO_NAME="${DISTRO_NAME:-Linux}"
        DISTRO_ID="${DISTRO_ID:-unknown}"
    fi
    if need_cmd apt-get; then PKG_MANAGER="apt"
    elif need_cmd dnf; then PKG_MANAGER="dnf"
    elif need_cmd yum; then PKG_MANAGER="yum"
    elif need_cmd pacman; then PKG_MANAGER="pacman"
    elif need_cmd zypper; then PKG_MANAGER="zypper"
    elif need_cmd apk; then PKG_MANAGER="apk"
    else PKG_MANAGER="none"
    fi
}

pkg_update_check() {
    case "$PKG_MANAGER" in
        apt) sudo apt-get update -qq && apt list --upgradable 2>/dev/null | tail -n +2 ;;
        dnf) dnf check-update ;;
        yum) yum check-update ;;
        pacman) checkupdates 2>/dev/null || run_priv "pacman -Sy" sudo pacman -Sy ;;
        zypper) zypper list-updates ;;
        apk) sudo apk update && apk version -l '<' ;;
        *) printf '%s\n' "No supported package manager detected." ;;
    esac
}

pkg_upgrade_all() {
    case "$PKG_MANAGER" in
        apt) run_priv "apt full-upgrade" sudo apt-get update && run_priv "apt full-upgrade" sudo apt-get full-upgrade -y ;;
        dnf) run_priv "dnf upgrade" sudo dnf upgrade -y ;;
        yum) run_priv "yum update" sudo yum update -y ;;
        pacman) run_priv "pacman -Syu" sudo pacman -Syu --noconfirm ;;
        zypper) run_priv "zypper update" sudo zypper update -y ;;
        apk) run_priv "apk upgrade" sudo apk update && sudo apk upgrade ;;
        *) printf '%s\n' "No supported package manager detected." ;;
    esac
}

pkg_clean_cache() {
    case "$PKG_MANAGER" in
        apt) run_priv "apt clean" sudo apt-get clean && run_priv "apt autoremove" sudo apt-get autoremove -y ;;
        dnf) run_priv "dnf clean" sudo dnf clean all && run_priv "dnf autoremove" sudo dnf autoremove -y ;;
        yum) run_priv "yum clean" sudo yum clean all ;;
        pacman) run_priv "pacman -Sc" sudo pacman -Sc --noconfirm ;;
        zypper) run_priv "zypper clean" sudo zypper clean --all ;;
        apk) run_priv "apk cache clean" sudo apk cache clean ;;
        *) printf '%s\n' "No supported package manager detected." ;;
    esac
}

pkg_install() {
    local pkg="$1"
    case "$PKG_MANAGER" in
        apt) run_priv "install $pkg" sudo apt-get install -y "$pkg" ;;
        dnf) run_priv "install $pkg" sudo dnf install -y "$pkg" ;;
        yum) run_priv "install $pkg" sudo yum install -y "$pkg" ;;
        pacman) run_priv "install $pkg" sudo pacman -S --noconfirm "$pkg" ;;
        zypper) run_priv "install $pkg" sudo zypper install -y "$pkg" ;;
        apk) run_priv "install $pkg" sudo apk add "$pkg" ;;
        *) return 1 ;;
    esac
}

# offer_install <binary-name> <pkg-name-hint> -- ask user to install a missing optional tool
offer_install() {
    local bin="$1" pkg="${2:-$1}"
    if need_cmd "$bin"; then return 0; fi
    printf '%s\n' "${C_YEL}'$bin' isn't installed.${C_RST}"
    if [ "$PKG_MANAGER" = "none" ]; then
        printf '%s\n' "${C_DIM}No supported package manager detected; install it manually.${C_RST}"
        return 1
    fi
    local ans=""
    read -r -p "Install '$pkg' now via $PKG_MANAGER? [y/N] " ans
    if [[ "$ans" =~ ^[Yy]$ ]]; then
        pkg_install "$pkg"
        need_cmd "$bin"
        return $?
    fi
    return 1
}

# ============================================================
#  LIVE SYSTEM MONITOR
# ============================================================
# Prefers a real TUI (btop > htop) if installed; otherwise falls back to
# a lightweight built-in dashboard sourced straight from /proc, so the
# monitor always works with zero dependencies.

_mon_bar() {
    # _mon_bar <percent 0-100> <width> -> colored bar string
    local pct="$1" width="${2:-30}"
    [ "$pct" -lt 0 ] 2>/dev/null && pct=0
    [ "$pct" -gt 100 ] 2>/dev/null && pct=100
    local filled=$(( pct * width / 100 ))
    local empty=$(( width - filled ))
    local color="$C_GRN"
    [ "$pct" -ge 60 ] && color="$C_YEL"
    [ "$pct" -ge 85 ] && color="$C_RED"
    local bar=""
    local i
    for ((i=0; i<filled; i++)); do bar+="#"; done
    for ((i=0; i<empty; i++)); do bar+="-"; done
    printf '%s[%s]%s %3d%%' "$color" "$bar" "$C_RST" "$pct"
}

_mon_cpu_snapshot() {
    # reads /proc/stat total+idle for delta calc; prints "total idle"
    read -r _ u n s idl io irq sirq steal _ < /proc/stat
    local idle_all=$(( idl + io ))
    local total=$(( u + n + s + idle_all + irq + sirq + steal ))
    printf '%s %s' "$total" "$idle_all"
}

builtin_monitor() {
    local prev_total=0 prev_idle=0
    read -r prev_total prev_idle < <(_mon_cpu_snapshot)
    local prev_rx=0 prev_tx=0
    local dev
    dev=$(ip route get 1.1.1.1 2>/dev/null | awk '{for(i=1;i<=NF;i++) if($i=="dev"){print $(i+1); exit}}')
    if [ -n "$dev" ] && [ -r "/sys/class/net/$dev/statistics/rx_bytes" ]; then
        prev_rx=$(cat "/sys/class/net/$dev/statistics/rx_bytes" 2>/dev/null || echo 0)
        prev_tx=$(cat "/sys/class/net/$dev/statistics/tx_bytes" 2>/dev/null || echo 0)
    fi
    tput civis 2>/dev/null
    trap 'tput cnorm 2>/dev/null' RETURN
    while true; do
        local cols; cols=$(tput cols 2>/dev/null || echo 80)
        local barwidth=$(( cols > 60 ? 40 : cols - 20 ))
        [ "$barwidth" -lt 10 ] && barwidth=10

        local total idle
        read -r total idle < <(_mon_cpu_snapshot)
        local dtotal=$(( total - prev_total ))
        local didle=$(( idle - prev_idle ))
        local cpu_pct=0
        [ "$dtotal" -gt 0 ] && cpu_pct=$(( (100 * (dtotal - didle)) / dtotal ))
        prev_total=$total; prev_idle=$idle

        local mem_total mem_avail mem_pct
        mem_total=$(awk '/^MemTotal:/{print $2}' /proc/meminfo)
        mem_avail=$(awk '/^MemAvailable:/{print $2}' /proc/meminfo)
        mem_pct=0
        [ "${mem_total:-0}" -gt 0 ] && mem_pct=$(( 100 * (mem_total - mem_avail) / mem_total ))

        local rx=0 tx=0 rx_rate=0 tx_rate=0
        if [ -n "$dev" ] && [ -r "/sys/class/net/$dev/statistics/rx_bytes" ]; then
            rx=$(cat "/sys/class/net/$dev/statistics/rx_bytes" 2>/dev/null || echo 0)
            tx=$(cat "/sys/class/net/$dev/statistics/tx_bytes" 2>/dev/null || echo 0)
            rx_rate=$(( (rx - prev_rx) * 8 / 1000000 ))
            tx_rate=$(( (tx - prev_tx) * 8 / 1000000 ))
            [ "$rx_rate" -lt 0 ] && rx_rate=0
            [ "$tx_rate" -lt 0 ] && tx_rate=0
            prev_rx=$rx; prev_tx=$tx
        fi

        clear_screen
        printf '%s\n' "${C_CYAN}══ LIVE SYSTEM MONITOR (built-in) ═══════════════════════ q + Enter to quit ══${C_RST}"
        printf ' %-10s %s\n' "CPU" "$(_mon_bar "$cpu_pct" "$barwidth")"
        printf ' %-10s %s   (%s / %s MB)\n' "RAM" "$(_mon_bar "$mem_pct" "$barwidth")" "$(( (mem_total-mem_avail)/1024 ))" "$(( mem_total/1024 ))"
        echo
        printf ' %-10s' "Disks"
        echo
        while read -r fs size used avail pctnum mnt; do
            [ "$fs" = "Filesystem" ] && continue
            local dpct="${pctnum%\%}"
            [[ "$dpct" =~ ^[0-9]+$ ]] || continue
            printf '   %-20s %s   %s used of %s\n' "$mnt" "$(_mon_bar "$dpct" $((barwidth-10)))" "$used" "$size"
        done < <(df -hT -x tmpfs -x devtmpfs -x squashfs -x overlay 2>/dev/null | awk 'NR>1{print $1,$3,$4,$5,$6,$7}')
        echo
        if [ -n "$dev" ]; then
            printf ' %-10s down %6d Mbps   up %6d Mbps   (%s)\n' "Net" "$rx_rate" "$tx_rate" "$dev"
            local ipaddr gw
            ipaddr=$(ip -4 addr show "$dev" 2>/dev/null | awk '/inet /{print $2; exit}')
            gw=$(ip route show default 2>/dev/null | awk '/default/{print $3; exit}')
            printf ' %-10s %s   gw %s\n' "" "${ipaddr:-n/a}" "${gw:-n/a}"
        else
            printf ' %-10s no default route detected\n' "Net"
        fi
        echo
        printf ' %-10s\n' "Top CPU processes"
        printf '   %-8s %-20s %6s %8s\n' "PID" "NAME" "CPU%" "MEM"
        ps -eo pid,comm,%cpu,%mem --sort=-%cpu 2>/dev/null | awk 'NR>1 && NR<=6{printf "   %-8s %-20.20s %5.1f%% %6.1f%%\n",$1,$2,$3,$4}'
        echo
        printf '%s\n' "${C_DIM}Updates ~1/sec. Type q + Enter at any time to return to the menu.${C_RST}"

        read -r -t 1 -n 1 key 2>/dev/null
        if [ "${key:-}" = "q" ]; then
            read -r -t 0.2 -n 200 _ 2>/dev/null
            break
        fi
    done
    tput cnorm 2>/dev/null
}

run_live_monitor() {
    header "Live System Monitor"
    if need_cmd btop; then
        printf '%s\n' "${C_DIM}Launching btop (press q to return)...${C_RST}"; sleep 1
        btop
    elif need_cmd htop; then
        printf '%s\n' "${C_DIM}Launching htop (press q to return)...${C_RST}"; sleep 1
        htop
    else
        printf '%s\n' "${C_DIM}Tip: install 'htop' or 'btop' for a richer live view. Using the built-in monitor for now.${C_RST}"
        sleep 1
        builtin_monitor
    fi
}

# ============================================================
#  SYSTEM INFO & REPORTS
# ============================================================

# print_quick_summary -- the data-only core, reusable from the interactive
# menu and from the --quick-summary CLI flag (no header/pause of its own).
print_quick_summary() {
    local kernel os cpu_model cpu_cores mem_total mem_avail uptime_s gpu
    kernel=$(uname -r)
    os="$DISTRO_NAME"
    cpu_model=$(lscpu 2>/dev/null | awk -F': ' '/^Model name/{print $2; exit}')
    cpu_model=$(printf '%s' "$cpu_model" | sed 's/^ *//;s/ *$//')
    # Some virtualized ARM hosts report lscpu's Model name as a bare "-"
    [ "$cpu_model" = "-" ] && cpu_model=""
    [ -z "$cpu_model" ] && cpu_model=$(awk -F': ' '/model name/{print $2; exit}' /proc/cpuinfo)
    [ -z "$cpu_model" ] && cpu_model=$(awk -F': ' '/^Hardware/{print $2; exit}' /proc/cpuinfo)
    cpu_model=$(printf '%s' "$cpu_model" | sed 's/^ *//')
    [ -z "$cpu_model" ] && cpu_model="unknown"
    cpu_cores=$(nproc 2>/dev/null || grep -c ^processor /proc/cpuinfo)
    mem_total=$(awk '/^MemTotal:/{printf "%.1f", $2/1024/1024}' /proc/meminfo)
    mem_avail=$(awk '/^MemAvailable:/{printf "%.1f", $2/1024/1024}' /proc/meminfo)
    uptime_s=$(awk '{print int($1)}' /proc/uptime)
    gpu=$(lspci 2>/dev/null | grep -Ei 'vga|3d|display' | sed 's/^[0-9a-f:.]* //')

    printf ' %-10s: %s\n' "OS" "$os"
    printf ' %-10s: %s\n' "Kernel" "$kernel"
    printf ' %-10s: %s (%s cores)\n' "CPU" "${cpu_model:-unknown}" "$cpu_cores"
    printf ' %-10s: %.1f GB total, %.1f GB available\n' "RAM" "$mem_total" "$mem_avail"
    printf ' %-10s: %dd %dh %dm\n' "Uptime" $((uptime_s/86400)) $((uptime_s%86400/3600)) $((uptime_s%3600/60))
    df -h -x tmpfs -x devtmpfs -x squashfs -x overlay 2>/dev/null | awk 'NR==1{next} {printf " Drive %-15s: %s free of %s (%s used)\n",$6,$4,$2,$5}'
    if [ -n "$gpu" ]; then
        while IFS= read -r line; do printf ' %-10s: %s\n' "GPU" "$line"; done <<< "$gpu"
    fi
    if command -v hostnamectl >/dev/null 2>&1; then
        local chassis
        chassis=$(hostnamectl 2>/dev/null | awk -F': ' '/Chassis/{print $2}')
        [ -n "$chassis" ] && printf ' %-10s: %s\n' "Chassis" "$chassis"
    fi
    local virt; virt=$(detect_virt)
    if [ "$virt" != "none" ] && [ -n "$virt" ]; then
        printf ' %-10s: %s%s%s\n' "Virt" "$C_YEL" "$virt" "$C_RST"
    fi
    printf ' %-10s: %s\n' "LSM" "$(lsm_status_line)"
}

info_quick() {
    header "Quick System Summary"
    print_quick_summary
    pause
}

info_full_report() {
    stamp_v=$(stamp)
    local f="${REPORT_DIR}/SystemReport_${stamp_v}.txt"
    header "Building Full System Report..."
    {
        echo "===== HOSTNAMECTL ====="; hostnamectl 2>/dev/null
        echo; echo "===== UNAME ====="; uname -a
        echo; echo "===== OS-RELEASE ====="; cat /etc/os-release 2>/dev/null
        echo; echo "===== CPU ====="; lscpu 2>/dev/null || cat /proc/cpuinfo
        echo; echo "===== MEMORY ====="; free -h
        echo; echo "===== DISKS (lsblk) ====="; lsblk -f 2>/dev/null
        echo; echo "===== DISK USAGE (df) ====="; df -hT
        echo; echo "===== PCI DEVICES ====="; lspci 2>/dev/null
        echo; echo "===== USB DEVICES ====="; lsusb 2>/dev/null
        echo; echo "===== NETWORK (ip a) ====="; ip a
        echo; echo "===== FAILED SYSTEMD UNITS ====="; systemctl --failed --no-pager 2>/dev/null
        echo; echo "===== UPTIME/LOAD ====="; uptime
    } > "$f" 2>&1
    log_action "Saved $f"
    printf '%s\n' "${C_GRN}Saved to $f${C_RST}"
    open_text "$f"
    pause
}

info_battery() {
    header "Battery Report"
    local found=0
    for bat in /sys/class/power_supply/BAT*; do
        [ -d "$bat" ] || continue
        found=1
        local name capacity status health energy_full energy_full_design
        name=$(basename "$bat")
        capacity=$(cat "$bat/capacity" 2>/dev/null || echo "?")
        status=$(cat "$bat/status" 2>/dev/null || echo "?")
        energy_full=$(cat "$bat/energy_full" 2>/dev/null || cat "$bat/charge_full" 2>/dev/null)
        energy_full_design=$(cat "$bat/energy_full_design" 2>/dev/null || cat "$bat/charge_full_design" 2>/dev/null)
        printf ' %-12s: %s\n' "Battery" "$name"
        printf ' %-12s: %s%%\n' "Charge" "$capacity"
        printf ' %-12s: %s\n' "Status" "$status"
        if [ -n "${energy_full:-}" ] && [ -n "${energy_full_design:-}" ] && [ "$energy_full_design" -gt 0 ]; then
            health=$(( 100 * energy_full / energy_full_design ))
            printf ' %-12s: %s%% of design capacity\n' "Health" "$health"
        fi
        echo
    done
    if [ "$found" -eq 0 ]; then
        printf '%s\n' "${C_YEL}No battery detected - this looks like a desktop/server.${C_RST}"
    fi
    if command -v upower >/dev/null 2>&1 && [ "$found" -eq 1 ]; then
        upower -i "$(upower -e | grep BAT | head -1)" 2>/dev/null
    fi
    pause
}

info_installed_packages() {
    local f="${REPORT_DIR}/InstalledPackages_$(stamp).txt"
    header "Collecting Installed Packages..."
    case "$PKG_MANAGER" in
        apt) dpkg-query -W -f='${Package}\t${Version}\t${Status}\n' > "$f" 2>&1 ;;
        dnf|yum) rpm -qa --qf '%{NAME}\t%{VERSION}-%{RELEASE}\n' | sort > "$f" 2>&1 ;;
        pacman) pacman -Q > "$f" 2>&1 ;;
        zypper) rpm -qa | sort > "$f" 2>&1 ;;
        apk) apk info -v > "$f" 2>&1 ;;
        *) printf 'No supported package manager.\n' > "$f" ;;
    esac
    log_action "Saved $f"
    printf '%s\n' "${C_GRN}Saved to $f ($(wc -l < "$f" 2>/dev/null) packages)${C_RST}"
    open_text "$f"
    pause
}

info_disk_health() {
    header "Disk Health"
    lsblk -o NAME,SIZE,TYPE,MOUNTPOINT,FSTYPE 2>/dev/null
    echo
    if ! need_cmd smartctl; then
        printf '%s\n' "${C_YEL}'smartctl' (smartmontools) isn't installed - can't show SMART health.${C_RST}"
        offer_install smartctl smartmontools
    fi
    if need_cmd smartctl; then
        local disk
        for disk in $(lsblk -dno NAME -e 7,11 2>/dev/null); do
            printf '\n%s\n' "${C_CYAN}--- /dev/$disk ---${C_RST}"
            run_priv "smartctl -H /dev/$disk" sudo smartctl -H "/dev/$disk" 2>/dev/null | grep -Ei 'SMART overall|result|passed|failed'
        done
    fi
    pause
}

info_recent_errors() {
    header "Critical Errors - Last 24 Hours"
    if need_cmd journalctl; then
        journalctl -p 3 --since "-1 day" --no-pager 2>/dev/null | tail -60
        local count
        count=$(journalctl -p 3 --since "-1 day" --no-pager 2>/dev/null | wc -l)
        [ "$count" -eq 0 ] && printf '%s\n' "${C_GRN}No critical errors found in the last 24 hours.${C_RST}"
    else
        printf '%s\n' "${C_YEL}journalctl not available on this system (no systemd journal).${C_RST}"
        printf '%s\n' "Checking /var/log/syslog or /var/log/messages instead:"
        grep -Ei 'error|critical|fail' /var/log/syslog 2>/dev/null | tail -30 || \
        grep -Ei 'error|critical|fail' /var/log/messages 2>/dev/null | tail -30 || \
        printf '%s\n' "No standard log file found either."
    fi
    pause
}

info_failed_services() {
    header "Failed systemd Units"
    if need_cmd systemctl; then
        systemctl --failed --no-pager
    else
        printf '%s\n' "${C_YEL}systemd not available on this system.${C_RST}"
    fi
    pause
}

info_boot_time() {
    header "Boot Time Analysis"
    if need_cmd systemd-analyze; then
        systemd-analyze
        echo
        systemd-analyze blame 2>/dev/null | head -15
    else
        printf '%s\n' "${C_YEL}systemd-analyze not available (non-systemd init).${C_RST}"
    fi
    pause
}

info_encryption_status() {
    header "Disk Encryption (LUKS) Status"
    local found=0
    while read -r name fstype; do
        [ "$fstype" = "crypto_LUKS" ] || continue
        found=1
        printf ' %-20s %s\n' "/dev/$name" "${C_GRN}LUKS encrypted${C_RST}"
    done < <(lsblk -rno NAME,FSTYPE 2>/dev/null)
    if [ "$found" -eq 0 ]; then
        printf '%s\n' "${C_YEL}No LUKS-encrypted block devices found.${C_RST}"
    fi
    if need_cmd cryptsetup; then
        echo
        printf '%s\n' "${C_CYAN}Active mappings (cryptsetup status):${C_RST}"
        local mapper
        for mapper in /dev/mapper/*; do
            [ -e "$mapper" ] || continue
            [ "$(basename "$mapper")" = "control" ] && continue
            run_priv "cryptsetup status" cryptsetup status "$(basename "$mapper")" 2>/dev/null | head -3
        done
    fi
    echo
    printf '%s\n' "${C_DIM}Root filesystem: $(findmnt -no FSTYPE / 2>/dev/null), source $(findmnt -no SOURCE / 2>/dev/null)${C_RST}"
    pause
}

sysinfo_menu() {
    while true; do
        header "$(t SI_TITLE)"
        cat <<EOF
 ${C_YEL}[1]${C_RST}  $(t SI_1)
 ${C_YEL}[2]${C_RST}  $(t SI_2)
 ${C_YEL}[3]${C_RST}  $(t SI_3)
 ${C_YEL}[4]${C_RST}  $(t SI_4)
 ${C_YEL}[5]${C_RST}  $(t SI_5)
 ${C_YEL}[6]${C_RST}  $(t SI_6)
 ${C_YEL}[7]${C_RST}  $(t SI_7)
 ${C_YEL}[8]${C_RST}  $(t SI_8)
 ${C_YEL}[9]${C_RST}  $(t SI_9)

 ${C_RED}[0]${C_RST}  $(t BACK)
EOF
        local opt=""
        read -r -p " $(t SELECT)" opt || { clear_screen; log_action "Input closed - exiting"; exit 0; }
        case "$opt" in
            1) info_quick ;;
            2) info_full_report ;;
            3) info_battery ;;
            4) info_installed_packages ;;
            5) info_disk_health ;;
            6) info_recent_errors ;;
            7) info_failed_services ;;
            8) info_boot_time ;;
            9) info_encryption_status ;;
            0) return ;;
            *) invalid_choice ;;
        esac
    done
}

# ============================================================
#  REPAIR & MAINTENANCE
# ============================================================

repair_fix_broken() {
    header "Fix Broken Packages"
    case "$PKG_MANAGER" in
        apt) run_priv "dpkg --configure -a" sudo dpkg --configure -a
             run_priv "apt --fix-broken install" sudo apt-get --fix-broken install -y ;;
        dnf) run_priv "dnf check" sudo dnf check ;;
        pacman) run_priv "pacman -Dk" sudo pacman -Dk ;;
        *) printf '%s\n' "${C_DIM}No specific fix routine for $PKG_MANAGER; try re-running a full upgrade.${C_RST}" ;;
    esac
    pause
}

repair_update_all() {
    header "Full System Update ($PKG_MANAGER)"
    confirm "This will update and upgrade all installed packages." || { pause; return; }
    pkg_upgrade_all
    log_action "Full system update via $PKG_MANAGER"
    pause
}

repair_rebuild_initramfs() {
    header "Rebuild initramfs / initrd"
    confirm "Rebuild the initial RAM filesystem for the current kernel?" || { pause; return; }
    if need_cmd update-initramfs; then
        run_priv "update-initramfs -u" sudo update-initramfs -u -k all
    elif need_cmd dracut; then
        run_priv "dracut --force" sudo dracut --force
    elif need_cmd mkinitcpio; then
        run_priv "mkinitcpio -P" sudo mkinitcpio -P
    else
        printf '%s\n' "${C_YEL}No known initramfs tool found (update-initramfs/dracut/mkinitcpio).${C_RST}"
    fi
    pause
}

repair_update_grub() {
    header "Update Bootloader Configuration"
    confirm "Regenerate the GRUB configuration?" || { pause; return; }
    if need_cmd update-grub; then
        run_priv "update-grub" sudo update-grub
    elif need_cmd grub2-mkconfig; then
        local out="/boot/grub2/grub.cfg"
        [ -d /boot/efi/EFI ] && out=$(find /boot/efi/EFI -maxdepth 1 -mindepth 1 -type d 2>/dev/null | head -1)/grub.cfg
        run_priv "grub2-mkconfig" sudo grub2-mkconfig -o "$out"
    elif need_cmd grub-mkconfig; then
        run_priv "grub-mkconfig" sudo grub-mkconfig -o /boot/grub/grub.cfg
    else
        printf '%s\n' "${C_YEL}No GRUB tooling found - this system may use systemd-boot or another bootloader.${C_RST}"
    fi
    pause
}

repair_fsck_next_boot() {
    header "Schedule Filesystem Check on Next Boot"
    confirm "Force fsck on the root filesystem at the next reboot?" || { pause; return; }
    if [ -d /run/systemd/system ]; then
        run_priv "fsck.mode=force" sudo touch /forcefsck
        printf '%s\n' "${C_GRN}/forcefsck created. Some systemd systems instead use: sudo shutdown -r now (with fsck.mode=force on the kernel cmdline).${C_RST}"
    else
        run_priv "touch /forcefsck" sudo touch /forcefsck
    fi
    log_action "Scheduled fsck for next boot"
    pause
}

repair_smart_test() {
    header "Disk SMART Self-Test"
    if ! need_cmd smartctl; then
        offer_install smartctl smartmontools || { pause; return; }
    fi
    lsblk -dno NAME -e 7,11
    local disk=""
    read -r -p "Device to test (e.g. sda, without /dev/): " disk
    [ -z "$disk" ] && return
    echo " [1] Short test (a few minutes)   [2] Long test (can take hours)"
    local t=""; read -r -p "Select test type: " t
    case "$t" in
        1) run_priv "smartctl short test" sudo smartctl -t short "/dev/$disk" ;;
        2) run_priv "smartctl long test" sudo smartctl -t long "/dev/$disk" ;;
        *) invalid_choice; pause; return ;;
    esac
    printf '%s\n' "${C_DIM}Test started in the background on the drive. Check results later with: sudo smartctl -a /dev/$disk${C_RST}"
    pause
}

repair_reset_failed_units() {
    header "Reset Failed systemd Units"
    if need_cmd systemctl; then
        run_priv "systemctl reset-failed" sudo systemctl reset-failed
        printf '%s\n' "${C_GRN}Done.${C_RST}"
    else
        printf '%s\n' "${C_YEL}systemd not available.${C_RST}"
    fi
    pause
}

repair_restart_service() {
    header "Restart a systemd Service"
    if ! need_cmd systemctl; then printf '%s\n' "${C_YEL}systemd not available.${C_RST}"; pause; return; fi
    local svc=""
    read -r -p "Service name (e.g. NetworkManager, sshd, cups): " svc
    [ -z "$svc" ] && return
    run_priv "restart $svc" sudo systemctl restart "$svc"
    systemctl is-active "$svc" 2>/dev/null | while read -r st; do
        [ "$st" = "active" ] && printf '%s\n' "${C_GRN}$svc is active.${C_RST}" || printf '%s\n' "${C_RED}$svc is $st.${C_RST}"
    done
    pause
}

repair_dkms_rebuild() {
    header "Rebuild DKMS Kernel Modules"
    if ! need_cmd dkms; then
        printf '%s\n' "${C_YEL}dkms isn't installed (used for out-of-tree drivers like NVIDIA/VirtualBox).${C_RST}"
        pause; return
    fi
    dkms status
    confirm "Rebuild and reinstall all DKMS modules for the current kernel?" || { pause; return; }
    run_priv "dkms autoinstall" sudo dkms autoinstall -k "$(uname -r)"
    pause
}

repair_create_snapshot() {
    header "Create System Snapshot / Restore Point"
    if need_cmd timeshift; then
        run_priv "timeshift --create" sudo timeshift --create --comments "TechToolkit manual snapshot" --tags D
    elif need_cmd snapper; then
        run_priv "snapper create" sudo snapper create --description "TechToolkit manual snapshot"
    else
        printf '%s\n' "${C_YEL}No snapshot tool found (timeshift/snapper). On Btrfs/LVM you may be able to snapshot manually.${C_RST}"
        offer_install timeshift timeshift
    fi
    pause
}

repair_backup_config() {
    header "Backup Key Config Files"
    local f="${REPORT_DIR}/ConfigBackup_$(stamp).tar.gz"
    printf '%s\n' "${C_DIM}Archiving /etc, crontabs, and the installed-package list. This is a lightweight config snapshot, not a full system backup - use Create System Snapshot for that.${C_RST}"
    printf '%s\n' "${C_YEL}Secrets are deliberately left out: /etc/shadow, /etc/gshadow, SSH host private keys, and any *.key/*.pem files.${C_RST}"
    local work; work=$(mktemp -d)
    mkdir -p "$work/crontabs"
    local u
    for u in root $(awk -F: '$3>=1000{print $1}' /etc/passwd); do
        run_priv "crontab -l $u" crontab -l -u "$u" 2>/dev/null > "$work/crontabs/$u.cron"
        [ -s "$work/crontabs/$u.cron" ] || rm -f "$work/crontabs/$u.cron"
    done
    case "$PKG_MANAGER" in
        apt) dpkg-query -W -f='${Package}\t${Version}\n' > "$work/packages.txt" 2>&1 ;;
        dnf|yum) rpm -qa --qf '%{NAME}\t%{VERSION}-%{RELEASE}\n' | sort > "$work/packages.txt" 2>&1 ;;
        pacman) pacman -Q > "$work/packages.txt" 2>&1 ;;
        zypper) rpm -qa | sort > "$work/packages.txt" 2>&1 ;;
        apk) apk info -v > "$work/packages.txt" 2>&1 ;;
    esac
    # Archive /etc directly (no intermediate copy - avoids ever leaving a root-owned
    # duplicate of /etc, including its secrets, sitting around in /tmp) with GNU tar's
    # basename-only exclude matching (a pattern with no '/' matches any file with that
    # basename, anywhere in the tree) to leave out credential material.
    run_priv "tar config backup" tar -czf "$f" \
        --exclude='shadow' --exclude='shadow-' --exclude='gshadow' --exclude='gshadow-' \
        --exclude='ssh_host_*_key' --exclude='*.key' --exclude='*.pem' \
        /etc -C "$work" crontabs packages.txt 2>/dev/null
    run_priv "chown backup" chown "$(id -u):$(id -g)" "$f" 2>/dev/null
    run_priv "chmod backup" chmod 600 "$f" 2>/dev/null
    rm -rf "$work"
    if [ -s "$f" ]; then
        printf '%s\n' "${C_GRN}Saved to $f (permissions 600)${C_RST}"
        log_action "Config backup saved to $f"
    else
        printf '%s\n' "${C_RED}Backup failed - check permissions.${C_RST}"
    fi
    pause
}

repair_restore_config_browse() {
    header "Extract a Config Backup for Review"
    printf '%s\n' "${C_DIM}This never overwrites live files - it extracts a backup into a folder so you can diff/copy what you need by hand.${C_RST}"
    ls -1t "${REPORT_DIR}"/ConfigBackup_*.tar.gz 2>/dev/null | nl -w2 -s') '
    local pick=""
    read -r -p "Number to extract (blank to cancel): " pick
    [ -z "$pick" ] && return
    local file
    file=$(ls -1t "${REPORT_DIR}"/ConfigBackup_*.tar.gz 2>/dev/null | sed -n "${pick}p")
    if [ -z "$file" ] || [ ! -f "$file" ]; then
        printf '%s\n' "${C_RED}Not a valid selection.${C_RST}"
        pause; return
    fi
    local dest="${REPORT_DIR}/ConfigBackup_extracted_$(stamp)"
    mkdir -p "$dest"
    tar -xzf "$file" -C "$dest"
    printf '%s\n' "${C_GRN}Extracted to $dest${C_RST}"
    open_path "$dest"
    pause
}

repair_menu() {
    local virt; virt=$(detect_virt)
    while true; do
        header "$(t RM_TITLE)"
        [ "$virt" != "none" ] && printf "${C_DIM}$(t RM_VIRT_NOTE)${C_RST}\\n\\n" "$virt"
        cat <<EOF
 ${C_YEL}[1]${C_RST}  $(t RM_1)
 ${C_YEL}[2]${C_RST}  $(t RM_2)           ${C_DIM}($PKG_MANAGER)${C_RST}
 ${C_YEL}[3]${C_RST}  $(t RM_3)
 ${C_YEL}[4]${C_RST}  $(t RM_4)
 ${C_YEL}[5]${C_RST}  $(t RM_5)
 ${C_YEL}[6]${C_RST}  $(t RM_6)
 ${C_YEL}[7]${C_RST}  $(t RM_7)
 ${C_YEL}[8]${C_RST}  $(t RM_8)
 ${C_YEL}[9]${C_RST}  $(t RM_9)
 ${C_YEL}[10]${C_RST} $(t RM_10)
 ${C_YEL}[11]${C_RST} $(t RM_11)
 ${C_YEL}[12]${C_RST} $(t RM_12)

 ${C_RED}[0]${C_RST}  $(t BACK)
EOF
        local opt=""
        read -r -p " $(t SELECT)" opt || { clear_screen; log_action "Input closed - exiting"; exit 0; }
        case "$opt" in
            1) repair_fix_broken ;;
            2) repair_update_all ;;
            3) repair_rebuild_initramfs ;;
            4) repair_update_grub ;;
            5) repair_fsck_next_boot ;;
            6) repair_smart_test ;;
            7) repair_reset_failed_units ;;
            8) repair_restart_service ;;
            9) repair_dkms_rebuild ;;
            10) repair_create_snapshot ;;
            11) repair_backup_config ;;
            12) repair_restore_config_browse ;;
            0) return ;;
            *) invalid_choice ;;
        esac
    done
}

# ============================================================
#  NETWORK TOOLS
# ============================================================

_default_iface() {
    ip route get 1.1.1.1 2>/dev/null | awk '{for(i=1;i<=NF;i++) if($i=="dev"){print $(i+1); exit}}'
}

net_diag() {
    header "One-Click Network Diagnosis"
    local gw
    gw=$(ip route show default 2>/dev/null | awk '/default/{print $3; exit}')
    if [ -n "$gw" ]; then
        if ping -c2 -W2 "$gw" >/dev/null 2>&1; then
            printf ' %s[ OK ]%s Router reachable at %s\n' "$C_GRN" "$C_RST" "$gw"
        else
            printf ' %s[FAIL]%s Router NOT reachable at %s\n' "$C_RED" "$C_RST" "$gw"
        fi
    else
        printf ' %s[FAIL]%s No default gateway found\n' "$C_RED" "$C_RST"
    fi
    if ping -c2 -W2 1.1.1.1 >/dev/null 2>&1; then
        printf ' %s[ OK ]%s Internet reachable\n' "$C_GRN" "$C_RST"
    else
        printf ' %s[FAIL]%s Internet NOT reachable\n' "$C_RED" "$C_RST"
    fi
    if getent hosts www.google.com >/dev/null 2>&1 || nslookup www.google.com >/dev/null 2>&1; then
        printf ' %s[ OK ]%s DNS resolution works\n' "$C_GRN" "$C_RST"
    else
        printf ' %s[FAIL]%s DNS resolution failed\n' "$C_RED" "$C_RST"
    fi
    pause
}

net_ipconfig() {
    header "IP Configuration"
    ip -4 addr show
    echo
    ip route show
    pause
}

net_public_ip() {
    header "Public IP"
    local ip=""
    ip=$(curl -s --max-time 8 https://api.ipify.org 2>/dev/null || curl -s --max-time 8 https://ifconfig.me 2>/dev/null)
    if [ -n "$ip" ]; then
        printf '%s\n' "${C_GRN}Public IP: $ip${C_RST}"
    else
        printf '%s\n' "${C_RED}Could not reach the internet (or curl isn't installed).${C_RST}"
    fi
    pause
}

net_flush_dns() {
    header "Flush DNS Cache"
    if need_cmd resolvectl; then
        run_priv "resolvectl flush-caches" sudo resolvectl flush-caches && printf '%s\n' "${C_GRN}Done (systemd-resolved).${C_RST}"
    elif need_cmd systemd-resolve; then
        run_priv "systemd-resolve --flush-caches" sudo systemd-resolve --flush-caches && printf '%s\n' "${C_GRN}Done.${C_RST}"
    elif need_cmd nscd; then
        run_priv "restart nscd" sudo systemctl restart nscd && printf '%s\n' "${C_GRN}Done (nscd restarted).${C_RST}"
    else
        printf '%s\n' "${C_YEL}No known DNS cache service found (systemd-resolved/nscd). Nothing to flush.${C_RST}"
    fi
    pause
}

net_renew_dhcp() {
    header "Release and Renew IP Address"
    confirm "Release and renew the DHCP lease? This will briefly drop your connection." || { pause; return; }
    local dev; dev=$(_default_iface)
    if need_cmd nmcli && nmcli -t -f DEVICE,STATE dev status 2>/dev/null | grep -q .; then
        run_priv "nmcli renew" sudo nmcli connection down "$(nmcli -t -f NAME,DEVICE con show --active | awk -F: -v d="$dev" '$2==d{print $1; exit}')" 2>/dev/null
        sleep 1
        run_priv "nmcli up" sudo nmcli device connect "$dev" 2>/dev/null
    elif need_cmd dhclient && [ -n "$dev" ]; then
        run_priv "dhclient release" sudo dhclient -r "$dev"
        run_priv "dhclient renew" sudo dhclient "$dev"
    else
        printf '%s\n' "${C_YEL}Couldn't find nmcli or dhclient to renew the lease on $dev.${C_RST}"
    fi
    pause
}

net_ping() {
    header "Ping"
    local host=""
    read -r -p "Host to ping: " host
    [ -z "$host" ] && return
    ping -c 6 "$host"
    pause
}

net_traceroute() {
    header "Traceroute"
    local host=""
    read -r -p "Host to trace: " host
    [ -z "$host" ] && return
    if need_cmd mtr; then mtr -r -c 5 "$host"
    elif need_cmd traceroute; then traceroute "$host"
    else offer_install traceroute traceroute && traceroute "$host"
    fi
    pause
}

net_saved_wifi() {
    header "Saved Wi-Fi Networks"
    if need_cmd nmcli; then
        nmcli -f NAME,TYPE,DEVICE connection show | grep -i wireless || nmcli connection show
    elif need_cmd iwgetid; then
        iwgetid
    else
        printf '%s\n' "${C_YEL}NetworkManager (nmcli) not found - can't list saved Wi-Fi profiles.${C_RST}"
    fi
    pause
}

net_wifi_passwords() {
    header "Show Saved Wi-Fi Passwords"
    printf '%s\n' "${C_YEL}This prints stored Wi-Fi passwords in plain text. Be mindful of who can see the screen.${C_RST}"
    if need_cmd nmcli; then
        local prof
        while IFS= read -r prof; do
            [ -z "$prof" ] && continue
            local pw
            pw=$(sudo nmcli -s -g 802-11-wireless-security.psk connection show "$prof" 2>/dev/null)
            printf ' %-30s %s\n' "$prof" "${pw:-<no password / open network>}"
        done < <(nmcli -t -f NAME,TYPE connection show | awk -F: '$2=="802-11-wireless"{print $1}')
    elif [ -d /etc/NetworkManager/system-connections ]; then
        run_priv "grep psk" sudo grep -H '^psk=' /etc/NetworkManager/system-connections/*.nmconnection 2>/dev/null
    elif [ -d /etc/wpa_supplicant ]; then
        run_priv "cat wpa_supplicant" sudo grep -H 'ssid\|psk' /etc/wpa_supplicant/*.conf 2>/dev/null
    else
        printf '%s\n' "${C_YEL}No known Wi-Fi credential store found (NetworkManager/wpa_supplicant).${C_RST}"
    fi
    pause
}

net_connections() {
    local f="${REPORT_DIR}/Connections_$(stamp).txt"
    header "Active Connections"
    if need_cmd ss; then
        ss -tulnp 2>&1 | tee "$f"
    else
        netstat -tulnp 2>&1 | tee "$f"
    fi
    log_action "Saved $f"
    printf '\n%s\n' "${C_GRN}Also saved to $f${C_RST}"
    pause
}

net_reset() {
    header "Full Network Reset"
    confirm "Restart the network stack (NetworkManager/networking service)? This will briefly drop your connection." || { pause; return; }
    if need_cmd nmcli; then
        run_priv "restart NetworkManager" sudo systemctl restart NetworkManager
    elif [ -f /etc/init.d/networking ]; then
        run_priv "restart networking" sudo systemctl restart networking 2>/dev/null || sudo /etc/init.d/networking restart
    elif need_cmd systemd-networkd; then
        run_priv "restart systemd-networkd" sudo systemctl restart systemd-networkd
    else
        printf '%s\n' "${C_YEL}Couldn't detect the network management service in use.${C_RST}"
    fi
    log_action "Network reset"
    pause
}

net_speedtest() {
    header "Internet Speed Test"
    if ! need_cmd speedtest && ! need_cmd speedtest-cli && ! need_cmd speedtest-go; then
        printf '%s\n' "${C_DIM}Needs a speedtest tool: Ookla's speedtest CLI, 'speedtest-cli', or (on Kali, which doesn't package speedtest-cli) 'speedtest-go'.${C_RST}"
        if ! offer_install speedtest-cli speedtest-cli; then
            # speedtest-cli isn't in every distro's repos (e.g. Kali dropped it in
            # favor of speedtest-go) - fall back to the alternative before giving up.
            printf '%s\n' "${C_DIM}'speedtest-cli' isn't available from your package manager - trying 'speedtest-go' instead.${C_RST}"
            offer_install speedtest-go speedtest-go || { pause; return; }
        fi
    fi
    if need_cmd speedtest; then
        speedtest --accept-license --accept-gdpr 2>/dev/null || speedtest
    elif need_cmd speedtest-cli; then
        speedtest-cli
    else
        speedtest-go
    fi
    pause
}

net_configure_ip() {
    header "Configure IP Address"
    if ! need_cmd nmcli; then
        printf '%s\n' "${C_YEL}This tool needs NetworkManager (nmcli). Edit your distro's network config manually instead.${C_RST}"
        pause; return
    fi
    nmcli device status
    local con=""
    read -r -p "Connection name to configure (from 'nmcli con show'): " con
    [ -z "$con" ] && return
    echo " [1] Switch to DHCP   [2] Set static IP"
    local sub=""; read -r -p "Select: " sub
    case "$sub" in
        1)
            run_priv "nmcli dhcp" sudo nmcli connection modify "$con" ipv4.method auto ipv4.addresses "" ipv4.gateway "" ipv4.dns ""
            run_priv "nmcli up" sudo nmcli connection up "$con"
            printf '%s\n' "${C_GRN}Set to DHCP.${C_RST}"
            ;;
        2)
            local ip cidr gw dns
            read -r -p "IP address (e.g. 192.168.1.50): " ip
            read -r -p "Prefix length (e.g. 24 for 255.255.255.0): " cidr
            read -r -p "Gateway (e.g. 192.168.1.1): " gw
            read -r -p "DNS server(s), space-separated (e.g. 1.1.1.1 8.8.8.8): " dns
            [ -z "$ip" ] || [ -z "$cidr" ] && { printf '%s\n' "${C_RED}IP and prefix are required.${C_RST}"; pause; return; }
            run_priv "nmcli static" sudo nmcli connection modify "$con" ipv4.addresses "${ip}/${cidr}" ipv4.gateway "$gw" ipv4.dns "${dns// /,}" ipv4.method manual
            run_priv "nmcli up" sudo nmcli connection up "$con"
            printf '%s\n' "${C_GRN}Static IP applied.${C_RST}"
            ;;
        *) invalid_choice ;;
    esac
    log_action "Configured IP on $con"
    pause
}

net_firewall_status() {
    header "Firewall Status"
    if need_cmd ufw; then
        run_priv "ufw status" sudo ufw status verbose
    elif need_cmd firewall-cmd; then
        run_priv "firewalld status" sudo firewall-cmd --state
        run_priv "firewalld rules" sudo firewall-cmd --list-all
    elif need_cmd nft; then
        run_priv "nft list ruleset" sudo nft list ruleset
    elif need_cmd iptables; then
        run_priv "iptables -L" sudo iptables -L -n -v
    else
        printf '%s\n' "${C_YEL}No known firewall tool found (ufw/firewalld/nft/iptables).${C_RST}"
    fi
    pause
}

network_menu() {
    while true; do
        header "$(t NT_TITLE)"
        cat <<EOF
 ${C_YEL}[1]${C_RST}  $(t NT_1)
 ${C_YEL}[2]${C_RST}  $(t NT_2)
 ${C_YEL}[3]${C_RST}  $(t NT_3)
 ${C_YEL}[4]${C_RST}  $(t NT_4)
 ${C_YEL}[5]${C_RST}  $(t NT_5)
 ${C_YEL}[6]${C_RST}  $(t NT_6)
 ${C_YEL}[7]${C_RST}  $(t NT_7)
 ${C_YEL}[8]${C_RST}  $(t NT_8)
 ${C_YEL}[9]${C_RST}  $(t NT_9)
 ${C_YEL}[10]${C_RST} $(t NT_10)
 ${C_YEL}[11]${C_RST} $(t NT_11)
 ${C_YEL}[12]${C_RST} $(t NT_12)
 ${C_YEL}[13]${C_RST} $(t NT_13)
 ${C_YEL}[14]${C_RST} $(t NT_14)

 ${C_RED}[0]${C_RST}  $(t BACK)
EOF
        local opt=""
        read -r -p " $(t SELECT)" opt || { clear_screen; log_action "Input closed - exiting"; exit 0; }
        case "$opt" in
            1) net_diag ;;
            2) net_ipconfig ;;
            3) net_public_ip ;;
            4) net_flush_dns ;;
            5) net_renew_dhcp ;;
            6) net_ping ;;
            7) net_traceroute ;;
            8) net_saved_wifi ;;
            9) net_connections ;;
            10) net_reset ;;
            11) net_wifi_passwords ;;
            12) net_speedtest ;;
            13) net_configure_ip ;;
            14) net_firewall_status ;;
            0) return ;;
            *) invalid_choice ;;
        esac
    done
}

# ============================================================
#  SECURITY TOOLS  (Linux-specific addition, no Windows equivalent)
# ============================================================

sec_firewall_toggle() {
    header "Firewall Enable / Disable"
    if need_cmd ufw; then
        sudo ufw status | head -1
        echo " [1] Enable   [2] Disable"
        local o=""; read -r -p "Select: " o
        case "$o" in
            1) run_priv "ufw enable" sudo ufw --force enable ;;
            2) confirm "Disable the firewall?" && run_priv "ufw disable" sudo ufw disable ;;
            *) invalid_choice ;;
        esac
    elif need_cmd firewall-cmd; then
        echo " [1] Enable (start + on boot)   [2] Disable"
        local o=""; read -r -p "Select: " o
        case "$o" in
            1) run_priv "firewalld enable" sudo systemctl enable --now firewalld ;;
            2) confirm "Disable the firewall?" && run_priv "firewalld disable" sudo systemctl disable --now firewalld ;;
            *) invalid_choice ;;
        esac
    else
        printf '%s\n' "${C_YEL}No ufw or firewalld found. Install ufw for an easy firewall.${C_RST}"
        offer_install ufw ufw
    fi
    pause
}

sec_open_ports() {
    header "Listening Ports & Owning Processes"
    if need_cmd ss; then
        run_priv "ss -tulnp" sudo ss -tulnp
    else
        run_priv "netstat -tulnp" sudo netstat -tulnp
    fi
    pause
}

sec_updates_available() {
    header "Pending Security / Package Updates"
    pkg_update_check
    pause
}

sec_ssh_audit() {
    header "SSH Configuration Audit"
    local cfg="/etc/ssh/sshd_config"
    if [ ! -r "$cfg" ] && ! sudo test -r "$cfg" 2>/dev/null; then
        printf '%s\n' "${C_YEL}No sshd_config found - SSH server may not be installed.${C_RST}"
        pause; return
    fi
    get_val() { sudo grep -Ei "^\s*$1\s+" "$cfg" 2>/dev/null | tail -1 | awk '{print $2}'; }
    local root_login pass_auth port pubkey
    root_login=$(get_val PermitRootLogin); root_login=${root_login:-"(default: prohibit-password)"}
    pass_auth=$(get_val PasswordAuthentication); pass_auth=${pass_auth:-"(default: yes)"}
    port=$(get_val Port); port=${port:-22}
    pubkey=$(get_val PubkeyAuthentication); pubkey=${pubkey:-"(default: yes)"}

    printf ' %-24s: %s' "PermitRootLogin" "$root_login"
    [[ "$root_login" == "yes" ]] && printf '  %s<- consider disabling%s' "$C_RED" "$C_RST"
    echo
    printf ' %-24s: %s' "PasswordAuthentication" "$pass_auth"
    [[ "$pass_auth" == "yes" || "$pass_auth" == *default:\ yes* ]] && printf '  %s<- key-only login is safer%s' "$C_YEL" "$C_RST"
    echo
    printf ' %-24s: %s\n' "Port" "$port"
    printf ' %-24s: %s\n' "PubkeyAuthentication" "$pubkey"
    pause
}

sec_failed_logins() {
    header "Failed Login Attempts"
    if need_cmd lastb; then
        run_priv "lastb" sudo lastb -n 25 2>/dev/null
    elif need_cmd journalctl; then
        journalctl -u sshd --no-pager 2>/dev/null | grep -i 'failed\|invalid' | tail -25
    else
        printf '%s\n' "${C_YEL}No lastb/journalctl available to check failed logins.${C_RST}"
    fi
    pause
}

sec_uid0_users() {
    header "Users With Superuser (UID 0) Privileges"
    awk -F: '($3 == 0){print " " $1}' /etc/passwd
    echo
    printf '%s\n' "${C_DIM}Only 'root' should normally be listed above.${C_RST}"
    echo
    printf '%s\n' "${C_CYAN}Members of sudo/wheel group:${C_RST}"
    getent group sudo wheel 2>/dev/null | awk -F: '{print " " $1": "$4}'
    pause
}

sec_rootkit_scan() {
    header "Rootkit Scan"
    if need_cmd rkhunter; then
        run_priv "rkhunter --check" sudo rkhunter --check --sk
    elif need_cmd chkrootkit; then
        run_priv "chkrootkit" sudo chkrootkit
    else
        printf '%s\n' "${C_YEL}Neither rkhunter nor chkrootkit is installed.${C_RST}"
        offer_install rkhunter rkhunter
    fi
    pause
}

sec_world_writable() {
    header "World-Writable Files in Key System Directories"
    printf '%s\n' "${C_DIM}Scanning /etc /usr/bin /usr/sbin /usr/lib (this can take a moment)...${C_RST}"
    find /etc /usr/bin /usr/sbin /usr/lib -xdev -type f -perm -0002 2>/dev/null | head -50
    printf '%s\n' "${C_DIM}(Showing at most 50 matches.)${C_RST}"
    pause
}

sec_fail2ban() {
    header "Fail2ban Status"
    if ! need_cmd fail2ban-client; then
        printf '%s\n' "${C_YEL}fail2ban isn't installed. It's the single most-recommended tool for cutting brute-force attempts on internet-facing servers.${C_RST}"
        offer_install fail2ban-client fail2ban || { pause; return; }
        run_priv "enable fail2ban" systemctl enable --now fail2ban 2>/dev/null
    fi
    if ! run_priv "fail2ban-client ping" fail2ban-client ping >/dev/null 2>&1; then
        printf '%s\n' "${C_YEL}fail2ban is installed but not running.${C_RST}"
        local ans=""; read -r -p "Start it now? [y/N] " ans
        [[ "$ans" =~ ^[Yy]$ ]] && run_priv "start fail2ban" systemctl start fail2ban
    fi
    echo
    run_priv "fail2ban status" fail2ban-client status
    local jails
    jails=$(run_priv "fail2ban jail list" fail2ban-client status 2>/dev/null | awk -F':' '/Jail list/{print $2}' | tr ',' '\n' | sed -E 's/^[[:space:]]+//;s/[[:space:]]+$//;/^$/d')
    if [ -n "$jails" ]; then
        echo
        local jail
        while IFS= read -r jail; do
            printf '%s\n' "${C_CYAN}--- $jail ---${C_RST}"
            run_priv "fail2ban jail status $jail" fail2ban-client status "$jail" 2>/dev/null | grep -E 'Currently banned|Total banned|Banned IP'
        done <<< "$jails"
    fi
    echo
    echo " [1] Ban an IP   [2] Unban an IP   [0] Back"
    local o=""; read -r -p "Select: " o
    case "$o" in
        1)
            [ -z "$jails" ] && { printf '%s\n' "${C_YEL}No active jails to ban against.${C_RST}"; pause; return; }
            local jail_name ip
            read -r -p "Jail name (e.g. sshd): " jail_name
            read -r -p "IP address to ban: " ip
            [ -n "$jail_name" ] && [ -n "$ip" ] && run_priv "fail2ban ban" fail2ban-client set "$jail_name" banip "$ip"
            ;;
        2)
            local jail_name ip
            read -r -p "Jail name (e.g. sshd): " jail_name
            read -r -p "IP address to unban: " ip
            [ -n "$jail_name" ] && [ -n "$ip" ] && run_priv "fail2ban unban" fail2ban-client set "$jail_name" unbanip "$ip"
            ;;
    esac
    pause
}

sec_lynis_audit() {
    header "Lynis Security Audit"
    if ! need_cmd lynis; then
        printf '%s\n' "${C_DIM}Lynis checks 300+ hardening items and gives your system a Hardening Index (0-100).${C_RST}"
        offer_install lynis lynis || { pause; return; }
    fi
    printf '%s\n' "${C_DIM}Running a full audit - this takes a minute or two...${C_RST}"
    run_priv "lynis audit system" lynis audit system --quick
    printf '\n%s\n' "${C_DIM}Full report saved by Lynis itself, typically at /var/log/lynis-report.dat and /var/log/lynis.log${C_RST}"
    pause
}

# Baseline sysctl keys this toolkit knows how to audit/harden. Deliberately
# excludes context-dependent settings like net.ipv4.ip_forward, which routers,
# Docker hosts and VPN boxes legitimately need enabled - flipping that off
# under a generic "hardening" banner would break those setups.
_SYSCTL_HARDENING_KEYS=(
    "net.ipv4.conf.all.accept_redirects=0"
    "net.ipv4.conf.default.accept_redirects=0"
    "net.ipv6.conf.all.accept_redirects=0"
    "net.ipv4.conf.all.send_redirects=0"
    "net.ipv4.conf.all.accept_source_route=0"
    "net.ipv6.conf.all.accept_source_route=0"
    "net.ipv4.conf.all.rp_filter=1"
    "net.ipv4.icmp_echo_ignore_broadcasts=1"
    "net.ipv4.tcp_syncookies=1"
    "kernel.randomize_va_space=2"
    "kernel.sysrq=0"
    "kernel.dmesg_restrict=1"
    "kernel.kptr_restrict=2"
    "fs.protected_hardlinks=1"
    "fs.protected_symlinks=1"
)

sec_sysctl_hardening() {
    header "Kernel (sysctl) Hardening"
    printf ' %-45s %10s %10s\n' "PARAMETER" "CURRENT" "RECOMMENDED"
    local entry key want current
    for entry in "${_SYSCTL_HARDENING_KEYS[@]}"; do
        key="${entry%%=*}"; want="${entry#*=}"
        current=$(sysctl -n "$key" 2>/dev/null)
        if [ "$current" = "$want" ]; then
            printf ' %-45s %10s %10s  %s\n' "$key" "${current:-?}" "$want" "${C_GRN}OK${C_RST}"
        else
            printf ' %-45s %10s %10s  %s\n' "$key" "${current:-?}" "$want" "${C_YEL}differs${C_RST}"
        fi
    done
    echo
    echo " [1] Apply recommended baseline   [2] Revert to previous baseline   [0] Back"
    local o=""; read -r -p "Select: " o
    local conf="/etc/sysctl.d/99-techtoolkit-hardening.conf"
    case "$o" in
        1)
            confirm "Write $conf and apply these values now? A backup of any existing file is kept." || { pause; return; }
            if [ -f "$conf" ]; then
                run_priv "backup sysctl conf" cp "$conf" "${conf}.bak.$(stamp)"
            fi
            {
                echo "# Written by LinuxTechToolKit - baseline kernel hardening"
                echo "# Deliberately excludes net.ipv4.ip_forward (context-dependent: routers/Docker/VPN hosts need it)"
                for entry in "${_SYSCTL_HARDENING_KEYS[@]}"; do echo "${entry/=/ = }"; done
            } > "/tmp/techtoolkit_sysctl_$$.conf"
            run_priv "install sysctl conf" cp "/tmp/techtoolkit_sysctl_$$.conf" "$conf"
            rm -f "/tmp/techtoolkit_sysctl_$$.conf"
            run_priv "sysctl --system" sysctl --system >/dev/null
            printf '%s\n' "${C_GRN}Applied. Re-open this menu to confirm the values took effect.${C_RST}"
            log_action "Applied sysctl hardening baseline"
            ;;
        2)
            local backups
            backups=$(ls -t "${conf}.bak."* 2>/dev/null)
            if [ -z "$backups" ]; then
                printf '%s\n' "${C_YEL}No backup found. If you never applied our baseline, just delete $conf manually.${C_RST}"
            else
                local latest; latest=$(head -1 <<< "$backups")
                confirm "Restore $latest over $conf and reload?" || { pause; return; }
                run_priv "restore sysctl conf" cp "$latest" "$conf"
                run_priv "sysctl --system" sysctl --system >/dev/null
                printf '%s\n' "${C_GRN}Restored.${C_RST}"
            fi
            ;;
    esac
    pause
}

# lsm_status_line -- one-line SELinux/AppArmor summary, reused by the quick
# summary and the dedicated Security Tools item.
lsm_status_line() {
    if need_cmd sestatus; then
        sestatus 2>/dev/null | awk -F': *' '/^SELinux status/{s=$2} /^Current mode/{m=$2} END{printf "SELinux: %s%s\n", s, (m? " ("m")":"")}'
    elif need_cmd aa-status; then
        if [ "$IS_ROOT" -eq 1 ] || sudo -n true 2>/dev/null; then
            if run_priv "aa-status --enabled" aa-status --enabled 2>/dev/null; then
                local loaded
                loaded=$(run_priv "aa-status" aa-status --json 2>/dev/null | grep -o '"profiles":[0-9]*' | head -1 | cut -d: -f2)
                printf 'AppArmor: enabled (%s profiles loaded)\n' "${loaded:-?}"
            else
                printf 'AppArmor: installed but not active\n'
            fi
        else
            printf 'AppArmor: installed (run as root/sudo for full status)\n'
        fi
    elif [ -r /sys/kernel/security/lsm ]; then
        printf 'active modules: %s\n' "$(cat /sys/kernel/security/lsm)"
    else
        printf 'none detected (no SELinux/AppArmor)\n'
    fi
}

sec_lsm_status() {
    header "SELinux / AppArmor Status"
    lsm_status_line
    echo
    if need_cmd sestatus; then
        sestatus -v 2>/dev/null
    elif need_cmd aa-status; then
        run_priv "aa-status" aa-status
    else
        printf '%s\n' "${C_DIM}Neither SELinux (sestatus) nor AppArmor (aa-status) tooling is present.${C_RST}"
    fi
    pause
}

security_menu() {
    while true; do
        header "$(t ST_TITLE)"
        cat <<EOF
 ${C_YEL}[1]${C_RST}  $(t ST_1)
 ${C_YEL}[2]${C_RST}  $(t ST_2)
 ${C_YEL}[3]${C_RST}  $(t ST_3)
 ${C_YEL}[4]${C_RST}  $(t ST_4)
 ${C_YEL}[5]${C_RST}  $(t ST_5)
 ${C_YEL}[6]${C_RST}  $(t ST_6)
 ${C_YEL}[7]${C_RST}  $(t ST_7)
 ${C_YEL}[8]${C_RST}  $(t ST_8)
 ${C_YEL}[9]${C_RST}  $(t ST_9)
 ${C_YEL}[10]${C_RST} $(t ST_10)
 ${C_YEL}[11]${C_RST} $(t ST_11)
 ${C_YEL}[12]${C_RST} $(t ST_12)

 ${C_RED}[0]${C_RST}  $(t BACK)
EOF
        local opt=""
        read -r -p " $(t SELECT)" opt || { clear_screen; log_action "Input closed - exiting"; exit 0; }
        case "$opt" in
            1) sec_firewall_toggle ;;
            2) sec_open_ports ;;
            3) sec_updates_available ;;
            4) sec_ssh_audit ;;
            5) sec_failed_logins ;;
            6) sec_uid0_users ;;
            7) sec_rootkit_scan ;;
            8) sec_world_writable ;;
            9) sec_fail2ban ;;
            10) sec_lynis_audit ;;
            11) sec_sysctl_hardening ;;
            12) sec_lsm_status ;;
            0) return ;;
            *) invalid_choice ;;
        esac
    done
}

# ============================================================
#  PACKAGE MANAGEMENT
# ============================================================

pkgmgr_menu() {
    while true; do
        header "$(t PM_TITLE) ($PKG_MANAGER $(t PM_ON) $DISTRO_NAME)"
        cat <<EOF
 ${C_YEL}[1]${C_RST}  $(t PM_1)
 ${C_YEL}[2]${C_RST}  $(t PM_2)
 ${C_YEL}[3]${C_RST}  $(t PM_3)
 ${C_YEL}[4]${C_RST}  $(t PM_4)
 ${C_YEL}[5]${C_RST}  $(t PM_5)
 ${C_YEL}[6]${C_RST}  $(t PM_6)
 ${C_YEL}[7]${C_RST}  $(t PM_7)

 ${C_RED}[0]${C_RST}  $(t BACK)
EOF
        local opt=""
        read -r -p " $(t SELECT)" opt || { clear_screen; log_action "Input closed - exiting"; exit 0; }
        case "$opt" in
            1) header "Checking for Updates"; pkg_update_check; pause ;;
            2) repair_update_all ;;
            3) header "Cleaning Package Cache"; pkg_clean_cache; pause ;;
            4)
                header "Install a Package"
                local pkg=""; read -r -p "Package name: " pkg
                [ -n "$pkg" ] && pkg_install "$pkg"
                pause ;;
            5)
                header "Search for a Package"
                local q=""; read -r -p "Search term: " q
                [ -z "$q" ] && { pause; continue; }
                case "$PKG_MANAGER" in
                    apt) apt-cache search "$q" | head -30 ;;
                    dnf) dnf search "$q" 2>/dev/null | head -30 ;;
                    yum) yum search "$q" 2>/dev/null | head -30 ;;
                    pacman) pacman -Ss "$q" | head -30 ;;
                    zypper) zypper search "$q" | head -30 ;;
                    apk) apk search "$q" | head -30 ;;
                    *) printf 'No supported package manager.\n' ;;
                esac
                pause ;;
            6)
                header "Remove a Package"
                local pkg=""; read -r -p "Package name to remove: " pkg
                [ -z "$pkg" ] && { pause; continue; }
                confirm "Remove '$pkg'?" || { pause; continue; }
                case "$PKG_MANAGER" in
                    apt) run_priv "apt remove $pkg" sudo apt-get remove -y "$pkg" ;;
                    dnf) run_priv "dnf remove $pkg" sudo dnf remove -y "$pkg" ;;
                    yum) run_priv "yum remove $pkg" sudo yum remove -y "$pkg" ;;
                    pacman) run_priv "pacman -R $pkg" sudo pacman -R --noconfirm "$pkg" ;;
                    zypper) run_priv "zypper rm $pkg" sudo zypper remove -y "$pkg" ;;
                    apk) run_priv "apk del $pkg" sudo apk del "$pkg" ;;
                    *) printf 'No supported package manager.\n' ;;
                esac
                pause ;;
            7)
                header "Explicitly Installed Packages"
                case "$PKG_MANAGER" in
                    apt) comm -23 <(apt-mark showmanual | sort -u) <(true) | head -100 ;;
                    pacman) pacman -Qe | head -100 ;;
                    dnf) dnf repoquery --userinstalled 2>/dev/null | head -100 ;;
                    *) printf 'Not supported for %s yet - see full package list under System Info.\n' "$PKG_MANAGER" ;;
                esac
                pause ;;
            0) return ;;
            *) invalid_choice ;;
        esac
    done
}

# ============================================================
#  CLEANUP
# ============================================================

clean_temp() {
    header "Clean Temporary Files"
    confirm "Delete files in /tmp older than 1 day and \$HOME/.cache contents?" || { pause; return; }
    find /tmp -mindepth 1 -maxdepth 1 -mtime +1 -exec rm -rf {} + 2>/dev/null
    rm -rf "${HOME:?}/.cache/"* 2>/dev/null
    log_action "Cleaned temp files"
    printf '%s\n' "${C_GRN}Done.${C_RST}"
    pause
}

clean_journal() {
    header "Vacuum systemd Journal"
    if ! need_cmd journalctl; then printf '%s\n' "${C_YEL}journalctl not available.${C_RST}"; pause; return; fi
    local days=""
    read -r -p "Keep how many days of logs? [7]: " days
    days="${days:-7}"
    run_priv "journalctl vacuum" sudo journalctl --vacuum-time="${days}d"
    log_action "Vacuumed journal to ${days}d"
    pause
}

clean_trash() {
    header "Empty Trash"
    local trash_dir="${HOME}/.local/share/Trash"
    if [ -d "$trash_dir" ]; then
        confirm "Empty the trash at $trash_dir?" || { pause; return; }
        rm -rf "${trash_dir:?}/files/"* "${trash_dir:?}/info/"* 2>/dev/null
        printf '%s\n' "${C_GRN}Trash emptied.${C_RST}"
    else
        printf '%s\n' "${C_YEL}No trash directory found at $trash_dir.${C_RST}"
    fi
    log_action "Trash emptied"
    pause
}

clean_old_kernels() {
    header "Remove Old Kernels"
    printf 'Current kernel: %s\n\n' "$(uname -r)"
    case "$PKG_MANAGER" in
        apt)
            dpkg -l 'linux-image-*' | awk '/^ii/{print $2}'
            confirm "Run 'apt autoremove --purge' to remove old kernels no longer needed?" || { pause; return; }
            run_priv "apt autoremove --purge" sudo apt-get autoremove --purge -y
            ;;
        dnf)
            need_cmd dnf && dnf repoquery --installonly --latest-limit=-1 -q 2>/dev/null
            confirm "Remove old kernels, keeping the 2 most recent?" || { pause; return; }
            run_priv "dnf remove old kernels" sudo dnf remove -y "$(dnf repoquery --installonly --latest-limit=-2 -q 2>/dev/null | tr '\n' ' ')" 2>/dev/null
            ;;
        pacman)
            printf '%s\n' "${C_DIM}Arch keeps only the current kernel package by design; nothing to remove here.${C_RST}"
            ;;
        *)
            printf '%s\n' "${C_DIM}Old-kernel cleanup isn't scripted for $PKG_MANAGER - check your package manager's docs.${C_RST}"
            ;;
    esac
    pause
}

clean_docker() {
    header "Docker / Podman Cleanup"
    local tool=""
    need_cmd docker && tool=docker
    need_cmd podman && tool=podman
    if [ -z "$tool" ]; then
        printf '%s\n' "${C_YEL}Neither docker nor podman found - skipping.${C_RST}"
        pause; return
    fi
    "$tool" system df 2>/dev/null
    confirm "Prune unused $tool containers, images, networks and build cache?" || { pause; return; }
    if [ "$tool" = docker ]; then run_priv "docker prune" sudo docker system prune -af
    else run_priv "podman prune" sudo podman system prune -af
    fi
    pause
}

clean_thumbnails() {
    header "Clear Thumbnail Cache"
    local dir="${HOME}/.cache/thumbnails"
    if [ -d "$dir" ]; then
        rm -rf "${dir:?}"/* 2>/dev/null
        printf '%s\n' "${C_GRN}Cleared.${C_RST}"
    else
        printf '%s\n' "${C_DIM}No thumbnail cache found.${C_RST}"
    fi
    pause
}

disk_usage_browser() {
    header "What's Using Disk Space?"
    local start=""
    read -r -p "Directory to scan [/]: " start
    start="${start:-/}"
    if [ ! -d "$start" ]; then
        printf '%s\n' "${C_RED}No such directory: $start${C_RST}"
        pause; return
    fi
    if need_cmd ncdu; then
        ncdu "$start"
    else
        printf '%s\n' "${C_DIM}Tip: install 'ncdu' for an interactive drill-down browser. Showing a static top-20 for now.${C_RST}"
        offer_install ncdu ncdu && { ncdu "$start"; pause; return; }
        echo
        printf ' %-70s %10s\n' "PATH" "SIZE"
        du -xh --max-depth=2 "$start" 2>/dev/null | sort -rh | head -20 | awk '{sz=$1; $1=""; printf " %-70s %10s\n", $0, sz}'
    fi
    pause
}

cleanup_menu() {
    while true; do
        header "$(t CL_TITLE)"
        cat <<EOF
 ${C_YEL}[1]${C_RST}  $(t CL_1)
 ${C_YEL}[2]${C_RST}  $(t CL_2)   ${C_DIM}($PKG_MANAGER)${C_RST}
 ${C_YEL}[3]${C_RST}  $(t CL_3)
 ${C_YEL}[4]${C_RST}  $(t CL_4)
 ${C_YEL}[5]${C_RST}  $(t CL_5)
 ${C_YEL}[6]${C_RST}  $(t CL_6)
 ${C_YEL}[7]${C_RST}  $(t CL_7)
 ${C_YEL}[8]${C_RST}  $(t CL_8)

 ${C_RED}[0]${C_RST}  $(t BACK)
EOF
        local opt=""
        read -r -p " $(t SELECT)" opt || { clear_screen; log_action "Input closed - exiting"; exit 0; }
        case "$opt" in
            1) clean_temp ;;
            2) header "Package Cache Cleanup"; pkg_clean_cache; pause ;;
            3) clean_journal ;;
            4) clean_trash ;;
            5) clean_old_kernels ;;
            6) clean_docker ;;
            7) clean_thumbnails ;;
            8) disk_usage_browser ;;
            0) return ;;
            *) invalid_choice ;;
        esac
    done
}

# ============================================================
#  POWER & BOOT
# ============================================================

power_firmware() {
    header "Reboot into Firmware (BIOS/UEFI) Setup"
    confirm "Reboot straight into firmware setup?" || { pause; return; }
    if need_cmd systemctl; then
        run_priv "reboot --firmware-setup" sudo systemctl reboot --firmware-setup 2>/dev/null || {
            printf '%s\n' "${C_YEL}Firmware isn't UEFI or doesn't support this; rebooting normally instead.${C_RST}"
            run_priv "reboot" sudo systemctl reboot
        }
    else
        run_priv "reboot" sudo reboot
    fi
}

power_rescue() {
    header "Boot into Rescue / Emergency Mode"
    echo " [1] Rescue mode (single-user, most services stopped)"
    echo " [2] Emergency mode (minimal, root fs read-only)"
    local o=""; read -r -p "Select: " o
    case "$o" in
        1) confirm "Switch to rescue target NOW? Interactive sessions will end." && run_priv "systemctl rescue" sudo systemctl rescue ;;
        2) confirm "Switch to emergency target NOW? Interactive sessions will end." && run_priv "systemctl emergency" sudo systemctl emergency ;;
        *) invalid_choice; pause ;;
    esac
}

power_default_target() {
    header "Set Default Boot Target (GUI on/off)"
    if ! need_cmd systemctl; then printf '%s\n' "${C_YEL}systemd not available.${C_RST}"; pause; return; fi
    printf 'Current default target: %s\n\n' "$(systemctl get-default 2>/dev/null)"
    echo " [1] graphical.target (normal desktop boot)"
    echo " [2] multi-user.target (text-only, like Safe Mode without GUI)"
    local o=""; read -r -p "Select: " o
    case "$o" in
        1) run_priv "set-default graphical" sudo systemctl set-default graphical.target ;;
        2) run_priv "set-default multi-user" sudo systemctl set-default multi-user.target ;;
        *) invalid_choice ;;
    esac
    pause
}

power_suspend() {
    header "Suspend / Hibernate"
    echo " [1] Suspend (sleep)   [2] Hibernate"
    local o=""; read -r -p "Select: " o
    case "$o" in
        1) run_priv "systemctl suspend" sudo systemctl suspend ;;
        2) run_priv "systemctl hibernate" sudo systemctl hibernate 2>/dev/null || printf '%s\n' "${C_YEL}Hibernate isn't configured (needs a swap partition/file sized for RAM).${C_RST}" ;;
        *) invalid_choice; pause ;;
    esac
}

power_restart() {
    confirm "Restart now?" || { pause; return; }
    log_action "Restart requested"
    run_priv "reboot" sudo systemctl reboot 2>/dev/null || sudo reboot
}

power_shutdown() {
    confirm "Shut down now?" || { pause; return; }
    log_action "Shutdown requested"
    run_priv "poweroff" sudo systemctl poweroff 2>/dev/null || sudo poweroff
}

power_menu() {
    local virt; virt=$(detect_virt)
    while true; do
        header "$(t PW_TITLE)"
        [ "$virt" != "none" ] && printf "${C_DIM}$(t PW_VIRT_NOTE)${C_RST}\\n\\n" "$virt"
        cat <<EOF
 ${C_YEL}[1]${C_RST}  $(t PW_1)
 ${C_YEL}[2]${C_RST}  $(t PW_2)
 ${C_YEL}[3]${C_RST}  $(t PW_3)
 ${C_YEL}[4]${C_RST}  $(t PW_4)
 ${C_YEL}[5]${C_RST}  $(t PW_5)
 ${C_YEL}[6]${C_RST}  $(t PW_6)

 ${C_RED}[0]${C_RST}  $(t BACK)
EOF
        local opt=""
        read -r -p " $(t SELECT)" opt || { clear_screen; log_action "Input closed - exiting"; exit 0; }
        case "$opt" in
            1) power_firmware ;;
            2) power_rescue ;;
            3) power_default_target ;;
            4) power_suspend ;;
            5) power_restart ;;
            6) power_shutdown ;;
            0) return ;;
            *) invalid_choice ;;
        esac
    done
}

# ============================================================
#  ADMIN CONSOLES
# ============================================================

consoles_menu() {
    while true; do
        header "$(t AC_TITLE)"
        cat <<EOF
 ${C_YEL}[1]${C_RST}  $(t AC_1)
 ${C_YEL}[2]${C_RST}  $(t AC_2)
 ${C_YEL}[3]${C_RST}  $(t AC_3)
 ${C_YEL}[4]${C_RST}  $(t AC_4)
 ${C_YEL}[5]${C_RST}  $(t AC_5)
 ${C_YEL}[6]${C_RST}  $(t AC_6)
 ${C_YEL}[7]${C_RST}  $(t AC_7)
 ${C_YEL}[8]${C_RST}  $(t AC_8)
 ${C_YEL}[9]${C_RST}  $(t AC_9)

 ${C_RED}[0]${C_RST}  $(t BACK)
EOF
        local opt=""
        read -r -p " $(t SELECT)" opt || { clear_screen; log_action "Input closed - exiting"; exit 0; }
        case "$opt" in
            1) header "Root Shell"; printf '%s\n' "${C_DIM}Type 'exit' to return to the toolkit.${C_RST}"; sudo -i ;;
            2)
                header "Service Manager"
                systemctl list-units --type=service --no-pager | head -40
                echo
                local svc=""; read -r -p "Service to inspect (blank to skip): " svc
                [ -n "$svc" ] && systemctl status "$svc" --no-pager
                pause ;;
            3) header "Live Log Viewer"; printf '%s\n' "${C_DIM}Ctrl+C to stop and return.${C_RST}"; sleep 1; journalctl -f ;;
            4)
                header "User Management"
                cut -d: -f1,3,6 /etc/passwd | awk -F: '$2>=1000{print " "$1" (uid "$2", home "$3")"}'
                echo
                echo " [1] Add user   [2] Change password   [0] Back"
                local o=""; read -r -p "Select: " o
                case "$o" in
                    1) local u=""; read -r -p "New username: " u; [ -n "$u" ] && run_priv "useradd $u" sudo useradd -m "$u" && run_priv "passwd $u" sudo passwd "$u" ;;
                    2) local u=""; read -r -p "Username: " u; [ -n "$u" ] && run_priv "passwd $u" sudo passwd "$u" ;;
                esac
                pause ;;
            5)
                if need_cmd htop; then htop; elif need_cmd btop; then btop; else top; fi ;;
            6)
                if need_cmd gnome-disks; then gnome-disks & else header "Disk Manager"; lsblk -f; pause; fi ;;
            7)
                header "Cron / Scheduled Tasks"
                printf '%s\n' "${C_CYAN}--- crontab -l ---${C_RST}"
                crontab -l 2>/dev/null || echo " (no user crontab)"
                if need_cmd systemctl; then
                    echo; printf '%s\n' "${C_CYAN}--- systemd timers ---${C_RST}"
                    systemctl list-timers --no-pager 2>/dev/null | head -20
                fi
                pause ;;
            8)
                if need_cmd gnome-software; then gnome-software & elif need_cmd plasma-discover; then plasma-discover & else printf '%s\n' "${C_YEL}No graphical package manager found.${C_RST}"; pause; fi ;;
            9)
                if need_cmd nmtui; then nmtui; elif need_cmd nm-connection-editor; then nm-connection-editor & else printf '%s\n' "${C_YEL}NetworkManager tools not found.${C_RST}"; pause; fi ;;
            0) return ;;
            *) invalid_choice ;;
        esac
    done
}

# ============================================================
#  SELF-UPDATE
# ============================================================

# _ver_gt <a> <b> -- true if version a > version b (dotted numeric versions)
_ver_gt() {
    [ "$1" = "$2" ] && return 1
    [ "$(printf '%s\n%s\n' "$1" "$2" | sort -V | tail -1)" = "$1" ]
}

check_self_update() {
    header "Check for Toolkit Updates"
    if ! need_cmd curl; then
        printf '%s\n' "${C_YEL}'curl' is required to check for updates.${C_RST}"
        pause; return
    fi
    printf '%s\n' "${C_DIM}Checking github.com/$GITHUB_REPO for a newer release...${C_RST}"
    local response
    response=$(curl -fsSL --max-time 10 "https://api.github.com/repos/$GITHUB_REPO/releases/latest" 2>/dev/null)
    if [ -z "$response" ]; then
        printf '%s\n' "${C_YEL}Couldn't reach GitHub (no internet, or no release has been published yet).${C_RST}"
        pause; return
    fi
    local latest_tag
    if need_cmd jq; then
        latest_tag=$(printf '%s' "$response" | jq -r '.tag_name // empty')
    else
        latest_tag=$(printf '%s' "$response" | grep -m1 '"tag_name"' | sed -E 's/.*"tag_name"[[:space:]]*:[[:space:]]*"([^"]+)".*/\1/')
    fi
    if [ -z "$latest_tag" ]; then
        printf '%s\n' "${C_YEL}No published releases found yet for $GITHUB_REPO.${C_RST}"
        pause; return
    fi
    local latest_ver="${latest_tag#v}"
    printf ' %-20s: %s\n' "Installed" "$TOOLKIT_VERSION"
    printf ' %-20s: %s\n' "Latest" "$latest_ver"
    if ! _ver_gt "$latest_ver" "$TOOLKIT_VERSION"; then
        printf '\n%s\n' "${C_GRN}You're already on the latest version.${C_RST}"
        pause; return
    fi
    echo
    printf '%s\n' "${C_GRN}A newer version is available.${C_RST}"
    local ans=""
    read -r -p "Download and install it now? [y/N] " ans
    [[ "$ans" =~ ^[Yy]$ ]] || { pause; return; }
    local dest="${BASH_SOURCE[0]}"
    local url="https://raw.githubusercontent.com/$GITHUB_REPO/$latest_tag/linuxtechtoolkit.sh"
    local tmp; tmp=$(mktemp)
    if ! curl -fsSL --max-time 20 "$url" -o "$tmp"; then
        printf '%s\n' "${C_RED}Download failed.${C_RST}"
        rm -f "$tmp"; pause; return
    fi
    if ! bash -n "$tmp"; then
        printf '%s\n' "${C_RED}Downloaded file failed a syntax check - not installed. Nothing was changed.${C_RST}"
        rm -f "$tmp"; pause; return
    fi
    if run_priv "self-update install" cp "$tmp" "$dest" && run_priv "self-update chmod" chmod +x "$dest"; then
        printf '%s\n' "${C_GRN}Updated to $latest_ver. Restart the toolkit to use the new version.${C_RST}"
        log_action "Self-updated to $latest_ver"
    else
        printf '%s\n' "${C_RED}Couldn't write to $dest - check permissions.${C_RST}"
    fi
    rm -f "$tmp"
    pause
}

# ============================================================
#  MAIN MENU
# ============================================================

main_menu() {
    while true; do
        header "$(t MAIN_TITLE)"
        cat <<EOF
 ${C_YEL}[1]${C_RST}  $(t MAIN_1)
 ${C_YEL}[2]${C_RST}  $(t MAIN_2)
 ${C_YEL}[3]${C_RST}  $(t MAIN_3)
 ${C_YEL}[4]${C_RST}  $(t MAIN_4)
 ${C_YEL}[5]${C_RST}  $(t MAIN_5)        ${C_DIM}($PKG_MANAGER)${C_RST}
 ${C_YEL}[6]${C_RST}  $(t MAIN_6)
 ${C_YEL}[7]${C_RST}  $(t MAIN_7)
 ${C_YEL}[8]${C_RST}  $(t MAIN_8)
 ${C_YEL}[9]${C_RST}  $(t MAIN_9)
 ${C_YEL}[10]${C_RST} $(t MAIN_10)
 ${C_YEL}[11]${C_RST} $(t MAIN_11)    ${C_DIM}(v$TOOLKIT_VERSION)${C_RST}

 ${C_RED}[0]${C_RST}  $(t EXIT)
EOF
        local opt=""
        read -r -p " $(t SELECT)" opt || { clear_screen; log_action "Input closed - exiting"; exit 0; }
        case "$opt" in
            1) consoles_menu ;;
            2) sysinfo_menu ;;
            3) repair_menu ;;
            4) network_menu ;;
            5) pkgmgr_menu ;;
            6) security_menu ;;
            7) cleanup_menu ;;
            8) power_menu ;;
            9) run_live_monitor ;;
            10) open_path "$REPORT_DIR" ;;
            11) check_self_update ;;
            0) log_action "Toolkit exited"; clear_screen; exit 0 ;;
            *) invalid_choice ;;
        esac
    done
}

# ============================================================
#  ENTRY POINT
# ============================================================

print_usage() {
    cat <<EOF
Linux Technician Toolkit PRO v$TOOLKIT_VERSION

Usage: $(basename "${BASH_SOURCE[0]}") [option]

With no option, launches the interactive menu.

Options:
  --quick-summary   Print the quick system summary and exit (scriptable/cron-friendly)
  --check-updates   Check GitHub for a newer release and exit
  --version         Print the toolkit version and exit
  --help            Show this help and exit
EOF
}

case "${1:-}" in
    --version)
        printf 'linuxtechtoolkit.sh v%s\n' "$TOOLKIT_VERSION"
        exit 0
        ;;
    --help|-h)
        print_usage
        exit 0
        ;;
    --quick-summary)
        detect_distro
        print_quick_summary
        exit 0
        ;;
    --check-updates)
        detect_distro
        mkdir -p "$REPORT_DIR" 2>/dev/null
        check_self_update
        exit 0
        ;;
    "")
        ;;
    *)
        printf 'Unknown option: %s\n\n' "$1" >&2
        print_usage >&2
        exit 1
        ;;
esac

detect_distro
mkdir -p "$REPORT_DIR" 2>/dev/null
select_language
log_action "Toolkit started (v$TOOLKIT_VERSION, distro=$DISTRO_ID, pkgmgr=$PKG_MANAGER, root=$IS_ROOT, lang=$LANG_CHOICE)"
main_menu
