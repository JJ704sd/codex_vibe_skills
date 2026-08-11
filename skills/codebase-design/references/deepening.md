# Deepening a Module

Use this reference when consolidating shallow modules or choosing an I/O, process, or network seam.

## Classify the dependency

1. **In-process**: pure computation or memory state. Keep it inside the module and test through the public interface.
2. **Local-substitutable**: filesystem, database, queue, or clock with a realistic local implementation. Exercise the module with that implementation when practical.
3. **Remote but owned**: an internal service across a network. Define a narrow port owned by the caller's domain; use transport and local test adapters.
4. **External**: a third-party service. Keep vendor details behind an adapter and return domain-shaped results.

## Keep the seam honest

- Introduce a port only when variation is real and valuable.
- Do not expose an internal seam merely because tests want access.
- Keep transport, serialization, retry, and vendor details behind the adapter.
- Put timeouts, ordering, idempotency, partial failure, and retry semantics in the public contract when callers must handle them.
- Prefer operation-specific ports to generic clients that leak the dependency's entire API.

## Migrate safely

1. Describe the new external contract before moving implementation.
2. Add behavior coverage through that contract.
3. Move logic behind the boundary in small reversible steps.
4. Redirect callers incrementally when possible.
5. Remove shallow wrappers and obsolete internal tests only after equivalent behavior is covered.
6. Re-run integration checks crossing the changed seam.

Use `$tdd` when behavior is known and the migration should proceed test-first.
