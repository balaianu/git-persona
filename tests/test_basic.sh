#!/bin/bash

# test_basic.sh: Test suite for git-persona
# Run with: bash tests/test_basic.sh
# Or via: make test

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
SCRIPT="$PROJECT_DIR/src/git-persona"

# Test counters
PASS=0
FAIL=0
FAILED_TESTS=()

# Temp test environment
TEST_HOME=$(mktemp -d)
TEST_WORKDIR="$TEST_HOME/work"
TEST_PERSONALDIR="$TEST_HOME/personal"

mkdir -p "$TEST_HOME/.ssh" "$TEST_WORKDIR" "$TEST_PERSONALDIR"

# Helper: run git-persona with test HOME
run() {
    HOME="$TEST_HOME" bash "$SCRIPT" "$@"
}

# Helper: assert equal
assert_equals() {
    local name="$1"
    local expected="$2"
    local actual="$3"
    if [ "$expected" = "$actual" ]; then
        PASS=$((PASS + 1))
        echo "  PASS: $name"
    else
        FAIL=$((FAIL + 1))
        FAILED_TESTS+=("$name")
        echo "  FAIL: $name"
        echo "    expected: [$expected]"
        echo "    actual:   [$actual]"
    fi
}

# Helper: assert contains
assert_contains() {
    local name="$1"
    local needle="$2"
    local haystack="$3"
    if echo "$haystack" | grep -F -- "$needle" >/dev/null 2>&1; then
        PASS=$((PASS + 1))
        echo "  PASS: $name"
    else
        FAIL=$((FAIL + 1))
        FAILED_TESTS+=("$name")
        echo "  FAIL: $name"
        echo "    expected to contain: [$needle]"
        echo "    actual: [$haystack]"
    fi
}

# Helper: assert not contains
assert_not_contains() {
    local name="$1"
    local needle="$2"
    local haystack="$3"
    if echo "$haystack" | grep -F -- "$needle" >/dev/null 2>&1; then
        FAIL=$((FAIL + 1))
        FAILED_TESTS+=("$name")
        echo "  FAIL: $name"
        echo "    expected NOT to contain: [$needle]"
        echo "    actual: [$haystack]"
    else
        PASS=$((PASS + 1))
        echo "  PASS: $name"
    fi
}

# Helper: assert file exists
assert_file_exists() {
    local name="$1"
    local file="$2"
    if [ -f "$file" ]; then
        PASS=$((PASS + 1))
        echo "  PASS: $name"
    else
        FAIL=$((FAIL + 1))
        FAILED_TESTS+=("$name")
        echo "  FAIL: $name"
        echo "    file does not exist: $file"
    fi
}

# Helper: assert file does not exist
assert_file_not_exists() {
    local name="$1"
    local file="$2"
    if [ ! -f "$file" ]; then
        PASS=$((PASS + 1))
        echo "  PASS: $name"
    else
        FAIL=$((FAIL + 1))
        FAILED_TESTS+=("$name")
        echo "  FAIL: $name"
        echo "    file still exists: $file"
    fi
}

echo "============================================"
echo "git-persona test suite"
echo "============================================"
echo ""

# --- Syntax check ---
echo "--- Syntax ---"
bash -n "$SCRIPT" && PASS=$((PASS + 1)) && echo "  PASS: bash syntax check" || { FAIL=$((FAIL + 1)); FAILED_TESTS+=("syntax"); echo "  FAIL: bash syntax check"; }

# --- Version ---
echo "--- Version ---"
output=$(run version)
assert_equals "version output" "git-persona 1.5.0" "$output"

# --- Release metadata ---
# Fails the PR that bumps VERSION without writing a changelog entry, so the
# release workflow never falls back to a bare "Release vX" note.
script_version="${output#git-persona }"
if grep -q "^## \\[${script_version}\\]" "$PROJECT_DIR/CHANGELOG.md"; then
    PASS=$((PASS + 1)); echo "  PASS: CHANGELOG has an entry for $script_version"
else
    FAIL=$((FAIL + 1)); FAILED_TESTS+=("CHANGELOG entry for $script_version"); echo "  FAIL: CHANGELOG has no entry for $script_version"
fi

# --- Help ---
echo "--- Help ---"
output=$(run help)
assert_contains "help shows create" "create" "$output"
assert_contains "help shows list" "list" "$output"
assert_contains "help shows delete" "delete" "$output"
assert_contains "help shows use" "use" "$output"
assert_contains "help shows current" "current" "$output"
assert_contains "help shows --no-ssh-key" "--no-ssh-key" "$output"
assert_contains "help shows --with-keys" "--with-keys" "$output"
assert_contains "help shows skill" "skill" "$output"

# --- Skill manual ---
echo "--- Skill manual ---"
output=$(run skill)
assert_contains "skill prints the manual header" "git-persona — agent manual" "$output"
assert_contains "skill covers the rules" "Never set git identity manually" "$output"
assert_contains "skill covers commands" "use-folder" "$output"
assert_contains "skill covers diagnostics" "Diagnostics" "$output"
# the manual is full of backticked shell fragments inside a quoted heredoc —
# they must survive verbatim, not execute (a silent execution would drop or
# substitute the text)
assert_contains "backticked content stays literal" 'git var GIT_AUTHOR_IDENT' "$output"
assert_contains "no expansion artifacts" 'core.sshCommand' "$output"

# --- Create profile (with SSH key, default) ---
echo "--- Create (default, with SSH key) ---"
output=$(run create work "Test Work" work@test.com "$TEST_WORKDIR" 2>&1)
assert_contains "create success message" "Profile 'work' created" "$output"
assert_file_exists "ssh key created" "$TEST_HOME/.ssh/id_ed25519_git_work"
assert_file_exists "ssh pub key created" "$TEST_HOME/.ssh/id_ed25519_git_work.pub"
assert_file_exists "profile conf created" "$TEST_HOME/.config/git-persona/profiles/work.conf"
assert_file_exists "profile gitconfig created" "$TEST_HOME/.config/git-persona/profiles/work.gitconfig"
assert_file_exists "gitconfig created" "$TEST_HOME/.gitconfig"
assert_contains "gitconfig has sshCommand" "sshCommand" "$(cat "$TEST_HOME/.config/git-persona/profiles/work.gitconfig")"

# --- Create duplicate ---
echo "--- Create duplicate ---"
output=$(run create work "Test Work" work@test.com "$TEST_WORKDIR" 2>&1 || true)
assert_contains "duplicate profile rejected" "already exists" "$output"

# --- Create with --no-ssh-key ---
echo "--- Create (--no-ssh-key) ---"
output=$(run create nokey "No Key User" nokey@test.com "$TEST_HOME/nokey" --no-ssh-key 2>&1)
assert_contains "create nokey success" "Profile 'nokey' created" "$output"
assert_file_not_exists "no ssh key created" "$TEST_HOME/.ssh/id_ed25519_git_nokey"
assert_file_not_exists "no ssh pub key created" "$TEST_HOME/.ssh/id_ed25519_git_nokey.pub"
assert_file_exists "nokey conf created" "$TEST_HOME/.config/git-persona/profiles/nokey.conf"
assert_file_exists "nokey gitconfig created" "$TEST_HOME/.config/git-persona/profiles/nokey.gitconfig"
NOKEY_GITCONFIG=$(cat "$TEST_HOME/.config/git-persona/profiles/nokey.gitconfig")
assert_not_contains "nokey gitconfig has no sshCommand" "sshCommand" "$NOKEY_GITCONFIG"
assert_contains "nokey output says none" "(none" "$output"

# --- Create with --no-ssh-key but flag before positional args ---
echo "--- Create (--no-ssh-key before positionals) ---"
output=$(run create nokey2 "No Key 2" nokey2@test.com "$TEST_HOME/nokey2" --no-ssh-key 2>&1)
assert_contains "create nokey2 success" "Profile 'nokey2' created" "$output"
assert_file_not_exists "nokey2 ssh key" "$TEST_HOME/.ssh/id_ed25519_git_nokey2"

# --- Create with special characters in name (conf sourcing safety) ---
echo "--- Create (special chars in name) ---"
SPECIAL_NAME='Name "quoted" \backslash'
output=$(run create special "$SPECIAL_NAME" special@test.com "$TEST_HOME/special" --no-ssh-key 2>&1)
assert_contains "create special success" "Profile 'special' created" "$output"
# list must not error out and must show the original name verbatim
output=$(run list 2>&1)
assert_contains "list shows special name verbatim" "$SPECIAL_NAME" "$output"
# current via base_dir match must also work
cd "$TEST_HOME/special"
output=$(run current 2>&1)
assert_contains "current shows special name" "$SPECIAL_NAME" "$output"
cd "$TEST_HOME"
# get_field round-trips the name exactly
RECOVERED=$(TEST_HOME="$TEST_HOME" bash -c '. "$TEST_HOME/.config/git-persona/profiles/special.conf"; printf "%s" "$name"')
assert_equals "special name round-trips via sourcing" "$SPECIAL_NAME" "$RECOVERED"

