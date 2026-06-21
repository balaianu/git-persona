# Contributing

Contributions are welcome. This is a small project, so the process is lightweight.

## Development

```bash
git clone git@github.com:balaianu/git-persona.git
cd git-persona
```

The main script is in `src/git-persona`. Edit it directly.

### Testing

Run the syntax and basic checks:

```bash
make test
```

This checks:
- Bash syntax validity
- Version output
- Help output

### Manual testing

Create test profiles in a temporary location:

```bash
git-persona create test-profile "Test" test@example.com /tmp/test-profile-dir
cd /tmp/test-profile-dir
mkdir test-repo && cd test-repo && git init
git-persona current
git config user.email  # should be test@example.com
git-persona delete test-profile
```

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
