# CI Workflow Mechanics

How `/ralph` interacts with GitHub Actions CI — the pre-claim health check and the post-push watch.

The principle: a push that hasn't been verified on CI is not "done". Local greens don't prove the change passes the CI environment (different Node version, missing env vars, stricter linting). Ralph is responsible for **landing green**, not just pushing.

## CI Health Check (before claiming any change)

Before picking up a new todo, confirm the current branch's CI is green.

```bash
# Resolve the remote and branch
REMOTE=$(git remote get-url origin | sed -E 's|.*[:/]([^/]+/[^/]+)\.git$|\1|; s|\.git$||')
BRANCH=$(git branch --show-current)

# Get the latest run for this branch. -R disambiguates when there are
# multiple remotes, --branch scopes to the current branch only.
gh run list --branch "$BRANCH" --limit 1 --json status,conclusion,databaseId,name
```

Outcomes:

- **`conclusion: "success"`** — CI is green. Proceed to pick the next change.
- **`status: "in_progress"` or `"queued"`** — the previous push is still running. **Wait for it.** Watch with `gh run watch <id> --exit-status` until it completes. Do NOT start a new change while a previous run is in flight — your work would land on top of an untested base and you have no way to tell which push broke things if CI flips red. On success, proceed. On failure, fix as below.
- **`conclusion: "failure"` or `"cancelled"`** — CI is red. Your job for this run is to fix it. Read the failed logs (`gh run view <id> --log-failed`), fix the underlying cause locally, run the same checks that failed, commit, push, and then **watch the new run to completion with `gh run watch <new-id> --exit-status`**. If the new run is green, exit (the next ralph instance picks up the next todo). If the new run is still red, repeat — fix, push, watch. **Never pick a new todo change while CI is red or a fix attempt is in flight.** Pushing a speculative fix and exiting without watching it land is not sufficient — the next ralph run must see a *green* conclusion on the most recent run before it is allowed to claim new work. If you've tried twice and still can't get it green, stop and set `status: blocked` on the relevant change with a note for Chris.
- **No runs at all** — nothing to watch; proceed.

If the repo has no CI configured (no `.github/workflows/`, no Cloudflare deploy config, etc.), skip the CI health check — local verification is the bar.

## Watch the Build (after every push)

Always watch the run triggered by your push and react to the result before exiting.

```bash
# Immediately after git push succeeds:
# Find the run your push triggered. `--branch` + `--limit 1` gets the
# latest for the current branch, which is almost always yours (racy
# only if another engineer pushes in the same second).
RUN_ID=$(gh run list --branch "$(git branch --show-current)" \
  --limit 1 --json databaseId --jq '.[0].databaseId')

# Block until the run finishes. --exit-status makes failed runs return
# non-zero so the CLI short-circuits properly.
gh run watch "$RUN_ID" --exit-status
```

Outcomes:

- **Green.** Print one-line success, mark the change done if not already, exit.
- **Red.**
  1. **First, run `git status`.** If the working tree is dirty, a previous session (or your own earlier edits) may have left the fix uncommitted. `git diff origin/main` shows exactly what isn't on the remote — that diff may BE what CI is missing. Do NOT start diagnosing a "new" failure before ruling this out. This is the single most common cause of "CI keeps failing even though I fixed it locally": the commit didn't include all the code that made local tests pass. If the diff looks like the fix, stage it, commit, push, re-watch.
  2. Pull the failed logs: `gh run view "$RUN_ID" --log-failed`.
  3. Understand the failure. Don't panic-revert.
  4. Fix it locally. Run the equivalent command yourself before trusting the fix (e.g. if CI's `npx next build` failed, run it locally).
  5. Commit the fix as a new commit (not --amend; global rule).
  6. **Before pushing, run `git status` again — working tree MUST be clean.** A dirty tree after the commit means the commit is partial; the rest will disappear from context when this session ends, and CI will be red for "no reason" next cycle. If you have intentional uncommitted work, stash it before pushing the fix and evaluate whether it should be in this commit.
  7. Push and repeat the watch. Ralph is responsible for landing green, not just pushing.
  8. If you can't fix it in this run, append a `## Notes` section to the change file with what went wrong + what you tried, flip its status to `blocked`, commit, push the block, and exit. Don't leave a red build unexplained.
- **Timeout / watch errors.** `gh run watch` can occasionally misbehave. Fall back to polling: `gh run view "$RUN_ID" --json status,conclusion` in a short loop. Do not use `sleep` loops without a bound — cap at ~20 minutes; if CI takes longer than that for a typical change, something else is wrong and Chris needs to see it.

## Cross-repo releases

When platform depends on a tagged CLI release: follow the specific order captured in the repo's CLAUDE.md (typically tag and release the CLI first, wait for its release workflow to publish, only then push the platform). Watch BOTH runs. Don't push the second repo until the first is green.
