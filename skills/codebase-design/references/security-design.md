# Security-Sensitive Design

Use this reference only when the selected design crosses a trust boundary or handles security-sensitive behavior.

## Bound the model

1. Name protected assets and goals: confidentiality, integrity, availability, authorization, tenant isolation, auditability, abuse resistance, or safe side effects.
2. Map the minimum data flow exposing actors, entry points, processes, stores, external systems, privileged operations, and trust-boundary crossings.
3. State attacker capabilities, exclusions, verified facts, and assumptions. Do not treat authentication or an internal network as trust by itself.

## Derive invariants

For each boundary crossing, trace plausible spoofing, tampering, authorization bypass, disclosure, exhaustion, replay, cross-tenant, and unintended-side-effect paths. Record prerequisites, affected assets, impact, and whether current controls prevent, detect, limit, or recover.

Turn each material path into the smallest design rule that breaks it, such as server-side object authorization, canonical parsing before validation, scoped credentials, bounded work, idempotency, non-secret logging, or an atomic transition.

Specify verification at the closest stable seam: a negative authorization matrix, parser corpus, property or fuzz test, concurrency test, configuration check, or approved operational control. Do not claim a control exists without code, configuration, or runtime evidence.

Rank residual risk with stated likelihood and impact assumptions. Keep unapproved threats as risks or design inputs; only owner-approved security requirements govern a later Spec review. Use `$diagnosing-bugs` when security behavior is already failing and its cause is unknown.
