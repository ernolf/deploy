# mkdeploy

**Package authoring tool for the Mini-Deploy ecosystem.**

`mkdeploy` is the companion tool to `deploy`. While `deploy` is for installing
and managing packages, `mkdeploy` is for creating and publishing them. It
generates the package skeleton, publishes packages as GitHub Gists, and keeps
them in sync.

`mkdeploy` is installed automatically alongside `deploy` when you run
`deploy me`.

---

## Commands

```
mkdeploy init                Create a new package skeleton in the current directory
mkdeploy create              Publish current directory as a new public GitHub Gist
mkdeploy create --secret     Publish as a secret Gist (not listed, but installable by ID)
mkdeploy push                Update the existing Gist for this package
mkdeploy auth                Configure GitHub token
```

---

## GitHub Token

To create or update Gists, `mkdeploy` needs a GitHub Personal Access Token
with `gist` scope. It resolves the token automatically from three sources, in
order:

1. `GITHUB_TOKEN` or `GH_TOKEN` environment variable
2. The configured git credential helper (credentials for `github.com`)
3. `~/.config/deploy/github_token` (set via `mkdeploy auth`)

If you already have git configured to push to GitHub, `mkdeploy` will find
your token automatically — no extra setup needed.

If not, run `mkdeploy auth` once:

```bash
mkdeploy auth
```

It will open the GitHub token creation page, ask you to paste the token, validate
it, and store it at `~/.config/deploy/github_token` (mode 600).

---

## Typical Workflows

### Create a new package from scratch

```bash
mkdir my-package && cd my-package
mkdeploy init
```

`mkdeploy init` asks a few questions interactively and creates:

- **`manifest.json`** — package metadata with dependency placeholders
- **`deploy.sh`** — skeleton with all four required actions (`install`, `remove`,
  `status`, `update`)

`deploy.sh` is created executable and ready to edit.

Then fill in the implementation, and publish:

```bash
mkdeploy create            # public Gist
mkdeploy create --secret   # secret Gist — not listed, but installable by ID
```

This uploads all non-hidden files in the current directory to a new public
GitHub Gist, writes the Gist ID back into `manifest.json`, and prints the
install command:

```
mkdeploy: Gist created:  https://gist.github.com/ernolf/abc123...
mkdeploy: Gist ID:       abc123...
mkdeploy: manifest.json updated with gist ID.

  To install this package on any server:
  deploy install abc123...
```

### Update an existing package

Edit files, then push:

```bash
mkdeploy push
```

`mkdeploy push` reads the Gist ID from `manifest.json` and uploads all current
files. No need for a git clone of the Gist — `mkdeploy` handles the API call
directly.

### Clone → adapt → publish as your own

```bash
# Clone someone else's package
git clone https://gist.github.com/<their-gist-id>.git my-variant
cd my-variant

# Adapt it to your needs
# Edit deploy.sh, manifest.json, ...

# Remove the inherited source so mkdeploy creates a new one
# (edit manifest.json: set "origin": "")

mkdeploy create
# → publishes as your own new Gist
```

---

## What gets uploaded

`mkdeploy create` and `mkdeploy push` upload all files in the current
directory except:

- Hidden files and directories (names starting with `.`, including `.git`)
- Binary files (skipped with a warning — Gists are text-only)

---

## Package structure reference

See [RFC.md](RFC.md) for the full Mini-Deploy Package Standard, including the
complete `manifest.json` schema and the `deploy.sh` interface specification.

---

## Credits

- **Author & Maintainer:** [[ernolf] Raphael Gradenwitz](https://github.com/ernolf)
