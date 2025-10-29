#!/usr/bin/env dash
# ==============================================================
# test4.sh
# Test 4: mygit-rm — tests removing files from the index and/or
# working tree, safety checks for staged/unstaged differences,
# and globbing behaviour.

# ==============================================================

set -u

# ---------------------------- helpers ----------------------------

script_dir() {
  cd -P -- "$(dirname -- "$0")" >/dev/null 2>&1 && pwd -P
}
SCRIPTDIR=$(script_dir)

TMPDIR=$(mktemp -d 2>/dev/null || mktemp -d -t mygit-test-4)
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

# ----------------------------- setup -----------------------------

cd "$TMPDIR" || exit 1

# 1) rm without repo -> error
expect_output \
  "1) rm without repo should error" \
  "mygit-rm: error: mygit repository directory .mygit not found" \
  python3 "$SCRIPTDIR/mygit-rm" file.txt

# 2) init repository
expect_output \
  "2) init should create repo" \
  "Initialized empty mygit repository in .mygit" \
  python3 "$SCRIPTDIR/mygit-init"

check_path_exists ".mygit" "repo directory created"

# --------------------------- run tests ---------------------------

# 3) usage: no args
expect_output \
  "3) rm with no args -> usage" \
  "usage: mygit-rm [--force] [--cached] <filenames>" \
  python3 "$SCRIPTDIR/mygit-rm"

# 4) usage: unknown flag
expect_output \
  "4) rm with unknown flag -> usage" \
  "usage: mygit-rm [--force] [--cached] <filenames>" \
  python3 "$SCRIPTDIR/mygit-rm" -x a.txt

# 5) invalid filename
expect_output \
  "5) invalid filename 'bad*'" \
  "mygit-rm: error: invalid filename 'bad*'" \
  python3 "$SCRIPTDIR/mygit-rm" 'bad*'

# 6) not in index
printf 'X\n' > nottracked.txt
expect_output \
  "6) file not in index" \
  "mygit-rm: error: 'nottracked.txt' is not in the mygit repository" \
  python3 "$SCRIPTDIR/mygit-rm" nottracked.txt

# 7) prepare both.txt: add and commit so full removal is allowed
printf 'X\n' > both.txt
python3 "$SCRIPTDIR/mygit-add" both.txt >/dev/null 2>&1
expect_output \
  "7) commit 0 with both.txt" \
  "Committed as commit 0" \
  python3 "$SCRIPTDIR/mygit-commit" -m "add both.txt"

# 8) basic removal (index + working)
expect_output \
  "8) rm both.txt success (silent)" \
  "" \
  python3 "$SCRIPTDIR/mygit-rm" both.txt
check_not_exists ".mygit/index/both.txt" "both.txt removed from index"
check_not_exists "both.txt" "both.txt removed from working tree"

# 9) cached removal (index only)
printf 'Y\n' > keepwd.txt
python3 "$SCRIPTDIR/mygit-add" keepwd.txt >/dev/null 2>&1
expect_output \
  "9) rm --cached keepwd.txt (silent)" \
  "" \
  python3 "$SCRIPTDIR/mygit-rm" --cached keepwd.txt
check_not_exists ".mygit/index/keepwd.txt" "keepwd.txt removed from index"
check_path_exists "keepwd.txt" "keepwd.txt remains in working tree"

# 10) staged-only conflict (no commit yet)
printf 'S1\n' > staged.txt
python3 "$SCRIPTDIR/mygit-add" staged.txt >/dev/null 2>&1
expect_output \
  "10) rm staged.txt -> staged changes conflict" \
  "mygit-rm: error: 'staged.txt' has staged changes in the index" \
  python3 "$SCRIPTDIR/mygit-rm" staged.txt

# 11) --force overrides staged-only conflict (removes index+wd)
expect_output \
  "11) rm --force staged.txt succeeds silently" \
  "" \
  python3 "$SCRIPTDIR/mygit-rm" --force staged.txt
