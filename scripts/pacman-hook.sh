#!/usr/bin/env bash
# Installs / removes the pacman hook that tells Config Sync to regenerate its
# package lists after any package transaction. Run as root:
#
#   sudo bash scripts/pacman-hook.sh install
#   sudo bash scripts/pacman-hook.sh status
#   sudo bash scripts/pacman-hook.sh uninstall

set -euo pipefail

HOOK_FILE="/etc/pacman.d/hooks/config-sync.hook"
STATE_SUBDIR="omarchy-config-sync/live-pkgs"

say() {
    printf "config-sync-hook: %s\n" "$*"
}

fail() {
    printf "config-sync-hook: %s\n" "$*" >&2
    exit 1
}

install_hook() {
    [[ $EUID -eq 0 ]] || fail "refusing to run as non-root; use sudo"
    local user="${SUDO_USER:-${USER:-}}"
    [[ -n "$user" ]] || fail "cannot determine the desktop user (SUDO_USER empty)"
    local home
    home="$(getent passwd "$user" 2>/dev/null | cut -d: -f6)" ||
        fail "no such user: $user"
    local cache_dir="${XDG_DATA_HOME:-${home}/.local/share}/${STATE_SUBDIR}"
    # The hook flushes the cache dir as root; the plugin recreates it lazily.
    mkdir -p /etc/pacman.d/hooks
    cat > "$HOOK_FILE" <<EOF
[Trigger]
Operation = Install
Operation = Upgrade
Operation = Remove
Type = Package
Target = *

[Action]
Description = Flush Config Sync package cache after pacman transactions
When = PostTransaction
Exec = rm -rf -- ${cache_dir}
EOF
    chmod 644 "$HOOK_FILE"
    say "installed $(basename "$HOOK_FILE") for ${user}"
    say "cache dir: ${cache_dir}"
}

uninstall_hook() {
    [[ $EUID -eq 0 ]] || fail "refusing to run as non-root; use sudo"
    if [[ -f "$HOOK_FILE" ]]; then
        rm -f "$HOOK_FILE"
        say "removed $(basename "$HOOK_FILE")"
    else
        say "no hook installed"
    fi
}

status_hook() {
    if [[ -f "$HOOK_FILE" ]]; then
        say "hook is installed ($HOOK_FILE)"
        sed -n '1,40p' "$HOOK_FILE"
    else
        say "hook is NOT installed"
        return 1
    fi
}

case "${1:-}" in
    install)
        install_hook
        ;;
    uninstall)
        uninstall_hook
        ;;
    status)
        status_hook
        ;;
    *)
        printf "usage: %s {install|uninstall|status}\n" "$0" >&2
        exit 2
        ;;
esac