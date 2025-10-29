#!/usr/bin/env dash
# ==============================================================
# test2.sh
# Test 2: mygit-log (outputs + filesystem checks)

# ==============================================================

set -u

# ---------------------------- helpers ----------------------------

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

# --------------------------- run tests ---------------------------

cd "$TMPDIR" || exit 1

# mygit-log without a repository
expect_output \
  "log without repo should error" \
  "mygit-log: error: mygit repository directory .mygit not found" \
  python3 "$SCRIPTDIR/mygit-log"

# init repository
expect_output \
  "init should create repo" \
  "Initialized empty mygit repository in .mygit" \
  python3 "$SCRIPTDIR/mygit-init"

check_path_exists ".mygit" "repo directory created"
check_path_exists ".mygit/branches/trunk" "default branch 'trunk' exists"
check_file_equals ".mygit/HEAD" "trunk" "HEAD points to 'trunk'"

# create three commits: 0, 1, 2
printf 'A\n' > file.txt
expect_output "add file.txt (silent)" "" python3 "$SCRIPTDIR/mygit-add" file.txt
expect_output "commit 0 created" "Committed as commit 0" python3 "$SCRIPTDIR/mygit-commit" -m "c0"

printf 'A B\n' > file.txt
expect_output "commit 1 via -a" "Committed as commit 1" python3 "$SCRIPTDIR/mygit-commit" -a -m "c1"

printf 'A B C\n' > file.txt
expect_output "commit 2 via -a" "Committed as commit 2" python3 "$SCRIPTDIR/mygit-commit" -a -m "c2"

check_path_exists ".mygit/repository/0" "commit 0 dir exists"
check_path_exists ".mygit/repository/1" "commit 1 dir exists"
check_path_exists ".mygit/repository/2" "commit 2 dir exists"

# usage: extra arg
expect_output \
  "log with extra arg -> usage" \
  "usage: mygit-log" \
  python3 "$SCRIPTDIR/mygit-log" extra

# linear history order from HEAD (2 -> 1 -> 0)
expect_output \
  "log prints tip-to-root order" \
  "2 c2
1 c1
0 c0" \
  python3 "$SCRIPTDIR/mygit-log"

# ---------------------------- summary ----------------------------

if [ "$fail" -ne 0 ]; then
  echo "One or more tests FAILED in Test 2."
  exit 1
fi

echo "All tests PASSED in Test 2."
exit 0
