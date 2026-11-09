#!/usr/bin/env bash
set -euo pipefail

HERE=$(cd "$(dirname "$0")" && pwd)
SCOPE=${TORUS_SCOPE:-$HERE/scope.txt}
home="" root="" out="" skip_lists=0 keep_stage=0

while (($#)); do
  case $1 in
    --home) home=$2; shift 2 ;;
    --root) root=$2; shift 2 ;;
    --out) out=$2; shift 2 ;;
    --skip-lists) skip_lists=1; shift ;;
    --keep-stage) keep_stage=1; shift ;;
    *) echo "unknown option: $1" >&2; exit 1 ;;
  esac
done

override_home=$home override_root=$root
user=${SUDO_USER:-$(id -un)}
[[ -n $home ]] || home=$(getent passwd "$user" | cut -d: -f6)
[[ -n $root ]] || root=/
[[ -n $out ]] || out=$home/backups/torus

if [[ -z $override_home || -z $override_root ]] && [[ $EUID -ne 0 || -z ${SUDO_USER:-} ]]; then
  echo "run with sudo: sudo $0" >&2
  exit 2
fi

stamp=${TORUS_STAMP:-$(date +%Y%m%d-%H%M%S)}
dir=$out/$stamp
S=$dir/stage
if [[ -e $dir ]]; then
  echo "backup dir exists: $dir" >&2
  exit 3
fi
mkdir -p "$out"
chmod 700 "$out"
mkdir -p "$S/home" "$S/system" "$S/meta"

as_user() {
  if [[ $EUID -eq 0 && $user != root ]]; then
    sudo -u "$user" XDG_RUNTIME_DIR="/run/user/$(id -u "$user")" "$@"
  else
    "$@"
  fi
}

home_excludes=()
system_paths=()
home_paths=()
while IFS= read -r line; do
  case $line in
    "home + "*) home_paths+=("${line#home + }") ;;
    "home - "*) home_excludes+=(--exclude "${line#home - }") ;;
    "system + "*) system_paths+=("${line#system + }") ;;
    system-modified)
      if ((!skip_lists)); then
        while IFS= read -r p; do system_paths+=("$p"); done < <(pacman -Qii | awk '/^MODIFIED/ {print $2}')
      fi
      ;;
  esac
done < "$SCOPE"

: > "$S/meta/missing-includes.txt"
copy() {
  local what=$1 rc=0
  shift
  rsync "$@" || rc=$?
  # 24: source files vanished while copying (live caches); everything else is real
  if ((rc == 24)); then
    echo "$what" >> "$S/meta/vanished.txt"
  elif ((rc != 0)); then
    exit "$rc"
  fi
}
for p in "${home_paths[@]}"; do
  if [[ -e $home/$p || -L $home/$p ]]; then
    copy "home $p" -a --relative "${home_excludes[@]}" "$home/./$p" "$S/home/"
  else
    echo "home $p" >> "$S/meta/missing-includes.txt"
  fi
done
for p in "${system_paths[@]}"; do
  rel=${p#/}
  if [[ -e $root/$rel || -L $root/$rel ]]; then
    copy "system $p" -a --relative "$root/./$rel" "$S/system/"
  else
    echo "system $p" >> "$S/meta/missing-includes.txt"
  fi
done

chmod --reference="$home" "$S/home"
chmod --reference="$root" "$S/system"
if [[ $EUID -eq 0 ]]; then
  chown --reference="$home" "$S/home"
  chown --reference="$root" "$S/system"
fi

cp "$SCOPE" "$S/meta/scope.txt"
cat "$root/etc/machine-id" > "$S/meta/machine-id" 2>/dev/null || : > "$S/meta/machine-id"
declare -A covered=()
for p in "${home_paths[@]}"; do covered[${p%%/*}]=1; done
: > "$S/meta/excluded.txt"
for e in "$home"/* "$home"/.[!.]*; do
  [[ -e $e || -L $e ]] || continue
  name=${e##*/}
  [[ -n ${covered[$name]:-} ]] || echo "$name" >> "$S/meta/excluded.txt"
done

if ((!skip_lists)); then
  pacman -Qqen > "$S/meta/pkg-native.txt"
  pacman -Qqem > "$S/meta/pkg-foreign.txt" || true
  if command -v flatpak >/dev/null; then flatpak list --app --columns=application > "$S/meta/flatpak.txt"; else : > "$S/meta/flatpak.txt"; fi
  { systemctl list-unit-files --state=enabled --no-legend || true; } | awk '{print $1}' > "$S/meta/units-system.txt"
  { as_user systemctl --user list-unit-files --state=enabled --no-legend || true; } | awk '{print $1}' > "$S/meta/units-user.txt"
  { as_user systemctl --user list-unit-files --state=masked --no-legend || true; } | awk '{print $1}' > "$S/meta/masked-user.txt"
  as_user dconf dump / > "$S/meta/dconf.ini" || : > "$S/meta/dconf.ini"
  as_user gsettings list-recursively org.gnome.desktop.interface > "$S/meta/gsettings.txt" 2>/dev/null || : > "$S/meta/gsettings.txt"
  as_user crontab -l > "$S/meta/crontab.txt" 2>/dev/null || : > "$S/meta/crontab.txt"
fi

(cd "$S" && find home system meta -type f -print0 | sort -z | xargs -0 -r sha256sum) > "$S/MANIFEST.sha256"
(cd "$S" && find home system meta -type l -print0 | sort -z | while IFS= read -r -d '' l; do printf '%s\t%s\n' "$l" "$(readlink "$l")"; done) > "$S/LINKS.txt"
[[ -f $HERE/restore.sh ]] && cp "$HERE/restore.sh" "$S/restore.sh"

tarball=torus-backup-$stamp.tar.zst
members=(home system meta MANIFEST.sha256 LINKS.txt)
[[ -f $S/restore.sh ]] && members+=(restore.sh)
tar --zstd --numeric-owner -cf "$dir/$tarball" -C "$S" "${members[@]}"
(cd "$dir" && sha256sum "$tarball" > "$tarball.sha256")
cp "$S/MANIFEST.sha256" "$S/LINKS.txt" "$dir/"
cp -r "$S/meta" "$dir/meta"
((keep_stage)) || rm -rf "$S"
if [[ $EUID -eq 0 && $user != root ]]; then
  chown -R "$user:" "$out"
fi

echo "$dir"