# --- Create with $ and backtick in name (must not execute on read) ---
echo "--- Create ($ and backtick in name) ---"
# Use a sentinel that would only appear if command substitution ran.
DOLLAR_NAME='Price $HOME is $5 and `echo PWNED`'
output=$(run create dollar "$DOLLAR_NAME" dollar@test.com "$TEST_HOME/dollar" --no-ssh-key 2>&1)
assert_contains "create dollar success" "Profile 'dollar' created" "$output"
# list must show the literal name with backticks and dollar signs intact
# (if backtick executed, the backtick chars would be consumed and replaced
# by command output; if $ expanded, $HOME would become a path).
output=$(run list 2>&1)
assert_contains "list shows dollar name verbatim" '$5' "$output"
assert_contains "list shows dollar backtick verbatim" '`echo PWNED`' "$output"
# The backtick char must still be present (execution would consume it)
assert_contains "list preserves backtick char (not executed)" '`' "$output"
assert_contains "list preserves dollar char (not expanded)" '$HOME' "$output"
# Round-trip via sourcing
RECOVERED=$(TEST_HOME="$TEST_HOME" bash -c '. "$TEST_HOME/.config/git-persona/profiles/dollar.conf"; printf "%s" "$name"')
assert_equals "dollar name round-trips via sourcing" "$DOLLAR_NAME" "$RECOVERED"

# --- List ---
echo "--- List ---"
output=$(run list)
assert_contains "list shows work" "work" "$output"
assert_contains "list shows email" "work@test.com" "$output"
assert_contains "list shows nokey" "nokey" "$output"

# --- Create second profile (with key) ---
echo "--- Create second profile ---"
output=$(run create personal "Test Personal" personal@test.com "$TEST_PERSONALDIR" 2>&1)
assert_contains "create personal success" "Profile 'personal' created" "$output"

# --- Current in work dir ---
echo "--- Current (dir match) ---"
cd "$TEST_WORKDIR"
output=$(run current)
assert_contains "current shows work profile" "work" "$output"
assert_contains "current shows no repo" "no git repo" "$output"

# --- Current in personal dir ---
echo "--- Current (personal dir) ---"
cd "$TEST_PERSONALDIR"
output=$(run current)
assert_contains "current shows personal profile" "personal" "$output"

# --- Current outside any profile ---
echo "--- Current (no match) ---"
cd /tmp
output=$(run current || true)
assert_contains "current shows no match" "No matching profile" "$output"

# --- Use in repo (with key) ---
echo "--- Use in repo (with key) ---"
TEST_REPO="$TEST_WORKDIR/test-repo"
mkdir -p "$TEST_REPO"
cd "$TEST_REPO"
git init -q
run use work
assert_equals "repo user.name" "Test Work" "$(git config user.name)"
assert_equals "repo user.email" "work@test.com" "$(git config user.email)"
assert_contains "repo sshCommand set" "id_ed25519_git_work" "$(git config core.sshCommand)"

# --- Use in repo (without key) ---
echo "--- Use in repo (no key) ---"
TEST_REPO_NOKEY="$TEST_HOME/nokey/test-repo"
mkdir -p "$TEST_REPO_NOKEY"
cd "$TEST_REPO_NOKEY"
git init -q
run use nokey
assert_equals "nokey repo user.name" "No Key User" "$(git config user.name)"
assert_equals "nokey repo user.email" "nokey@test.com" "$(git config user.email)"
# sshCommand should not be set for keyless profile
if git config core.sshCommand >/dev/null 2>&1; then
    FAIL=$((FAIL + 1))
    FAILED_TESTS+=("nokey repo should not have sshCommand")
    echo "  FAIL: nokey repo should not have sshCommand (got: $(git config core.sshCommand))"
else
    PASS=$((PASS + 1))
    echo "  PASS: nokey repo has no sshCommand"
fi

# --- Current in repo ---
echo "--- Current (in repo) ---"
cd "$TEST_REPO"
output=$(run current)
assert_contains "current in repo shows work" "work" "$output"
assert_contains "current in repo shows name" "Test Work" "$output"

# --- Use: switching from keyed to keyless profile clears sshCommand ---
echo "--- Use: keyed→keyless clears sshCommand ---"
# TEST_REPO currently has work's sshCommand set (from earlier `use work`)
# Switch to nokey profile — sshCommand must be cleared
cd "$TEST_REPO"
run use nokey
assert_equals "switched to nokey name" "No Key User" "$(git config user.name)"
assert_equals "switched to nokey email" "nokey@test.com" "$(git config user.email)"
if git config core.sshCommand >/dev/null 2>&1; then
    FAIL=$((FAIL + 1))
    FAILED_TESTS+=("keyed→keyless should clear sshCommand")
    echo "  FAIL: keyed→keyless should clear sshCommand (got: $(git config core.sshCommand))"
else
    PASS=$((PASS + 1))
    echo "  PASS: keyed→keyless clears sshCommand"
fi
# Switch back to work — sshCommand should be set again
run use work
if [ -n "$(git config core.sshCommand 2>/dev/null || true)" ]; then
    PASS=$((PASS + 1))
    echo "  PASS: keyless→keyed sets sshCommand"
else
    FAIL=$((FAIL + 1))
    FAILED_TESTS+=("keyless→keyed should set sshCommand")
    echo "  FAIL: keyless→keyed should set sshCommand"
fi

# --- Current disambiguation: two profiles, same name+email, different keys ---
echo "--- Current (disambiguation by key) ---"
# Create a second profile that shares work's name+email but has its own key/dir.
TEST_TWIN_DIR="$TEST_HOME/twin"
output=$(run create twin "Test Work" work@test.com "$TEST_TWIN_DIR" 2>&1)
assert_contains "twin profile created" "Profile 'twin' created" "$output"
# In TEST_REPO (which had `use work` applied), current must resolve to work,
# not twin, because the repo's sshCommand points at work's key.
cd "$TEST_REPO"
output=$(run current)
assert_contains "current resolves to work by key" "Current profile: work" "$output"
assert_not_contains "current does not resolve to twin" "Current profile: twin" "$output"
# Now apply twin to a fresh repo and confirm current resolves to twin there.
TEST_TWIN_REPO="$TEST_TWIN_DIR/twin-repo"
mkdir -p "$TEST_TWIN_REPO"
cd "$TEST_TWIN_REPO"
git init -q
run use twin
output=$(run current)
assert_contains "current resolves to twin by key" "Current profile: twin" "$output"
# Clean up twin so its "Test Work" name doesn't interfere with later
# substring-based assertions (e.g. "list after delete - work should be gone").
run delete twin --with-keys >/dev/null 2>&1

# --- Use-folder ---
echo "--- Use-folder ---"
TEST_EXTRA="$TEST_HOME/extra"
mkdir -p "$TEST_EXTRA"
output=$(run use-folder work "$TEST_EXTRA")
assert_contains "use-folder success" "applied to folder" "$output"

# --- Verify includeIf entries ---
echo "--- IncludeIf entries ---"
GITCONFIG_CONTENT=$(cat "$TEST_HOME/.gitconfig")
assert_contains "gitconfig has work includeIf" "gitdir:$TEST_WORKDIR/" "$GITCONFIG_CONTENT"
assert_contains "gitconfig has extra includeIf" "gitdir:$TEST_EXTRA/" "$GITCONFIG_CONTENT"
assert_contains "gitconfig has personal includeIf" "gitdir:$TEST_PERSONALDIR/" "$GITCONFIG_CONTENT"

# --- Use-folder dedup: same folder twice should not duplicate the block ---
echo "--- Use-folder dedup ---"
BEFORE_COUNT=$(grep -c "gitdir:$TEST_EXTRA/" "$TEST_HOME/.gitconfig")
output=$(run use-folder work "$TEST_EXTRA")
assert_contains "use-folder repeat succeeds" "applied to folder" "$output"
AFTER_COUNT=$(grep -c "gitdir:$TEST_EXTRA/" "$TEST_HOME/.gitconfig")
assert_equals "no duplicate includeIf block" "$BEFORE_COUNT" "$AFTER_COUNT"

# --- Use-folder dedup: create-then-use-folder on the same dir ---
echo "--- Create then use-folder dedup ---"
TEST_DEDUP="$TEST_HOME/dedup"
mkdir -p "$TEST_DEDUP"
output=$(run create dedup "Dedup" dedup@test.com "$TEST_DEDUP" --no-ssh-key 2>&1)
assert_contains "dedup profile created" "Profile 'dedup' created" "$output"
BEFORE_COUNT=$(grep -c "gitdir:$TEST_DEDUP/" "$TEST_HOME/.gitconfig")
output=$(run use-folder dedup "$TEST_DEDUP")
AFTER_COUNT=$(grep -c "gitdir:$TEST_DEDUP/" "$TEST_HOME/.gitconfig")
assert_equals "create+use-folder no duplicate" "$BEFORE_COUNT" "$AFTER_COUNT"

