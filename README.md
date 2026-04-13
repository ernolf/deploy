# deploy

**One command to install anything. Server configs, tools, AI coding assistant skills — all based on one open standard.**

```bash
deploy install 8d16744998afffeb8abb67c41bf29f73          # a server package
deploy install 5ea566c2dcbdef0ddf271831235bffaf          # a Claude Code skill
deploy install https://codeberg.org/user/my-package      # a full Git repo
```

That's it. The package gets cloned, dependencies get installed, and your
`deploy.sh` runs. On any server, any distro, reproducibly.

---

## Two problems. One tool.

### The server admin problem

Every server accumulates custom setups that no distro packages for you: a
module compiled against the exact installed version, a package manager hook
that rebuilds it automatically on upgrades, a monitoring integration wired to
your specific stack. These things work — until you provision a second server,
and you spend hours reconstructing what you did years ago from memory and shell
history. On long-running LTS systems, that accumulated knowledge can be half a
decade old.

### The AI skill problem

AI coding assistants now ship with extensible skill systems. Installing a skill
still means finding a GitHub repo, reading a README, copying files to the right
directory, and hoping the instructions are still current. There is no standard,
no package manager, no versioning, no `remove` command. Every skill author
invents their own distribution method.

**deploy solves both with the same mechanism** — a shell script and a manifest,
hosted anywhere git can reach.

---

## The first open-standard skill installer

`deploy` is the first package manager that treats AI coding assistant skills
as first-class installable packages. A skill is just a deploy package that
happens to copy a file into `~/.claude/skills/` — which means it gets all the
same guarantees as any other package:

- **Versioned.** `deploy update my-skill` pulls the latest and re-installs.
- **Removable.** `deploy remove my-skill` cleans up completely.
- **Inspectable.** `deploy inspect <id>` shows you exactly what will be installed
  before anything runs.
- **Bundleable.** List your entire AI toolset in a `skills.json` and install
  everything in one shot on a new machine.
- **Based on an open standard.** The [Mini-Deploy Package Standard](RFC.md)
  is fully documented. Anyone can write a skill package, publish it as a Gist,
  and share it with a single ID — no registry, no approval process, no account
  required beyond a GitHub login.

There is no competing tool that does this. Skill distribution today is README
files and manual copy-paste.

---

## How it works

A deploy package is a git repository (a GitHub Gist, a GitHub repo, a
Codeberg repo, or any public Git URL) with two required files:

| File | Purpose |
|---|---|
| `manifest.json` | Package name, version, description, dependencies per package manager |
| `deploy.sh` | Shell script implementing `install`, `remove`, `status`, `update` |

`deploy` clones the repository, reads the manifest, installs any missing
system packages, shows you a summary, asks for confirmation, and then calls
`deploy.sh install`. The package itself decides what that means — copy files,
symlink binaries, write configs, enable services, register apt hooks, install
a Claude Code skill. Anything a shell script can do.

```
deploy inspect <id|url>       # show package info and deploy.sh — nothing runs
deploy install <id|url>       # clone, confirm, install
deploy update  <name>         # git pull + re-run deploy.sh update
deploy status  <name>         # health check
deploy remove  <name>         # clean uninstall
deploy list                   # all installed packages
deploy bundle  <bundle.json>  # install everything from a list
deploy platforms              # list supported source platforms
```

---

## What makes it different

**No central registry.** Packages live on GitHub Gists, GitHub repos,
Codeberg, or any public Git URL. You control your packages. No one can take
them down, change them without your knowledge, or disappear. `deploy platforms`
lists all supported formats.

**Inspect before you run.** `deploy inspect <id>` clones the package to a
temporary directory, prints the manifest and the full `deploy.sh`, then cleans
up — without executing a single line of the package. Only `deploy install`
runs anything, and only after you confirm.

**The standard is open.** The [Mini-Deploy Package Standard](RFC.md) defines
exactly what a valid package looks like. Any package that conforms works with
`deploy`. Fork it, extend it, build tooling around it.

**Distribution-independent.** `deploy` detects the OS and package manager at
startup and exports `DEPLOY_OS`, `DEPLOY_PKG_MANAGER`, and related variables
to every `deploy.sh` it runs. One package can handle Debian, RHEL, Alpine, and
Arch without a single `if [ -f /etc/debian_version ]` hack.

**No dependencies.** Python 3.6+ and `git`. That's it. No `jq`, no `curl`,
no package manager wrappers. Works on any Linux system that can run Python.

---

## Requirements

- Python 3.6+
- `git`

---

## Installation

```bash
# Download
curl -fsSL https://raw.githubusercontent.com/ernolf/deploy_test/main/deploy -o deploy

# Self-install: copies binary to /usr/local/bin, fetches os-lib.sh, sets up directories
sudo python3 deploy me
```

After that, both `deploy` and `mkdeploy` are available system-wide:

```bash
deploy --help
mkdeploy --help
```

To update both tools later:

```bash
sudo deploy update me
```

---

## Installing a Claude Code skill

Any Claude Code skill published as a deploy package installs with one command:

```bash
sudo deploy install <gist-id>
```

The skill is immediately available as a `/slash-command` in your next Claude
Code session. To update it when the author pushes changes:

```bash
sudo deploy update <skill-name>
```

To remove it:

