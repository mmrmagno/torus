#!/usr/bin/env bash
set -euo pipefail

usage() {
  echo "usage: $0 push <backup-dir> [--dest REMOTE:PATH] [--recipient FILE]" >&2
  echo "       $0 fetch <stamp> <out-dir> --identity FILE [--src REMOTE:PATH]" >&2
  exit 1
}

check_rclone() {
  local v
  v=$(rclone version | awk 'NR==1 {sub(/^v/, "", $2); print $2}')
  if [[ $(printf '%s\n1.64\n' "$v" | sort -V | head -1) != 1.64 ]]; then
    echo "rclone $v is older than 1.64" >&2
    exit 2
  fi
  if [[ $1 == proton:* ]] && ! rclone help backends | grep -w protondrive >/dev/null; then
    echo "this rclone has no protondrive backend" >&2
    exit 2
  fi
}

push() {
  local dir=$1; shift
  local dest=proton:Backups/torus recipient=$HOME/.config/torus/backup-recipient
  while (($#)); do
    case $1 in
      --dest) dest=$2; shift 2 ;;
      --recipient) recipient=$2; shift 2 ;;
      *) usage ;;
    esac
  done
  [[ -s $recipient ]] || { echo "no age recipient at $recipient" >&2; exit 2; }
  check_rclone "$dest"
  local tarball
  tarball=$(find "$dir" -maxdepth 1 -name 'torus-backup-*.tar.zst' | head -1)
  [[ -n $tarball ]] || { echo "no tarball in $dir" >&2; exit 1; }
  local name=${tarball##*/} up=$dir/.offsite
  trap 'rm -rf "$up"' RETURN
  mkdir -p "$up"
  age -R "$recipient" -o "$up/$name.age" "$tarball"
  cp "$tarball.sha256" "$up/"
  local extra=()
  [[ $dest == proton:* ]] && extra=(--protondrive-replace-existing-draft=true)
  rclone copy "${extra[@]}" "$up" "$dest"
  rclone check --one-way "$up" "$dest"
  echo "uploaded $name.age to $dest"
}

fetch() {
  local stamp=$1 out=$2; shift 2
  local src=proton:Backups/torus identity=""
  while (($#)); do
    case $1 in
      --src) src=$2; shift 2 ;;
      --identity) identity=$2; shift 2 ;;
      *) usage ;;
    esac
  done
  [[ -r $identity ]] || { echo "no age identity at $identity" >&2; exit 2; }
  umask 077
  check_rclone "$src"
  local name=torus-backup-$stamp.tar.zst
  mkdir -p "$out"
  rclone copy "$src" "$out" --include "$name.age" --include "$name.sha256"
  age -d -i "$identity" -o "$out/$name" "$out/$name.age"
  rm -f "$out/$name.age"
  (cd "$out" && sha256sum -c --quiet "$name.sha256")
  echo "fetched $out/$name"
}

(($#)) || usage
cmd=$1; shift
case $cmd in
  push) (($#)) || usage; push "$@" ;;
  fetch) (($# >= 2)) || usage; fetch "$@" ;;
  *) usage ;;
esac
