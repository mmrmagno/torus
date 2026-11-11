#!/usr/bin/env bash
set -euo pipefail
. "$(dirname "$0")/lib.sh"

F=$(mktemp -d)
trap 'rm -rf "$F"' EXIT
mkdir -p "$F/bin"
export PATH=$F/bin:/usr/bin:/bin STUB_LOG=$F/calls
T=$REPO/home/.local/bin/torus-gh
cat > "$F/bin/gh" <<'S'
#!/usr/bin/env bash
echo "gh $1 $2" >> "$STUB_LOG"
[[ $1 == auth ]] && exit "${STUB_AUTH:-0}"
[[ -n ${STUB_OFFLINE:-} ]] && exit 1
cat <<'J'
{"data":{"viewer":{"login":"me",
 "pullRequests":{"nodes":[
  {"number":7,"title":"fix the lock","url":"https://github.com/me/a/pull/7","isDraft":false,"updatedAt":"2026-11-11T10:00:00Z","repository":{"nameWithOwner":"me/a"},"commits":{"nodes":[{"commit":{"statusCheckRollup":{"state":"FAILURE"}}}]}},
  {"number":8,"title":"draft thing","url":"https://github.com/me/a/pull/8","isDraft":true,"updatedAt":"2026-11-11T09:00:00Z","repository":{"nameWithOwner":"me/a"},"commits":{"nodes":[{"commit":{"statusCheckRollup":null}}]}}]},
 "repositories":{"nodes":[
  {"nameWithOwner":"me/a","url":"https://github.com/me/a","isArchived":false,"pushedAt":"2026-11-11T10:00:00Z","defaultBranchRef":{"name":"main","target":{"statusCheckRollup":{"state":"SUCCESS"}}}},
  {"nameWithOwner":"me/b","url":"https://github.com/me/b","isArchived":false,"pushedAt":"2026-11-10T10:00:00Z","defaultBranchRef":{"name":"main","target":{"statusCheckRollup":{"state":"FAILURE"}}}},
  {"nameWithOwner":"me/old","url":"https://github.com/me/old","isArchived":true,"pushedAt":"2025-01-01T00:00:00Z","defaultBranchRef":{"name":"main","target":{"statusCheckRollup":{"state":"FAILURE"}}}},
  {"nameWithOwner":"me/empty","url":"https://github.com/me/empty","isArchived":false,"pushedAt":"2025-01-01T00:00:00Z","defaultBranchRef":null}]}},
 "review":{"nodes":[{"number":3,"title":"please look","url":"https://github.com/o/c/pull/3","updatedAt":"2026-11-11T08:00:00Z","author":{"login":"pal"},"repository":{"nameWithOwner":"o/c"}},{}]}}}
J
S
chmod +x "$F/bin/gh"

out=$("$T")
assert_eq ok "$(jq -r .status <<< "$out")" "status"
assert_eq me "$(jq -r .login <<< "$out")" "login"
assert_eq "failure|" "$(jq -r '[.mine[].ci] | join("|")' <<< "$out")" "ci per pr"
assert_eq "true" "$(jq -r '.mine[1].draft' <<< "$out")" "draft kept"
assert_eq "me/b" "$(jq -r '[.failing[].repo] | join(",")' <<< "$out")" "only live failing default branches"
assert_eq "https://github.com/me/b/actions" "$(jq -r '.failing[0].url' <<< "$out")" "failing links to actions"
assert_eq "o/c#3 pal" "$(jq -r '.review | map("\(.repo)#\(.number) \(.author)") | join(",")' <<< "$out")" "review requests, empty nodes dropped"
assert_eq signed-out "$(STUB_AUTH=1 "$T" | jq -r .status)" "signed out"
assert_eq offline "$(STUB_OFFLINE=1 "$T" | jq -r .status)" "offline"
