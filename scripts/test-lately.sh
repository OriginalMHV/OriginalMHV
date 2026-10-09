#!/usr/bin/env bash
# Offline check of the row builder with hostile release text. No network.
# shellcheck disable=SC2016,SC1003
set -euo pipefail
here="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
fail=0

row() { # $1 = tag, $2 = name, $3 = body
  jq -n -c --arg tag "$1" --arg name "$2" --arg body "$3" '
    {repo: "Demo", home: "https://github.com/o/Demo", tag: $tag, at: "2026-01-01T00:00:00Z",
     date: "2026-01-01", name: $name, note: ($body | split("\n"))}'
}

check() { # $1 = label, $2 = tag, $3 = name, $4 = body
  local out text tagpart outside ticks
  out="$(row "$2" "$3" "$4" | jq -r -s --argjson max 5 -f "$here/lately.jq")"
  text="${out#*<br>}"
  tagpart="${out%%<br>*}"
  outside="$(sed -E 's/`[^`]*`//g' <<<"$text")"
  ticks="$(tr -cd '`' <<<"$text" | wc -c)"
  if grep -Eq '<|>' <<<"$text" || grep -Eq '<|>|\]\(|http|www\.|@|\[|\\' <<<"$outside" || [ $((ticks % 2)) -ne 0 ]; then
    echo "FAIL $1: $text"; fail=1; return
  fi
  if ! grep -Eq '^- \*\*\[Demo\]\(https://github.com/o/Demo\)\*\* \[[A-Za-z0-9._+\\-]*\]\(https://github.com/o/Demo/releases/tag/[A-Za-z0-9._~%/-]*\) \(latest\) · 2026-01-01$' <<<"$tagpart"; then
    echo "FAIL $1 row markup: $tagpart"; fail=1; return
  fi
  echo "ok   $1: $text"
}

check "html tag"        v1 n 'Fix <img src=x onerror=alert(1)> now.'
check "odd backtick"    v1 n 'Fix `a <img src=x> done'
check "double backtick" v1 n 'Fix ``a` <img src=x> done'
check "escaped tick"    v1 n 'Fix \` <img src=x> `'
check "bare url"        v1 n 'See https://evil.example/x and www.evil.example for more.'
check "markdown link"   v1 n 'See [docs](https://evil.example/x) for more.'
check "image"           v1 n 'Look ![x](https://evil.example/p.png) here.'
check "email"           v1 n 'Thanks to bob@example.com for help.'
check "empty body name" v1 'Name <b>bold</b> https://evil.example' ''
check "bad tag"         'v1<img src=x>("' n 'Plain note.'
check "bullet"          v1 n '- Add `foo` support (new)'
check "heading only"    v1 n '## Heading'
check "period in span"  v1 n 'Run `a. b` now'
check "marker in span"  v1 n 'Do `<!-- lately:end -->` now'
check "slash tag"       'rel/1.0' n 'Plain note.'
check "underscore tag"  'v_1_' n 'Plain note.'
check "long name"       v1 "$(printf 'word %.0s' {1..60})" ''
check "marker in span2" v1 n 'Do `<!-- lately:start -->` now.'
exit "$fail"
