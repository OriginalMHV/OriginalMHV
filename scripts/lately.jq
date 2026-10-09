# Input: slurped array of release records and release-less repository records.
# Variable: $max, the maximum number of release rows.
# Output: Markdown list rows. Release text is untrusted and is cleaned here.

# Keep letters, digits and a few safe marks for display.
def safe_tag: gsub("[^A-Za-z0-9._+-]"; "");

# Remove everything that can turn release text into HTML, a link or an image.
def clean:
  gsub("\\\\"; "")
  | gsub("`{2,}"; "")
  | (if (([match("`"; "g")] | length) % 2) == 1 then sub("`(?<r>[^`]*)$"; "\(.r)") else . end)
  | split("`")
  | to_entries
  | map(
      if (.key % 2) == 0 then
        .value
        | gsub("\\[(?<t>[^\\]]*)\\]\\([^)]*\\)"; "\(.t)")
        | gsub("(https?://|www\\.)\\S*"; ""; "i")
        | gsub("\\S*@\\S*"; "")
        | gsub("[<>\\[\\]*]"; "")
        | gsub("\\(\\s*\\)"; "")
      else .value | gsub("[<>]"; "") end)
  | join("`")
  | gsub("^\\s*([-+]\\s+)+"; "")
  | gsub("\\s+"; " ")
  | sub("^ "; "") | sub(" $"; "");

# Cut long text at a word. Prefer a clause break. Never leave half a code span.
def shorten:
  if length <= 110 then .
  else
    (.[:107] | sub("\\s+\\S*$"; ""))
    | (if (.[40:] | test("[,;(]")) then sub("(?<h>^.{40,}?)\\s*[,;(][^,;(]*$"; "\(.h)") else . end)
    | (if (([match("`"; "g")] | length) % 2) == 1 then sub("`[^`]*$"; "") else . end)
    | sub("[\\s,;(]+$"; "") + "..."
  end;

# A bullet line is a fragment. Drop its parenthetical groups and end it with a period.
def fragment:
  if test("^\\s*[-+*]\\s") then
    clean | gsub(" \\([^)]*\\)"; "") | (if test("[.!?]$") then . else . + "." end)
  else clean end;

def sentence:
  (if type == "array" then
     (map(select((test("^\\s*(#|\\||```|\\*\\*Full Changelog)") | not) and test("[A-Za-z0-9]"))) | .[0] // "")
   else . end)
  | fragment
  | sub("(?<p>[.!?])\\s.*$"; "\(.p)")
  | (if (([match("`"; "g")] | length) % 2) == 1 then sub("`(?<r>[^`]*)$"; "\(.r)") else . end)
  | shorten;

(map(select(.tag != null)) | sort_by([.at, .repo]) | reverse | .[:$max]) as $rel
| (map(select(.tag == null)) | sort_by(.repo)) as $none
| ($rel | to_entries | map(
    .value as $r
    | "- **[\($r.repo)](\($r.home))** [\($r.tag | safe_tag | gsub("_"; "\\_"))](\($r.home)/releases/tag/\($r.tag | split("/") | map(@uri) | join("/")))"
      + (if .key == 0 then " (latest)" else "" end)
      + " · \($r.date)<br>\(($r.note | sentence) | if . == "" then ($r.name | clean | shorten) else . end | if . == "" then ($r.tag | safe_tag) else . end)"))
  + ($none | map("- **[\(.repo)](\(.home))** · no release yet"))
| join("\n")