# --- Use-folder reassignment: same folder, different profile updates path ---
echo "--- Use-folder reassignment ---"
# TEST_EXTRA currently points to work.gitconfig. Reassign it to personal.
output=$(run use-folder personal "$TEST_EXTRA")
assert_contains "reassignment succeeds" "applied to folder" "$output"
# Still exactly one block for this dir
REASSIGN_COUNT=$(grep -c "gitdir:$TEST_EXTRA/" "$TEST_HOME/.gitconfig")
assert_equals "reassignment keeps single block" "1" "$REASSIGN_COUNT"
# The path must now point to personal, not work. Extract the path line
# that follows the TEST_EXTRA header using pure bash.
EXTRA_HEADER="[includeIf \"gitdir:$TEST_EXTRA/\"]"
EXTRA_BLOCK_PATH=""
found=0
while IFS= read -r tline || [ -n "$tline" ]; do
    if [ "$found" = 1 ]; then
        case "$tline" in
            *path\ =*) EXTRA_BLOCK_PATH="$tline"; break;;
        esac
    fi
    [ "$tline" = "$EXTRA_HEADER" ] && found=1
done < "$TEST_HOME/.gitconfig"
assert_contains "reassignment points to personal" "personal.gitconfig" "$EXTRA_BLOCK_PATH"
assert_not_contains "reassignment no longer points to work" "work.gitconfig" "$EXTRA_BLOCK_PATH"

# --- Current in a use-folder dir (not the original base_dir) ---
echo "--- Current (use-folder dir, non-repo) ---"
# TEST_EXTRA was reassigned to personal via use-folder. personal's original
# base_dir is TEST_PERSONALDIR, not TEST_EXTRA. current must still match here
# by reading the includeIf block from .gitconfig, not the stale base_dir.
cd "$TEST_EXTRA"
output=$(run current)
assert_contains "current matches in use-folder dir" "personal" "$output"
assert_contains "current shows no repo in use-folder dir" "no git repo" "$output"

# --- Delete profile (default: keeps keys) ---
echo "--- Delete (default, keeps keys) ---"
output=$(run delete work)
assert_contains "delete success" "Profile 'work' deleted" "$output"
assert_contains "delete says key kept" "SSH key kept" "$output"
# Key should still exist
assert_file_exists "ssh key kept after delete" "$TEST_HOME/.ssh/id_ed25519_git_work"
assert_file_exists "ssh pub key kept after delete" "$TEST_HOME/.ssh/id_ed25519_git_work.pub"
# But profile files should be gone
assert_file_not_exists "profile conf removed" "$TEST_HOME/.config/git-persona/profiles/work.conf"
assert_file_not_exists "profile gitconfig removed" "$TEST_HOME/.config/git-persona/profiles/work.gitconfig"

# --- Verify includeIf entries removed after delete ---
echo "--- IncludeIf cleanup ---"
GITCONFIG_CONTENT=$(cat "$TEST_HOME/.gitconfig")
assert_not_contains "work includeIf removed" "work.gitconfig" "$GITCONFIG_CONTENT"
# TEST_EXTRA was reassigned to personal, so it must survive the work delete.
assert_contains "extra includeIf survives (reassigned to personal)" "gitdir:$TEST_EXTRA/" "$GITCONFIG_CONTENT"

# --- List after delete ---
echo "--- List after delete ---"
output=$(run list)
assert_contains "list still shows personal" "personal" "$output"
if echo "$output" | grep -q "work"; then
    FAIL=$((FAIL + 1))
    FAILED_TESTS+=("list after delete - work should be gone")
    echo "  FAIL: list after delete - work should be gone"
else
    PASS=$((PASS + 1))
    echo "  PASS: list after delete - work is gone"
fi

# --- Delete profile with --with-keys ---
echo "--- Delete (--with-keys) ---"
output=$(run delete personal --with-keys)
assert_contains "delete personal success" "Profile 'personal' deleted" "$output"
assert_contains "delete says key removed" "SSH key removed" "$output"
assert_file_not_exists "ssh key removed with --with-keys" "$TEST_HOME/.ssh/id_ed25519_git_personal"
assert_file_not_exists "ssh pub key removed with --with-keys" "$TEST_HOME/.ssh/id_ed25519_git_personal.pub"
assert_file_not_exists "personal conf removed" "$TEST_HOME/.config/git-persona/profiles/personal.conf"
assert_file_not_exists "personal gitconfig removed" "$TEST_HOME/.config/git-persona/profiles/personal.gitconfig"

# --- Delete with --with-keys but flag before id ---
echo "--- Delete (--with-keys before id) ---"
# Create a profile to test flag ordering
output=$(run create testorder "Test" test@test.com "$TEST_HOME/testorder" 2>&1)
assert_file_exists "testorder key created" "$TEST_HOME/.ssh/id_ed25519_git_testorder"
output=$(run delete --with-keys testorder)
assert_contains "testorder deleted" "Profile 'testorder' deleted" "$output"
assert_file_not_exists "testorder key removed" "$TEST_HOME/.ssh/id_ed25519_git_testorder"

# --- Delete removes includeIf block with non-standard indentation ---
echo "--- Delete (non-standard indent in gitconfig) ---"
output=$(run create indent "Indent Test" indent@test.com "$TEST_HOME/indent" 2>&1)
INDENT_PROFILE_FILE="$TEST_HOME/.config/git-persona/profiles/indent.gitconfig"
# Rewrite .gitconfig so the includeIf block uses 2-space indent (not the 4 we write)
cat > "$TEST_HOME/.gitconfig" << EOF
[user]
    name = Someone
    email = someone@test.com

[includeIf "gitdir:$TEST_HOME/indent/"]
  path = $INDENT_PROFILE_FILE
EOF
output=$(run delete indent 2>&1)
assert_contains "indent deleted" "Profile 'indent' deleted" "$output"
GITCONFIG_CONTENT=$(cat "$TEST_HOME/.gitconfig")
assert_not_contains "indent includeIf header removed" "indent.gitconfig" "$GITCONFIG_CONTENT"
assert_not_contains "indent includeIf path removed" "$INDENT_PROFILE_FILE" "$GITCONFIG_CONTENT"
# The unrelated [user] block must survive
assert_contains "user block preserved" "[user]" "$GITCONFIG_CONTENT"

# --- Delete non-existent profile ---
echo "--- Delete non-existent ---"
output=$(run delete nonexistent 2>&1 || true)
assert_contains "delete non-existent rejected" "not found" "$output"

# --- Invalid profile IDs ---
echo "--- Invalid profile IDs ---"
output=$(run create "../etc" "Bad" bad@x.com 2>&1 || true)
assert_contains "create with path traversal rejected" "invalid" "$output"
output=$(run create "my profile" "Bad" bad@x.com 2>&1 || true)
assert_contains "create with space rejected" "invalid" "$output"
output=$(run create "good;rm" "Bad" bad@x.com 2>&1 || true)
assert_contains "create with semicolon rejected" "invalid" "$output"
output=$(run delete "../etc" 2>&1 || true)
assert_contains "delete with path traversal rejected" "invalid" "$output"
output=$(run use "../etc" 2>&1 || true)
assert_contains "use with path traversal rejected" "invalid" "$output"
output=$(run use-folder "../etc" /tmp 2>&1 || true)
assert_contains "use-folder with path traversal rejected" "invalid" "$output"
output=$(run create "" "Bad" bad@x.com 2>&1 || true)
assert_contains "create with empty id rejected" "invalid" "$output"

# --- Valid profile IDs with hyphens and underscores ---
echo "--- Valid profile IDs ---"
output=$(run create "my-profile_1" "Test" test@x.com "$TEST_HOME/testdir" --no-ssh-key 2>&1 || true)
assert_contains "create with hyphen and underscore accepted" "created" "$output"
output=$(run delete "my-profile_1" 2>&1 || true)
assert_contains "delete hyphen-underscore profile" "deleted" "$output"

# --- Use non-existent profile ---
echo "--- Use non-existent ---"
output=$(run use nonexistent 2>&1 || true)
assert_contains "use non-existent rejected" "not found" "$output"

# --- Use outside repo ---
echo "--- Use outside repo ---"
cd /tmp
output=$(run use nokey 2>&1 || true)
assert_contains "use outside repo rejected" "Not a git repository" "$output"

# --- git persona (extension) ---
echo "--- Git extension ---"
cd "$TEST_HOME"
output=$(git persona version 2>/dev/null || echo "GIT_EXTENSION_FAILED")
if [ "$output" = "GIT_EXTENSION_FAILED" ]; then
    echo "  SKIP: git persona extension (git-persona not in test PATH)"
    PASS=$((PASS + 1))
else
    assert_contains "git persona extension works" "git-persona" "$output"
fi

