#!/usr/bin/env bash
# Rewrites the block between the lately markers in a README.
# Source: the GitHub REST API. Public, non-fork, non-archived repositories of the
# owner that carry the topic (default profile-lately). Releases are read with GH_TOKEN.
# The README is rewritten only when the block changes, so a run with the same data makes no diff.
# Usage: scripts/lately.sh [README.md]
# Env: OWNER, TOPIC, PER_REPO, MAX_ROWS
set -euo pipefail

readme="${1:-README.md}"
owner="${OWNER:-${GITHUB_REPOSITORY_OWNER:-OriginalMHV}}"
topic="${TOPIC:-profile-lately}"
per_repo="${PER_REPO:-2}"
max_rows="${MAX_ROWS:-5}"
here="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

start='<!-- lately:start -->'
end='<!-- lately:end -->'

if grep -q $'\r' "$readme"; then
  echo "$readme has CRLF line endings. Use LF." >&2
  exit 1
fi
n_start="$(grep -cxF "$start" "$readme" || true)"
n_end="$(grep -cxF "$end" "$readme" || true)"
if [ "$n_start" -ne 1 ] || [ "$n_end" -ne 1 ]; then
  echo "Expected exactly one '$start' line and one '$end' line in $readme. Found $n_start and $n_end." >&2
  exit 1
fi
if [ "$(grep -nxF "$start" "$readme" | cut -d: -f1)" -ge "$(grep -nxF "$end" "$readme" | cut -d: -f1)" ]; then
  echo "The start marker must come before the end marker in $readme." >&2
  exit 1
fi

work="$(mktemp -d)"
trap 'rm -rf "$work"' EXIT

# Assign first so that an API failure stops the script.
all_repos="$(gh api --paginate "users/${owner}/repos?per_page=100")"
repos="$(jq -r -s --arg t "$topic" '
  add // []
  | map(select((.topics // []) | index($t)))
  | map(select(.private == false and .fork == false and .archived == false))
  | map(.name | select(test("^[A-Za-z0-9._-]+$")))
  | sort | .[]' <<<"$all_repos")"

[ -n "$repos" ] || { echo "No public repository with topic '${topic}' found. README left unchanged." >&2; exit 1; }

: >"$work/all.jsonl"
while IFS= read -r repo; do
  releases="$(gh api "repos/${owner}/${repo}/releases?per_page=100")"
  jq -c --arg repo "$repo" --arg owner "$owner" --argjson n "$per_repo" '
    [.[] | select(.draft == false and .prerelease == false)] | sort_by(.published_at) | reverse as $rel
    | "https://github.com/\($owner)/\($repo)" as $home
    | if ($rel | length) == 0 then
        {repo: $repo, home: $home, tag: null}
      else
        $rel[:$n][]
        | {repo: $repo, home: $home, tag: .tag_name, at: .published_at, date: .published_at[:10],
           name: (.name // .tag_name), note: ((.body // "") | gsub("\r"; "") | split("\n"))}
      end' <<<"$releases" >>"$work/all.jsonl"
done <<<"$repos"

[ -s "$work/all.jsonl" ] || { echo "No data from the API. README left unchanged." >&2; exit 1; }

jq -r -s --argjson max "$max_rows" -f "$here/lately.jq" "$work/all.jsonl" >"$work/rows.md"
[ -s "$work/rows.md" ] || { echo "No rows built. README left unchanged." >&2; exit 1; }

{
  echo "$start"
  cat "$work/rows.md"
  echo
  echo "Updated weekly from my GitHub releases."
  echo "$end"
} >"$work/block.md"

awk -v start="$start" -v end="$end" '$0 == start { on = 1 } on { print } $0 == end { on = 0 }' "$readme" >"$work/old.md"

if cmp -s "$work/old.md" "$work/block.md"; then
  echo "No change in the list. README left as is." >&2
  exit 0
fi

awk -v block="$work/block.md" -v start="$start" -v end="$end" '
  $0 == start { while ((getline line < block) > 0) print line; skip = 1; next }
  $0 == end   { skip = 0; next }
  !skip       { print }
' "$readme" >"$work/new.md"

cat "$work/new.md" >"$readme"
echo "README updated." >&2
