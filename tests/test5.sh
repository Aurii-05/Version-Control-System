#!/usr/bin/env dash
# ==============================================================
# test5.sh
# Test 5: mygit-status — shows the status of files in the working
# directory, the index, and the repository.

# ==============================================================

set -u

# ---------------------------- helpers ----------------------------

script_dir() {
  cd -P -- "$(dirname -- "$0")" >/dev/null 2>&1 && pwd -P
}
SCRIPTDIR=$(script_dir)

TMPDIR=$(mktemp -d 2>/dev/null || mktemp -d -t mygit-test-5)
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

mkrepo() {
  dir=$1
  rm -rf "$TMPDIR/$dir"
  mkdir -p "$TMPDIR/$dir"
}

# ----------------------------- setup -----------------------------

cd "$TMPDIR" || exit 1

# 1) status without repo -> error
expect_output \
  "1) status without repo should error" \
  "mygit-status: error: mygit repository directory .mygit not found" \
  python3 "$SCRIPTDIR/mygit-status"

# 2) usage with extra arg -> usage
expect_output \
  "2) usage with extra arg -> usage" \
  "usage: mygit-status" \
  python3 "$SCRIPTDIR/mygit-status" extra

# --------------------------- run tests ---------------------------

# 3) clean repo, no files -> no output
mkrepo t3; (
  cd t3 || exit 1
  python3 "$SCRIPTDIR/mygit-init" >/dev/null 2>&1
  expect_output "3) empty repo prints nothing" "" python3 "$SCRIPTDIR/mygit-status"
)

# 4) untracked file
mkrepo t4; (
  cd t4 || exit 1
  python3 "$SCRIPTDIR/mygit-init" >/dev/null 2>&1
  printf 'U\n' > u.txt
  expect_output "4) untracked" "u.txt - untracked" python3 "$SCRIPTDIR/mygit-status"
)

# 5) added to index
mkrepo t5; (
  cd t5 || exit 1
  python3 "$SCRIPTDIR/mygit-init" >/dev/null 2>&1
  printf 'A\n' > a.txt
  python3 "$SCRIPTDIR/mygit-add" a.txt >/dev/null 2>&1
  expect_output "5) added to index" "a.txt - added to index" python3 "$SCRIPTDIR/mygit-status"
)

# 6) added to index, file changed
mkrepo t6; (
  cd t6 || exit 1
  python3 "$SCRIPTDIR/mygit-init" >/dev/null 2>&1
  printf 'v1\n' > ac.txt
  python3 "$SCRIPTDIR/mygit-add" ac.txt >/dev/null 2>&1
  printf 'v2\n' > ac.txt
  expect_output "6) added to index, file changed" "ac.txt - added to index, file changed" python3 "$SCRIPTDIR/mygit-status"
)

# 7) same as repo
mkrepo t7; (
  cd t7 || exit 1
  python3 "$SCRIPTDIR/mygit-init" >/dev/null 2>&1
  printf 'S\n' > s.txt
  python3 "$SCRIPTDIR/mygit-add" s.txt >/dev/null 2>&1
  python3 "$SCRIPTDIR/mygit-commit" -m "c0" >/dev/null 2>&1
  expect_output "7) same as repo" "s.txt - same as repo" python3 "$SCRIPTDIR/mygit-status"
)

# 8) changes not staged (wd != index == repo)
mkrepo t8; (
  cd t8 || exit 1
  python3 "$SCRIPTDIR/mygit-init" >/dev/null 2>&1
  printf 'N1\n' > ns.txt
  python3 "$SCRIPTDIR/mygit-add" ns.txt >/dev/null 2>&1
  python3 "$SCRIPTDIR/mygit-commit" -m "c0" >/dev/null 2>&1
  printf 'N2\n' > ns.txt
  expect_output "8) changes not staged" "ns.txt - file changed, changes not staged for commit" python3 "$SCRIPTDIR/mygit-status"
)

# 9) changes staged (wd == index != repo)
mkrepo t9; (
  cd t9 || exit 1
  python3 "$SCRIPTDIR/mygit-init" >/dev/null 2>&1
  printf 'T1\n' > st.txt
  python3 "$SCRIPTDIR/mygit-add" st.txt >/dev/null 2>&1
  python3 "$SCRIPTDIR/mygit-commit" -m "c0" >/dev/null 2>&1
  printf 'T2\n' > st.txt
  python3 "$SCRIPTDIR/mygit-add" st.txt >/dev/null 2>&1
  expect_output "9) changes staged" "st.txt - file changed, changes staged for commit" python3 "$SCRIPTDIR/mygit-status"
)

