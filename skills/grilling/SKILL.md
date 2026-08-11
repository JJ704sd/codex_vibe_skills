---
name: grilling
description: Stress-test a plan, design, or consequential decision with the current user through dependency-aware interview rounds. Use when important choices or assumptions remain unresolved before implementation; do not use for facts Codex can discover, routine clarification, or knowledge held only by another person.
---

# Grilling

Turn uncertainty into an explicit decision graph. Ask only questions that require the current user's judgment.

## Build the decision graph

1. Inspect the conversation, repository, existing specs, and available evidence before asking questions.
2. Separate discoverable facts from genuine decisions. Investigate facts directly; never offload repository exploration to the user.
3. Record each unresolved decision and the decisions that depend on it.
4. Treat decisions whose prerequisites are settled as the current frontier.

## Work in rounds

Ask one compact numbered round from the frontier. If the frontier is large, ask the highest-leverage three to five questions and queue the rest.

For each question include:

```text
Q1 — <short title>: <decision and materially different choices>
Recommended: <choice and concise reason>
Impact: <what this answer unlocks or changes>
```

Wait for the answers before asking dependent questions. After every round, update the graph: an answer may resolve, add, remove, or reorder later decisions. Challenge contradictions and hidden assumptions directly but neutrally.

Do not ask for a choice when evidence already determines the answer. State the evidence and proceed.

## Finish deliberately

Stop when the frontier is empty or the remaining uncertainty is explicitly accepted. Summarize confirmed decisions, accepted assumptions, unresolved risks, and the next recommended action, then ask the user to confirm the shared understanding.

Do not begin implementation as an implicit continuation. Write confirmed outcomes to a repository document only when the user requests durable documentation and identifies or approves the destination.
