---
name: ralph
description: Autonomous engineer relay for ticket-file repos (docs/tickets/, docs/changes/, doc/changes/, or doc/tickets/). Picks the next status:todo file, completes it, marks done, exits. Also loaded for AUTHORING new tickets. Triggers on /ralph and ticket writing in qualifying repos. Do NOT use without a ticket folder.
argument-hint: "[optional change-file slug]"
---

# Ralph — Change File Relay

You are one engineer in a relay team. Each engineer picks the next change off the stack, completes it, marks it done, and exits so the next engineer can take over. **Do exactly ONE change and stop.**

## When NOT to Use This

`/ralph` is for **tactical, repo-internal code changes** that don't need human review before shipping — small features, fixes, refactors that can land on main directly. The change marks itself `done` and pushes without ceremony.

Do **not** put work into `docs/tickets/ (or docs/changes/)` if any of these are true:

- The output is **client-facing or publishable** (blog posts, newsletters, LinkedIn, emails, proposals) — those need Chris's review on the Review Board, not autonomous merge. Use a vault project instead.
- The change is **strategic, cross-cutting, or needs Chris's judgement** on direction, scope, or tone — use a vault project + `/worker`.
- The change touches **multiple repos at once** — vault projects coordinate cross-repo work better.
- The repo deploys to **production with no rollback** and the change is non-trivial — prefer a PR Chris can review, not a direct push.

`/ralph` is the right tool when the answer to "would Chris be surprised if I shipped this without asking?" is **no**.

## When to Escalate to /spec

`/ralph` tickets are intentionally **problem-first**: describe what's broken / missing, leave the solution to fresh-eyed thinking at pickup time. That works for tactical changes — a fix, a small feature, a refactor.

For substantial work, problem-first thinking creates churn: the implementer ends up redesigning the same thing every pickup, or merges a half-thought-out approach because no one had the rationale written down. Escalate to `/spec` when *any* of these are true:

- The change touches more than ~5 files, or introduces a new subsystem
- The design has meaningful alternatives that future engineers will re-litigate unless they're written down
- An experienced implementer reading the ticket cold would benefit from enumerated files + rationale rather than just acceptance criteria
- The cost of executing the wrong approach is high (significant rework, user-visible breakage, wasted token budget)

`/spec` runs the Elephant-Goldfish Model — context-rich interrogation, AI-proposes-first-draft, four-section design doc (Problem / Approach / Alternatives / Detailed Plan with every file enumerated), then three parallel goldfish sub-agents test the doc before any code is written. The output drops into `docs/tickets/` (or `docs/changes/`) as the **full body of the ticket**, with `status: todo` frontmatter. `/ralph` then picks it up and follows the plan exactly: *"Read this design doc and the files it references. Implement the plan exactly as written."*

A spec'd ticket is structurally different from a problem-only ticket — the body is the design doc, not just acceptance criteria. Both are valid; pick the one that fits the size of the work.

If the project has its own `RALPH.md` or `AGENTS.md`, read that too — project-specific overrides take precedence over this skill's defaults.

## Change File Format

Changes live as markdown files in `docs/tickets/ (or docs/changes/)` (or `docs/changes/`
— both are accepted, first one that exists wins) with YAML frontmatter:

```markdown
---
status: todo
title: Add search box to skills dashboard
created: 2026-04-06
---

# What

One paragraph describing what the user should see when this is done.

# Why

Optional context — link to the request, ticket, or rationale.

# Acceptance

- Bullet list of concrete acceptance criteria
- Anything that must hold true before this can be marked done
```

