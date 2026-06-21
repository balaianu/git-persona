# Configuration

## File locations

### Script

```
~/.local/bin/git-persona
```

### Profile metadata

```
~/.config/git-persona/profiles/<id>.conf
```

Each file is a simple key=value file that bash can source:

```ini
id="work"
name="Work Name"
email="work@example.com"
base_dir="/home/andy/dev/work"
key_file="/home/andy/.ssh/id_ed25519_git_work"
profile_file="/home/andy/.config/git-persona/profiles/work.gitconfig"
```

### Profile configs

```
~/.config/git-persona/profiles/<id>.gitconfig
```

Each file contains the Git config for that profile. With SSH key (default):

```ini
[user]
    name = Work Name
    email = work@example.com
[core]
    sshCommand = ssh -i /home/andy/.ssh/id_ed25519_git_work -o IdentitiesOnly=yes
```

Without SSH key (`--no-ssh-key`):

```ini
[user]
    name = Work Name
    email = work@example.com
```

### SSH keys

```
~/.ssh/id_ed25519_git_<id>
~/.ssh/id_ed25519_git_<id>.pub
```

Keys are named with a `git_` prefix to distinguish them from other SSH keys.

### Main Git config

```
~/.gitconfig
```

`git-persona` adds `includeIf` blocks to this file:

```ini
[includeIf "gitdir:/home/andy/dev/work/"]
    path = /home/andy/.config/git-persona/profiles/work.gitconfig
```

## How includeIf works

Git's `includeIf` directive applies a config file only when the current repository is under the specified path.

The `gitdir:` pattern matches any git repo whose working tree is under the given directory. The trailing `/` is important — it ensures subdirectories are matched.

When you run `git config user.email` inside a repo under `~/dev/work/`, Git checks the `includeIf` rules, finds a match, loads `work.gitconfig`, and returns `work@example.com`.

## Multiple folders per profile

A single profile can be applied to multiple folders:

```bash
git-persona use-folder work ~/dev/work
git-persona use-folder work ~/projects/client-a
git-persona use-folder work ~/projects/client-b
```

This adds multiple `includeIf` entries pointing to the same profile config.

## Custom install location

By default, the script installs to `~/.local/bin/`. To install elsewhere:

```bash
make install PREFIX=/usr/local
```

## Removing all data

To remove everything `git-persona` has created:

```bash
git-persona delete work
git-persona delete personal
# ... repeat for all profiles

rm -rf ~/.config/git-persona
```

Then manually remove any `includeIf` entries from `~/.gitconfig` that reference `git-persona` profile files.

## Dependencies

`git-persona` has no external dependencies beyond standard system tools:

- **bash** 4.0+ — the script itself
- **git** 2.13+ — for `includeIf` support and config manipulation
- **openssh** — for `ssh-keygen` to generate SSH keys

No Python, no jq, no sed, no extra packages needed. Works on any Linux (including Alpine) and macOS.
