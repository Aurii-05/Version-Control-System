#!/usr/bin/env dash
# ==============================================================
# test8.sh
# Test 8: mygit-merge — merges a branch or commit into the current
# branch, handling fast-forward vs. three-way merges, conflicts,
# and updating the working tree and index.

# ==============================================================

set -u

# ---------------------------- helpers ----------------------------

script_dir() {
  cd -P -- "$(dirname -- "$0")" >/dev/null 2>&1 && pwd -P
}
SCRIPTDIR=$(script_dir)

TMPDIR=$(mktemp -d 2>/dev/null || mktemp -d -t mygit-test-8)
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

# ----------------------------- setup -----------------------------

cd "$TMPDIR" || exit 1

# 1) merge without repo -> error
expect_output \
  "1) merge without repo should error" \
  "mygit-merge: error: mygit repository directory .mygit not found" \
  python3 "$SCRIPTDIR/mygit-merge" trunk -m msg

# 2) usage: missing message entirely -> empty commit message
expect_output \
  "2) missing message -> empty commit message" \
  "mygit-merge: error: empty commit message" \
  python3 "$SCRIPTDIR/mygit-merge" trunk

# 3) usage: wrong flag -> usage
expect_output \
  "3) wrong flag -> usage" \
  "usage: mygit-merge <branch|commit> -m commit-message" \
  python3 "$SCRIPTDIR/mygit-merge" trunk -x msg

# 4) usage: empty message string -> empty commit message
expect_output \
  "4) explicit empty message" \
  "mygit-merge: error: empty commit message" \
  python3 "$SCRIPTDIR/mygit-merge" trunk -m ""

# Initialize repo and create base commit on trunk (commit 0)
python3 "$SCRIPTDIR/mygit-init" >/dev/null 2>&1
printf 'A0\n' > a.txt
python3 "$SCRIPTDIR/mygit-add" a.txt >/dev/null 2>&1
python3 "$SCRIPTDIR/mygit-commit" -m "c0" >/dev/null 2>&1

# Create branch 'feature' from commit 0 and advance it to commit 1
python3 "$SCRIPTDIR/mygit-branch" feature >/dev/null 2>&1
python3 "$SCRIPTDIR/mygit-checkout" feature >/dev/null 2>&1
printf 'F1\n' > fonly.txt
python3 "$SCRIPTDIR/mygit-add" fonly.txt >/dev/null 2>&1
python3 "$SCRIPTDIR/mygit-commit" -m "c1" >/dev/null 2>&1
python3 "$SCRIPTDIR/mygit-checkout" trunk >/dev/null 2>&1

# --------------------------- run tests ---------------------------

# 5) fast-forward merge from 'feature' into trunk
expect_output \
  "5) fast-forward from feature" \
  "Fast-forward: no commit created" \
  python3 "$SCRIPTDIR/mygit-merge" feature -m "ff"
check_file_equals ".mygit/branches/trunk/HEAD" "1" "trunk HEAD moved to 1 (FF)"
check_file_equals "fonly.txt" "F1" "fonly.txt present after FF"
check_file_equals "a.txt" "A0" "a.txt unchanged after FF"
check_not_exists ".mygit/repository/2" "no commit 2 created by FF merge"

# Advance trunk to commit 2 by changing a.txt
printf 'A2\n' > a.txt
python3 "$SCRIPTDIR/mygit-add" a.txt >/dev/null 2>&1
python3 "$SCRIPTDIR/mygit-commit" -m "c2-a" >/dev/null 2>&1
# Create 'conflict' branch pointing to current trunk (commit 2)
python3 "$SCRIPTDIR/mygit-branch" conflict >/dev/null 2>&1

# 6) three-way merge (no conflict): merge older 'feature' (commit 1) into trunk (commit 2)
expect_output \
  "6) three-way non-conflicting merge from feature" \
  "Committed as commit 3" \
  python3 "$SCRIPTDIR/mygit-merge" feature -m "merge feature into trunk"
check_path_exists ".mygit/repository/3" "merge commit 3 created"
check_file_equals ".mygit/branches/trunk/HEAD" "3" "trunk HEAD moved to 3"
check_file_equals "a.txt" "A2" "a.txt kept from trunk"
check_file_equals "fonly.txt" "F1" "fonly.txt brought in from feature"

# 7) conflict merge: both changed a.txt since base -> error and no changes
expect_output \
  "7) conflicting merge from 'conflict' branch" \
  "mygit-merge: error: These files can not be merged:\na.txt" \
  python3 "$SCRIPTDIR/mygit-merge" conflict -m "conflict"
check_file_equals ".mygit/branches/trunk/HEAD" "3" "HEAD unchanged after conflict"

# 8) unknown branch/commit -> error
expect_output \
  "8) unknown branch" \
  "mygit-merge: error: unknown branch 'nope'" \
  python3 "$SCRIPTDIR/mygit-merge" nope -m msg

# 9) merge by explicit commit id (0) -> creates a new merge commit
expect_output \
  "9) merge by commit id 0" \
  "Committed as commit 4" \
  python3 "$SCRIPTDIR/mygit-merge" 0 -m "merge commit 0"
check_path_exists ".mygit/repository/4" "merge commit 4 created"
check_file_equals ".mygit/branches/trunk/HEAD" "4" "trunk HEAD moved to 4"

# ---------------------------- summary ----------------------------

if [ "$fail" -ne 0 ]; then
  echo "One or more tests FAILED in Test 8."
  exit 1
fi

echo "All tests PASSED in Test 8."
exit 0
