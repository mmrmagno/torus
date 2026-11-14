#!/usr/bin/env bash
set -euo pipefail
. "$(dirname "$0")/lib.sh"

F=$(mktemp -d)
trap 'rm -rf "$F"' EXIT
mkdir -p "$F/bin"
export PATH=$F/bin:$PATH LOG=$F/calls TORUS_SPIRE_CONF=$F/spire.json
S=$REPO/home/.local/bin/torus-spire
Q=$REPO/home/.config/quickshell/torus

write_verbs='kubectl[^|;&]*\b(apply|delete|patch|edit|create|replace|scale|drain|cordon|uncordon|label|annotate|rollout|exec|cp|port-forward|run|set|taint|debug)\b|flux[^|;&]*\b(reconcile|suspend|resume|delete|create|bootstrap|install|uninstall)\b|talosctl[^|;&]*\b(apply|apply-config|reboot|reset|shutdown|upgrade|edit|patch|bootstrap|restart|rollback|kill|wipe)\b'
hits=$(grep -nE "$write_verbs" "$S" $(ls "$Q"/services/Spire*.qml "$Q"/spire/*.qml 2> /dev/null) | grep -v '^[^:]*:[0-9]*:#' || true)
[[ -z $hits ]] || fail "write verb in the homelab hub: $hits"

cp "$REPO/tests/fixtures/spire/kubectl" "$REPO/tests/fixtures/spire/talosctl" "$F/bin/"
chmod +x "$F"/bin/*
echo '{"tailscale":["ironclad"],"amt":{"ironclad":"127.0.0.1"}}' > "$TORUS_SPIRE_CONF"

out=$("$S" status)
assert_eq true "$(jq -r .ok <<< "$out")" "status ok"
assert_eq "architect:true:control plane:6% ironclad:false:worker:10%" "$(jq -r '[.nodes[] | "\(.name):\(.ready):\(.role):\(.cpu)"] | join(" ")' <<< "$out")" "nodes"
assert_eq "apps/web-1:CrashLoopBackOff" "$(jq -r '.pods | map("\(.ns)/\(.name):\(.why)") | join(" ")' <<< "$out")" "unhealthy pods only"
assert_eq 3 "$(jq -r .problems <<< "$out")" "problems: NotReady node, crashing pod, failed helm release"
assert_eq "https://blog.example.test https://grafana.example.test" "$(jq -r '.apps | map(.url) | join(" ")' <<< "$out")" "apps from HTTPRoutes"
assert_eq "ironclad:Running OK:192.0.2.0/24" "$(jq -r '.tailscale | map("\(.node):\(.state):\(.routes)") | join(" ")' <<< "$out")" "tailscale router health"
assert_eq "2026-11-11T18:00:00Z" "$(jq -r '.backups[0].last' <<< "$out")" "backup age source"
grep -q "TS_AUTHKEY" <<< "$out" && fail "secrets from the extension config must not leak"

bad=$(grep -vE '^kubectl --request-timeout=5s (get|top) |^kubectl config current-context$|^talosctl -n [0-9.]+ (service ext-tailscale|get extensionserviceconfigs tailscale -o json)$' "$LOG" || true)
[[ -z $bad ]] || fail "unexpected calls: $bad"

out=$(NOCTX=1 "$S" status)
assert_eq "false:no kubectl context" "$(jq -r '"\(.ok):\(.reason)"' <<< "$out")" "no context, no polling"
out=$("$S" amt-check)
assert_eq "ironclad" "$(jq -r '.[0].node' <<< "$out")" "amt node listed"
assert_eq "https://127.0.0.1:16993" "$(jq -r '.[0].web' <<< "$out")" "amt web ui link"
mkdir -p "$F/envbin"
printf '#!/bin/sh\necho "$KUBECONFIG|$TALOSCONFIG" > "%s/seen"\nexit 1\n' "$F" > "$F/envbin/kubectl"; chmod +x "$F/envbin/kubectl"
echo '{"kubeconfig": "~/spire/kubeconfig", "talosconfig": "~/spire/talosconfig"}' > "$TORUS_SPIRE_CONF"
(unset KUBECONFIG TALOSCONFIG; PATH=$F/envbin:$PATH "$S" status > /dev/null)
assert_eq "$HOME/spire/kubeconfig|$HOME/spire/talosconfig" "$(cat "$F/seen")" "config paths from spire.json when the environment has none"
(export KUBECONFIG=/own/kc; PATH=$F/envbin:$PATH "$S" status > /dev/null)
[[ $(cat "$F/seen") == /own/kc\|* ]] || fail "an existing KUBECONFIG wins: $(cat "$F/seen")"
grep -niE 'kitty|ssh|console|terminal' "$Q"/spire/*.qml "$Q"/services/Spire.qml && fail "the hub offers no console, ssh or terminal for the Talos nodes"
grep -q '"torus-spire", "kvm"' "$Q/services/Spire.qml" && grep -q 'Spire.kvm()' "$Q/spire/SpireHub.qml" || fail "Remote KVM button runs torus-spire kvm"

port=$(python3 -c 'import socket; s=socket.socket(); s.bind(("127.0.0.1", 0)); print(s.getsockname()[1])')
mkdir -p "$F/mc"
{
  echo '#!/bin/sh'
  echo "echo started >> '$F/mc/starts'"
  echo "exec python3 -c 'import socket,time; s=socket.socket(); s.setsockopt(socket.SOL_SOCKET, socket.SO_REUSEADDR, 1); s.bind((\"127.0.0.1\", $port)); s.listen(); time.sleep(20)' torus-test-mc"
} > "$F/mc/run.sh"
chmod +x "$F/mc/run.sh"
printf '#!/bin/sh\necho "launch $*" >> "%s/opened"\n' "$F" > "$F/bin/torus-launch"
chmod +x "$F/bin/torus-launch"
jq -n --arg u "http://127.0.0.1:$port/default.htm" --arg d "$F/mc" '{ meshcommander: { url: $u, dir: $d } }' > "$TORUS_SPIRE_CONF"
XDG_RUNTIME_DIR=$F "$S" kvm || fail "kvm starts MeshCommander"
XDG_RUNTIME_DIR=$F "$S" kvm || fail "kvm with MeshCommander already up"
assert_eq 1 "$(wc -l < "$F/mc/starts")" "MeshCommander started once"
assert_eq "launch xdg-open http://127.0.0.1:$port/default.htm|launch xdg-open http://127.0.0.1:$port/default.htm" "$(paste -sd'|' "$F/opened")" "opens default.htm through torus-launch"
pkill -f torus-test-mc 2> /dev/null || true
jq -n --arg u "http://127.0.0.1:$port/default.htm" '{ meshcommander: { url: $u, dir: "/nonexistent" } }' > "$TORUS_SPIRE_CONF"
sleep 0.3
XDG_RUNTIME_DIR=$F "$S" kvm 2> /dev/null && fail "kvm without MeshCommander must fail"
assert_eq 2 "$(wc -l < "$F/opened")" "nothing opened when MeshCommander is missing"
echo "spire: ok"