# ============================================================================
# Hardening tests. Each scenario gets its own throwaway HOME under TEST_HOME.
# ============================================================================

run_home() {
    local h="$1"
    shift
    HOME="$h" bash "$SCRIPT" "$@"
}

new_home() {
    local h="$TEST_HOME/homes/$1"
    mkdir -p "$h"
    printf '%s' "$h"
}

# --- current: a key path that prefixes another key path ---
echo "--- Current (key path prefix collision) ---"
H=$(new_home prefix)
run_home "$H" create pre "Pre" pre@test.com "$H/pre" >/dev/null 2>&1
run_home "$H" create pre2 "Pre Two" pre2@test.com "$H/pre2" >/dev/null 2>&1
mkdir -p "$H/pre2/repo"
cd "$H/pre2/repo"
git init -q
run_home "$H" use pre2 >/dev/null
output=$(run_home "$H" current)
assert_contains "current resolves pre2, not its prefix pre" "Current profile: pre2" "$output"
cd "$TEST_HOME"

# --- Values written to the profile gitconfig survive intact ---
echo "--- Profile gitconfig escaping ---"
H=$(new_home escape)
TRICKY='A "B" #c ;d \e'
run_home "$H" create tricky "$TRICKY" 'e@test.com' "$H/tricky" --no-ssh-key >/dev/null 2>&1
assert_equals "tricky name round-trips through git" "$TRICKY" "$(git config --file "$H/.config/git-persona/profiles/tricky.gitconfig" user.name)"
output=$(run_home "$H" list)
assert_contains "tricky name round-trips through conf" "$TRICKY" "$output"

echo "--- Reject newline injection ---"
INJECT=$'Evil\n[core]\n\tsshCommand = touch PWNED'
output=$(run_home "$H" create inj "$INJECT" inj@test.com "$H/inj" --no-ssh-key 2>&1 || true)
assert_contains "newline in name rejected" "control characters" "$output"
assert_file_not_exists "no conf left after rejected create" "$H/.config/git-persona/profiles/inj.conf"
output=$(run_home "$H" create inj2 "Ok" $'a@b\n[core]' "$H/inj2" --no-ssh-key 2>&1 || true)
assert_contains "newline in email rejected" "control characters" "$output"

# --- Input validation ---
echo "--- Input validation ---"
output=$(run_home "$H" create badflag Name e@test.com "$H/badflag" --bogus 2>&1 || true)
assert_contains "unknown create option rejected" "Unknown option" "$output"
output=$(run_home "$H" delete --bogus 2>&1 || true)
assert_contains "unknown delete option rejected" "Unknown option" "$output"
output=$(run_home "$H" create globby Name e@test.com "$H/we*ird" --no-ssh-key 2>&1 || true)
assert_contains "glob chars in base_dir rejected" "cannot be used" "$output"
assert_file_not_exists "no conf for rejected base_dir" "$H/.config/git-persona/profiles/globby.conf"

# --- Errors go to stderr, not stdout ---
echo "--- Errors on stderr ---"
output=$(run_home "$H" use "../etc" 2>/dev/null || true)
assert_equals "invalid id error not on stdout" "" "$output"

# --- Key path with spaces ---
echo "--- SSH command quoting ---"
H=$(new_home "with space")
run_home "$H" create sp "Sp" sp@test.com "$H/sp" >/dev/null 2>&1
mkdir -p "$H/sp/repo"
cd "$H/sp/repo"
git init -q
run_home "$H" use sp >/dev/null
SSH_CMD="$(git config core.sshCommand)"
eval "set -- $SSH_CMD"
assert_equals "sshCommand key arg survives shell word splitting" "$H/.ssh/id_ed25519_git_sp" "$3"
set --
output=$(run_home "$H" current)
assert_contains "current matches quoted sshCommand" "Current profile: sp" "$output"
cd "$TEST_HOME"

# --- Symlinked ~/.gitconfig is preserved and restored byte-for-byte ---
echo "--- Symlinked gitconfig ---"
H=$(new_home symlink)
mkdir -p "$H/dotfiles"
printf '[user]\n\tname = X\n\n\n[alias]\n\tco = checkout\n' > "$H/dotfiles/gitconfig"
cp "$H/dotfiles/gitconfig" "$H/original"
ln -s "$H/dotfiles/gitconfig" "$H/.gitconfig"
run_home "$H" create sl "Sl" sl@test.com "$H/sl" --no-ssh-key >/dev/null 2>&1
if [ -L "$H/.gitconfig" ]; then
    PASS=$((PASS + 1)); echo "  PASS: gitconfig symlink survives create"
else
    FAIL=$((FAIL + 1)); FAILED_TESTS+=("gitconfig symlink survives create"); echo "  FAIL: gitconfig symlink survives create"
fi
assert_contains "includeIf written through symlink" "gitdir:$H/sl/" "$(cat "$H/dotfiles/gitconfig")"
assert_file_exists "gitconfig backup written" "$H/.config/git-persona/gitconfig.bak"
run_home "$H" delete sl >/dev/null 2>&1
if cmp -s "$H/original" "$H/dotfiles/gitconfig" && [ -L "$H/.gitconfig" ]; then
    PASS=$((PASS + 1)); echo "  PASS: delete restores gitconfig exactly, symlink intact"
else
    FAIL=$((FAIL + 1)); FAILED_TESTS+=("delete restores gitconfig exactly"); echo "  FAIL: delete restores gitconfig exactly"
    diff "$H/original" "$H/dotfiles/gitconfig" || true
fi

# --- Existing keys are never reused by --no-ssh-key or deleted unless owned ---
echo "--- Key ownership ---"
H=$(new_home keys)
mkdir -p "$H/.ssh"
for k in nk reuse; do
    printf 'PRIVATE' > "$H/.ssh/id_ed25519_git_$k"
    printf 'PUBLIC' > "$H/.ssh/id_ed25519_git_$k.pub"
done
run_home "$H" create nk "Nk" nk@test.com "$H/nk" --no-ssh-key >/dev/null 2>&1
assert_not_contains "--no-ssh-key ignores a pre-existing key" "sshCommand" "$(cat "$H/.config/git-persona/profiles/nk.gitconfig")"
run_home "$H" delete nk --with-keys >/dev/null 2>&1
assert_file_exists "--no-ssh-key profile delete leaves unrelated key" "$H/.ssh/id_ed25519_git_nk"
output=$(run_home "$H" create reuse "Re" re@test.com "$H/reuse" 2>&1)
assert_contains "reuse reports existing key" "already exists" "$output"
assert_contains "reused key is wired into sshCommand" "id_ed25519_git_reuse" "$(cat "$H/.config/git-persona/profiles/reuse.gitconfig")"
output=$(run_home "$H" delete reuse --with-keys 2>&1)
assert_file_exists "delete --with-keys keeps a key it did not generate" "$H/.ssh/id_ed25519_git_reuse"
assert_contains "delete explains why key was kept" "not recorded as generated" "$output"

# --- delete --with-keys refuses paths outside ~/.ssh ---
echo "--- Delete refuses foreign key path ---"
H=$(new_home foreign)
run_home "$H" create victim "V" v@test.com "$H/victim" --no-ssh-key >/dev/null 2>&1
printf 'PRECIOUS' > "$H/precious"
printf '%s\n' 'id="victim"' 'name="V"' 'email="v@test.com"' "base_dir=\"$H/victim\"" \
    "key_file=\"$H/precious\"" 'key_owned="1"' "profile_file=\"$H/.config/git-persona/profiles/victim.gitconfig\"" \
    > "$H/.config/git-persona/profiles/victim.conf"
output=$(run_home "$H" delete victim --with-keys 2>&1)
assert_file_exists "foreign key_file not deleted" "$H/precious"
assert_contains "refusal is reported" "Refusing to remove" "$output"
assert_file_not_exists "profile still deleted" "$H/.config/git-persona/profiles/victim.conf"

# --- Conf files are parsed, never executed ---
echo "--- Conf is not sourced ---"
H=$(new_home noexec)
mkdir -p "$H/.config/git-persona/profiles"
printf '%s\n' 'id="evil"' "name=\"\$(touch $H/PWNED1)\"" 'email="e@test.com"' \
    "touch $H/PWNED2" "key_file=\"\"; touch $H/PWNED3" \
    > "$H/.config/git-persona/profiles/evil.conf"
output=$(run_home "$H" list 2>&1)
assert_contains "list shows literal command text" "touch $H/PWNED1" "$output"
if [ -e "$H/PWNED1" ] || [ -e "$H/PWNED2" ] || [ -e "$H/PWNED3" ]; then
    FAIL=$((FAIL + 1)); FAILED_TESTS+=("conf executed code"); echo "  FAIL: conf executed code"
else
    PASS=$((PASS + 1)); echo "  PASS: conf content is never executed"
fi

