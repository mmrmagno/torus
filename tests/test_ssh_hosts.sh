#!/usr/bin/env bash
set -euo pipefail
. "$(dirname "$0")/lib.sh"

F=$(mktemp -d)
trap 'rm -rf "$F"' EXIT
export HOME=$F
mkdir -p "$F/.ssh/config.d"
cat > "$F/.ssh/config" <<'C'
Include config.d/*
# comment
Host *
    ServerAliveInterval 30
Host bastion jump
    HostName 203.0.113.7
    User admin
Host box
    HostName=box.example
    ProxyJump bastion
    User first
    User second
Host *.internal !nope
    User x
Match host foo
    User y
C
printf 'Host extra\n  HostName extra.example\n' > "$F/.ssh/config.d/10-extra"
out=$("$REPO/home/.local/bin/torus-ssh-hosts")
assert_eq "extra	extra.example		
bastion	203.0.113.7	admin	
jump	203.0.113.7	admin	
box	box.example	first	bastion" "$out" "hosts in order, first value wins, patterns skipped"
rm -rf "$F/.ssh"
assert_eq "" "$("$REPO/home/.local/bin/torus-ssh-hosts")" "no config"
