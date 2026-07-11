---
name: review-issue
description: Review and repair one GitHub issue implementation in the current checkout.
license: MIT
---

# Review Issue

Review and repair exactly one GitHub issue implementation in the current checkout. Stay local: do not create worktrees, Docker containers, branches, pull requests, labels, issue comments, pushes, or issue closes.

## Intake

1. Require exactly one GitHub issue number from the user. If it is missing or ambiguous, ask for the issue number and stop.
2. Read repository instructions before editing: root `AGENTS.md`, nested `AGENTS.md` files that apply to touched paths, and any domain or issue-tracker docs those files name.
3. Fetch the issue packet with `gh issue view <number> --comments`.
4. Search the issue body and comments for parent PRD references, blocker issues, follow-on issues, and related implementation issues. Fetch every linked issue that affects expected behavior with `gh issue view <number> --comments`.
5. Treat the issue packet, linked PRD/spec, existing tests, and repo instructions as the source of truth. Do not pause for plan approval unless they contradict each other or required context is missing.
6. Work on the current branch only. Do not create or switch branches.
7. Infer the base branch from a user-provided base, the branch upstream, or the repository default branch. Confirm it resolves before reviewing.
8. Run `git status --short`, `git log --oneline <base>..HEAD`, and `git diff <base>...HEAD`. If the implementation diff is empty, stop with `BLOCKED: no implementation diff to review`.

Intake is complete when the issue packet, linked context, repo instructions, base branch, working-tree state, commit list, and implementation diff are understood.

## Review

Do not invoke the report-only `review` skill. Inline the two-axis review here before fixing anything.

1. Read the relevant source, tests, standards, and local guidance before judging the diff. Include `AGENTS.md`, `CONTEXT.md` if present, relevant ADRs, `docs/standards/python-docstrings.md` if Python files may change, and relevant test/style/config files.
2. Read the diff carefully, file by file and hunk by hunk.
3. Verify the implementation against the issue and linked PRD/spec.
4. Stress-test edge cases and regressions.
5. Record findings under these headings, keeping the axes separate:

   ```text
   ## Standards
   - <file:line> <finding>. Standard: <standard or local convention>.

   ## Spec
   - <file:line> <finding>. Source: <issue or PRD requirement>.
   ```

Standards findings are documented-standard violations, local convention breaks, brittle tests, or maintainability risks introduced by the diff. Spec findings are missing requirements, partial implementation, wrong behavior, scope creep, edge-case failures, or regressions against the issue or linked PRD/spec. Within each axis, order findings by severity. If there are no valid findings, say so clearly and name any residual test gaps or risk.

Review is complete only when every touched behavior and changed file has been checked against both axes, and each valid finding is recorded or explicitly dismissed as not valid.

## Fix

Fix every valid finding, one finding at a time.

1. For each behavioral or spec finding, first add or update a focused failing behavior test through a public interface. Do not create artificial seams just to test internals.
2. Implement the smallest correct fix.
3. Run the targeted test and get it green before moving to the next finding.
4. Refactor only while tests are green.
5. For standards-only findings that do not need tests, make the smallest cleanup and run the nearest relevant verification.

Preserve unrelated local changes. Stage and commit only files relevant to this issue and its review fixes. Do not leave commented-out code or TODO comments in committed code.

Fixing is complete when every valid finding is fixed, tested or justified as standards-only, and no unrelated changes are staged.

## Verify

Follow the repo's `AGENTS.md` test workflow.

- Prefer the smallest meaningful pytest scope for the touched code, then broaden only when the changed surface justifies it.
- If Python code changed, run the repo-approved syntax/type check; when `src` and `tests` exist and repo instructions do not specify otherwise, use `uv run python -m compileall -q src tests`.
- Run any additional focused checks the findings specifically require.
- Do not run full training jobs, W&B-backed commands, Docker validation, broad suites, or full suites unless repo instructions, the changed surface, or the user explicitly requires it.

Verification is complete when targeted tests and required syntax/type checks pass, or failures are diagnosed as blockers.

## Commit

If no valid findings needed fixing, make no commit. Output the review result, commands run, and residual risk.

If fixes were made and verification passed, review `git diff`, `git status --short`, and staged files before committing. Commit only relevant changes. Do not use a `RALPH:` prefix. Prefer this message shape:

```text
fix: address review findings for issue #<number>

Issue: #<number> <title>
PRD: #<number> <title>        # omit if none
Findings fixed:
- <finding summary>
Verification:
- <command run>
Risk:
- <residual risk or "None known">
```

Committing is complete when a local follow-up commit exists for the fixes, or no commit was made because the review found nothing valid to fix.

## Blocked Path

If required context is missing, the base cannot be resolved, tests fail for reasons you cannot fix, dependencies are unavailable, or the issue cannot be reviewed or repaired safely:

1. Do not post to GitHub.
2. Do not commit partial work unless it is a useful local checkpoint and clearly described as incomplete.
3. Output `BLOCKED`, the blocker, evidence gathered, commands run, and a draft issue comment the user can post.
