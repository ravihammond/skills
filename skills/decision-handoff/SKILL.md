---
name: decision-handoff
description: Produce a decision handoff that preserves explicit user decisions and relevant inspectable context for a fresh agent.
license: MIT
disable-model-invocation: true
---

Produce a first-person decision handoff to be given to a fresh agent. Produce the handoff text directly in chat. Do not create, edit, delete, stage, commit, or open files for writing.

Use a decided-only record: capture explicit user decisions from the current session, plus the directly relevant inspectable context that was mentioned, used, or found in the session. If evidence is not enough to state a user decision, omit that claim rather than infer it.

Do not duplicate content already captured in other artifacts (PRDs, plans, ADRs, issues, commits, diffs). Reference them by path or URL instead.

Redact any sensitive information, such as API keys, passwords, or personally identifiable information.

If the user passed arguments, treat them as a description of what the next agent session will focus on and tailor the doc accordingly.

## Output Shape

Use this exact structure (don't add any more sections):

```text
<1-2 sentence first-person handoff abstract addressed to the fresh agent. Start by saying that I am handing over a decision record for a specific work area, tool, module, bug, or cleanup. Briefly state the current problem before, and briefly state the decisions made. Use phrasing like "Here is..." or "I'm giving you...".>

## Problems Addressed

## Context To Inspect

## Decisions

## Summary
```

Write as the user speaking to the fresh agent. Use first person (`I`, `my`) for decisions, preferences, and motivation; do not refer to the user in third person in the generated handoff.

Write a neutral decision record, not an implementation prompt. Do not include user stories, acceptance criteria, implementation steps, testing plans, task breakdowns, or PRD framing.

## Problems Addressed

Describe the problems being addressed in enough detail for a fresh agent to understand the motivation. Include:

- the current behavior or situation discussed in the session;
- concise fenced code snippets showing the problematic current code when the problem is code-level and snippets were surfaced in the session;
- why that behavior or situation is undesirable;
- the product, engineering, testing, review, or maintenance pressure behind the decisions.

Keep this section factual and detailed enough that the reader sees the concrete issue, not just a summary. Do not recap the debate, rejected options, or model recommendations.

## Context To Inspect

List only sources that were mentioned, used, or found in the current session and are directly relevant to the decisions or their surrounding motivation.

Valid sources include files, line references, diffs, command outputs, test failures, logs, GitHub issues, PRs, comments, docs, blog posts, and URLs. Do not inspect new files, run new searches, or add new sources just because they might be useful.

For every source, write one sentence explaining its relevance before naming the source:

```text
<Sentence explaining how this file reference contains current behavior, decided target shape, or code-level context.>:
`<path/to/file.ext>`

<Sentence explaining how this issue, PR, or comment records the user-visible problem or decision context.>:
`GitHub issue #<issue-number>`

<Sentence explaining how this external website, documentation page, or blog post constrains or motivates the decision.>:
`<https://example.com/relevant-page>`
```

Omit sources that are merely adjacent, historical, or part of the conversation but not directly related to the decisions or useful to the fresh session.

## Decisions

Include every explicit user decision that affects what should change or how the change should be understood.

For each decision, use this format:

```text
### <short decision name>

Current state:
<what the codebase, relevant code snippets, test, issue, or observed behavior currently does, when known and relevant>

Motivation:
<why the current state matters or why the decision was made>

Decision:
<the decided target state, written as a neutral fact>

Decided shape:
<fenced code snippet, command, config fragment, interface, or concrete example when the decision includes code-level detail>
```

Decision rules:

- Treat user corrections, selections, and approvals as the decision source.
- Phrase decisions from the user's perspective, for example `I decided...` or `I want...`, not `The user decided...` or `The user wants...`.
- Do not present model suggestions as decisions unless the user explicitly accepted them.
- Do not mention rejected alternatives, pros/cons from the debate, or options that are not current code behavior.
- Use negative phrasing only for explicit negative decisions or when describing current behavior being replaced. Do not include rejected alternatives.
- Preserve concrete details: names, paths, commands, modes, data shapes, constraints, and boundary conditions.
- Include fenced code snippets for current and decided code shapes when those snippets or shapes were surfaced in the session. Do not replace available code-level decisions with prose summaries.
- Make each decision detailed enough for a fresh agent to understand the exact target state. Do not compress a code-level decision to a few vague lines when the session contains signatures, snippets, examples, commands, or constraints.
- If the session contains several decisions, separate them instead of merging them into a vague umbrella decision.

## Summary

End with a brief high-level summary of the decided direction. Keep it to one short paragraph.
