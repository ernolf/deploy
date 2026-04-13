#!/usr/bin/env bash
# SPDX-FileCopyrightText: 2026 [ernolf] Raphael Gradenwitz
# SPDX-License-Identifier: MIT
#
# os-lib.sh — OS and package manager abstraction library for deploy packages
#
# Installed by the deploy tool to /var/lib/deploy/lib/os-lib.sh.
# Source this file at the top of any deploy.sh to get distribution-agnostic
# package management functions and the OS detection variables.
#
# Usage in deploy.sh:
#   . "${DEPLOY_LIB}/os-lib.sh"
#
# When sourced, this file:
#   - Sets DEPLOY_OS, DEPLOY_OS_VERSION, DEPLOY_OS_FAMILY, DEPLOY_ARCH,
#     DEPLOY_PKG_MANAGER if not already set by the deploy tool
#   - Defines pm_install, pm_is_installed, pm_update_cache

# == OS Detection ==============================================================
# Only run detection if the deploy tool hasn't already exported these variables.

if [[ -z "${DEPLOY_PKG_MANAGER:-}" ]]; then

    # /etc/os-release is standard on all modern distros; /usr/lib/os-release is
    # a fallback used on some immutable/atomic distros (e.g. Fedora Silverblue).
    local _osrel=""
    [[ -f /etc/os-release     ]] && _osrel=/etc/os-release
    [[ -z "$_osrel" ]] && [[ -f /usr/lib/os-release ]] && _osrel=/usr/lib/os-release

    if [[ -n "$_osrel" ]]; then
        # shellcheck source=/etc/os-release
        . "$_osrel"
        DEPLOY_OS="${ID:-unknown}"
        # Arch Linux is a rolling release with no VERSION_ID — use BUILD_ID as fallback.
        DEPLOY_OS_VERSION="${VERSION_ID:-${BUILD_ID:-unknown}}"
        # ID_LIKE is space-separated and can contain multiple values:
        #   "ubuntu debian", "rhel centos fedora", "suse opensuse", etc.
        # Keep the full string; callers use substring matching:
        #   [[ "$DEPLOY_OS_FAMILY" == *debian* ]]
        #   [[ "$DEPLOY_OS_FAMILY" == *rhel* ]]
        # Falls back to ID so the pattern works even when ID_LIKE is absent.
        DEPLOY_OS_FAMILY="${ID_LIKE:-${ID:-unknown}}"
    else
        DEPLOY_OS="unknown"
        DEPLOY_OS_VERSION="unknown"
        DEPLOY_OS_FAMILY="unknown"
    fi

    DEPLOY_ARCH="$(uname -m)"

    # Detect package manager — OS identity takes precedence where binary detection
    # would give the wrong answer:
    #
    #   ALT Linux (ID=altlinux): ships apt-get (APT-RPM), but packages are .rpm,
    #   not .deb. dpkg does not exist on ALT Linux. Map to "apt-rpm" so callers
    #   know to use rpm -q for installation checks.
    #
    # For all others: binary presence is reliable. Check dnf before yum because
    # RHEL-family systems often ship a yum compatibility shim alongside dnf.
    if   [[ "${DEPLOY_OS:-}" == "altlinux" ]]; then DEPLOY_PKG_MANAGER="apt-rpm"
    elif command -v apt-get >/dev/null 2>&1;   then DEPLOY_PKG_MANAGER="apt"
    elif command -v dnf     >/dev/null 2>&1;   then DEPLOY_PKG_MANAGER="dnf"
    elif command -v yum     >/dev/null 2>&1;   then DEPLOY_PKG_MANAGER="yum"
    elif command -v zypper  >/dev/null 2>&1;   then DEPLOY_PKG_MANAGER="zypper"
    elif command -v apk     >/dev/null 2>&1;   then DEPLOY_PKG_MANAGER="apk"
    elif command -v pacman  >/dev/null 2>&1;   then DEPLOY_PKG_MANAGER="pacman"
    else                                            DEPLOY_PKG_MANAGER="unknown"
    fi

    export DEPLOY_OS DEPLOY_OS_VERSION DEPLOY_OS_FAMILY DEPLOY_ARCH DEPLOY_PKG_MANAGER

fi

# == Package Manager Abstraction ===============================================

# pm_install <package...>
# Install one or more packages via the detected package manager.
# Runs non-interactively and suppresses confirmations.
pm_install() {
    case "$DEPLOY_PKG_MANAGER" in
        apt)    apt-get install -y "$@" ;;
        dnf)    dnf install -y "$@" ;;
        yum)    yum install -y "$@" ;;
        zypper) zypper install -y "$@" ;;
        apk)    apk add "$@" ;;
        pacman) pacman -S --noconfirm "$@" ;;
        *)
            echo "os-lib: pm_install: unsupported package manager '${DEPLOY_PKG_MANAGER}'." >&2
            echo "os-lib: Install manually: $*" >&2
            return 1
            ;;
    esac
}

# pm_is_installed <package>
# Returns 0 if the package is installed, 1 if not.
# Note: package names differ across distros — this function uses whatever
# name the caller provides. Use the correct name for the current pkg manager.
pm_is_installed() {
    local pkg="$1"
    case "$DEPLOY_PKG_MANAGER" in
        apt)           dpkg -l "$pkg" 2>/dev/null | grep -q "^ii" ;;
        dnf|yum)       rpm -q "$pkg" >/dev/null 2>&1 ;;
        zypper)        rpm -q "$pkg" >/dev/null 2>&1 ;;
        apk)           apk info -e "$pkg" >/dev/null 2>&1 ;;
        pacman)        pacman -Q "$pkg" >/dev/null 2>&1 ;;
        # Fallback: check if the binary exists (best-effort for unknown managers)
        *)             command -v "$pkg" >/dev/null 2>&1 ;;
    esac
}

# pm_update_cache
# Refresh the package index. Equivalent to `apt update`, `dnf makecache`, etc.
# Suppresses output except errors.
pm_update_cache() {
    case "$DEPLOY_PKG_MANAGER" in
        apt)    apt-get update -q ;;
        dnf)    dnf makecache -q ;;
        yum)    yum makecache -q ;;
        zypper) zypper refresh -q ;;
        apk)    apk update -q ;;
        pacman) pacman -Sy --noconfirm ;;
        *)      return 0 ;;
    esac
}
