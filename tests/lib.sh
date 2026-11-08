REPO=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)

fail() {
  echo "FAIL: $*" >&2
  exit 1
}

assert_eq() {
  [[ "$1" == "$2" ]] || fail "${3:-assert_eq}: expected [$1] got [$2]"
}

assert_file() {
  [[ -f "$1" && ! -L "$1" ]] || fail "not a regular file: $1"
}

assert_absent() {
  [[ ! -e "$1" && ! -L "$1" ]] || fail "should not exist: $1"
}

assert_link() {
  [[ -L "$1" ]] || fail "not a symlink: $1"
  assert_eq "$2" "$(readlink "$1")" "link target of $1"
}

assert_contains() {
  grep -qF -- "$2" "$1" || fail "$1 does not contain [$2]"
}

assert_fails() {
  if "$@" >/dev/null 2>&1; then
    fail "expected failure: $*"
  fi
}

mkfixture() {
  local d=$1
  mkdir -p "$d/home" "$d/root" "$d/out" "$d/torus"
}

wait_for() {
  local file=$1 pattern=$2 i
  for i in $(seq 50); do
    grep -q -- "$pattern" "$file" 2> /dev/null && return 0
    sleep 0.05
  done
  return 1
}
