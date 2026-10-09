# Lately list

The Lately section of the profile README is built by a script. Do not edit the text between the two marker lines by hand. The next change overwrites it.

## Files

| File | Purpose |
| --- | --- |
| `scripts/lately.sh` | Finds the projects, reads their releases, rewrites the README block. |
| `scripts/lately.jq` | Builds the list rows and cleans the release text. |
| `scripts/test-lately.sh` | Offline test of the text cleaning. No network. |
| `.github/workflows/lately.yml` | Runs the script every Monday at 05:23 UTC and on demand. |

## Add a project

1. Make sure the repository is public, is not a fork, and is not archived.
2. Add the topic `profile-lately` to the repository.
3. Wait for the next weekly run, or start the workflow by hand (see "Run it by hand").

A repository with the topic but no release appears last with the text "no release yet". Draft and pre-release releases are ignored.

## Remove a project

Remove the topic `profile-lately` from the repository. Making the repository private, archiving it, or deleting it also removes it. The row disappears at the next run.

## Run it by hand

Run the workflow in GitHub:

```sh
gh workflow run lately.yml --repo OriginalMHV/OriginalMHV
```

Run the script on a local clone:

```sh
OWNER=OriginalMHV GH_TOKEN=$(gh auth token) bash scripts/lately.sh README.md
git diff README.md
```

Settings, all optional:

| Variable | Default | Meaning |
| --- | --- | --- |
| `OWNER` | `OriginalMHV` | The account whose public repositories are searched. |
| `TOPIC` | `profile-lately` | The topic that selects a project. |
| `PER_REPO` | `2` | The most releases shown for one repository. |
| `MAX_ROWS` | `5` | The most release rows in total. |

Test the text cleaning with `bash scripts/test-lately.sh`.

## When the README changes

The script writes a new README only when the block differs from the new one. The block holds no date. A run with the same data changes nothing and makes no commit.

## What happens on failure

The script stops with a non-zero exit code and leaves the README unchanged in these cases:

1. An API call fails, for example a rate limit or a bad token.
2. No public repository has the topic.
3. No rows can be built.
4. The README does not contain exactly one start marker line and one end marker line, or the end marker comes first. Do not show the markers in a code example in the README.
5. The README uses CRLF line endings. Use LF.

The workflow run then shows as failed in the Actions tab. The old list stays on the profile. Fix the cause and run the workflow again.

The workflow can also fail at `git push` if a branch protection rule blocks pushes to `main` by `github-actions[bot]`. Allow the bot to push, or run the script by hand and open a pull request.

## Scheduled runs can stop

GitHub disables scheduled workflows in a public repository after 60 days without repository activity. The workflow commits only when the list changes, so a quiet period can switch it off. To start it again, open the Actions tab, choose the `lately` workflow, and select Enable workflow. Then run it once by hand.

## Safety of release text

Release notes are untrusted text. The script keeps the first sentence of the notes and removes HTML, links, images, bare URLs, email addresses, backslashes and unmatched backticks. Text inside paired code spans stays, but the characters `<` and `>` are removed there too, so no HTML or marker comment can appear in the README. The tag in the link text is limited to letters, digits and `._+-`. The `scripts/test-lately.sh` test covers these cases.
