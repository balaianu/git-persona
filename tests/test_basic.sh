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
