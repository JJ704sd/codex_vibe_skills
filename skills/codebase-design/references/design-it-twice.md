# Design It Twice

Use this process when the selected module's interface is consequential enough to justify alternatives.

## Frame the contract

Record caller needs, invariants, ordering, errors, performance expectations, dependency categories, and what must remain hidden. Use sketches only to ground constraints, not to anchor the preferred answer.

## Generate independent alternatives

Produce at least three materially different designs in separate reasoning passes. Deliberately reset assumptions between passes. Vary the primary objective:

1. minimize interface area and maximize leverage;
2. support justified variation without speculative hooks;
3. make the common caller path trivial;
4. when relevant, isolate a remote or external dependency.

For each design provide:

- the full caller-visible contract;
- a representative caller example;
- responsibilities hidden behind the boundary;
- dependency and adapter strategy;
- migration cost, failure modes, and trade-offs.

## Compare and choose

Compare interface depth, locality, seam placement, caller effort, observability, test surface, and change cost. Recommend one option or a justified hybrid. Do not leave the user with an unranked menu.
