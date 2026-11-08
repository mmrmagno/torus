#!/usr/bin/env bash
set -uo pipefail

R=${TORUS_REPO:-$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)}
state=${XDG_STATE_HOME:-$HOME/.local/state}/torus
backup=""
while (($#)); do
  case $1 in
    --backup) backup=$2; shift 2 ;;
    *) echo "unknown option: $1" >&2; exit 1 ;;
  esac
done

[[ -n $backup ]] || backup=$(sed -n 's/^backup=//p' "$state/cutover" 2> /dev/null | tail -n 1)
[[ -n $backup ]] || { echo "no cutover recorded, pass --backup DIR to restore one anyway" >&2; exit 2; }
[[ -d $backup ]] || { echo "backup not found: $backup" >&2; exit 2; }
echo "rolling back to HyDE from $backup"

sudo "$R/install.sh" --system --undo
rc=$?
if ((rc != 0 && rc != 10)); then
  echo "rollback stopped: undoing the system files failed (exit $rc), nothing else was touched" >&2
  exit "$rc"
fi

sudo "$R/backup/restore.sh" "$backup" --torus "$R"
rc=$?
case $rc in
  0) ;;
  7) echo "some packages could not be reinstalled, see $backup/missing-packages.txt" >&2 ;;
  *) echo "restore failed (exit $rc), see its output above" >&2; exit "$rc" ;;
esac

rm -f "$state/cutover"
echo "HyDE is back, reboot now"
