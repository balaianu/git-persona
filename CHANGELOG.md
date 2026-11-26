# Changelog

All notable changes to git-persona are documented here.

The format is based on [Keep a Changelog](https://keepachangelog.com/),
and this project adheres to [Semantic Versioning](https://semver.org/).

## [1.5.0] - 2026-11-27

### Added
- `skill` command prints an agent-facing manual: the rules an AI agent must follow when working in a git-persona environment (never set identity manually, verify before committing, surface misconfiguration rather than patch it), a command reference, and diagnostics. The manual is embedded in the script, so every install self-documents at exactly the version installed.

## [1.4.8] - 2026-11-17

### Fixed
- `includeIf` conditions with escaped quotes or backslashes (`[includeIf "gitdir:/d\"x/"]`) are parsed the way git parses them, so `current` and the section scans no longer miss them.
- A bare `~user` and a bare `~` in a `path` value are expanded like git does.

### Changed
- The gitdir condition parsing shared by `current` and the section scans lives in one helper, and `delete` no longer carries two checks that could never fail.
- The script only dispatches when executed directly, so the tests can source it and exercise the parsers on their own. New unit tests cover escape decoding, quote toggling, `~` forms and header conditions.

## [1.4.7] - 2026-11-17

### Fixed
- `use-folder` and `create` no longer report success while writing nothing when another line of `~/.gitconfig` merely contains a quoted `gitdir:<dir>/` string, for example a commented-out `includeIf` header. Only real `includeIf` headers count as sections, and headers followed by a comment with quotes are recognised.
- `~-`, `~+` and `~0` are no longer expanded as tildes; only names shaped like a login name reach `~user` expansion.
- `use-folder` refuses a profile whose conf lacks an id, name or email, like `use` does.
- `list`, `current`, `use` and `delete` all name a profile by its filename. If a conf's id differs from its filename, `delete --with-keys` refuses the key and says which key the profile owns.
- `delete` no longer prints an empty base directory for a damaged conf.
- The docs describe key removal as exactly the profile's own key, and note that broader gitdir patterns are left alone.

## [1.4.6] - 2026-11-17

### Security
- A `path` is treated as a git-persona profile only when it is exactly `<profiles dir>/<id>.gitconfig`. Paths with `..` and paths that only look like profile files are never replaced or dropped, which closes a bypass of the 1.4.5 "keep hand-added paths" guarantee.
- `\t`, `\n` and `\b` escapes in quoted `path` values are decoded the way git decodes them, so an escaped path cannot masquerade as a profile.
- `delete --with-keys` only removes the key named after the profile being deleted, so one profile's conf can no longer remove another profile's key.

### Fixed
- `delete` cleans up a profile whose conf is damaged (it lost its `id`), including its `includeIf` block; `use` refuses such a profile with a clear message instead of writing empty values.
- `~user/` path values are expanded like git does. The name is validated first and nothing from the config file is ever executed.
- `gitdir/i:` and `gitdir:./` headers are recognised when deduplicating and matching.
- When several sections target the same folder, only the last one gets our path; git-persona paths are cleared from the others.
- `list` and `current` name profiles by filename consistently.

## [1.4.5] - 2026-11-17

### Fixed
- `use-folder` and `create` no longer delete hand-added `path` lines from an existing `includeIf` section. Git applies every path and later files only override the keys they define, so layered include files are kept. Paths of git-persona profiles are replaced by a single path of ours, placed last so the profile's identity keys win, and a correct section is left byte-identical.
- A matching section without a `path` gets its path inside that section instead of a duplicate section.
- `path` values follow git's rules: quotes toggle (`"a"b` is `ab`), unquoted `#` or `;` starts a comment, trailing unquoted whitespace is dropped, and a leading `~/` means `$HOME`. `gitdir:~/...` headers dedup against absolute ones.
- `use` and `delete` reject a conf that parsed to nothing instead of writing empty values.
- `current` labels the profile it found by its filename, like the rest of the derived paths.

## [1.4.4] - 2026-11-17

### Fixed
- `use-folder` and `create` no longer leave a stale second `path` in an `includeIf` section. Git applies every path and the last one wins, so the first path now points at the new profile and later ones are dropped.
- `includeIf` section names are matched case-insensitively (`[INCLUDEIF ...]`), and headers with extra interior spaces are deduped.
- `path` values are read the way git reads them: double quotes are removed and unquoted values end at `#` or `;`. Paths that contain `;`, `#`, quotes or backslashes (for example in `$HOME`) are written quoted so git resolves them correctly.
- Whitespace-only lines at the end of a removed block count as separators.
- `list` warns about unreadable or malformed confs and no longer prints empty entries; `current` skips them.
- `current` derives the profile path from the filename instead of trusting the conf.
- `delete` unlinks the `includeIf` block before it removes the key, matching its own comment.
- An unreadable conf shows only the friendly error.

## [1.4.3] - 2026-11-17

### Security
- The profile gitconfig path is always derived from the profile ID. A `profile_file` in a conf that points elsewhere (for example with `..`) is ignored with a warning, so `delete` can no longer be steered at files outside the profiles directory.

### Fixed
- Removing an `includeIf` block drops blank lines inside it, and a blank line no longer ends the block, so a `path` after a blank line is found. A section with several paths only loses ours.
- `path=X`, `path  =  X` and any key casing are understood when adding, removing and matching `includeIf` blocks; `[includeif ...]` headers are recognised case-insensitively.
- `create` normalises trailing and doubled slashes in the base directory and rejects the filesystem root.
- A conf that cannot be read now produces an error message instead of a silent exit.
- Confs with CR-only line endings parse.
- A `~/.gitconfig` with CRLF line endings is refused with a clear message instead of being edited into a mixed-ending file. Nothing is created or deleted in that case.
- The write-failure message only mentions the backup when one was made.
- `current` ignores CR in `~/.gitconfig` and treats blank lines inside a section as part of it.

### Changed
- CI workflow declares read-only `contents` permission.

## [1.4.2] - 2026-11-17

### Fixed
- CRLF stripping in conf parsing no longer relies on `$'\r'` inside a quoted expansion, which older bash (macOS 3.2) does not interpret.

### Changed
- CI also runs the test suite on Alpine Linux.

## [1.4.1] - 2026-11-17

### Security
- `delete --with-keys` only removes keys recorded as generated by `git-persona`. Profiles created before 1.4.0 have no such record, so their key is now kept (previously 1.4.0 would still delete it).

### Fixed
- Adding or removing an `includeIf` no longer touches neighbouring sections: a header without a `path` is ignored, and the whole removed block (including extra keys and comments) is dropped.
- A conf with CRLF line endings or a missing `profile_file` no longer leaves a dangling `includeIf` on `delete`.
- `create` and `use-folder` report when they reassign a folder from another profile.
- `create` rejects `.` and `..` as the base directory leaf.
- `current` no longer claims "no git repo detected" inside a repo.
- A failed write to `~/.gitconfig` points to the backup.

## [1.4.0] - 2026-11-17

### Security
- Profile IDs are validated to prevent path traversal and shell injection.
- Profile `.gitconfig` files are written with `git config --file`, so names and emails with quotes, `#`, `;` or backslashes are escaped correctly. Values containing control characters (including newlines) are rejected, which closes a gitconfig injection path.
- Profile `.conf` files are parsed instead of sourced, so a damaged or tampered file can no longer run code.
- `core.sshCommand` quotes the key path, so paths with spaces or quotes work.
- `delete --with-keys` only removes keys that `git-persona` generated, and only under `~/.ssh` with the `id_ed25519_git_` prefix.
- Directories containing `"`, `\`, `*`, `?` or `[` are rejected for `create` and `use-folder`.

### Fixed
- `use` clears `core.sshCommand` when switching to a keyless profile.
- `current` no longer matches the wrong profile when one key path is a prefix of another (for example `work` and `work2`).
- `--no-ssh-key` no longer picks up a key that already exists at the default path.
- `~/.gitconfig` edits are written through symlinks, keep file permissions, leave unrelated blank lines alone, and save a backup to `~/.config/git-persona/gitconfig.bak`.
- A failed `create` removes the partial profile files instead of leaving them behind.
- `current` matches directories through symlinks, honours `~/` and `gitdir/i:` rules, and lets the last matching `includeIf` win, like git.
- `create` without `base_dir` works when `~/git-profiles` does not exist yet.
- `version`, `help`, `list` and `current` no longer create files in `$HOME`.
- Errors are written to stderr; unknown options are rejected.
- `use` warns when a profile's SSH key file is missing.
- `use-folder` reports when it reassigns a folder from another profile.
- `delete` unlinks the `includeIf` block before removing profile files.

### Changed
- Required bash lowered to 3.2 in the documentation (exercised by the macOS CI job).
- `install.sh` downloads to a temp file before replacing the installed script and accepts `GIT_PERSONA_REF` to pin a release.
- The release workflow runs the tests and checks that the tag matches the script version.

## [1.3.3] - 2026-08-03

### Fixed
- Profile matching in `current`, and validation in `create`.

## [1.3.2] - 2026-08-03

### Fixed
- `create` errors if `base_dir`'s parent does not exist instead of silently using a relative path.
- Relative `base_dir` values are resolved to absolute paths.

## [1.3.1] - 2026-08-02

### Fixed
- Trailing slash on `base_dir` is stripped so `includeIf` matches.
- `use-folder` updates the `includeIf` path in place when reassigning a folder.

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
