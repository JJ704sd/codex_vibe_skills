# Code Smell Baseline

Use this fallback only for changed hunks. Repository standards override it, and every smell is a judgment call requiring a concrete cost.

- **Mysterious name**: a name conceals purpose or domain meaning.
- **Duplicated logic**: the same decision or algorithm appears in multiple changed locations.
- **Feature envy**: behavior reaches into another module's data more than its own.
- **Data clump**: the same fields or parameters repeatedly travel together without a focused type.
- **Primitive obsession**: a primitive represents a domain concept with rules or invariants.
- **Repeated dispatch**: the same switch or conditional dispatch recurs for one concept.
- **Shotgun surgery**: one logical change requires scattered edits across many modules.
- **Divergent change**: one module changes for several unrelated reasons.
- **Speculative generality**: hooks, options, or abstractions serve no current requirement.
- **Message chain**: callers navigate deep object structure instead of asking for a meaningful operation.
- **Middle man**: a module delegates without adding behavior, policy, or isolation.
- **Leaky boundary**: callers must understand transport, storage, vendor, or internal sequencing details.

Do not report a smell merely because its shape exists. Explain the correctness, maintenance, coupling, or change-locality cost introduced by this diff, and suppress it when project guidance intentionally endorses the design.
