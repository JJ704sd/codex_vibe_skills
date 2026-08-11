# Debugging Feedback Loops

Choose the earliest safe option that reproduces the exact symptom.

## Loop options

1. Focused failing test at a public seam.
2. HTTP script against a local or approved test server.
3. CLI invocation with fixture input and an explicit assertion.
4. Headless browser check over DOM, console, or network behavior.
5. Redacted request, event, trace, or payload replay.
6. Throwaway harness around the smallest affected path.
7. Property or fuzz loop for input-dependent failures.
8. Bisection harness between known versions or datasets.
9. Differential loop comparing versions, environments, or configurations.
10. Structured human loop when automation is impossible.

Never capture credentials or personal data in fixtures or transcripts. Obtain approval before adding production instrumentation.

## Tighten the signal

- Assert the exact wrong result, error, state transition, or timing.
- Cache or bypass unrelated setup without bypassing the suspected path.
- Freeze time, seed randomness, isolate filesystem state, and control network dependencies.
- Keep the runnable command and required fixtures together.
- For a human loop, state one action at a time and capture only the observation needed for the next hypothesis.

## Handle flakes

Measure reproduction rate over a stated sample count. Add controlled stress, repeat or parallelize the trigger when safe, and narrow timing windows until experiments can distinguish changes. A single pass does not prove a flaky defect fixed.

## If automation fails

Request only the smallest missing item: safe environment access, a redacted trace/log/core dump, or narrowly scoped instrumentation permission. Label conclusions from static analysis as unverified.