# --- Failed create leaves nothing behind ---
echo "--- Create rollback ---"
H=$(new_home rollback)
FAKEBIN="$H/fakebin"
mkdir -p "$FAKEBIN"
printf '#!/bin/sh\nexit 1\n' > "$FAKEBIN/ssh-keygen"
chmod +x "$FAKEBIN/ssh-keygen"
output=$(PATH="$FAKEBIN:$PATH" run_home "$H" create rb "Rb" rb@test.com "$H/rb" 2>&1 || true)
assert_contains "failed create reports rollback" "partial profile files were removed" "$output"
assert_file_not_exists "rollback removed conf" "$H/.config/git-persona/profiles/rb.conf"
assert_file_not_exists "rollback removed profile gitconfig" "$H/.config/git-persona/profiles/rb.gitconfig"
output=$(run_home "$H" create rb "Rb" rb@test.com "$H/rb" --no-ssh-key 2>&1)
assert_contains "create succeeds after rolled-back attempt" "Profile 'rb' created" "$output"

# --- Read-only commands leave no trace ---
echo "--- No side effects ---"
H=$(new_home pristine)
for c in version help list current; do
    run_home "$H" "$c" >/dev/null 2>&1 || true
done
if [ -e "$H/.config" ] || [ -e "$H/.gitconfig" ] || [ -e "$H/.ssh" ]; then
    FAIL=$((FAIL + 1)); FAILED_TESTS+=("read-only commands left files"); echo "  FAIL: read-only commands left files"
else
    PASS=$((PASS + 1)); echo "  PASS: version/help/list/current create nothing"
fi

# --- Default base_dir ---
echo "--- Default base_dir ---"
H=$(new_home defbase)
output=$(run_home "$H" create defp "D" d@test.com --no-ssh-key 2>&1)
assert_contains "create without base_dir succeeds" "Profile 'defp' created" "$output"
if [ -d "$H/git-profiles/defp" ]; then
    PASS=$((PASS + 1)); echo "  PASS: default base_dir created"
else
    FAIL=$((FAIL + 1)); FAILED_TESTS+=("default base_dir created"); echo "  FAIL: default base_dir created"
fi

# --- Folder matching through symlinks, and reassignment notice ---
echo "--- Folder matching ---"
H=$(new_home folders)
run_home "$H" create lnk "Lnk" lnk@test.com "$H/realdir" --no-ssh-key >/dev/null 2>&1
ln -s "$H/realdir" "$H/linkdir"
cd "$H/linkdir"
output=$(run_home "$H" current)
assert_contains "current matches through a symlinked cwd" "Profile that would apply here: lnk" "$output"
cd "$TEST_HOME"
run_home "$H" create other "Other" other@test.com "$H/otherdir" --no-ssh-key >/dev/null 2>&1
output=$(run_home "$H" use-folder other "$H/realdir")
assert_contains "use-folder reports reassignment" "previously assigned" "$output"

# --- Legacy confs (no key_owned) never lose their key ---
echo "--- Legacy conf key safety ---"
H=$(new_home legacy)
mkdir -p "$H/.ssh"
printf 'PRIVATE' > "$H/.ssh/id_ed25519_git_old"
run_home "$H" create old "Old" old@test.com "$H/old" --no-ssh-key >/dev/null 2>&1
printf '%s\n' 'id="old"' 'name="Old"' 'email="old@test.com"' "base_dir=\"$H/old\"" \
    "key_file=\"$H/.ssh/id_ed25519_git_old\"" "profile_file=\"$H/.config/git-persona/profiles/old.gitconfig\"" \
    > "$H/.config/git-persona/profiles/old.conf"
output=$(run_home "$H" delete old --with-keys 2>&1)
assert_file_exists "legacy conf key kept by --with-keys" "$H/.ssh/id_ed25519_git_old"
assert_contains "legacy delete explains how to remove key" "remove it manually" "$output"

# --- gitconfig section boundaries ---
echo "--- includeIf section boundaries ---"
H=$(new_home sections)
run_home "$H" create sec "Sec" sec@test.com "$H/sec" --no-ssh-key >/dev/null 2>&1
run_home "$H" create other "Other" other@test.com "$H/other" --no-ssh-key >/dev/null 2>&1
mkdir -p "$H/a"
# Pathless block for /a followed by an unrelated block for /b and a plain include.
printf '[includeIf "gitdir:%s/a/"]\n[includeIf "gitdir:/b/"]\n    path = /b.gitconfig\n[include]\n    path = /plain.gitconfig\n' "$H" > "$H/.gitconfig"
run_home "$H" use-folder sec "$H/a" >/dev/null 2>&1
content="$(cat "$H/.gitconfig")"
assert_contains "unrelated includeIf path untouched" "path = /b.gitconfig" "$content"
assert_contains "plain include path untouched" "path = /plain.gitconfig" "$content"
assert_contains "pathless folder now mapped" "path = $H/.config/git-persona/profiles/sec.gitconfig" "$content"

echo "--- Delete drops whole block ---"
printf '[user]\n    name = X\n\n[includeIf "gitdir:%s/other/"]\n    path = %s/.config/git-persona/profiles/other.gitconfig\n    # note\n    stray = 1\n\n[alias]\n    co = checkout\n' "$H" "$H" > "$H/.gitconfig"
run_home "$H" delete other >/dev/null 2>&1
printf '[user]\n    name = X\n\n[alias]\n    co = checkout\n' > "$H/expected"
if cmp -s "$H/expected" "$H/.gitconfig"; then
    PASS=$((PASS + 1)); echo "  PASS: delete removes block incl. trailing keys, no leakage"
else
    FAIL=$((FAIL + 1)); FAILED_TESTS+=("delete removes whole block"); echo "  FAIL: delete removes whole block"
    diff "$H/expected" "$H/.gitconfig" || true
fi

# --- Damaged (CRLF) conf still cleans up its includeIf ---
echo "--- CRLF conf ---"
H=$(new_home crlf)
run_home "$H" create cr "Cr" cr@test.com "$H/cr" --no-ssh-key >/dev/null 2>&1
conf="$H/.config/git-persona/profiles/cr.conf"
cr=$'\r'
while IFS= read -r l || [ -n "$l" ]; do printf '%s%s\n' "$l" "$cr"; done < "$conf" > "$conf.tmp"
mv "$conf.tmp" "$conf"
run_home "$H" delete cr >/dev/null 2>&1
assert_not_contains "CRLF conf delete removes includeIf" "cr.gitconfig" "$(cat "$H/.gitconfig")"

# --- Dot leaf and create reassignment note ---
echo "--- base_dir leaf and reassignment note ---"
H=$(new_home leaf)
output=$(run_home "$H" create dots Name e@test.com "$H/.." --no-ssh-key 2>&1 || true)
assert_contains "'..' leaf rejected" "real folder name" "$output"
run_home "$H" create first "F" f@test.com "$H/shared" --no-ssh-key >/dev/null 2>&1
output=$(run_home "$H" create second "S" s@test.com "$H/shared" --no-ssh-key 2>&1)
assert_contains "create reports folder reassignment" "previously assigned" "$output"

# --- includeIf block editing edge cases ---
echo "--- includeIf block edge cases ---"
H=$(new_home blocks)
run_home "$H" create bl "Bl" bl@test.com "$H/bl" --no-ssh-key >/dev/null 2>&1
PF="$H/.config/git-persona/profiles/bl.gitconfig"

# Interior blank lines of a removed block must not survive.
printf '[user]\n    name = X\n\n[includeIf "gitdir:%s/bl/"]\n    path = %s\n\n    # tail\n    k = 1\n\n[alias]\n    co = checkout\n' "$H" "$PF" > "$H/.gitconfig"
printf '[user]\n    name = X\n\n[alias]\n    co = checkout\n' > "$H/expected"
run_home "$H" delete bl >/dev/null 2>&1
if cmp -s "$H/expected" "$H/.gitconfig"; then
    PASS=$((PASS + 1)); echo "  PASS: blank lines inside a removed block are dropped"
else
    FAIL=$((FAIL + 1)); FAILED_TESTS+=("interior blank lines in removed block"); echo "  FAIL: interior blank lines in removed block"
    diff "$H/expected" "$H/.gitconfig" || true
fi

# A blank line before path= does not end the section; odd spacing and key case parse.
run_home "$H" create bl "Bl" bl@test.com "$H/bl" --no-ssh-key >/dev/null 2>&1
printf '[user]\n    name = X\n\n[includeif "gitdir:%s/bl/"]\n\n  Path=%s\n[alias]\n    co = checkout\n' "$H" "$PF" > "$H/.gitconfig"
run_home "$H" delete bl >/dev/null 2>&1
assert_not_contains "blank-separated, oddly spaced path removed" "bl.gitconfig" "$(cat "$H/.gitconfig")"
assert_contains "neighbouring section survives" "co = checkout" "$(cat "$H/.gitconfig")"

