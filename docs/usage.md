# Usage Guide

## Commands

### `create`

Create a new profile with an SSH key and `includeIf` rule.

```bash
git persona create <id> <name> <email> [base_dir] [--no-ssh-key]
```

- `<id>`: Short identifier for the profile (e.g., `work`, `personal`)
- `<name>`: Your name for this identity
- `<email>`: Your email for this identity
- `[base_dir]`: Optional base directory. Defaults to `~/git-profiles/<id>/`
- `[--no-ssh-key]`: Skip SSH key generation. Use this if you already have a key or use HTTPS.

By default, an ed25519 SSH key is generated at `~/.ssh/id_ed25519_git_<id>` and the profile config includes `core.sshCommand`. With `--no-ssh-key`, only `user.name` and `user.email` are set.

Example:

```bash
git persona create work "Andrei Balaianu" andrei@example.com ~/dev/work
```

Output:

```
Profile 'work' created.
  Base directory: /home/andy/dev/work
  SSH key:        /home/andy/.ssh/id_ed25519_git_work
  Public key:     /home/andy/.ssh/id_ed25519_git_work.pub

Add this public key to GitHub:
ssh-ed25519 AAAAC3NzaC1lZDI1NTE5...

Put repos under /home/andy/dev/work to automatically use this profile.
```

Example without SSH key:

```bash
git persona create work "Andrei Balaianu" andrei@example.com ~/dev/work --no-ssh-key
```

### `list`

Show all configured profiles.

```bash
git persona list
```

### `delete`

Delete a profile, its config file, and remove `includeIf` entries.

```bash
git persona delete <id> [--with-keys]
```

- `<id>`: The profile identifier
- `[--with-keys]`: Also remove the SSH key pair. By default, keys are kept to avoid breaking access to remote repos.

The base directory is not removed.

Example (keeps SSH key):

```bash
git persona delete work
```

Example (also removes SSH key):

```bash
git persona delete work --with-keys
```

### `use`

Apply a profile to the current git repository.

```bash
cd ~/some-repo
git persona use <id>
```

This sets `user.name` and `user.email` in the repo's local config. If the profile has an SSH key, `core.sshCommand` is also set. For profiles created with `--no-ssh-key`, only name and email are applied.

### `use-folder`

Apply a profile to a folder via `includeIf`.

```bash
git persona use-folder <id> <folder>
```

Any git repo under the specified folder will automatically use this profile.

Example:

```bash
git persona use-folder work ~/projects/client-a
```

### `current`

Show which profile applies to the current directory.

```bash
git persona current
```

If inside a git repo, it reads the effective git config and matches it to a profile. If not in a git repo, it checks if the current directory is under any profile's base directory.

### `version`

Show the installed version.

```bash
git persona version
```

### `help`

Show usage information.

```bash
git persona help
```

## Typical workflow

1. Create profiles for each identity:

```bash
git persona create work "Work Name" work@example.com ~/dev/work
git persona create personal "Personal Name" personal@example.com ~/dev/personal
```

2. Add the printed SSH public keys to the corresponding GitHub accounts.

3. Clone repos into the right folders:

```bash
cd ~/dev/work
git clone git@github.com:workorg/repo.git

cd ~/dev/personal
git clone git@github.com:personaluser/repo.git
```

4. Verify the identity is correct:

```bash
cd ~/dev/work/repo
git config user.email
# work@example.com

git persona current
# Current profile: work
```

5. If a repo is outside the base directory, apply manually:

```bash
cd ~/other-repo
git persona use work
```
