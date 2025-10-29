#!/usr/bin/env dash
# ==============================================================
# test3.sh
# Test 3: mygit-show (outputs + filesystem checks)

# ==============================================================

set -u

# -----------------------------helpers -----------------------------

script_dir() {
  cd -P -- "$(dirname -- "$0")" >/dev/null 2>&1 && pwd -P
}
SCRIPTDIR=$(script_dir)

TMPDIR=$(mktemp -d 2>/dev/null || mktemp -d -t mygit-test-3)
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

# ------------------------------setup------------------------------

cd "$TMPDIR" || exit 1

# 1) show without repo -> error
expect_output \
  "1) show without repo should error" \
  "mygit-show: error: mygit repository directory .mygit not found" \
  python3 "$SCRIPTDIR/mygit-show" 0:a.txt

# 2) init repository
expect_output \
  "2) init should create repo" \
  "Initialized empty mygit repository in .mygit" \
  python3 "$SCRIPTDIR/mygit-init"

# 3) repo structure exists
check_path_exists ".mygit" "3) repo directory created"
check_path_exists ".mygit/branches/trunk" "4) default branch 'trunk' exists"
check_file_equals ".mygit/HEAD" "trunk" "5) HEAD points to 'trunk'"

# Prepare commits
printf 'IDX' > idx.txt                # no trailing newline for precise output
expect_output "6) add idx.txt (silent)" "" python3 "$SCRIPTDIR/mygit-add" idx.txt
expect_output "7) commit 0 created" "Committed as commit 0" python3 "$SCRIPTDIR/mygit-commit" -m "c0"

printf 'NEW' > idx.txt
expect_output "8) commit 1 via -a" "Committed as commit 1" python3 "$SCRIPTDIR/mygit-commit" -a -m "c1"

# ----------------------------run tests----------------------------

# 9) usage: missing colon
expect_output \
  "9) show with missing colon -> usage" \
  "usage: mygit-show <commit>:<filename>" \
  python3 "$SCRIPTDIR/mygit-show" 0

# 10) invalid filename
expect_output \
  "10) invalid filename '_bad'" \
  "mygit-show: error: invalid filename '_bad'" \
  python3 "$SCRIPTDIR/mygit-show" 0:_bad

# 11) unknown commit (nonexistent id)
expect_output \
  "11) unknown commit 99" \
  "mygit-show: error: unknown commit '99'" \
  python3 "$SCRIPTDIR/mygit-show" 99:idx.txt

# 12) from commit 0
expect_output \
  "12) show commit 0:idx.txt -> 'IDX'" \
  "IDX" \
  python3 "$SCRIPTDIR/mygit-show" 0:idx.txt

# 13) from commit 1
expect_output \
  "13) show commit 1:idx.txt -> 'NEW'" \
  "NEW" \
  python3 "$SCRIPTDIR/mygit-show" 1:idx.txt

# 14) from index (empty commit string)
expect_output \
  "14) show :idx.txt reads from index (currently 'NEW')" \
  "NEW" \
  python3 "$SCRIPTDIR/mygit-show" :idx.txt

# 15) missing file in a commit
expect_output \
  "15) file not in commit 1" \
  "mygit-show: error: 'missing.txt' not found in commit 1" \
  python3 "$SCRIPTDIR/mygit-show" 1:missing.txt

# 16) missing file in index
expect_output \
  "16) file not in index" \
  "mygit-show: error: 'absent.txt' not found in index" \
  python3 "$SCRIPTDIR/mygit-show" :absent.txt

# -----------------------------summary -----------------------------

if [ "$fail" -ne 0 ]; then
  echo "One or more tests FAILED in Test 3."
  exit 1
fi

echo "All tests PASSED in Test 3."
exit 0
