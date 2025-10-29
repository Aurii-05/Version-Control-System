#!/usr/bin/env dash
# ==============================================================
# test1.sh
# Test 1: mygit-commit (outputs + filesystem checks)

# ==============================================================

set -u

# -------------------------helpers-----------------------------
script_dir() {
  cd -P -- "$(dirname -- "$0")" >/dev/null 2>&1 && pwd -P
}
SCRIPTDIR=$(script_dir)

TMPDIR=$(mktemp -d 2>/dev/null || mktemp -d -t mygit-test-2)
[ -d "$TMPDIR" ] || { echo "FAIL: could not create temp directory" >&2; exit 1; }
cleanup() { rm -rf "$TMPDIR"; }
trap cleanup EXIT HUP INT TERM

fail=0

expect_output() {
  desc=$1; exp_output=$2; shift 2
  out="$TMPDIR/out.$$"
  ( "$@" ) >"$out" 2>&1
  actual=$(cat "$out")
  if [ "$actual" != "$exp_output" ]; then
    echo "FAIL: $desc"
    echo "  Expected:"
    printf '%s\n' "$exp_output"
    echo "  Actual:"
    printf '%s\n' "$actual"
    echo ""
    fail=1
  else
    echo "PASS: $desc"
  fi
}

check_path_exists() {
  path=$1; desc=$2
  if [ -e "$path" ]; then
    echo "PASS: $desc"
  else
    echo "FAIL: $desc (missing: $path)"
    fail=1
  fi
}

check_not_exists() {
  path=$1; desc=$2
  if [ ! -e "$path" ]; then
    echo "PASS: $desc"
  else
    echo "FAIL: $desc (exists but should not: $path)"
    fail=1
  fi
}

check_file_equals() {
  path=$1; expected=$2; desc=$3
  if [ ! -f "$path" ]; then
    echo "FAIL: $desc (missing file: $path)"
    fail=1
    return
  fi
  actual=$(cat "$path")
  if [ "$actual" != "$expected" ]; then
    echo "FAIL: $desc"
    echo "  Expected content:"
    printf '%s\n' "$expected"
    echo "  Actual content:"
    printf '%s\n' "$actual"
    fail=1
  else
    echo "PASS: $desc"
  fi
}

# -----------------------run tests -----------------------------
cd "$TMPDIR" || exit 1

# 1) commit without repo -> error
expect_output \
  "commit without repo should error" \
  "mygit-commit: error: mygit repository directory .mygit not found" \
  python3 "$SCRIPTDIR/mygit-commit" -m "x"

# 2) init repo
expect_output \
  "init should create repo" \
  "Initialized empty mygit repository in .mygit" \
  python3 "$SCRIPTDIR/mygit-init"

check_path_exists ".mygit" "repo directory created"
check_path_exists ".mygit/branches/trunk" "default branch 'trunk' exists"

# 3) usage errors
expect_output "commit no args -> usage" \
  "usage: mygit-commit [-a] -m commit-message" \
  python3 "$SCRIPTDIR/mygit-commit"

expect_output "commit '-a' only -> usage" \
  "usage: mygit-commit [-a] -m commit-message" \
  python3 "$SCRIPTDIR/mygit-commit" -a

expect_output "commit wrong flag -> usage" \
  "usage: mygit-commit [-a] -m commit-message" \
  python3 "$SCRIPTDIR/mygit-commit" -x -m "msg"

expect_output "commit '-m' without message -> usage" \
  "usage: mygit-commit [-a] -m commit-message" \
  python3 "$SCRIPTDIR/mygit-commit" -m

# 4) ensure index dir exists, then "nothing to commit" on empty index
#    (mygit-add creates .mygit/index even on usage error)
expect_output \
  "add with no args prints usage (and creates index dir)" \
  "usage: mygit-add <filenames>" \
  python3 "$SCRIPTDIR/mygit-add"

check_path_exists ".mygit/index" "global index directory exists"

expect_output \
  "commit with empty index -> nothing to commit" \
  "nothing to commit" \
  python3 "$SCRIPTDIR/mygit-commit" -m "first"

# 5) stage a file and commit -> commit 0
printf 'hello\n' > a.txt
expect_output \
  "add a.txt success (silent)" \
  "" \
  python3 "$SCRIPTDIR/mygit-add" a.txt

expect_output \
  "first real commit -> commit 0" \
  "Committed as commit 0" \
  python3 "$SCRIPTDIR/mygit-commit" -m "first commit"

check_path_exists ".mygit/repository" "repository dir exists"
check_path_exists ".mygit/repository/0" "commit 0 dir exists"
check_file_equals ".mygit/repository/0/commit_message" "first commit" "commit 0 message recorded"
check_not_exists ".mygit/repository/0/parent" "commit 0 has no parent"
check_file_equals ".mygit/repository/0/a.txt" "hello" "commit 0 captured a.txt content"
check_file_equals ".mygit/branches/trunk/HEAD" "0" "branch HEAD updated to 0"

# 6) unchanged index -> nothing to commit
expect_output \
  "no changes vs commit 0 -> nothing to commit" \
  "nothing to commit" \
  python3 "$SCRIPTDIR/mygit-commit" -m "noop"

# 7) modify tracked file; use -a to commit without re-adding -> commit 1
printf 'hello world\n' > a.txt
expect_output \
  "commit -a updates tracked files -> commit 1" \
  "Committed as commit 1" \
  python3 "$SCRIPTDIR/mygit-commit" -a -m "update via -a"

check_path_exists ".mygit/repository/1" "commit 1 dir exists"
check_file_equals ".mygit/repository/1/commit_message" "update via -a" "commit 1 message recorded"
check_file_equals ".mygit/repository/1/parent" "0" "commit 1 parent points to 0"
check_file_equals ".mygit/repository/1/a.txt" "hello world" "commit 1 captured updated a.txt"
check_file_equals ".mygit/branches/trunk/HEAD" "1" "branch HEAD updated to 1"

# 8) -a does NOT add new files: create c.txt but do not add; expect nothing to commit
printf 'new file\n' > c.txt
expect_output \
  "-a does not stage new files -> nothing to commit" \
  "nothing to commit" \
  python3 "$SCRIPTDIR/mygit-commit" -a -m "should not include c.txt"

# ---------------------summary---------------------------------
if [ "$fail" -ne 0 ]; then
  echo "One or more tests FAILED in Test 2."
  exit 1
fi

echo "All test PASSED in Test 2."
exit 0