# Two paths in one section: only ours goes.
run_home "$H" create bl "Bl" bl@test.com "$H/bl" --no-ssh-key >/dev/null 2>&1
printf '[includeIf "gitdir:%s/bl/"]\n    path = /keep/me.gitconfig\n    path   =   %s\n' "$H" "$PF" > "$H/.gitconfig"
run_home "$H" delete bl >/dev/null 2>&1
assert_contains "other path in shared section kept" "/keep/me.gitconfig" "$(cat "$H/.gitconfig")"
assert_not_contains "our path removed from shared section" "bl.gitconfig" "$(cat "$H/.gitconfig")"

# use-folder dedups against a path written without spaces.
run_home "$H" create bl2 "Bl2" bl2@test.com "$H/bl2" --no-ssh-key >/dev/null 2>&1
PF2="$H/.config/git-persona/profiles/bl2.gitconfig"
printf '[includeIf "gitdir:%s/bl2/"]\npath=%s\n' "$H" "$PF2" > "$H/.gitconfig"
run_home "$H" use-folder bl2 "$H/bl2" >/dev/null 2>&1
assert_equals "spacing-tolerant dedup keeps one block" "1" "$(grep -c 'gitdir:' "$H/.gitconfig")"
cd "$H/bl2"
output=$(run_home "$H" current)
assert_contains "current reads path=X without spaces" "Profile that would apply here: bl2" "$output"
cd "$TEST_HOME"

# --- profile_file in a conf can never point outside the profiles dir ---
echo "--- profile_file traversal ---"
H=$(new_home traversal)
run_home "$H" create tv "Tv" tv@test.com "$H/tv" --no-ssh-key >/dev/null 2>&1
printf 'PRECIOUS' > "$H/victim"
printf '%s\n' 'id="tv"' 'name="Tv"' 'email="tv@test.com"' \
    "profile_file=\"$H/.config/git-persona/profiles/../../../victim\"" \
    > "$H/.config/git-persona/profiles/tv.conf"
output=$(run_home "$H" delete tv 2>&1)
assert_file_exists "traversing profile_file does not delete outside files" "$H/victim"
assert_contains "unexpected profile_file is reported" "ignoring unexpected profile_file" "$output"
assert_file_not_exists "real profile gitconfig still removed" "$H/.config/git-persona/profiles/tv.gitconfig"

# --- backup message only when a backup exists ---
echo "--- Backup message ---"
H=$(new_home nobackup)
ln -s "$H/no-such-dir/gitconfig" "$H/.gitconfig"
output=$(run_home "$H" create nb "Nb" nb@test.com "$H/nb" --no-ssh-key 2>&1 || true)
assert_contains "failed write is reported" "Failed to write" "$output"
assert_not_contains "no backup claimed when none was made" "previous content is saved" "$output"
assert_file_not_exists "failed create rolled back" "$H/.config/git-persona/profiles/nb.conf"

# --- base_dir slash normalisation ---
echo "--- base_dir slashes ---"
H=$(new_home slashes)
output=$(run_home "$H" create sl1 "S" s@test.com "$H/dir//" --no-ssh-key 2>&1)
assert_contains "trailing double slash normalised" "Base directory: $H/dir" "$output"
assert_contains "gitdir has a single trailing slash" "gitdir:$H/dir/\"" "$(cat "$H/.gitconfig")"
output=$(run_home "$H" create sl2 "S" s@test.com "//" --no-ssh-key 2>&1 || true)
assert_contains "filesystem root rejected" "filesystem root" "$output"

# --- CR-only conf and CRLF gitconfig ---
echo "--- Line ending handling ---"
H=$(new_home cr)
run_home "$H" create co "Co" co@test.com "$H/co" --no-ssh-key >/dev/null 2>&1
conf="$H/.config/git-persona/profiles/co.conf"
tr '\n' '\r' < "$conf" > "$conf.tmp" && mv "$conf.tmp" "$conf"
output=$(run_home "$H" list)
assert_contains "CR-only conf parses" "email:    co@test.com" "$output"

H=$(new_home crlf-gitconfig)
printf '[user]\r\n    name = X\r\n' > "$H/.gitconfig"
cp "$H/.gitconfig" "$H/original"
output=$(run_home "$H" create cg "Cg" cg@test.com "$H/cg" --no-ssh-key 2>&1 || true)
assert_contains "CRLF gitconfig refused" "CRLF" "$output"
assert_file_not_exists "nothing created for CRLF gitconfig" "$H/.config/git-persona/profiles/cg.conf"
if cmp -s "$H/original" "$H/.gitconfig"; then
    PASS=$((PASS + 1)); echo "  PASS: CRLF gitconfig left untouched"
else
    FAIL=$((FAIL + 1)); FAILED_TESTS+=("CRLF gitconfig untouched"); echo "  FAIL: CRLF gitconfig untouched"
fi

# --- Multiple paths, header casing, value normalisation ---
echo "--- includeIf semantics matching git ---"
H=$(new_home gitsem)
run_home "$H" create w "W" w@test.com "$H/w" --no-ssh-key >/dev/null 2>&1
run_home "$H" create o "O" o@test.com "$H/o" --no-ssh-key >/dev/null 2>&1
PW="$H/.config/git-persona/profiles/w.gitconfig"
PO="$H/.config/git-persona/profiles/o.gitconfig"
mkdir -p "$H/x"

# Another profile's path is replaced by ours; a hand-added path is kept.
printf '[includeIf "gitdir:%s/x/"]\n    path = %s\n    path = %s/hand.inc\n' "$H" "$PO" "$H" > "$H/.gitconfig"
printf '[alias]\n    zz = status\n' > "$H/hand.inc"
output=$(run_home "$H" use-folder w "$H/x" 2>&1)
content="$(cat "$H/.gitconfig")"
assert_contains "use-folder reports replacing another profile" "previously assigned" "$output"
assert_not_contains "other profile's path replaced" "o.gitconfig" "$content"
assert_contains "hand-added path is preserved" "hand.inc" "$content"
cd "$H/x"
git init -q
assert_equals "git resolves the new identity" "W" "$(HOME="$H" git config user.name)"
assert_equals "hand-added file still applies" "status" "$(HOME="$H" git config alias.zz)"
cd "$TEST_HOME"

# Layered hand-added paths survive and ours goes last so identity wins.
printf '[user]\n    name = Layer1\n    email = l1@test.com\n' > "$H/layer1.inc"
printf '[user]\n    name = Layer2\n' > "$H/layer2.inc"
printf '[includeIf "gitdir:%s/x/"]\n    path = %s/layer1.inc\n    path = %s/layer2.inc\n' "$H" "$H" "$H" > "$H/.gitconfig"
run_home "$H" use-folder w "$H/x" >/dev/null 2>&1
content="$(cat "$H/.gitconfig")"
assert_contains "first layered path kept" "layer1.inc" "$content"
assert_contains "second layered path kept" "layer2.inc" "$content"
cd "$H/x"
assert_equals "profile identity wins over layered files" "W" "$(HOME="$H" git config user.name)"
assert_equals "profile email wins too" "w@test.com" "$(HOME="$H" git config user.email)"
cd "$TEST_HOME"
cp "$H/.gitconfig" "$H/before"
run_home "$H" use-folder w "$H/x" >/dev/null 2>&1
if cmp -s "$H/before" "$H/.gitconfig"; then
    PASS=$((PASS + 1)); echo "  PASS: use-folder is idempotent on a correct section"
else
    FAIL=$((FAIL + 1)); FAILED_TESTS+=("use-folder idempotent"); echo "  FAIL: use-folder is idempotent on a correct section"
fi

# A pathless section gets its path inside it, not a duplicate section.
printf '[includeIf "gitdir:%s/x/"]\n[alias]\n    keep = me\n' "$H" > "$H/.gitconfig"
run_home "$H" use-folder w "$H/x" >/dev/null 2>&1
assert_equals "pathless section reused" "1" "$(grep -c 'includeIf' "$H/.gitconfig")"
assert_contains "path added to the pathless section" "$PW" "$(cat "$H/.gitconfig")"
assert_contains "following section untouched" "keep = me" "$(cat "$H/.gitconfig")"

# Values are read the way git reads them: quotes toggle, ~/ is $HOME.
printf '[includeIf "gitdir:~/w/"]\n    path = ~/.config/git-persona/profiles/w.gitconfig\n' > "$H/.gitconfig"
run_home "$H" use-folder w "$H/w" >/dev/null 2>&1
assert_equals "~/ header and path dedup against absolute ones" "1" "$(grep -c 'gitdir:' "$H/.gitconfig")"

# Section names are case-insensitive in git.
printf '[INCLUDEIF "gitdir:%s/w/"]\n    path = %s\n' "$H" "$PW" > "$H/.gitconfig"
cd "$H/w"
output=$(run_home "$H" current)
assert_contains "current sees an upper-case header" "Profile that would apply here: w" "$output"
cd "$TEST_HOME"
run_home "$H" use-folder w "$H/w" >/dev/null 2>&1
assert_equals "no duplicate block next to an upper-case header" "1" "$(grep -ic 'includeif' "$H/.gitconfig")"
run_home "$H" delete w >/dev/null 2>&1
assert_not_contains "upper-case header block removed" "w.gitconfig" "$(cat "$H/.gitconfig")"