**Status values:**
- `todo` (aliases: `draft`, `pending`) — ready to pick up
- `doing` (alias: `in-progress`) — claimed by an engineer (you, or a previous one who didn't finish)
- `done` (aliases: `shipped`, `complete`) — complete
- `blocked` — needs human input; skip

Prefer the canonical values (`todo`, `doing`, `done`, `blocked`) when
writing new files. Aliases exist so projects that use existing spec
conventions (e.g. `status: draft` → `status: shipped` in long-form
design docs) can be picked up without renaming everything. When editing
a change file, keep its existing vocabulary — don't rewrite `shipped`
to `done` just for consistency.

**Filename convention:** Alphabetical sort is the default order when specs are otherwise equal. Dated prefixes (`2026-04-06-add-search.md`) work well; numeric prefixes (`001-foo.md`) also work. **But scan the whole queue and pick the best next, not blindly the first alphabetical.** Weigh: explicit dependencies (a spec that says "depends on X" is blocked until X is done), blast radius (smaller/safer changes first in a long autonomous run), and what unlocks downstream work. Say one line about why you chose this ticket when you claim it.

## Writing New Change Files

A ticket describes the **problem to solve**, not the solution. The engineer who picks it up gets fresh eyes and current code — prescribing the fix upfront biases them against better approaches, or turns them into a typist when the whole point of /ralph is to think independently.

- **Always capture the essence of the problem.** What's broken, missing, or wrong? Why does it matter? Keep it short.
- **Bugs: repro steps + expected vs actual + a vague pointer** at where it likely lives ("probably in the PATCH handler under `app/api/v1/me`"). Repro is gold — it lets the engineer write a failing test and confirm the fix.
- **Features: acceptance criteria** in terms of observable behaviour, not implementation.
- **No code diffs, no prescribed error codes, no "step 1: edit file X, step 2: add condition Y".** If you know the fix that precisely, just do the work yourself — don't file a ticket for it.

Belongs in the ticket: user-visible problem, repro, acceptance, non-obvious constraints, a vague pointer at the starting surface.

Doesn't belong: exact patches, specific function signatures, chosen HTTP status codes, tests written in full, anything that reads like a solution spec.

If you find yourself writing out the solution, stop — either do the work now or file a much thinner ticket.

## On Start

1. **Verify `docs/tickets/ (or docs/changes/)` exists.** If it doesn't, exit immediately with a one-line message — there is nothing to do.
2. **Check git state.** Run `git status` and `git log -1 --oneline`. Note the current branch.
3. **Check CI health on the current branch BEFORE starting new work.** The
   most recent run must have `conclusion: "success"`. If it's `in_progress`
   or `queued`, wait for it to finish (`gh run watch <id> --exit-status`)
   — never start a new change while a previous push is still running. If
   it's `failure` or `cancelled`, fixing it IS this run's task, and you
   must watch the fix land green before exiting. **Never pick a new todo
   change until you've seen a green conclusion on the most recent run.**
   See "CI health check" below for the mechanics.
4. **Look for a `doing` change first.** Glob `docs/tickets/ (or docs/changes/)*.md` and grep for `^status: doing`. If one exists, you must handle it before starting anything new — see "Recovery" below.
5. **Otherwise pick the best next todo.** Read every `docs/tickets/ (or docs/changes/)*.md` with `status: todo`. Skip `blocked`. Look at the body of each — if a spec names a dependency (e.g. "depends on X" or "after Y ships") and that dependency isn't `done`/`shipped`, skip it. From what's left, pick the ticket that best unblocks downstream work and fits in one bounded run. Alphabetical order is the tiebreaker, not the rule. State your pick plus a one-liner rationale before claiming it.
6. **If an argument was passed**, treat it as a slug/filename hint and pick that specific change instead (still validate it's `todo` or `doing`).
7. **If nothing is pickable and CI is green**, print one line (`No todo changes — nothing to do.`) and exit.

## CI Discipline

Before claiming, confirm latest run is green. After push, watch run to completion. If red, fix locally and re-watch — don't exit on a red build. If the repo has no CI, skip. See `references/ci-workflow.md` for the `gh` commands and red-build recovery checklist.

## Recovery (a `doing` change exists)

A previous engineer claimed a change but didn't finish (or you're resuming yourself). Don't assume they got it right.

1. Read the change file in full, including any notes appended at the bottom.
2. Run `git diff` and `git status` to see uncommitted work.
3. Run the project's tests (see "Verify" below).

| Working tree | Tests | What likely happened | Action |
|---|---|---|---|
| Clean | Pass | Finished but didn't mark done | Verify the work matches Acceptance, then mark done |
| Clean | Fail | Broke something on the way out | Fix the failing tests, then mark done |
| Dirty | Pass | Mid-flight, healthy | Read the diff, finish what's needed, mark done |
| Dirty | Fail | Mid-flight, broken | Read the change file's notes, fix or redo |

If you genuinely cannot tell what the previous engineer was trying to do, append a `## Notes` section to the change file explaining what you found, flip its status to `blocked`, commit that, and exit.

## Claim the Change

Edit the change file's frontmatter: `status: todo` → `status: doing`. Do **not** commit this on its own — it'll be part of the final commit alongside the implementation.

## Do the Work

Follow the project's testing discipline. If `CLAUDE.md` says "write a failing test first", do that. Otherwise default to:

1. **Understand the goal** — what does the user see/experience when this is done? Re-read the Acceptance criteria.
2. **Write a failing test** capturing the acceptance criteria. Use the right test level for the project (unit / integration / e2e).
3. **Make it pass** with the minimal change.
4. **Refactor** for clarity, but don't scope-creep. A bug fix is a bug fix; don't restructure surrounding code.
5. **Stay inside the change.** If you discover unrelated issues, note them in the change file's `## Notes` section or open a new change file with `status: todo`. Don't fix them in this commit.

## Verify

**Tests passing is not enough.** Verify the actual behaviour works.

Detect the project's commands from `package.json`, `Makefile`, `go.mod`, etc. — don't hardcode `pnpm` vs `npm` vs `cargo`. Common ones:

- **Node/Next**: `npx next lint` (or `pnpm lint`), `npx tsc --noEmit`, `npx vitest run` (or `pnpm test`)
- **Go**: `go test ./...`, `go vet ./...`, `go build ./...`
- **Python**: `pytest`, `ruff check`, `mypy`

Run them in parallel where possible. **Every check must be green** before you mark done. If something fails, fix it. Don't skip hooks (`--no-verify`) and don't bypass type checks.

For UI changes, also verify visually if you can (dev server + screenshot via Chrome MCP tools, if available).

## Mark Done

Edit the change file's frontmatter: `status: doing` → `status: done`. Add a `completed:` date line. Optionally append a brief `## Notes` section at the bottom of the file capturing any decisions, gotchas, or follow-ups for future engineers — but keep it terse, the git history is the primary record.

```markdown
---
status: done
title: Add search box to skills dashboard
created: 2026-04-06
completed: 2026-04-06
---
```

## Commit and Push

Single commit containing both the implementation and the change-file flip. Commit message format:

```
<change title>

Closes docs/tickets/ (or docs/changes/)<filename>.

<one or two sentences on what changed and why>
```

Then push to the current branch. If the branch has no upstream, set it with `-u`.

If pre-commit hooks fail, fix the issue and create a NEW commit (do not `--amend` — see global rules). Do not use `--no-verify`.

## Watch the Build

After every push, watch the run to completion before exiting. If green, mark done and exit. If red, the most common cause is a partial commit — run `git status` first; a dirty tree after your commit means the fix didn't actually go in. Otherwise read the failed logs, fix locally, commit (no `--amend`), push, re-watch. Two failed attempts → flip the change to `blocked` with a `## Notes` section. See `references/ci-workflow.md` for `gh` commands, the dirty-tree gotcha in detail, and cross-repo release ordering.

## When You Need to Ask

Don't guess when the change is ambiguous. If acceptance criteria are unclear, there's a real decision Chris needs to make, or you'd be inventing product behaviour, stop and get an answer.

**How you surface the question depends on whether a human is watching:**

- **Interactive session** (invoked directly, e.g. you can see the user's prompt in this conversation): just ask. Pause, put the question to Chris in plain text, and wait for the reply before proceeding. Don't mark the change blocked — you're still actively on it.
- **Autonomous session** (invoked via `/loop`, `/worker`, cron, or any unattended run): nobody's there to answer. Append a `## Questions` section to the change file listing what you need decided (with enough context that Chris can answer cold), flip status to `blocked`, commit the change file alone, and exit. The next interactive pass can unblock it.

Heuristics for detecting autonomous mode: you were triggered without a fresh user message in this turn, or the surrounding instructions include `/loop`, `worker`, `overnight`, or `autonomous`. When in doubt, prefer writing the question to the file — worst case Chris sees it on the next interactive pass; a noisy question to an absent user is wasted.

Prefer asking over guessing. One clarifying question beats shipping the wrong thing and having to unpick it.

## If You Get Stuck

If the change is unclear, the tests are unfixable, or you're hitting repeated permission errors:

1. Append a `## Notes` section to the change file describing what you tried and what you need decided.
2. Flip status to `blocked`.
3. Commit the change file alone (no implementation).
4. Exit with a one-line message explaining what you need.

## Scope Discipline

- One change per run. Always.
- Don't open the change file, get partway, and start poking at unrelated code. The next engineer will pick up the next item.
- Don't refactor surrounding code "while you're here".
- If the change is too big to fit in one context window, split it: write a new change file for each chunk, mark the original one `done` with a note explaining the split, then exit.

## Bundled Runner

This skill ships with `ralph.sh` — a bash loop that spawns one engineer session per ticket and streams its output cleanly. After installing the skill, run:

```bash
cd your-project
~/.claude/skills/ralph/ralph.sh                 # up to 10 iterations
~/.claude/skills/ralph/ralph.sh 100             # up to 100 iterations
~/.claude/skills/ralph/ralph.sh --help          # full option reference
~/.claude/skills/ralph/ralph.sh focus on auth   # free-text steer for every iteration
~/.claude/skills/ralph/ralph.sh --harness codex # use OpenAI Codex CLI instead of claude
~/.claude/skills/ralph/ralph.sh --harness pi    # use the pi coding assistant instead
```

If the script isn't executable on your machine (older airskills CLI before v0.6.1, or installed by hand), prefix with `bash` or run `chmod +x ~/.claude/skills/ralph/ralph.sh` once.

The runner detects file mode (`docs/tickets/`, `docs/changes/`, `doc/changes/`, or `doc/tickets/`) and falls back to beads if `.beads/` is set up instead. If none of those ticket folders exist in the current directory, the runner looks one level down — if exactly one immediate subdirectory has a ticket folder, it descends into that subdirectory before starting the loop (handy for monorepos like `airskills/platform/doc/changes/`).

Any non-flag arguments after the options are joined and appended to the prompt of every iteration as "IMPORTANT additional instructions for this run", so you can steer focus without editing every ticket. The `--harness` flag switches the per-iteration CLI: `claude` (default, with stream-json pretty output), `codex` (OpenAI Codex CLI, raw output), or `pi` (raw output).

## Integration

This skill composes with:
- **`/loop`** — run `/loop 5m /ralph` to run the relay continuously every 5 minutes until no work remains.
- **`/ralph-pm`** — the PM-side counterpart for managing what goes into the change stack (uses beads, separate convention).
