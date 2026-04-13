# Gist-Based Mini-Deploy Package Standard

| | |
|---|---|
| **Author** | [ernolf] Raphael Gradenwitz |
| **Date** | April 2026 |
| **Status** | Personal Standard — not submitted to any standards body |
| **Repository** | github.com/ernolf/deploy |

---

**Status of This Memo**

This document is not an Internet Standards Track specification. It is
an informal personal standard published for documentation and
reproducibility purposes. It has not been submitted to the IETF and
carries no official status. Distribution is unlimited.

---

**Abstract**

This document defines a lightweight convention for packaging personal
server configurations, scripts, and system integrations as
self-contained deployable units — stored as GitHub Gists, managed by
the `deploy` command-line tool. The standard covers package structure,
the mandatory `manifest.json` schema, the `deploy.sh` lifecycle
interface, OS environment variables, the OS abstraction library, and
the package registry format.

---

**Table of Contents**

1. [Introduction](#1-introduction)
2. [Core Principles](#2-core-principles)
3. [Package Structure](#3-package-structure)
4. [manifest.json](#4-manifestjson)
5. [deploy.sh Interface](#5-deploysh-interface)
6. [OS Environment](#6-os-environment)
7. [OS Abstraction Library](#7-os-abstraction-library)
8. [Dependency Auto-Installation](#8-dependency-auto-installation)
9. [Platform-Specific Logic](#9-platform-specific-logic)
10. [File Permissions and Ownership](#10-file-permissions-and-ownership)
11. [Bundle Files](#11-bundle-files)
12. [Package Registry](#12-package-registry)
13. [Naming Conventions](#13-naming-conventions)
14. [Conformance Checklist](#14-conformance-checklist)

---

## 1. Introduction

Every Linux system accumulates customizations that don't belong in a
distro package: custom nginx modules, apt hooks, monitoring
integrations, cron jobs, admin scripts. These configurations are
tedious and error-prone to reproduce on a second machine, and are
usually undocumented.

This standard solves that with three goals:

- **One command to install anything:** `deploy install <origin>`
- **One command to update everything:** `deploy update --all`
- **Fully reproducible:** a fresh system is configured by running
  `deploy bundle server.json`

The key words "MUST", "MUST NOT", "REQUIRED", "SHALL", "SHALL NOT",
"SHOULD", "SHOULD NOT", "RECOMMENDED", "MAY", and "OPTIONAL" in this
document are to be interpreted as described in RFC 2119.

---

## 2. Core Principles

### 2.1. Distribution Independence

The `deploy` tool and all conforming packages MUST NOT assume a
specific Linux distribution or package manager. A package MUST run
correctly on any supported system without changes to its code.

The systems a conforming package SHOULD support:

| Family | Package Managers | Examples |
|---|---|---|
| Debian/Ubuntu | `apt` | Ubuntu 22.04, Debian 12 |
| RHEL and derivatives | `dnf`, `yum` | RHEL 9, CentOS Stream, Fedora, Amazon Linux 2023 |
| SUSE | `zypper` | SLES 15, openSUSE Leap |
| Alpine | `apk` | Alpine Linux |
| Arch | `pacman` | Arch Linux, Manjaro |

Distribution-specific logic (e.g., dpkg hooks that only exist on
Debian-family systems) is allowed inside `deploy.sh` but MUST be
guarded by an explicit OS check. See Section 9.

### 2.2. Self-Documenting Packages

A well-written `deploy.sh` is better documentation than a README.
If the `install` action is clear and the `status` action is
informative, the package documents itself. Conforming packages
SHOULD minimize the gap between what the code does and what
documentation says by keeping them in the same place.

---

## 3. Package Structure

A conforming package is a git repository (typically a GitHub Gist)
containing at minimum:

```
<repo>/
├── manifest.json   — required: package metadata and dependency declarations
├── deploy.sh       — required: entry point for all lifecycle actions
└── <other files>   — any scripts, configs, templates the package needs
```

All files MUST live flat at the repository root. GitHub Gists do not
support subdirectories.

---

## 4. manifest.json

### 4.1. Schema

```json
{
  "name":          "nginx-module-vts",
  "version":       "1.0.0",
  "description":   "VTS dynamic module for nginx with auto-rebuild on package upgrades",
  "origin":        "8d16744998afffeb8abb67c41bf29f73",
  "author":        "username",
  "platform":      ["ubuntu:22.04", "debian:12"],
  "requires_root": true,
  "tags":          ["nginx", "monitoring"],
  "dependencies": {
    "apt":    ["build-essential", "libpcre3-dev", "libssl-dev", "zlib1g-dev", "wget", "git"],
    "dnf":    ["gcc", "make", "pcre-devel", "openssl-devel", "zlib-devel", "wget", "git"],
    "zypper": ["gcc", "make", "pcre-devel", "libopenssl-devel", "zlib-devel", "wget", "git"],
    "apk":    ["build-base", "pcre-dev", "openssl-dev", "zlib-dev", "wget", "git"],
    "pacman": ["base-devel", "pcre", "openssl", "zlib", "wget", "git"]
  }
}
```

### 4.2. Field Reference

| Field | Type | Required | Description |
|---|---|---|---|
| `name` | string | REQUIRED | Unique identifier. Lowercase, hyphens only. Used as directory name in the registry. |
| `version` | string | REQUIRED | Semantic version (`MAJOR.MINOR.PATCH`). MUST be incremented on every meaningful change. |
| `description` | string | REQUIRED | One-line description. Shown in `deploy list`. |
| `origin` | string | REQUIRED | Package origin: a bare Gist ID (hex string) or any full Git URL (`https://`, `git@`). Used by `mkdeploy push` to identify where to publish updates. |
| `author` | string | OPTIONAL | GitHub username or full name. |
| `platform` | array | OPTIONAL | Platforms this package has been tested on (`os:version`). Purely informational — does not restrict installation. |
| `requires_root` | bool | OPTIONAL | Whether `deploy.sh` MUST run as root. The `deploy` tool enforces this before calling `deploy.sh`. |
| `tags` | array | OPTIONAL | Free-form tags. |
| `dependencies` | object | OPTIONAL | Map of package manager name → array of package names. The `deploy` tool auto-installs missing dependencies before calling `deploy.sh install` or `deploy.sh update`. MUST only list packages available in the distribution's standard repository. Packages requiring special repository configuration MUST be handled explicitly in `deploy.sh`. |

### 4.3. Versioning

The `version` field MUST be incremented when:

- `install` behavior changes (new files, new symlinks, new config)
- `remove` behavior changes
- Any file that is deployed to the system changes

The `version` field SHOULD NOT be changed for documentation-only
changes.

---

## 5. deploy.sh Interface

`deploy.sh` is the single entry point for all lifecycle operations.
It MUST accept exactly one positional argument — the action name.

### 5.1. Required Actions

| Action | Description |
|---|---|
| `install` | Full installation: create directories, install files/symlinks, start services. MUST be idempotent. |
| `remove` | Undo everything `install` did. MUST leave no orphaned files. |
| `status` | Print a human-readable status summary to stdout. MUST exit 0 if healthy, 1 if not installed, 2 if installed but broken. |
| `update` | Called by `deploy` after `git pull`. Reinstall files/symlinks as needed, restart services if config changed. MUST be idempotent. |

### 5.2. Exit Codes

| Code | Meaning |
|---|---|
| 0 | Success (or: healthy, for `status`) |
| 1 | Not installed / precondition not met (for `status`) |
| 2 | Error / installed but broken (for `status`) |
| Any non-zero | General failure for `install`, `remove`, `update` |

### 5.3. Logging

- All output MUST go to stdout/stderr. The `deploy` tool captures and
  logs it.
- Log lines for `install`, `remove`, `update` SHOULD be prefixed with
  a timestamp: `[2026-04-11 20:00:00] message`
- `status` output is not logged — it is shown directly to the user.

### 5.4. Idempotency

Both `install` and `update` MUST be safe to run multiple times:

- Check before creating: don't fail if a directory already exists
  (`mkdir -p`)
- Recreate symlinks: remove old link before creating new one
- Don't reinstall if already at the correct state

### 5.5. Self-Location

`deploy.sh` MUST determine its own directory at runtime to reference
sibling files (e.g. `hook.sh`, configuration templates):

```bash
PACKAGE_DIR="$(cd "$(dirname "$0")" && pwd)"
```

This ensures the package works regardless of where `deploy` cloned it.

---

## 6. OS Environment

Before calling `deploy.sh` for any action, the `deploy` tool detects
the current OS and exports the following environment variables:

| Variable | Example values | Description |
|---|---|---|
| `DEPLOY_OS` | `ubuntu`, `debian`, `rhel`, `fedora`, `alpine`, `sles`, `arch` | OS identifier from `/etc/os-release` (`$ID`) |
| `DEPLOY_OS_VERSION` | `22.04`, `12`, `9`, `3.19` | OS version from `/etc/os-release` (`$VERSION_ID`) |
| `DEPLOY_OS_FAMILY` | `debian`, `rhel fedora`, `suse` | OS family (`$ID_LIKE`, falls back to `$ID`). Space-separated; use substring matching: `[[ "$DEPLOY_OS_FAMILY" == *debian* ]]` |
| `DEPLOY_PKG_MANAGER` | `apt`, `dnf`, `yum`, `zypper`, `apk`, `pacman` | Detected package manager |
| `DEPLOY_ARCH` | `x86_64`, `aarch64`, `armv7l` | CPU architecture from `uname -m` |
| `DEPLOY_LIB` | `/var/lib/deploy/lib` | Path to the deploy OS abstraction library |

These variables are available to `deploy.sh` without any additional
setup.

---

## 7. OS Abstraction Library

The `deploy` tool installs an OS abstraction library at
`/var/lib/deploy/lib/os-lib.sh`. Any `deploy.sh` SHOULD source it to
get distribution-agnostic package management functions:

```bash
# Source at the top of deploy.sh
# shellcheck source=/var/lib/deploy/lib/os-lib.sh
. "${DEPLOY_LIB}/os-lib.sh"
```

### 7.1. Available Functions

| Function | Description |
|---|---|
| `pm_install <pkg...>` | Install one or more packages via the detected package manager |
| `pm_is_installed <pkg>` | Returns 0 if the package is installed, 1 if not |
| `pm_update_cache` | Update the package index (`apt update`, `dnf makecache`, etc.) |

### 7.2. Example Usage

```bash
. "${DEPLOY_LIB}/os-lib.sh"

# Install a package if not already present
pm_is_installed wget || pm_install wget

# Or let deploy handle it automatically via manifest.json dependencies —
# explicit pm_install calls are only needed for conditional or complex cases.
```

---

## 8. Dependency Auto-Installation

When `deploy.sh install` or `deploy.sh update` is called, the `deploy`
tool first reads the `dependencies` field from `manifest.json` and
installs any missing packages using the current package manager.

This happens BEFORE `deploy.sh` is called. `deploy.sh` MAY therefore
assume that all declared dependencies are already installed.

```
deploy install <origin>
  1. resolve platform from origin (gist ID or URL)
  2. clone repository
  3. read manifest.json
  4. detect OS and package manager
  5. install missing packages from dependencies[<pkg-manager>]
  6. call deploy.sh install
```

Packages that require repository configuration before installation
(e.g. nginx.org mainline, EPEL) MUST NOT be declared in `dependencies`
and MUST be handled explicitly in `deploy.sh install`.

---

## 9. Platform-Specific Logic

Distribution-specific code is allowed and expected in `deploy.sh`.
All platform-specific code MUST be guarded by the `DEPLOY_PKG_MANAGER`
or `DEPLOY_OS_FAMILY` variables:

```bash
# Example: install a package manager hook only where it makes sense
case "$DEPLOY_PKG_MANAGER" in
    apt)
        # DPkg::Post-Invoke hooks — Debian/Ubuntu only
        install_dpkg_hook
        ;;
    dnf|yum)
        # DNF plugins / transaction hooks — RHEL family
        install_dnf_hook
        ;;
    apk)
        # apk does not support post-install hooks — use a different mechanism
        install_openrc_trigger
        ;;
    *)
        log "WARNING: No package manager hook available for ${DEPLOY_PKG_MANAGER}."
        log "         Auto-rebuild will not trigger on package updates."
        log "         Run manually after nginx updates: ${HOOK_DIR}/rebuild.sh"
        ;;
esac
```

The `platform` field in `manifest.json` is informational only — it
MUST NOT prevent installation on unlisted platforms.

---

## 10. File Permissions and Ownership

Git stores only the executable bit (mode 644 or 755). Ownership is
never stored in git. `deploy.sh` is REQUIRED to set the correct modes
and ownership on every file it deploys.

### 10.1. Conventions

```bash
# Scripts that are called directly:
chmod 755 /usr/local/lib/mypackage/script.sh

# Config files:
chmod 644 /etc/mypackage/config

# Sensitive files (credentials, keys):
chmod 600 /etc/mypackage/secret.conf
chown root:root /etc/mypackage/secret.conf

# Symlinks that must be owned by a specific service user:
sudo -u www-data ln -sf /path/to/source /home/www-data/link
```

### 10.2. Symlink Ownership

Symlinks belong permanently to the user that created them (`ln -s`).
This is a Linux kernel invariant — `chown` on a symlink changes the
target, not the link itself. When a symlink MUST be owned by a
specific user, use `sudo -u <user> ln -sf ...`.

### 10.3. Git Executable Bit

Scripts MUST be marked executable in git before committing:

```bash
git add deploy.sh hook.sh
git update-index --chmod=+x deploy.sh hook.sh
git commit -m "chore: mark scripts executable"
```

---

## 11. Bundle Files

A bundle file allows installing a set of packages in one command
(`deploy bundle server.json`):

```json
{
  "description": "optiplex-380-0 base configuration",
  "packages": [
    {"origin": "8d16744998afffeb8abb67c41bf29f73"},
    {"origin": "https://codeberg.org/user/another-package"}
  ]
}
```

Packages are installed in order. The `deploy` tool MUST stop on first
failure unless `--continue-on-error` is passed.

---

## 12. Package Registry

The `deploy` tool maintains a registry at `/var/lib/deploy/registry.json`:

```json
{
  "version": 1,
  "packages": {
    "nginx-module-vts": {
      "name":         "nginx-module-vts",
      "origin":       "8d16744998afffeb8abb67c41bf29f73",
      "version":      "1.0.0",
      "description":  "VTS dynamic module for nginx with auto-rebuild on package upgrades",
      "path":         "/var/lib/deploy/packages/nginx-module-vts",
      "installed_at": "2026-04-11T20:00:00Z",
      "updated_at":   "2026-04-11T20:00:00Z"
    }
  }
}
```

The package clone lives permanently at `path` — this is what
`deploy update` pulls into and what `deploy.sh` is called from.

---

## 13. Naming Conventions

| Item | Convention | Example |
|---|---|---|
| Package name | lowercase, hyphens | `nginx-module-vts` |
| Gist repo | same as package name preferred | — |
| Script files | lowercase, hyphens, `.sh` | `hook.sh`, `deploy.sh` |
| Config files | lowercase, hyphens, `.conf` | `apt-hook.conf` |
| Version tags (git) | `v1.0.0` | `git tag v1.0.0` |

---

## 14. Conformance Checklist

```
[ ] manifest.json with all required fields
[ ] dependencies declared per package manager (apt, dnf, zypper, apk ...)
[ ] deploy.sh implementing install / remove / status / update
[ ] deploy.sh is idempotent (safe to run twice)
[ ] deploy.sh sources ${DEPLOY_LIB}/os-lib.sh for package management
[ ] Platform-specific code guarded by $DEPLOY_PKG_MANAGER or $DEPLOY_OS_FAMILY
[ ] Package manager hooks (dpkg, dnf) only installed where applicable
[ ] All deployed files have explicit chmod/chown calls
[ ] Symlinks that need a specific owner use sudo -u <user>
[ ] deploy.sh and all executable scripts committed with +x bit
[ ] status exits 0/1/2 correctly
[ ] remove undoes everything install did
[ ] Tested on a clean system
```

---

**Author's Address**

```
[ernolf] Raphael Gradenwitz
GitHub: github.com/ernolf
```

---

## Credits

- **Author & Maintainer:** [[ernolf] Raphael Gradenwitz](https://github.com/ernolf)
