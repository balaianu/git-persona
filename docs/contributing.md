# Contributing

Contributions are welcome. This is a small project, so the process is lightweight.

## Development

```bash
git clone git@github.com:balaianu/git-persona.git
cd git-persona
```

The main script is in `src/git-persona`. Edit it directly.

### Testing

Run the full test suite:

```bash
make test
```

Or directly:

```bash
bash tests/test_basic.sh
```

The test suite uses an isolated temp directory as `HOME`, so it won't touch your real profiles or SSH keys. It covers:

- Syntax validation
- Version and help output
- Profile creation with SSH key (default)
- Profile creation with `--no-ssh-key` (no key, no sshCommand)
- Profile listing
- Duplicate profile rejection
- Current profile detection (in repo, in base dir, outside)
- Per-repo profile application (with and without key)
- Per-folder profile application
- Profile deletion (default: keeps keys)
- Profile deletion with `--with-keys` (removes keys)
- Flag ordering (flags before and after positional args)
- Error handling (non-existent profiles, non-repo use)
- Git extension invocation (`git persona`)

## Submitting changes

1. Fork the repository
2. Create a feature branch: `git checkout -b my-feature`
3. Make your changes in `src/git-persona`
4. Run `make test` to verify
5. Commit with a clear message
6. Push and open a pull request

## Code style

- Use `bash` with `set -euo pipefail`
- Use pure bash for text manipulation (no sed, awk, Python, or jq)
- Profile metadata is stored as bash-sourceable key=value files
- Keep functions small and focused
- Use `local` variables inside functions
- Quote all variable expansions

## Reporting bugs

Open an issue on GitHub with:

- Your OS and version
- Bash version (`bash --version`)
- Git version (`git --version`)
- OpenSSH version (`ssh -V`)
- The exact command you ran
- The output or error you got