# Quoted and commented values are read the way git reads them.
run_home "$H" create w "W" w@test.com "$H/w" --no-ssh-key >/dev/null 2>&1
printf '[includeIf "gitdir:%s/w/"]\n    path = "%s" # note\n' "$H" "$PW" > "$H/.gitconfig"
run_home "$H" delete w >/dev/null 2>&1
assert_not_contains "quoted, commented path removed" "w.gitconfig" "$(cat "$H/.gitconfig")"

# Quotes toggle in git, so "a"b is ab.
run_home "$H" create w "W" w@test.com "$H/w" --no-ssh-key >/dev/null 2>&1
printf '[includeIf "gitdir:%s/w/"]\n    path = "%s"g\n' "$H" "${PW%g}" > "$H/.gitconfig"
run_home "$H" delete w >/dev/null 2>&1
assert_not_contains "partially quoted path removed" "w.gitconf" "$(cat "$H/.gitconfig")"

# Extra spaces inside the header still dedup.
printf '[includeIf  "gitdir:%s/o/"]\n    path = %s\n' "$H" "$PO" > "$H/.gitconfig"
run_home "$H" use-folder o "$H/o" >/dev/null 2>&1
assert_equals "header with extra spaces is deduped" "1" "$(grep -c 'gitdir:' "$H/.gitconfig")"

# Whitespace-only trailing lines count as separators.
printf '[user]\n    name = X\n\n[includeIf "gitdir:%s/o/"]\n    path = %s\n  \n[alias]\n    co = checkout\n' "$H" "$PO" > "$H/.gitconfig"
printf '[user]\n    name = X\n\n[alias]\n    co = checkout\n' > "$H/expected"
run_home "$H" delete o >/dev/null 2>&1
if cmp -s "$H/expected" "$H/.gitconfig"; then
    PASS=$((PASS + 1)); echo "  PASS: whitespace-only separator handled"
else
    FAIL=$((FAIL + 1)); FAILED_TESTS+=("whitespace-only separator"); echo "  FAIL: whitespace-only separator"
    diff "$H/expected" "$H/.gitconfig" || true
fi

# A HOME containing ; and # must round-trip through git's own parser.
echo "--- Path quoting round trip ---"
H=$(new_home 'semi;colon#hash')
run_home "$H" create q "Quoted" q@test.com "$H/q" --no-ssh-key >/dev/null 2>&1
mkdir -p "$H/q/repo"
cd "$H/q/repo"
git init -q
assert_equals "git follows a ;/# path in includeIf" "Quoted" "$(HOME="$H" git config user.name)"
cd "$TEST_HOME"
run_home "$H" delete q >/dev/null 2>&1
assert_not_contains "quoted path block removed again" "q.gitconfig" "$(cat "$H/.gitconfig")"

# --- Malformed confs and untrusted profile_file in current ---
echo "--- Malformed confs ---"
H=$(new_home malformed)
run_home "$H" create ok "Ok" ok@test.com "$H/ok" --no-ssh-key >/dev/null 2>&1
: > "$H/.config/git-persona/profiles/empty.conf"
output=$(run_home "$H" list 2>&1)
assert_contains "list warns about an empty conf" "skipping unreadable or malformed" "$output"
assert_equals "no phantom entry for the empty conf" "1" "$(printf '%s\n' "$output" | grep -c 'name:')"
conf="$H/.config/git-persona/profiles/ok.conf"
printf '%s\n' 'id="ok"' 'name="Ok"' 'email="ok@test.com"' "base_dir=\"$H/ok\"" 'profile_file="/bogus/path.gitconfig"' > "$conf"
cd "$H/ok"
output=$(run_home "$H" current)
assert_contains "current ignores a bogus profile_file in the conf" "Profile that would apply here: ok" "$output"
cd "$TEST_HOME"

# --- Persona path classification, damaged confs, key binding ---
echo "--- Foreign path classification ---"
H=$(new_home classify)
run_home "$H" create w "W" w@test.com "$H/w" --no-ssh-key >/dev/null 2>&1
run_home "$H" create w2 "W2" w2@test.com "$H/w2" --no-ssh-key >/dev/null 2>&1
PR="$H/.config/git-persona/profiles"
mkdir -p "$H/x"

# A ".." path that git resolves to a foreign file is not ours to drop.
printf '[alias]\n    zz = hand\n' > "$H/.config/git-persona/team.gitconfig"
printf '[includeIf "gitdir:%s/x/"]\n    path = %s/../team.gitconfig\n' "$H" "$PR" > "$H/.gitconfig"
run_home "$H" use-folder w "$H/x" >/dev/null 2>&1
assert_contains "path with .. is kept as foreign" "../team.gitconfig" "$(cat "$H/.gitconfig")"
cd "$H/x"; git init -q
assert_equals "foreign file reached through .. still applies" "hand" "$(HOME="$H" git config alias.zz)"
cd "$TEST_HOME"

# A quoted escape that git decodes to a control character is not a profile id.
printf '[includeIf "gitdir:%s/x/"]\n    path = "%s/w2\\t.gitconfig"\n' "$H" "$PR" > "$H/.gitconfig"
run_home "$H" use-folder w "$H/x" >/dev/null 2>&1
assert_contains "escape-disguised path is kept as foreign" 'w2\t.gitconfig' "$(cat "$H/.gitconfig")"

# ~user/ is expanded only for valid login names, never executed.
mkdir -p "$H/pwn"
printf '[includeIf "gitdir:%s/x/"]\n    path = "~a;touch %s/pwn/q"\n' "$H" "$H" > "$H/.gitconfig"
run_home "$H" use-folder w "$H/x" >/dev/null 2>&1
if [ -z "$(ls -A "$H/pwn")" ]; then
    PASS=$((PASS + 1)); echo "  PASS: ~user expansion never executes the path"
else
    FAIL=$((FAIL + 1)); FAILED_TESTS+=("~user expansion executed"); echo "  FAIL: ~user expansion executed"
fi

echo "--- Header forms ---"
mkdir -p "$H/Mixed" "$H/rel"
printf '[includeIf "gitdir/i:%s/mixed/"]\n    path = %s/w.gitconfig\n' "$H" "$PR" > "$H/.gitconfig"
run_home "$H" use-folder w "$H/Mixed" >/dev/null 2>&1
assert_equals "gitdir/i: header deduped" "1" "$(grep -c 'includeIf' "$H/.gitconfig")"
printf '[includeIf "gitdir:./rel/"]\n    path = %s/w.gitconfig\n' "$PR" > "$H/.gitconfig"
run_home "$H" use-folder w "$H/rel" >/dev/null 2>&1
assert_equals "relative ./ header deduped" "1" "$(grep -c 'includeIf' "$H/.gitconfig")"
cd "$H/rel"
output=$(run_home "$H" current)
assert_contains "current resolves a ./ header" "Profile that would apply here: w" "$output"
cd "$TEST_HOME"

echo "--- Two matching sections ---"
printf '[includeIf "gitdir:%s/x/"]\n    path = %s/w2.gitconfig\n[user]\n    name = keep\n[includeIf "gitdir:%s/x/"]\n    path = %s/hand2.inc\n' "$H" "$PR" "$H" "$H" > "$H/.gitconfig"
run_home "$H" use-folder w "$H/x" >/dev/null 2>&1
content="$(cat "$H/.gitconfig")"
assert_equals "our path appears once across duplicate sections" "1" "$(grep -c "path = $PR/w.gitconfig" "$H/.gitconfig")"
assert_not_contains "stale persona path cleared from the earlier section" "w2.gitconfig" "$content"
assert_contains "hand-added path in the last section kept" "hand2.inc" "$content"
assert_contains "unrelated section kept" "name = keep" "$content"

echo "--- Damaged conf lifecycle ---"
H=$(new_home damaged)
run_home "$H" create dm "Dm" dm@test.com "$H/dm" --no-ssh-key >/dev/null 2>&1
conf="$H/.config/git-persona/profiles/dm.conf"
printf '%s\n' 'name="Dm"' 'email="dm@test.com"' > "$conf"
mkdir -p "$H/dm/repo"; cd "$H/dm/repo"; git init -q
output=$(run_home "$H" use dm 2>&1 || true)
assert_contains "use refuses a damaged profile" "is damaged" "$output"
cd "$TEST_HOME"
output=$(run_home "$H" delete dm 2>&1)
assert_contains "delete cleans a damaged profile" "Profile 'dm' deleted" "$output"
assert_file_not_exists "damaged conf removed" "$conf"
assert_file_not_exists "damaged profile gitconfig removed" "$H/.config/git-persona/profiles/dm.gitconfig"
assert_not_contains "damaged profile includeIf removed" "dm.gitconfig" "$(cat "$H/.gitconfig")"

