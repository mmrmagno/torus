#!/usr/bin/env bash
set -euo pipefail
. "$(dirname "$0")/lib.sh"

F=$(mktemp -d)
trap 'rm -rf "$F"' EXIT
export STUB_LOG=$F/calls
mkdir -p "$F/bin"
printf '#!/usr/bin/env bash\necho "systemctl $*" >> "$STUB_LOG"\n' > "$F/bin/systemctl"
chmod +x "$F/bin/systemctl"
export PATH=$F/bin:$PATH
ssh-keygen -q -t ed25519 -N "" -f "$F/key"
printf 't@t %s\n' "$(cat "$F/key.pub")" > "$F/signers"
g() { git -C "$1" -c user.email=t@t -c user.name=t -c gpg.format=ssh -c user.signingkey="$F/key.pub" "${@:2}"; }
seed() {
  mkdir -p "$1/home/.local/bin" "$1/home/.config/quickshell/torus"
  cp "$REPO/home/.local/bin/torus-update" "$REPO/home/.local/bin/torus-updates" "$1/home/.local/bin/"
  printf '#!/usr/bin/env bash\necho "install $*" >> "$STUB_LOG"\n' > "$1/install.sh"
  chmod +x "$1/install.sh"
  echo one > "$1/home/.config/quickshell/torus/shell.qml"
}
git init -q -b main "$F/torus"
seed "$F/torus"
g "$F/torus" add -A
g "$F/torus" commit -q -S -m "feat: one"
for r in "$F/torus"; do git -C "$r" config gpg.ssh.allowedSignersFile "$F/signers"; git -C "$r" config gpg.format ssh; done
git clone -q "$F/torus" "$F/torus-dev"
U=$F/torus/home/.local/bin/torus-update

assert_eq "torus update: already up to date at $(git -C "$F/torus" rev-parse --short HEAD)" "$("$U")" "nothing new"
[[ ! -e $STUB_LOG ]] || fail "nothing new must not install"

echo two > "$F/torus-dev/home/.config/quickshell/torus/shell.qml"
g "$F/torus-dev" commit -q -S -am "fix: two"
assert_eq "installed feat: one|new fix: two" "$("$U" --list | cut -f1,3 | tr '\t' ' ' | paste -sd'|')" "list: signed incoming commit"
out=$("$U")
grep -q "1 new commit from torus-dev (main)" <<< "$out" || fail "says what came: $out"
assert_eq "two" "$(cat "$F/torus/home/.config/quickshell/torus/shell.qml")" "fast-forwarded"
grep -q '^install --no-packages$' "$STUB_LOG" || fail "runs install.sh --no-packages"
grep -q 'restart torus-shell' "$STUB_LOG" && fail "a changed shell file alone must not restart the shell"

echo new > "$F/torus-dev/home/.config/quickshell/torus/New.qml"
g "$F/torus-dev" add home/.config/quickshell/torus/New.qml
g "$F/torus-dev" commit -q -S -m "feat: three"
out=$("$U")
grep -q "shell restarted, 1 new shell file" <<< "$out" || fail "says the shell restarted: $out"
grep -q 'restart torus-shell.service' "$STUB_LOG" || fail "a new shell file restarts the shell"

before=$(git -C "$F/torus" rev-parse HEAD)
: > "$STUB_LOG"
g "$F/torus-dev" commit -q --allow-empty -m "feat: unsigned four"
assert_eq "installed|unsigned" "$("$U" --list | cut -f1 | paste -sd'|')" "list marks the unsigned commit"
assert_fails "$U"
grep -q "feat: unsigned four" <<< "$("$U" 2>&1 || true)" || fail "names the unsigned commit"
assert_eq "$before" "$(git -C "$F/torus" rev-parse HEAD)" "unsigned: nothing merged"
[[ ! -s $STUB_LOG ]] || fail "unsigned: nothing installed"

