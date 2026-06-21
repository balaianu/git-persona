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
- No runtime dependencies beyond `bash`, `git`, and `ssh-keygen`

## Requirements

- Bash 4.0+
- Git 2.13+ (for `includeIf` support)
- OpenSSH (for `ssh-keygen`)

## Installation

### One-liner (recommended)

```bash
curl -fsSL https://raw.githubusercontent.com/balaianu/git-persona/main/install.sh | bash
```

Downloads the script and installs it to `~/.local/bin/git-persona`. No cloning required.

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
| `~/.config/git-persona/profiles/<id>.conf` | Per-profile metadata (key=value) |
| `~/.config/git-persona/profiles/<id>.gitconfig` | Per-profile Git config |
| `~/.ssh/id_ed25519_git_<id>` | Per-profile SSH key |
| `~/.gitconfig` | Modified with `includeIf` entries |

## Documentation

- [Usage Guide](docs/usage.md)
- [Configuration](docs/configuration.md)
- [Contributing](docs/contributing.md)

## Testing

```bash
make test
```

Or directly:

```bash
bash tests/test_basic.sh
```

The test suite runs in an isolated temp directory and won't touch your real profiles or SSH keys.

## License

MIT
