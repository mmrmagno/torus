#!/usr/bin/env bash
set -euo pipefail
. "$(dirname "$0")/lib.sh"

F=$(mktemp -d)
trap 'rm -rf "$F"' EXIT
mkdir -p "$F/bin"
export PATH=$F/bin:/usr/bin:/bin STUB_LOG=$F/calls
for e in docker podman; do
  cat > "$F/bin/$e" <<S
#!/usr/bin/env bash
echo "$e \$*" >> "\$STUB_LOG"
[[ -n \${STUB_DOWN_$e:-} ]] && exit 1
if [[ \$1 == ps ]]; then
  [[ \$2 == -q ]] && exit 0
  [[ $e == docker ]] && printf 'a1b2\tweb\tnginx:1.27\tUp 3 hours\t0.0.0.0:8080->80/tcp\nc3d4\tdb\tpostgres:17\tUp 2 minutes (healthy)\t\n'
  [[ $e == podman ]] && printf 'e5f6\tcache\tredis:7\tUp 5 seconds\t\n'
fi
exit 0
S
  chmod +x "$F/bin/$e"
done
T=$REPO/home/.local/bin/torus-containers

out=$("$T" list)
assert_eq 3 "$(grep -c . <<< "$out")" "docker and podman listed"
assert_eq "docker	a1b2	web	nginx:1.27	Up 3 hours	0.0.0.0:8080->80/tcp" "$(head -1 <<< "$out")" "fields"
grep -q "^podman	e5f6	cache	redis:7" <<< "$out" || fail "podman row: $out"
assert_eq 2 "$(STUB_DOWN_podman=1 "$T" list | grep -c .)" "an engine that does not answer is skipped"
assert_eq "" "$(STUB_DOWN_podman=1 STUB_DOWN_docker=1 "$T" list)" "nothing when no engine answers"
"$T" restart docker a1b2
grep -q '^docker restart a1b2$' "$STUB_LOG" || fail "restart"
"$T" stop podman e5f6
grep -q '^podman stop e5f6$' "$STUB_LOG" || fail "stop"
assert_fails "$T" stop docker 'a1;rm -rf /'
assert_fails "$T" stop kubectl a1b2
