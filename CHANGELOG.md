# Changelog

All notable changes to git-persona are documented here.

The format is based on [Keep a Changelog](https://keepachangelog.com/),
and this project adheres to [Semantic Versioning](https://semver.org/).

## [1.3.0] - 2026-06-21

### Added
- `--no-ssh-key` flag for `create` to skip SSH key generation
- `--with-keys` flag for `delete` to also remove SSH key pair
- One-liner installer (`install.sh`)
- Compatibility table in README (Linux, macOS, Windows, WSL)

### Changed
- `delete` now keeps SSH keys by default (was destructive before)
- `use` command skips `core.sshCommand` when profile has no SSH key
- Profile config omits `core.sshCommand` when created with `--no-ssh-key`

### Fixed
- `cmd_list` exit code 1 when profiles exist (set -e + `[ ] &&` pattern)

## [1.2.0] - 2026-06-21

### Changed
- Replaced sed-based `remove_include_if` with pure bash line-by-line reader
- Removed all external text processing dependencies
- Now works on Alpine Linux (busybox) and macOS (BSD tools) without modification

### Fixed
- Off-by-one bug in includeIf block detection

## [1.1.0] - 2026-06-21

### Changed
- Replaced JSON profile database with bash-sourceable key=value files
- Replaced Python regex with sed for includeIf removal
- Removed Python 3 dependency

## [1.0.0] - 2026-06-21

### Added
- Initial release
- `create`, `list`, `delete`, `use`, `use-folder`, `current`, `version` commands
- SSH key generation per profile (ed25519)
- `includeIf` automation for folder-based identity switching
- Makefile with install, update, uninstall, test targets
- Test suite
- Documentation: README, usage guide, configuration guide, contributing guide
