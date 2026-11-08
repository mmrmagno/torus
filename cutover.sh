#!/usr/bin/env bash
set -uo pipefail

R=${TORUS_REPO:-$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)}
state=${XDG_STATE_HOME:-$HOME/.local/state}/torus
log=$(mktemp)
trap 'rm -f "$log"' EXIT

failed() {
  echo "cutover failed at $1 (exit $2), run ./rollback.sh to go back to HyDE" >&2
  exit "$2"
}

"$R/uninstall-current.sh" | tee "$log"
rc=${PIPESTATUS[0]}
((rc == 9)) && { echo "HyDE was already moved, finishing the install" >&2; rc=0; }
((rc == 0)) || failed uninstall-current.sh "$rc"
backup=$(sed -n 's/^backup=//p' "$log" | tail -n 1)

"$R/install.sh" || failed install.sh $?
sudo "$R/install.sh" --system || failed "install.sh --system" $?

mkdir -p "$state"
printf 'backup=%s\nstamp=%s\n' "$backup" "$(date +%Y%m%d-%H%M%S)" > "$state/cutover"
echo "torus is installed, reboot now"
