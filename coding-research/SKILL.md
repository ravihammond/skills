---
name: coding-research
description: Research implementation approaches for coding work; compare options and recommend the best option.
disable-model-invocation: true
---

# Coding Research

Run an implementation-research. Produce the research report directly in chat. Do not create, edit, delete, stage, commit, or open files for writing.

## Boundary

Stay in research mode:

- Inspect the repo and external sources.
- Compare implementation approaches.
- Recommend one approach.
- Explain how it would be implemented at a concrete planning level.

Do not write code, tests, patches, commits, PRs, issue comments, or files. If the user asks for implementation while invoking this skill, deliver the research report and say which coding skill or normal coding pass should follow.

## Autonomy

Proceed without interrupting the user. Make reasonable assumptions and label them. Ask a blocking question only when the goal is impossible to research safely because essential context is missing or contradictory. Put non-blocking open questions at the end of the report.

## Local First

If the question relates to the current checkout, inspect the codebase before recommending anything:

- Read applicable instructions from the repository.
- Identify stack and dependency signals from package manifests, lockfiles, config, build files, imports, and framework conventions.
- Search for existing implementations, interfaces, tests, naming patterns, error handling, observability, data access, migrations, and deployment constraints near the affected area.
- Treat existing code as context, not a cage. If the best professional answer requires refactoring, replacing an abstraction, or changing architecture, recommend that clearly and explain the migration risk.
- Understand exactly how the code is currently implementing it.

Local inspection is complete when the report can name the relevant stack, architecture shape, existing patterns, tests, dependencies, and constraints that materially affect the decision.

## Research Loop

Research as deeply as needed to compare the strongest viable approaches confidently. Use any source that helps reveal professional practice, but label evidence quality.

Prefer high-signal evidence:

- Official docs, specs, RFCs, standards, release notes.
- Framework/library source code and mature OSS implementations.
- Maintainer issues, PRs, design discussions, migration guides.
- Credible engineering blogs, postmortems, benchmarks, conference talks.
- Forum discussions, examples, and weaker articles as leads or background only.

Go deeper when the decision is architectural, high-impact, security-sensitive, performance-sensitive, hard to reverse, unfamiliar, or when sources conflict.

## Decision Criteria

Operationalize "top-tier FANG-level engineering" as concrete criteria:

- Correctness and edge-case behavior.
- Simplicity at the interface and implementation level.
- Maintainability, locality, and fit with existing architecture.
- Scalability and performance under expected load.
- Security, privacy, and data-integrity risks.
- Testability through public seams.
- Observability, debugging, and operational failure modes.
- Migration path, rollback plan, and compatibility.
- Dependency maturity, ecosystem fit, and maintenance risk.

## Approach Landscape

Always output multiple top-tier FANG-level approaches.

For each approach, include:

- What it is
- How it would work in this codebase.
- Pros and cons
- When this approach would be the right choice.

## Report Format

Write the final answer in chat using this skeleton:

1. **Problem Restatement** - the implementation goal and any assumptions.
2. **Codebase Context** - relevant local architecture, stack, dependencies, tests, constraints, and tensions.
3. **Decision Criteria** - the criteria that matter most for this problem.
4. **Approaches** - the top-tier engineering approach landscape with evidence, examples, pros, cons, tradeoffs, risks, and fit.
5. **Recommendation** - the chosen approach, why it wins for this codebase, and what evidence or judgment supports it.
6. **Implementation Plan** - High level steps that describe how this plan would be implemented in my repo. Do not include code patches.
7. **Open Questions** - only questions that genuinely affect the implementation decision.

Keep the report direct and comparative.
