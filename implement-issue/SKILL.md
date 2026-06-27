---
name: implement-issue
description: Implement one GitHub issue in the current checkout using the issue, comments, linked PRD, existing branch work, TDD, repo validation rules, and a local commit. User-invoked only; require an explicit issue number.
disable-model-invocation: true
---

# Implement Issue

Implement exactly one GitHub issue in the current checkout. Stay local: do not create worktrees, Docker containers, branches, pull requests, labels, issue comments, pushes, or issue closes.

## Intake

1. Require exactly one GitHub issue number from the user. If it is missing or ambiguous, ask for the issue number and stop.
2. Read repository instructions before editing: root `AGENTS.md`, nested `AGENTS.md` files that apply to touched paths, and any domain or issue-tracker docs those files name.
3. Fetch the issue packet with `gh issue view <number> --comments`. Also fetch labels or structured fields if needed to understand status.
4. Search the issue body and comments for parent PRD references. Fetch every referenced parent PRD issue with `gh issue view <number> --comments`.
5. Work on the current branch only. Do not create or switch branches.
6. Infer the base branch from a user-provided base, the branch upstream, or the repository default branch.
7. Before writing, run `git status --short`, `git log --oneline <base>..HEAD`, and inspect any existing diff from `<base>...HEAD`. Continue partial work already present; do not restart or redo completed work.

Intake is complete when the issue packet, parent PRD context, repo instructions, base branch, working-tree state, and existing branch changes are understood.

## Scope

- Treat the GitHub issue, linked PRD, existing tests, and repo instructions as the approved behavior list. Do not pause for plan approval unless the issue packet is contradictory or missing required context.
- Work on one issue only. If another issue appears necessary, report it as follow-up instead of implementing it.
- Preserve unrelated local changes. Stage and commit only files relevant to the issue.
- Do not leave commented-out code or TODO comments in committed code.
- Do not mutate GitHub. On blockers, print a concise blocker report and a draft issue comment instead of posting it.

## Workflow

1. Explore.
   Read the issue packet, parent PRD, relevant source, and relevant tests before editing.
   Completion: the expected behavior, affected public interfaces, and nearest tests are identified.

2. Plan.
   Choose the smallest implementation that satisfies the issue. Name the first behavior test to add or change.
   Completion: there is a narrow edit plan tied to issue or PRD requirements.

3. Execute with a red-green loop.
   Use `$tdd` when available, but override its interactive approval gates: the issue packet is the approval source. Write one failing behavior test through a public interface, implement enough to pass it, then repeat. Do not invent new seams only to make testing easier.
   Completion: every required behavior from the issue packet is represented by passing behavior tests or explicitly justified as already covered.

4. Verify.
   Follow the repo's `AGENTS.md` test workflow. Prefer the smallest meaningful test scope first, then broaden only when the changed surface justifies it. For Python repos, run the repo-approved syntax or type check; when `src` and `tests` exist and repo instructions do not specify otherwise, use `uv run python -m compileall -q src tests`. Do not run full training, W&B-backed commands, Docker validation, or broad/full suites unless repo instructions, the changed surface, or the user explicitly requires it.
   Completion: targeted tests and required syntax/type checks pass, or failures are diagnosed as blockers.

5. Commit locally.
   Review `git diff`, `git status --short`, and staged files before committing. Commit only relevant changes. Do not use a `RALPH:` prefix. Use this commit shape:

   ```text
   Issue #<number>: <imperative summary>

   Issue: #<number> <title>
   PRD: #<number> <title>        # omit if none
   Decisions:
   - <key decision>
   Files:
   - <important file or area>
   Verification:
   - <command run>
   Risk:
   - <residual risk or "None known">
   ```

   Completion: a local commit exists on the current branch and contains only this issue's relevant changes.

6. Stop.
   After a successful commit, output the commit hash and commands run. Do not start another issue.

## Blocked Path

If required context is missing, tests fail for reasons you cannot fix, dependencies are unavailable, or the issue cannot be completed safely:

1. Do not commit partial work unless it is a useful local checkpoint and clearly described as incomplete.
2. Do not post to GitHub.
3. Output `BLOCKED`, the blocker, evidence gathered, commands run, and a draft issue comment the user can post.
