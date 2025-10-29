#!/usr/bin/env dash
# ==============================================================
# test7.sh
# Test 7: mygit-checkout — switches branches and updates the
# working tree and index, with conflict detection when changes
# would be overwritten.

# ==============================================================

set -u

# ---------------------------- helpers ----------------------------

script_dir() {
  cd -P -- "$(dirname -- "$0")" >/dev/null 2>&1 && pwd -P
}
SCRIPTDIR=$(script_dir)

TMPDIR=$(mktemp -d 2>/dev/null || mktemp -d -t mygit-test-7)
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

# 1) checkout without repo -> error
expect_output \
  "1) checkout without repo should error" \
  "mygit-checkout: error: mygit repository directory .mygit not found" \
  python3 "$SCRIPTDIR/mygit-checkout" trunk

# init repo
python3 "$SCRIPTDIR/mygit-init" >/dev/null 2>&1

# 2) before first commit -> blocked
expect_output \
  "2) checkout before first commit -> blocked" \
  "mygit-checkout: error: this command can not be run until after the first commit" \
  python3 "$SCRIPTDIR/mygit-checkout" trunk

# Create first commit on trunk (commit 0)
printf 'A0\n' > a.txt
python3 "$SCRIPTDIR/mygit-add" a.txt >/dev/null 2>&1
python3 "$SCRIPTDIR/mygit-commit" -m "c0" >/dev/null 2>&1

# 3) usage: missing arg -> usage
expect_output \
  "3) usage: missing arg" \
  "usage: mygit-checkout <branch-name>" \
  python3 "$SCRIPTDIR/mygit-checkout"

# 4) invalid branch name
expect_output \
  "4) invalid branch name" \
  "mygit-checkout: error: invalid branch '_bad'" \
  python3 "$SCRIPTDIR/mygit-checkout" _bad

# 5) unknown branch
expect_output \
  "5) unknown branch 'nope'" \
  "mygit-checkout: error: unknown branch 'nope'" \
  python3 "$SCRIPTDIR/mygit-checkout" nope

# Create branch 'feature' (points to commit 0)
python3 "$SCRIPTDIR/mygit-branch" feature >/dev/null 2>&1

# Advance trunk to commit 1: modify a.txt and add t.txt
printf 'A1\n' > a.txt
printf 'T1\n' > t.txt
python3 "$SCRIPTDIR/mygit-add" a.txt t.txt >/dev/null 2>&1
python3 "$SCRIPTDIR/mygit-commit" -m "c1" >/dev/null 2>&1

# --------------------------- run tests ---------------------------

# 6) checkout feature (from trunk) -> success; WD matches commit 0
expect_output \
  "6) switch to 'feature' succeeds" \
  "Switched to branch 'feature'" \
  python3 "$SCRIPTDIR/mygit-checkout" feature
check_file_equals "a.txt" "A0" "a.txt restored to feature snapshot (A0)"
check_not_exists "t.txt" "t.txt removed when switching to feature"

# 7) checkout trunk -> success; WD matches commit 1
expect_output \
  "7) switch back to 'trunk' succeeds" \
  "Switched to branch 'trunk'" \
  python3 "$SCRIPTDIR/mygit-checkout" trunk
check_file_equals "a.txt" "A1" "a.txt restored to trunk snapshot (A1)"
check_path_exists "t.txt" "t.txt restored when switching back to trunk"

# 8) conflict on common file changed in WD (a.txt)
printf 'A1-local\n' > a.txt
expect_output \
  "8) conflict on modified common file" \
  "mygit-checkout: error: Your changes to the following files would be overwritten by checkout:\na.txt" \
  python3 "$SCRIPTDIR/mygit-checkout" feature
# revert WD to trunk snapshot
printf 'A1\n' > a.txt

# 9) conflict on file present only in old (t.txt edited)
printf 'T1-local\n' > t.txt
expect_output \
  "9) conflict on file removed in target" \
  "mygit-checkout: error: Your changes to the following files would be overwritten by checkout:\nt.txt" \
  python3 "$SCRIPTDIR/mygit-checkout" feature
# revert
printf 'T1\n' > t.txt

# Prepare feature-only file: switch to feature, add fonly.txt, commit 2, back to trunk
python3 "$SCRIPTDIR/mygit-checkout" feature >/dev/null 2>&1
printf 'F1\n' > fonly.txt
python3 "$SCRIPTDIR/mygit-add" fonly.txt >/dev/null 2>&1
python3 "$SCRIPTDIR/mygit-commit" -m "c2" >/dev/null 2>&1
python3 "$SCRIPTDIR/mygit-checkout" trunk >/dev/null 2>&1

# 10) conflict on file present only in new (fonly.txt)
printf 'F-local\n' > fonly.txt
expect_output \
  "10) conflict on file added in target" \
  "mygit-checkout: error: Your changes to the following files would be overwritten by checkout:\nfonly.txt" \
  python3 "$SCRIPTDIR/mygit-checkout" feature
rm -f fonly.txt

# 11) clean switch to feature after resolving conflicts
expect_output \
  "11) clean switch to 'feature'" \
  "Switched to branch 'feature'" \
  python3 "$SCRIPTDIR/mygit-checkout" feature
check_file_equals "a.txt" "A0" "a.txt is A0 on feature"
check_not_exists "t.txt" "t.txt absent on feature"
check_file_equals "fonly.txt" "F1" "fonly.txt present on feature"

# 12) switch back to trunk cleanly
expect_output \
  "12) clean switch back to 'trunk'" \
  "Switched to branch 'trunk'" \
  python3 "$SCRIPTDIR/mygit-checkout" trunk
check_file_equals "a.txt" "A1" "a.txt is A1 on trunk"
check_path_exists "t.txt" "t.txt present on trunk"
check_not_exists "fonly.txt" "fonly.txt absent on trunk"

# ---------------------------- summary ----------------------------

if [ "$fail" -ne 0 ]; then
  echo "One or more tests FAILED in Test 7."
  exit 1
fi

echo "All tests PASSED in Test 7."
exit 0