echo "--- Key bound to profile ---"
H=$(new_home keybind)
run_home "$H" create ka "Ka" ka@test.com "$H/ka" >/dev/null 2>&1
run_home "$H" create kb "Kb" kb@test.com "$H/kb" >/dev/null 2>&1
conf="$H/.config/git-persona/profiles/ka.conf"
printf '%s\n' 'id="ka"' 'name="Ka"' 'email="ka@test.com"' "key_file=\"$H/.ssh/id_ed25519_git_kb\"" 'key_owned="1"' > "$conf"
output=$(run_home "$H" delete ka --with-keys 2>&1)
assert_file_exists "another profile's key is never removed" "$H/.ssh/id_ed25519_git_kb"
assert_contains "refusal names the profile that owns the key" "owns" "$output"

# --- Lines that merely mention a gitdir string must not count as sections ---
echo "--- Stray gitdir mentions ---"
H=$(new_home strays)
run_home "$H" create w "W" w@test.com "$H/w" --no-ssh-key >/dev/null 2>&1
PW="$H/.config/git-persona/profiles/w.gitconfig"
mkdir -p "$H/x"
for variant in comment-after value-before quoted-comment; do
    case "$variant" in
        comment-after) printf '[includeIf "gitdir:%s/x/"]\n    path = /hand.inc\n#[includeIf "gitdir:%s/x/"]\n' "$H" "$H" > "$H/.gitconfig" ;;
        value-before) printf '[alias]\n    zz = "gitdir:%s/x/"\n[includeIf "gitdir:%s/x/"]\n    path = /hand.inc\n' "$H" "$H" > "$H/.gitconfig" ;;
        quoted-comment) printf '[includeIf "gitdir:%s/x/"] # keep "this" one\n    path = /hand.inc\n' "$H" > "$H/.gitconfig" ;;
    esac
    run_home "$H" use-folder w "$H/x" >/dev/null 2>&1
    content="$(cat "$H/.gitconfig")"
    assert_contains "$variant: our path is written" "path = $PW" "$content"
    assert_contains "$variant: hand-added path kept" "/hand.inc" "$content"
    expected_headers=1
    [ "$variant" = comment-after ] && expected_headers=2
    assert_equals "$variant: no extra section appended" "$expected_headers" "$(printf '%s\n' "$content" | grep -c 'includeIf')"
done
printf '[includeIf "gitdir:%s/x/"] # keep "this" one\n    path = /hand.inc\n' "$H" > "$H/.gitconfig"
run_home "$H" use-folder w "$H/x" >/dev/null 2>&1
assert_equals "header with a quoted comment is reused, not duplicated" "1" "$(grep -c 'includeIf' "$H/.gitconfig")"

# --- ~ forms that are not login names stay literal ---
echo "--- Tilde forms ---"
PR="$H/.config/git-persona/profiles"
run_home "$H" create w2 "W2" w2@test.com "$H/w2" --no-ssh-key >/dev/null 2>&1
printf '[includeIf "gitdir:%s/x/"]\n    path = ~-/w2.gitconfig\n' "$H" > "$H/.gitconfig"
OLDPWD="$PR" run_home "$H" use-folder w "$H/x" >/dev/null 2>&1
assert_contains "~- is not expanded to OLDPWD and stays a foreign path" "~-/w2.gitconfig" "$(cat "$H/.gitconfig")"

# --- use-folder refuses a profile that use refuses ---
echo "--- Damaged profile in use-folder ---"
H=$(new_home dmg-folder)
run_home "$H" create dg "Dg" dg@test.com "$H/dg" --no-ssh-key >/dev/null 2>&1
printf '%s\n' 'name="Dg"' 'email="dg@test.com"' > "$H/.config/git-persona/profiles/dg.conf"
mkdir -p "$H/other"
output=$(run_home "$H" use-folder dg "$H/other" 2>&1 || true)
assert_contains "use-folder refuses a damaged profile" "is damaged" "$output"
assert_not_contains "no includeIf written for a damaged profile" "$H/other" "$(cat "$H/.gitconfig")"
output=$(run_home "$H" delete dg 2>&1)
assert_not_contains "damaged delete does not print an empty base directory" "base directory  was" "$output"

# --- A conf whose id differs from its filename ---
echo "--- id vs filename ---"
H=$(new_home idname)
run_home "$H" create ya "Ya" ya@test.com "$H/ya" >/dev/null 2>&1
printf '%s\n' 'id="xa"' 'name="Ya"' 'email="ya@test.com"' "key_file=\"$H/.ssh/id_ed25519_git_xa\"" 'key_owned="1"' > "$H/.config/git-persona/profiles/ya.conf"
printf 'K' > "$H/.ssh/id_ed25519_git_xa"
output=$(run_home "$H" delete ya --with-keys 2>&1)
assert_file_exists "key of a differently-named id is kept" "$H/.ssh/id_ed25519_git_xa"
assert_contains "refusal says which key the profile owns" "id_ed25519_git_ya" "$output"
assert_contains "profile is still deleted" "Profile 'ya' deleted" "$output"

# --- Parser unit tests (the script is source-able) ---
echo "--- parse_path_line / includeif_condition ---"
H=$(new_home units)
parse() { HOME="$H" bash -c 'source "$1"; parse_path_line "$2" && printf "%s" "$PATH_VALUE"' _ "$SCRIPT" "$1"; }
cond() { HOME="$H" bash -c 'source "$1"; includeif_condition "$2" && printf "%s" "$INCLUDEIF_COND"' _ "$SCRIPT" "$1"; }
ROOT_HOME="$(eval echo ~root)"

assert_equals "bare ~ is HOME" "$H" "$(parse 'path = ~')"
assert_equals "~/x is under HOME" "$H/x" "$(parse 'path = ~/x')"
if [ "$ROOT_HOME" != "~root" ]; then
    assert_equals "bare ~user expands" "$ROOT_HOME" "$(parse 'path = ~root')"
    assert_equals "~user/rest expands" "$ROOT_HOME/y" "$(parse 'path = ~root/y')"
fi
assert_equals "digit-leading name stays literal" "~0abc" "$(parse 'path = ~0abc')"
assert_equals "~- stays literal" "~-/z" "$(parse 'path = ~-/z')"
assert_equals "\\t decodes to a tab" "a"$'\t'"b" "$(parse 'path = "a\tb"')"
assert_equals "\\b decodes to backspace" "a"$'\b'"b" "$(parse 'path = "a\bb"')"
assert_equals "\\n decodes to a newline" "a"$'\n'"b" "$(parse 'path = "a\nb"')"
assert_equals "quotes toggle" "ab" "$(parse 'path = "a"b # c')"
assert_equals "comment ends an unquoted value" "/p" "$(parse 'path = /p ; note')"
assert_equals "quoted trailing space is kept" "/p " "$(parse 'path = "/p "')"
assert_equals "escaped quote in a condition" 'gitdir:/d"x/' "$(cond '[includeIf "gitdir:/d\"x/"]')"
assert_equals "escaped backslash in a condition" 'gitdir:/d\x/' "$(cond '[includeIf "gitdir:/d\\x/"]')"
if cond '#[includeIf "gitdir:/d/"]' >/dev/null; then
    FAIL=$((FAIL + 1)); FAILED_TESTS+=("comment parsed as header"); echo "  FAIL: comment parsed as header"
else
    PASS=$((PASS + 1)); echo "  PASS: commented header is not a header"
fi

# --- current sees a hand-written header whose directory contains a quote ---
echo "--- Escaped quote in a header ---"
H=$(new_home quote)
run_home "$H" create qp "Qp" qp@test.com "$H/qp" --no-ssh-key >/dev/null 2>&1
mkdir -p "$H/q\"x"
printf '[includeIf "gitdir:%s/q\\"x/"]\n    path = %s/.config/git-persona/profiles/qp.gitconfig\n' "$H" "$H" > "$H/.gitconfig"
cd "$H/q\"x"
output=$(run_home "$H" current)
assert_contains "current matches a header with an escaped quote" "Profile that would apply here: qp" "$output"
cd "$TEST_HOME"
mkdir -p "$H/plain"
run_home "$H" use-folder qp "$H/plain" >/dev/null 2>&1
assert_equals "use-folder leaves the escaped-quote block alone" "2" "$(grep -c 'includeIf' "$H/.gitconfig")"

# --- Cleanup ---
echo "--- Cleanup ---"
rm -rf "$TEST_HOME"
echo "  PASS: test environment cleaned up"
PASS=$((PASS + 1))

# --- Summary ---
echo ""
echo "============================================"
echo "Results: $PASS passed, $FAIL failed"
echo "============================================"

if [ "$FAIL" -gt 0 ]; then
    echo ""
    echo "Failed tests:"
    for t in "${FAILED_TESTS[@]}"; do
        echo "  - $t"
    done
    exit 1
fi

echo "All tests passed!"
exit 0
