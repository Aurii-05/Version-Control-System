#!/usr/bin/env dash
# ==============================================================
# test9.sh
# Test 9: End-to-end user flow using all the scripts

# ==============================================================

set -u

# ---------------------------- helpers ----------------------------

script_dir() {
  cd -P -- "$(dirname -- "$0")" >/dev/null 2>&1 && pwd -P
}
SCRIPTDIR=$(script_dir)

TMPDIR=$(mktemp -d 2>/dev/null || mktemp -d -t mygit-test-9)
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

# 1) init new repo
expect_output \
  "1) init should create repo" \
  "Initialized empty mygit repository in .mygit" \
  python3 "$SCRIPTDIR/mygit-init"

# Create a working file (untracked)
printf 'hello' > a.txt

# 2) status shows untracked
expect_output \
  "2) status: a.txt untracked" \
  "a.txt - untracked" \
  python3 "$SCRIPTDIR/mygit-status"

# 3) add (silent)
expect_output \
  "3) add a.txt (silent)" \
  "" \
  python3 "$SCRIPTDIR/mygit-add" a.txt

# 4) status shows added to index
expect_output \
  "4) status: added to index" \
  "a.txt - added to index" \
  python3 "$SCRIPTDIR/mygit-status"

# 5) first commit on trunk -> commit 0
expect_output \
  "5) commit 0 (trunk)" \
  "Committed as commit 0" \
  python3 "$SCRIPTDIR/mygit-commit" -m "init"

# 6) log shows single commit
expect_output \
  "6) log after first commit" \
  "0 init" \
  python3 "$SCRIPTDIR/mygit-log"

# 7) create a branch 'feature' (silent) and list branches
expect_output \
  "7) create branch 'feature' (silent)" \
  "" \
  python3 "$SCRIPTDIR/mygit-branch" feature
expect_output \
  "8) list branches (sorted)" \
  "feature\ntrunk" \
  python3 "$SCRIPTDIR/mygit-branch"

# 9) checkout feature
expect_output \
  "9) checkout feature" \
  "Switched to branch 'feature'" \
  python3 "$SCRIPTDIR/mygit-checkout" feature

# Modify a.txt on feature and commit (commit 1)
printf 'hello feature' > a.txt
expect_output \
  "10) add a.txt on feature (silent)" \
  "" \
  python3 "$SCRIPTDIR/mygit-add" a.txt
expect_output \
  "11) commit 1 on feature" \
  "Committed as commit 1" \
  python3 "$SCRIPTDIR/mygit-commit" -m "feature change"

# 12) feature log shows 1 -> 0
expect_output \
  "12) log on feature" \
  "1 feature change\n0 init" \
  python3 "$SCRIPTDIR/mygit-log"

# 13) switch back to trunk
expect_output \
  "13) checkout trunk" \
  "Switched to branch 'trunk'" \
  python3 "$SCRIPTDIR/mygit-checkout" trunk
check_file_equals "a.txt" "hello" "a.txt content on trunk before merge"

# 14) merge feature into trunk (fast-forward expected)
expect_output \
  "14) merge feature into trunk (FF)" \
  "Fast-forward: no commit created" \
  python3 "$SCRIPTDIR/mygit-merge" feature -m "merge feature"
check_file_equals "a.txt" "hello feature" "a.txt after FF merge"

# 15) trunk log now shows feature history
expect_output \
  "15) log on trunk after merge" \
  "1 feature change\n0 init" \
  python3 "$SCRIPTDIR/mygit-log"

# 16) show confirms file content from commit and index
expect_output \
  "16) show 1:a.txt" \
  "hello feature" \
  python3 "$SCRIPTDIR/mygit-show" 1:a.txt
expect_output \
  "17) show :a.txt (index)" \
  "hello feature" \
  python3 "$SCRIPTDIR/mygit-show" :a.txt

# ---------------------------- summary ----------------------------

if [ "$fail" -ne 0 ]; then
  echo "One or more tests FAILED in Test 9."
  exit 1
fi

echo "All tests PASSED in Test 9."
exit 0