```bash
sudo deploy remove <skill-name>
```

### Available skills

| Skill | ID | What it does |
|---|---|---|
| `mkdeploy-skill` | `5ea566c2dcbdef0ddf271831235bffaf` | `/mkdeploy` — generate a complete deploy package from a description |

---

## Writing a package

Use **[mkdeploy](mkdeploy.md)** to create and publish packages. It generates
the skeleton, creates the GitHub Gist, and keeps it in sync — all from the
command line without touching the GitHub website.

```bash
mkdir my-package && cd my-package
mkdeploy init                # interactive skeleton generator
# ... implement deploy.sh ...
mkdeploy create              # publish as a public GitHub Gist
mkdeploy create --secret     # or as a secret Gist (not listed, installable by ID)
```

See [mkdeploy.md](mkdeploy.md) for the full authoring workflow and
[RFC.md](RFC.md) for the package specification.

A minimal package looks like this:

**`manifest.json`**
```json
{
  "name":          "my-package",
  "version":       "1.0.0",
  "description":   "Does something useful",
  "origin":        "",
  "author":        "your-username",
  "requires_root": true,
  "dependencies": {
    "apt":    ["wget", "git"],
    "dnf":    ["wget", "git"],
    "pacman": ["wget", "git"]
  }
}
```

**`deploy.sh`**
```bash
#!/usr/bin/env bash
set -euo pipefail
PACKAGE_DIR="$(cd "$(dirname "$0")" && pwd)"
. "${DEPLOY_LIB}/os-lib.sh"

case "${1:-}" in
    install) echo "Installing ..." ;;
    remove)  echo "Removing ..."  ;;
    status)  echo "Status ..."    ;;
    update)  echo "Updating ..."  ;;
    *) echo "Usage: deploy.sh <install|remove|status|update>" >&2; exit 1 ;;
esac
```

---

## Writing a package with AI assistance

I'll be honest: I am not a fan of vibe coding or AI-generated code as a
general practice. But I'm also a realist — having an LLM write your code has
become standard for a large part of the developer community, and that
development is here to stay. Given that, I would rather contribute to making
sure the AI at least gets fed the right context than pretend the practice
doesn't exist. A package generated from a well-informed prompt is considerably
more likely to be correct than one generated from nothing.

### Option A — Claude Code skill (recommended)

Install the `mkdeploy-skill` package. It adds a `/mkdeploy` slash command to
Claude Code with the full package standard pre-loaded as context:

```bash
sudo deploy install 5ea566c2dcbdef0ddf271831235bffaf
```

Then, in any Claude Code session:

```
/mkdeploy nginx reverse proxy with rate limiting and fail2ban integration
```

Claude generates a fully conformant `manifest.json` and `deploy.sh` in one
pass, ready to publish with `mkdeploy create`.

### Option B — any other AI assistant

Paste the following context block before describing your package:

````
I need a deploy package conforming to the Mini-Deploy Package Standard.

A package consists of two files:

**manifest.json** — required fields:
  name          string   unique identifier, lowercase, hyphens only
  version       string   semver (1.0.0)
  description   string   one-line description
  origin        string   leave empty (""), filled automatically on publish
  author        string   your name or username
  requires_root bool     true if deploy.sh must run as root
  dependencies  object   map of package manager → array of package names
                         Keys: apt, dnf, zypper, apk, pacman

**deploy.sh** — must implement exactly these four actions:
  install   install the software and register any hooks
  remove    cleanly undo everything install did
  status    print a health summary; exit 0 if OK, non-zero if not
  update    re-apply after git pull (deploy already pulled)

Shell conventions:
  - Shebang: #!/usr/bin/env bash
  - set -euo pipefail at the top
  - PACKAGE_DIR="$(cd "$(dirname "$0")" && pwd)"
  - Source the OS abstraction library: . "${DEPLOY_LIB}/os-lib.sh"
  - Section separators: # == Title =====... (equals signs, not dashes)
  - Helper functions: log(), die(), ok(), nok() as defined in the template

Environment variables available in deploy.sh:
  DEPLOY_OS, DEPLOY_OS_VERSION, DEPLOY_OS_FAMILY, DEPLOY_ARCH,
  DEPLOY_PKG_MANAGER, DEPLOY_LIB

Functions from os-lib.sh (already sourced):
  pm_install <pkg...>    non-interactive package install
  pm_is_installed <pkg>  returns 0 if installed
  pm_update_cache        refresh package index
````

For the full behavioral specification — idempotency, exit codes, status format
— see [RFC.md](RFC.md).

---

## Bundle files

Install a complete server setup or skill collection in one shot:

**`server.json`**
```json
{
  "description": "my-server base configuration",
  "packages": [
    {"origin": "8d16744998afffeb8abb67c41bf29f73"},
    {"origin": "https://codeberg.org/user/another-package"}
  ]
}
```

**`skills.json`**
```json
{
  "description": "my AI assistant skill set",
  "packages": [
    {"origin": "5ea566c2dcbdef0ddf271831235bffaf"}
  ]
}
```

```bash
sudo deploy bundle server.json
sudo deploy bundle skills.json
```

---

## License

MIT — see [LICENSE](LICENSE).

---

## Credits

- **Author & Maintainer:** [[ernolf] Raphael Gradenwitz](https://github.com/ernolf)
