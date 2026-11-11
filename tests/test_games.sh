#!/usr/bin/env bash
set -euo pipefail
. "$(dirname "$0")/lib.sh"

F=$(mktemp -d)
trap 'rm -rf "$F"' EXIT
S=$F/Steam
mkdir -p "$S/steamapps" "$S/userdata/42/config" "$S/userdata/0/config" "$S/appcache/librarycache/10/abc" "$S/appcache/librarycache/20"
man() { printf '"AppState"\n{\n\t"appid"\t\t"%s"\n\t"name"\t\t"%s"\n\t"LastPlayed"\t\t"%s"\n}\n' "$1" "$2" "$3" > "$S/steamapps/appmanifest_$1.acf"; }
man 10 "Old Game" 100
man 20 "New Game" 200
man 30 "Never Played" 0
man 40 "New Layout" 50
man 1493710 "Proton Experimental" 300
man 1628350 "Steam Linux Runtime 3.0 (sniper)" 400
cat > "$S/userdata/42/config/localconfig.vdf" <<'V'
"UserLocalConfigStore"
{
	"Software"
	{
		"Valve"
		{
			"Steam"
			{
				"apps"
				{
					"10"
					{
						"cloud"
						{
							"last_sync_state"		"synchronized"
						}
						"LastPlayed"		"500"
						"Playtime"		"125"
					}
					"20"
					{
						"Playtime"		"7"
					}
				}
			}
		}
	}
}
V
: > "$S/appcache/librarycache/10/abc/library_600x900.jpg"
: > "$S/appcache/librarycache/20/header.jpg"
mkdir -p "$S/appcache/librarycache/40/0cc1" "$S/appcache/librarycache/40/c227"
: > "$S/appcache/librarycache/40/0cc1/library_capsule.jpg"
: > "$S/appcache/librarycache/40/c227/library_header.jpg"

out=$(TORUS_STEAM=$S "$REPO/home/.local/bin/torus-games")
assert_eq 4 "$(grep -c . <<< "$out")" "Proton and runtimes skipped"
grep -q "^40	New Layout	50	0	$S/appcache/librarycache/40/0cc1/library_capsule.jpg$" <<< "$out" || fail "new Steam layout: library_capsule wins over the header: $out"
assert_eq "10	Old Game	500	125	$S/appcache/librarycache/10/abc/library_600x900.jpg" "$(sed -n 1p <<< "$out")" "localconfig LastPlayed beats the manifest, nested blocks parsed, capsule art"
assert_eq "20	New Game	200	7	$S/appcache/librarycache/20/header.jpg" "$(sed -n 2p <<< "$out")" "header art fallback"
assert_eq "30	Never Played	0	0	" "$(sed -n 4p <<< "$out")" "never played last, no art"
assert_eq "" "$(TORUS_STEAM=$F/none "$REPO/home/.local/bin/torus-games")" "no Steam, no output"