g "$F/torus-dev" reset -q --hard HEAD~1
ssh-keygen -q -t ed25519 -N "" -f "$F/other"
printf 't@t %s\n' "$(cat "$F/other.pub")" >> "$F/signers"
git -C "$F/torus-dev" -c user.email=t@t -c user.name=t -c gpg.format=ssh -c user.signingkey="$F/other.pub" commit -q -S --allow-empty -m "feat: signed by a stranger"
assert_eq "G" "$(git -C "$F/torus-dev" -c gpg.ssh.allowedSignersFile="$F/signers" log -1 --format=%G?)" "fixture: the stranger's signature is valid"
assert_eq "installed|unsigned" "$("$U" --list | cut -f1 | paste -sd'|')" "a valid signature from another key is not trusted"
assert_fails "$U"
assert_eq "$before" "$(git -C "$F/torus" rev-parse HEAD)" "another key: nothing merged"
[[ ! -s $STUB_LOG ]] || fail "another key: nothing installed"
g "$F/torus-dev" reset -q --hard HEAD~1
git -C "$F/torus-dev" -c user.email=t@t -c user.name=t -c gpg.format=ssh -c user.signingkey="$F/other.pub" commit -q -S --allow-empty -m "feat: stranger on a side branch"
side=$(git -C "$F/torus-dev" rev-parse HEAD)
g "$F/torus-dev" reset -q --hard HEAD~1
g "$F/torus-dev" merge -q -S --no-ff --no-edit "$side"
assert_fails "$U"
assert_eq "$before" "$(git -C "$F/torus" rev-parse HEAD)" "a signed merge cannot carry a stranger's commit in"
g "$F/torus-dev" reset -q --hard HEAD~1
g "$F/torus" commit -q -S --allow-empty -m "feat: local only"
g "$F/torus-dev" commit -q -S --allow-empty -m "feat: diverged"
assert_fails "$U"
grep -q "not a fast-forward" <<< "$("$U" 2>&1 || true)" || fail "diverged history is refused"
[[ ! -s $STUB_LOG ]] || fail "diverged: nothing installed"

g "$F/torus-dev" reset -q --hard HEAD~1
assert_eq 0 "$("$U" > /dev/null; echo $?)" "dev behind the installed commit is fine"

mv "$F/torus-dev" "$F/gone"
assert_fails "$U"
assert_eq "" "$("$U" --list)" "no source: the list is empty"

git init -q -b main "$F/up"
git -C "$F/up" config gpg.format ssh
g "$F/up" commit -q -S --allow-empty -m "feat: one"
git clone -q "$F/up" "$F/laptop"
seed "$F/laptop"
git -C "$F/laptop" config gpg.ssh.allowedSignersFile "$F/signers"
git -C "$F/laptop" config gpg.format ssh
g "$F/up" commit -q -S --allow-empty -m "fix: from upstream"
out=$("$F/laptop/home/.local/bin/torus-update")
grep -q "1 new commit from origin/main" <<< "$out" || fail "without a dev checkout it follows upstream: $out"
g "$F/up" commit -q --allow-empty -m "fix: unsigned upstream"
assert_fails "$F/laptop/home/.local/bin/torus-update"
grep -q "not signed by the key" <<< "$("$F/laptop/home/.local/bin/torus-update" 2>&1 || true)" || fail "upstream path refuses unsigned too"
git init -q -b main "$F/plain"
seed "$F/plain"
g "$F/plain" add -A; g "$F/plain" commit -q -m "feat: unsigned install"
git clone -q "$F/plain" "$F/plain-dev"
g "$F/plain-dev" commit -q -S --allow-empty -m "feat: signed"
git -C "$F/plain" config gpg.ssh.allowedSignersFile "$F/signers"; git -C "$F/plain" config gpg.format ssh
grep -q "no good signature, so there is no key to trust" <<< "$("$F/plain/home/.local/bin/torus-update" 2>&1 || true)" || fail "an unsigned install trusts no key"
echo "update: ok"
