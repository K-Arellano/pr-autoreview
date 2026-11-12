# pr-autoreview

Automatically reviews every open GitHub PR where you are a **requested reviewer**,
using Claude Code on your **Claude subscription** (no API key), and posts the result
as a review under your GitHub account.

- Each finding is tagged 🔴 **Blocking** or 🟡 **Non-blocking**, inline on the diff.
- No findings → the PR is **approved** (set `AUTO_APPROVE=false` to only comment).
- Findings → a `COMMENT` review (it never requests changes).

Runs locally on your Mac via launchd every 15 minutes, so it only runs while the
Mac is awake and you are logged in.

## How it works

1. `gh search prs --review-requested=@me --state=open --draft=false`
2. For each PR not yet reviewed at its current head commit, it fetches the PR into
   a cached blobless clone and checks out a temporary worktree.
3. Runs `claude -p` in that worktree with **read-only tools** (Read/Grep/Glob,
   `git diff/log/show/blame`, skills) and a JSON schema for structured output.
   Your user-level skills and the repo's `CLAUDE.md` apply.
4. The script — not Claude — builds and posts the review via `gh api`. If an inline
   comment points outside the diff, it retries with comments folded into the body.
5. Records `owner/repo#N@sha` in `~/.local/state/pr-autoreview/reviewed.txt`. New
   pushes plus a re-request get reviewed again.

## Setup

Requires `gh` (logged in), `claude` (logged in with your subscription), `jq`, `git`.

```sh
cp config.env.example config.env   # set OWNERS to your org(s)
DRY_RUN=1 ./review.sh              # prints what it would post; posts nothing
./install.sh                       # installs the launchd agent
launchctl kickstart gui/$(id -u)/local.pr-autoreview   # run once now
```

Logs: `~/Library/Logs/pr-autoreview.log` · Remove: `./uninstall.sh`

`install.sh` copies the files to `~/.local/share/pr-autoreview` and runs them from
there, because macOS blocks background services from reading `~/Desktop` and
`~/Documents`. **Re-run `./install.sh` after editing anything in this repo.**

## Dashboard

`install.sh` also starts an always-on local dashboard at **http://localhost:8787**
(localhost only). It refreshes every 3 seconds and shows the PRs being reviewed right
now with a timer, the PRs still waiting on you, and a history of reviews. Each history
row links to the PR and to the posted review; expand it to see the summary and
every finding. It reads `status.json` and `events.jsonl` from
`~/.local/state/pr-autoreview`.

## Configuration (`config.env`)

| Var | Default | |
|---|---|---|
| `OWNERS` | all | Orgs/users to limit to |
| `EXCLUDE_REPOS` | none | `owner/repo` to skip |
| `AUTO_APPROVE` | `true` | Approve when no findings |
| `MAX_PRS_PER_RUN` | `5` | Protects your usage limits |
| `MAX_ATTEMPTS` | `3` | Retries per PR head before giving up |
| `MODEL` | Claude Code default | e.g. `sonnet` to save usage |
| `INTERVAL_SECONDS` | `900` | Re-run `./install.sh` after changing |
| `DRY_RUN` | `0` | `1` = print, don't post |
| `DASHBOARD_PORT` | `8787` | Re-run `./install.sh` after changing |

Tune what Claude looks for in `prompt.md`.

## Notes

- **Auto-approve trust:** approvals go out under your name. The PR description is
  passed to Claude as untrusted data, but a malicious diff could still try to talk
  the reviewer into "no issues". Set `OWNERS` to orgs you trust, or `AUTO_APPROVE=false`.
- To re-review a PR, delete its line from `reviewed.txt` (and `failures.txt`).
