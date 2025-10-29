#!/usr/bin/env dash
# ==============================================================
# test6.sh
# Test 6: mygit-branch — creates, deletes, and lists branches.

# ==============================================================

set -u

# ---------------------------- helpers ----------------------------

script_dir() {
  cd -P -- "$(dirname -- "$0")" >/dev/null 2>&1 && pwd -P
}
SCRIPTDIR=$(script_dir)

TMPDIR=$(mktemp -d 2>/dev/null || mktemp -d -t mygit-test-6)
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

# ----------------------------- setup -----------------------------

cd "$TMPDIR" || exit 1

# 1) mygit-branch without repo -> error
expect_output \
  "1) branch without repo should error" \
  "mygit-branch: error: mygit repository directory .mygit not found" \
  python3 "$SCRIPTDIR/mygit-branch"

# 2) init repository
expect_output \
  "2) init should create repo" \
  "Initialized empty mygit repository in .mygit" \
  python3 "$SCRIPTDIR/mygit-init"
check_path_exists ".mygit" "repo directory created"

# --------------------------- run tests ---------------------------

# 3) before first commit -> command blocked
expect_output \
  "3) branch before first commit -> blocked" \
  "mygit-branch: error: this command can not be run until after the first commit" \
  python3 "$SCRIPTDIR/mygit-branch"

# Create first commit (commit 0)
printf 'base\n' > base.txt
expect_output \
  "4) add base.txt (silent)" \
  "" \
  python3 "$SCRIPTDIR/mygit-add" base.txt
expect_output \
  "5) commit 0 created" \
  "Committed as commit 0" \
  python3 "$SCRIPTDIR/mygit-commit" -m "c0"

# 6) list branches -> only trunk
expect_output \
  "6) list branches after first commit" \
  "trunk" \
  python3 "$SCRIPTDIR/mygit-branch"

# 7) create new branch 'feature' (silent on success)
expect_output \
  "7) create branch 'feature'" \
  "" \
  python3 "$SCRIPTDIR/mygit-branch" feature

# 8) list -> sorted names
expect_output \
  "8) list shows feature then trunk (sorted)" \
  "feature
trunk" \
  python3 "$SCRIPTDIR/mygit-branch"

# 9) creating existing branch -> error
expect_output \
  "9) create existing 'feature' -> error" \
  "mygit-branch: error: branch 'feature' already exists" \
  python3 "$SCRIPTDIR/mygit-branch" feature

# 10) invalid branch name
expect_output \
  "10) invalid branch name" \
  "mygit-branch: error: invalid branch name '_bad'" \
  python3 "$SCRIPTDIR/mygit-branch" _bad

# 11) delete non-existent branch
expect_output \
  "11) delete non-existent branch" \
  "mygit-branch: error: branch 'nope' doesn't exist" \
  python3 "$SCRIPTDIR/mygit-branch" -d nope

# 12) cannot delete default branch 'trunk'
expect_output \
  "12) delete 'trunk' -> default branch error" \
  "mygit-branch: error: can not delete branch 'trunk': default branch" \
  python3 "$SCRIPTDIR/mygit-branch" -d trunk

# 13) delete 'feature' succeeds
expect_output \
  "13) delete 'feature' succeeds" \
  "Deleted branch 'feature'" \
  python3 "$SCRIPTDIR/mygit-branch" -d feature

# 14) list -> back to trunk only
expect_output \
  "14) list after deletion -> trunk only" \
  "trunk" \
  python3 "$SCRIPTDIR/mygit-branch"

# 15) create 'ahead' and simulate it being ahead of current branch
expect_output \
  "15) create branch 'ahead'" \
  "" \
  python3 "$SCRIPTDIR/mygit-branch" ahead
# Simulate ahead by setting its HEAD to a larger number than trunk's
printf '5' > .mygit/branches/ahead/HEAD

# 16) deleting 'ahead' blocked due to unmerged changes
expect_output \
  "16) delete 'ahead' -> has unmerged changes" \
  "mygit-branch: error: branch 'ahead' has unmerged changes" \
  python3 "$SCRIPTDIR/mygit-branch" -d ahead

# 17) usage: '-d' missing argument
expect_output \
  "17) usage: -d without arg" \
  "usage: mygit-branch [-d] [branch-name]" \
  python3 "$SCRIPTDIR/mygit-branch" -d

# 18) usage: too many args
expect_output \
  "18) usage: too many args" \
  "usage: mygit-branch [-d] [branch-name]" \
  python3 "$SCRIPTDIR/mygit-branch" a b

# 19) create and delete another branch to confirm deletion path
expect_output \
  "19) create 'x'" \
  "" \
  python3 "$SCRIPTDIR/mygit-branch" x
expect_output \
  "20) delete 'x'" \
  "Deleted branch 'x'" \
  python3 "$SCRIPTDIR/mygit-branch" -d x

# 21) final list -> trunk only
expect_output \
  "21) final list -> trunk" \
  "trunk" \
  python3 "$SCRIPTDIR/mygit-branch"

# ---------------------------- summary ----------------------------

if [ "$fail" -ne 0 ]; then
  echo "One or more tests FAILED in Test 6."
  exit 1
fi

echo "All tests PASSED in Test 6."
exit 0