check_not_exists ".mygit/index/staged.txt" "staged.txt removed from index (force)"
check_not_exists "staged.txt" "staged.txt removed from working tree (force)"

# 12) prepare commit containing unstaged.txt
printf 'U1\n' > unstaged.txt
python3 "$SCRIPTDIR/mygit-add" unstaged.txt >/dev/null 2>&1
expect_output \
  "12) commit 1 with unstaged.txt" \
  "Committed as commit 1" \
  python3 "$SCRIPTDIR/mygit-commit" -m "add unstaged.txt"

# 13) unstaged modification conflict (repo vs working)
printf 'U2\n' > unstaged.txt
expect_output \
  "13) rm unstaged.txt -> repo vs working conflict" \
  "mygit-rm: error: 'unstaged.txt' in the repository is different to the working file" \
  python3 "$SCRIPTDIR/mygit-rm" unstaged.txt

# 14) prepare diverged states: commit A, index B, working C
printf 'A\n' > diverge.txt
python3 "$SCRIPTDIR/mygit-add" diverge.txt >/dev/null 2>&1
expect_output \
  "14) commit 2 with diverge.txt (A)" \
  "Committed as commit 2" \
  python3 "$SCRIPTDIR/mygit-commit" -m "add diverge.txt A"
printf 'B\n' > diverge.txt
python3 "$SCRIPTDIR/mygit-add" diverge.txt >/dev/null 2>&1 
printf 'C\n' > diverge.txt

# 15) index differs from both working and repo -> error
expect_output \
  "15) rm diverge.txt -> index differs from both working and repo" \
  "mygit-rm: error: 'diverge.txt' in index is different to both the working file and the repository" \
  python3 "$SCRIPTDIR/mygit-rm" diverge.txt

# 16) even with --cached still error (same condition applies)
expect_output \
  "16) rm --cached diverge.txt -> same conflict" \
  "mygit-rm: error: 'diverge.txt' in index is different to both the working file and the repository" \
  python3 "$SCRIPTDIR/mygit-rm" --cached diverge.txt

# 17) --force --cached removes from index only, keeps working
expect_output \
  "17) rm --force --cached diverge.txt succeeds silently" \
  "" \
  python3 "$SCRIPTDIR/mygit-rm" --force --cached diverge.txt
check_not_exists ".mygit/index/diverge.txt" "diverge.txt removed from index (force --cached)"
check_path_exists "diverge.txt" "diverge.txt remains in working tree (force --cached)"
rm -f diverge.txt

# 18) prepare globbing case: add and commit g1.txt and g2.txt
printf 'g1\n' > g1.txt
printf 'g2\n' > g2.txt
python3 "$SCRIPTDIR/mygit-add" g1.txt g2.txt >/dev/null 2>&1
expect_output \
  "18) commit 3 with g files" \
  "Committed as commit 3" \
  python3 "$SCRIPTDIR/mygit-commit" -m "add g files"

# 19) globbing: pattern removes both files
expect_output \
  "19) rm 'g*.txt' removes both g1.txt and g2.txt (silent)" \
  "" \
  python3 "$SCRIPTDIR/mygit-rm" 'g*.txt'
check_not_exists ".mygit/index/g1.txt" "g1.txt removed from index"
check_not_exists ".mygit/index/g2.txt" "g2.txt removed from index"
check_not_exists "g1.txt" "g1.txt removed from working tree"
check_not_exists "g2.txt" "g2.txt removed from working tree"

# 20) globbing: quoted pattern with no matches -> invalid filename
expect_output \
  "20) rm 'nope*.txt' -> invalid filename" \
  "mygit-rm: error: invalid filename 'nope*.txt'" \
  python3 "$SCRIPTDIR/mygit-rm" 'nope*.txt'

# ---------------------------- summary ----------------------------

if [ "$fail" -ne 0 ]; then
  echo "One or more tests FAILED in Test 4."
  exit 1
fi

echo "All tests PASSED in Test 4."
exit 0
