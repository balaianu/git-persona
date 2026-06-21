# git-persona

A CLI tool to manage multiple Git identities with SSH keys and `includeIf` automation.

## Why

If you work with multiple GitHub accounts (work, personal, open-source), you need different `user.name`, `user.email`, and SSH keys per repository. Doing this manually is error-prone and tedious.

`git-persona` automates the entire workflow:

- Generates SSH keys for each identity
- Creates profile-specific Git configs
- Wires up `includeIf` rules so repos in specific folders automatically use the right identity
- Lets you manually apply a profile to any repo or folder

## Features

- Create, list, and delete Git identity profiles
- Automatic SSH key generation (ed25519) per profile
- Folder-based automatic identity switching via `includeIf`
- Per-repo manual identity application
- Show which profile applies to the current directory
- No runtime dependencies beyond `bash`, `git`, `ssh-keygen`, and `python3`

## Requirements

- Bash 4.0+
- Git 2.13+ (for `includeIf` support)
- OpenSSH (for `ssh-keygen`)
- Python 3.6+ (for JSON parsing)

## Installation

### From source

```bash
git clone git@github.com:balaianu/git-persona.git
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

## Usage

### Create a profile

```bash
git-persona create work "Work Name" work@example.com ~/dev/work
```

This will:
1. Generate an SSH key at `~/.ssh/id_ed25519_git_work`
2. Create a profile config at `~/.config/git-persona/profiles/work.gitconfig`
3. Add an `includeIf` rule to `~/.gitconfig` for `~/dev/work/`
4. Print the public key for you to add to GitHub

Add the printed public key to your GitHub account under **Settings > SSH and GPG keys**.

### List profiles

```bash
git-persona list
```

### Apply a profile to the current repo

```bash
cd ~/some-repo
git-persona use work
```

### Apply a profile to a folder

```bash
git-persona use-folder work ~/projects/client-a
```

Any git repo under `~/projects/client-a/` will automatically use the `work` profile.

### Show the current profile

```bash
git-persona current
```

### Delete a profile

```bash
git-persona delete work
```

This removes the SSH key, profile config, and `includeIf` entries. The base directory is not removed.

### Show version

```bash
git-persona version
```

## How it works

`git-persona` uses Git's built-in `includeIf` directive to apply different configs based on directory paths.

When you create a profile, it generates:

```
~/.config/git-persona/
  profiles.json              # profile database
  profiles/
    work.gitconfig           # profile-specific git config
    personal.gitconfig       # profile-specific git config
```

And adds to `~/.gitconfig`:

```ini
[includeIf "gitdir:/home/andy/dev/work/"]
    path = /home/andy/.config/git-persona/profiles/work.gitconfig

[includeIf "gitdir:/home/andy/dev/personal/"]
    path = /home/andy/.config/git-persona/profiles/personal.gitconfig
```

Each profile config sets `user.name`, `user.email`, and `core.sshCommand`:

```ini
[user]
    name = Work Name
    email = work@example.com
[core]
    sshCommand = ssh -i /home/andy/.ssh/id_ed25519_git_work -o IdentitiesOnly=yes
```

So any repo under `~/dev/work/` automatically uses the work identity and SSH key.

## File locations

| Path | Purpose |
|---|---|
| `~/.local/bin/git-persona` | The script |
| `~/.config/git-persona/profiles.json` | Profile database |
| `~/.config/git-persona/profiles/<id>.gitconfig` | Per-profile Git config |
| `~/.ssh/id_ed25519_git_<id>` | Per-profile SSH key |
| `~/.gitconfig` | Modified with `includeIf` entries |

## Documentation

- [Usage Guide](docs/usage.md)
- [Configuration](docs/configuration.md)
- [Contributing](docs/contributing.md)

## License

MIT