# 10) different changes staged (wd != index != repo)
mkrepo t10; (
  cd t10 || exit 1
  python3 "$SCRIPTDIR/mygit-init" >/dev/null 2>&1
  printf 'A\n' > df.txt
  python3 "$SCRIPTDIR/mygit-add" df.txt >/dev/null 2>&1
  python3 "$SCRIPTDIR/mygit-commit" -m "c0" >/dev/null 2>&1
  printf 'B\n' > df.txt
  python3 "$SCRIPTDIR/mygit-add" df.txt >/dev/null 2>&1
  printf 'C\n' > df.txt
  expect_output "10) different changes staged" "df.txt - file changed, different changes staged for commit" python3 "$SCRIPTDIR/mygit-status"
)

# 11) file deleted (wd missing, index==repo)
mkrepo t11; (
  cd t11 || exit 1
  python3 "$SCRIPTDIR/mygit-init" >/dev/null 2>&1
  printf 'D\n' > del.txt
  python3 "$SCRIPTDIR/mygit-add" del.txt >/dev/null 2>&1
  python3 "$SCRIPTDIR/mygit-commit" -m "c0" >/dev/null 2>&1
  rm -f del.txt
  expect_output "11) file deleted (working only)" "del.txt - file deleted" python3 "$SCRIPTDIR/mygit-status"
)

# 12) file deleted, changes staged for commit (wd missing, index!=repo)
mkrepo t12; (
  cd t12 || exit 1
  python3 "$SCRIPTDIR/mygit-init" >/dev/null 2>&1
  printf 'E1\n' > dsc.txt
  python3 "$SCRIPTDIR/mygit-add" dsc.txt >/dev/null 2>&1
  python3 "$SCRIPTDIR/mygit-commit" -m "c0" >/dev/null 2>&1
  printf 'E2\n' > dsc.txt
  python3 "$SCRIPTDIR/mygit-add" dsc.txt >/dev/null 2>&1
  rm -f dsc.txt
  expect_output "12) file deleted, changes staged for commit" "dsc.txt - file deleted, changes staged for commit" python3 "$SCRIPTDIR/mygit-status"
)

# 13) deleted from index (repo present, wd present)
mkrepo t13; (
  cd t13 || exit 1
  python3 "$SCRIPTDIR/mygit-init" >/dev/null 2>&1
  printf 'I\n' > delidx.txt
  python3 "$SCRIPTDIR/mygit-add" delidx.txt >/dev/null 2>&1
  python3 "$SCRIPTDIR/mygit-commit" -m "c0" >/dev/null 2>&1
  python3 "$SCRIPTDIR/mygit-rm" --cached delidx.txt >/dev/null 2>&1
  expect_output "13) deleted from index" "delidx.txt - deleted from index" python3 "$SCRIPTDIR/mygit-status"
)

# 14) file deleted, deleted from index (repo present, wd missing)
mkrepo t14; (
  cd t14 || exit 1
  python3 "$SCRIPTDIR/mygit-init" >/dev/null 2>&1
  printf 'BOTH\n' > bothdel.txt
  python3 "$SCRIPTDIR/mygit-add" bothdel.txt >/dev/null 2>&1
  python3 "$SCRIPTDIR/mygit-commit" -m "c0" >/dev/null 2>&1
  python3 "$SCRIPTDIR/mygit-rm" bothdel.txt >/dev/null 2>&1
  expect_output "14) file deleted, deleted from index" "bothdel.txt - file deleted, deleted from index" python3 "$SCRIPTDIR/mygit-status"
)

# 15) added to index, file deleted (no repo)
mkrepo t15; (
  cd t15 || exit 1
  python3 "$SCRIPTDIR/mygit-init" >/dev/null 2>&1
  printf 'AD\n' > adddel.txt
  python3 "$SCRIPTDIR/mygit-add" adddel.txt >/dev/null 2>&1
  rm -f adddel.txt
  expect_output "15) added to index, file deleted" "adddel.txt - added to index, file deleted" python3 "$SCRIPTDIR/mygit-status"
)

# ---------------------------- summary ----------------------------

if [ "$fail" -ne 0 ]; then
  echo "One or more tests FAILED in Test 5."
  exit 1
fi

echo "All tests PASSED in Test 5."
exit 0
