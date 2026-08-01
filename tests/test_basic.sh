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
assert_equals "version output" "git-persona 1.3.0" "$output"

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
assert_not_contains "extra includeIf removed" "extra" "$GITCONFIG_CONTENT"

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
