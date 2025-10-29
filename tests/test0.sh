#!/usr/bin/env dash
# ==============================================================
# test0.sh
# Test 0: mygit-init + mygit-add (outputs + filesystem checks)

# ==============================================================

set -u

# --------------------------- helpers ---------------------------
script_dir() {
  cd -P -- "$(dirname -- "$0")" >/dev/null 2>&1 && pwd -P
}
SCRIPTDIR=$(script_dir)

TMPDIR=$(mktemp -d 2>/dev/null || mktemp -d -t mygit-test-1)
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

# ----------------------run tests ------------------------------
cd "$TMPDIR" || exit 1

# 1) add without repo -> repo-missing error
expect_output \
  "add without repo should error" \
  "mygit-add: error: mygit repository directory .mygit not found" \
  python3 "$SCRIPTDIR/mygit-add"

# 2) init -> success message and structure
expect_output \
  "init should create repo" \
  "Initialized empty mygit repository in .mygit" \
  python3 "$SCRIPTDIR/mygit-init"

check_path_exists ".mygit"                         "repo directory created"
check_path_exists ".mygit/branches"                "branches directory created"
check_path_exists ".mygit/branches/trunk"          "default branch 'trunk' created"
check_path_exists ".mygit/branches/trunk/index"    "branch index directory created"
check_path_exists ".mygit/branches/trunk/repository" "branch repository directory created"
check_file_equals ".mygit/HEAD" "trunk"           "HEAD points to 'trunk'"

# 3) init again -> already-exists error
expect_output \
  "init again should error" \
  "mygit-init: error: .mygit already exists" \
  python3 "$SCRIPTDIR/mygit-init"

# 4) add with no args -> usage
expect_output \
  "add with no args prints usage" \
  "usage: mygit-add <filenames>" \
  python3 "$SCRIPTDIR/mygit-add"

# 5) invalid filename
expect_output \
  "add invalid filename '_bad'" \
  "mygit-add: error: invalid filename '_bad'" \
  python3 "$SCRIPTDIR/mygit-add" _bad

# 6) successful add (silent) -> ensures global index exists and a.txt staged
printf 'hello\n' > a.txt
expect_output \
  "add a.txt success (silent)" \
  "" \
  python3 "$SCRIPTDIR/mygit-add" a.txt
check_path_exists ".mygit/index"        "global index directory created by add"
check_path_exists ".mygit/index/a.txt"  "a.txt staged into index"
# (content comparison is optional here; command output is authoritative)

# 7) add directory -> not a regular file
mkdir dir1
expect_output \
  "add directory should error" \
  "mygit-add: error: 'dir1' is not a regular file" \
  python3 "$SCRIPTDIR/mygit-add" dir1

# 8) add missing file -> error
expect_output \
  "add missing file should error" \
  "mygit-add: error: can not open 'missing.txt'" \
  python3 "$SCRIPTDIR/mygit-add" missing.txt

# 9) re-adding previously staged file after deletion -> silent (removes from index)
printf 'bye\n' > b.txt
python3 "$SCRIPTDIR/mygit-add" b.txt >/dev/null 2>&1  # stage once
check_path_exists ".mygit/index/b.txt" "b.txt initially staged"
rm -f b.txt
expect_output \
  "re-add missing b.txt is silent (removes from index)" \
  "" \
  python3 "$SCRIPTDIR/mygit-add" b.txt
check_not_exists ".mygit/index/b.txt" "b.txt removed from index after missing-source add"

# ----------------------summary--------------------------------
if [ "$fail" -ne 0 ]; then
  echo "One or more tests FAILED in Test 1."
  exit 1
fi

echo "All tests PASSED in Test 1."
exit 0
