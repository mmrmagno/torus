REPO=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
export GIT_CONFIG_COUNT=2 GIT_CONFIG_KEY_0=commit.gpgsign GIT_CONFIG_VALUE_0=false GIT_CONFIG_KEY_1=tag.gpgsign GIT_CONFIG_VALUE_1=false

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

mkedid() {
  local out=$1 name=$2 i
  mkdir -p "$(dirname "$out")"
  {
    printf '\x00\xff\xff\xff\xff\xff\xff\x00'
    for i in $(seq 9 72); do printf '\x00'; done
    printf '\x00\x00\x00\xfc\x00'
    printf '%-13s' "$name" | sed 's/ /\n/' | head -c 13
    for i in $(seq 91 128); do printf '\x00'; done
  } > "$out"
}

patched() {
  local src=$1 dir=$2 out
  out=$dir/$(basename "$src")
  shift 2
  cp "$src" "$out"
  python3 -I - "$out" "$@" <<'PY' || fail "patched: $(basename "$src") no longer holds the address the test replaces"
import sys
p, pairs = sys.argv[1], sys.argv[2:]
s = open(p).read()
for old, new in zip(pairs[::2], pairs[1::2]):
    if old not in s:
        sys.exit(1)
    s = s.replace(old, new)
open(p, "w").write(s)
PY
  chmod +x "$out"
  echo "$out"
}
