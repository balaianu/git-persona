# git-persona

> **Never commit with the wrong Git identity again.**
>
> Automatically switch Git name, email, and SSH key based on repository location using Git's built-in `includeIf` feature.

[![Tests](https://github.com/balaianu/git-persona/actions/workflows/tests.yml/badge.svg)](https://github.com/balaianu/git-persona/actions/workflows/tests.yml)
[![License: MIT](https://img.shields.io/badge/License-MIT-blue.svg)](https://opensource.org/licenses/MIT)
[![Version](https://img.shields.io/github/v/release/balaianu/git-persona?color=green)](https://github.com/balaianu/git-persona/releases)
[![Bash](https://img.shields.io/badge/bash-3.2%2B-green.svg)](https://www.gnu.org/software/bash/)
[![Buy Me A Coffee](https://img.shields.io/badge/☕-Buy%20Me%20A%20Coffee-yellow)](https://buymeacoffee.com/balaianu)

---

## The problem

You have a work GitHub account and a personal GitHub account. You clone repos into different folders. But every now and then, you commit to a personal repo with your work email — or worse, commit to a work repo with your personal email. Now your commit history is wrong, and fixing it means rewriting history.

Managing this manually is error-prone:

```bash
git config user.name "Work Name"
git config user.email work@example.com
git config core.sshCommand "ssh -i ~/.ssh/id_ed25519_work"
# ... repeat for every single repo
```

## The solution

`git-persona` creates identity profiles and wires them up to folders. Any repo under a profile's folder **automatically** uses the right name, email, and SSH key. No per-repo config needed.

```bash
git persona create work "Work Name" work@example.com ~/dev/work
git persona create personal "Personal Name" personal@example.com ~/dev/personal
```

Now every repo under `~/dev/work/` uses your work identity. Every repo under `~/dev/personal/` uses your personal identity. Done.

## Features

- Automatic identity switching using Git's native `includeIf`
- Automatic SSH key generation per profile
- Per-repository profile overrides
- Current profile detection
- Native Git subcommand (`git persona`)
- Zero runtime dependencies (pure Bash)
- Linux, macOS, and WSL support

## Table of contents

- [Requirements](#requirements)
- [Compatibility](#compatibility)
- [Installation](#installation)
- [Quick Start](#quick-start)
- [Command reference](#command-reference)
- [How it works](#how-it-works)
- [File locations](#file-locations)
- [Testing](#testing)
- [Changelog](#changelog)
- [Contributing](#contributing)
- [License](#license)
- [Support](#support)

## Requirements

- Bash 3.2+
- Git 2.13+ (for `includeIf` support)
- OpenSSH (for `ssh-keygen`)

## Compatibility

| Platform | Status | Notes |
|---|---|---|
| Linux (Ubuntu, Debian, Fedora, Arch, etc.) | ✅ Fully supported | |
| Alpine Linux | ✅ Fully supported | Pure bash, no GNU sed needed |
| macOS | ✅ Fully supported | Uses built-in bash (or Homebrew bash 5+) |
| Windows (WSL) | ✅ Fully supported | Same as Linux |
| Windows (Git Bash) | ⚠️ Expected to work (untested) | Comes with Git for Windows. See note below |
| Windows (PowerShell/cmd) | ❌ Not supported | Use Git Bash or WSL |

**Windows with Git Bash:** Expected to work but not yet tested. Git for Windows includes a full bash environment with `ssh-keygen` and all required tools. There may be a path format mismatch between Git Bash's MSYS-style paths (`/c/Users/...`) and what Git's `includeIf` expects on Windows. Install via the one-liner from a Git Bash terminal. If you test it, please open an issue with your results.

## Installation

### One-liner (recommended)

```bash
curl -fsSL https://raw.githubusercontent.com/balaianu/git-persona/main/install.sh | bash
```

Downloads the script and installs it to `~/.local/bin/git-persona`. No cloning required.

### From source

```bash
git clone https://github.com/balaianu/git-persona.git
cd git-persona
make install
```

This installs `git-persona` to `~/.local/bin/` by default. Make sure that directory is in your `PATH`:

```bash
echo 'export PATH="$HOME/.local/bin:$PATH"' >> ~/.bashrc
source ~/.bashrc
```

### Custom install location

```bash
make install PREFIX=/usr/local
```

## Update

```bash
cd git-persona
git pull
make update
```

## Uninstall

```bash
cd git-persona
make uninstall
```

This removes the script from `~/.local/bin/`. Profile data in `~/.config/git-persona/` is not removed. To remove all profile data:

```bash
rm -rf ~/.config/git-persona
```

## Quick Start

Create two identities:

```bash
git persona create work "Work Name" work@example.com ~/dev/work
git persona create personal "Personal Name" personal@example.com ~/dev/personal
```

Add the printed SSH public keys to the corresponding GitHub accounts, then clone repos into the matching folders. Every repo under `~/dev/work/` automatically uses your work identity; every repo under `~/dev/personal/` uses your personal one.

Verify the active profile:

```bash
git persona current
```

List configured profiles:

```bash
git persona list
```

Apply a profile manually to the current repository:

```bash
git persona use work
```

See the [Command reference](#command-reference) below for all commands and flags.

## Command reference

Since the script is named `git-persona`, Git automatically recognizes it as a subcommand. Both forms work identically:

```bash
git persona create work "Name" work@example.com ~/dev/work   # recommended
git-persona create work "Name" work@example.com ~/dev/work   # also works
```

### Create a profile

```bash
git persona create work "Work Name" work@example.com ~/dev/work
```

This will:
1. Generate an SSH key at `~/.ssh/id_ed25519_git_work`
2. Create a profile config at `~/.config/git-persona/profiles/work.gitconfig`
3. Add an `includeIf` rule to `~/.gitconfig` for `~/dev/work/`
4. Print the public key for you to add to GitHub

Add the printed public key to your GitHub account under **Settings > SSH and GPG keys**.

To skip SSH key generation (e.g. if you already have a key or use HTTPS):

```bash
git persona create work "Work Name" work@example.com ~/dev/work --no-ssh-key
```

The profile will only set `user.name` and `user.email`, without `core.sshCommand`.

### List profiles

```bash
git persona list
```

```
Profiles:
  work
    name:     Work Name
    email:    work@example.com
    base_dir: /home/user/dev/work
    key:      /home/user/.ssh/id_ed25519_git_work
  personal
    name:     Personal Name
    email:    personal@example.com
    base_dir: /home/user/dev/personal
    key:      /home/user/.ssh/id_ed25519_git_personal
```

### Apply a profile to the current repo

```bash
cd ~/some-repo
git persona use work
```

### Apply a profile to a folder

```bash
git persona use-folder work ~/projects/client-a
```

Any git repo under `~/projects/client-a/` will automatically use the `work` profile.

### Show the current profile

```bash
git persona current
```

```
Current profile: work
  name:  Work Name
  email: work@example.com
  key:   /home/user/.ssh/id_ed25519_git_work
```

### Print the agent manual

```bash
git persona skill
```

Prints a manual written for AI agents: the rules an agent must follow when working in a git-persona environment, the command surface, and diagnostics. The manual is embedded in the script itself, so every install self-documents at exactly the version installed — point your agent at `git persona skill` and it gets ground truth for the version you run.

### Delete a profile

```bash
git persona delete work
```

This removes the profile config and `includeIf` entries. By default, the SSH key is **kept** — deleting it could break access to remote repos if the key is in use. The base directory is not removed.

To also remove the SSH key pair:

```bash
git persona delete work --with-keys
```

### Show version

```bash
git persona version
```

## How it works

`git-persona` uses Git's built-in `includeIf` directive to apply different configs based on directory paths.

When you create a profile, it generates:

```
~/.config/git-persona/
  profiles/
    work.conf               # profile metadata (key=value)
    work.gitconfig          # profile-specific git config
    personal.conf           # profile metadata (key=value)
    personal.gitconfig      # profile-specific git config
```

And adds to `~/.gitconfig`:

```ini
[includeIf "gitdir:/home/user/dev/work/"]
    path = /home/user/.config/git-persona/profiles/work.gitconfig

[includeIf "gitdir:/home/user/dev/personal/"]
    path = /home/user/.config/git-persona/profiles/personal.gitconfig
```

Each profile config sets `user.name`, `user.email`, and `core.sshCommand`:

```ini
[user]
    name = Work Name
    email = work@example.com
[core]
    sshCommand = ssh -i '/home/user/.ssh/id_ed25519_git_work' -o IdentitiesOnly=yes
```

So any repo under `~/dev/work/` automatically uses the work identity and SSH key. No per-repo config needed.

## File locations

| Path | Purpose |
|---|---|
| `~/.local/bin/git-persona` | The script |
| `~/.config/git-persona/profiles/<id>.conf` | Per-profile metadata (key=value) |
| `~/.config/git-persona/profiles/<id>.gitconfig` | Per-profile Git config |
| `~/.ssh/id_ed25519_git_<id>` | Per-profile SSH key |
| `~/.gitconfig` | Modified with `includeIf` entries |

## Testing

```bash
make test
```

Or directly:

```bash
bash tests/test_basic.sh
```

The test suite runs in an isolated temp directory and won't touch your real profiles or SSH keys.

## Changelog

See [CHANGELOG.md](CHANGELOG.md) for version history.

## Contributing

See [Contributing Guide](docs/contributing.md) for development setup, testing, and code style.

Pull requests are welcome. Please ensure tests pass before submitting.

## Documentation

- [Usage Guide](docs/usage.md) — detailed command reference
- [Configuration](docs/configuration.md) — file locations and internals
- [Contributing](docs/contributing.md) — development setup and guidelines
- [Changelog](CHANGELOG.md) — version history
- [Code of Conduct](CODE_OF_CONDUCT.md) — community standards

## License

MIT — see [LICENSE](LICENSE)

## Support

If you find this tool useful, consider buying me a coffee:

[![Buy Me A Coffee](https://img.shields.io/badge/☕-Buy%20Me%20A%20Coffee-yellow)](https://buymeacoffee.com/balaianu)
