# Dependency Upgrade Evidence

## Pin evidence and scope

1. Record the resolved current version, justified target, direct or transitive status, and coupled packages.
2. Prefer official migration guides and compatibility matrices for the exact interval, then release notes, registry metadata, security advisories, and upstream source when official guidance is ambiguous.
3. Search repository imports and used APIs before applying generic migrations.
4. Find all manifests, lockfiles, workspace catalogs, vendored modules, containers, CI images, tool-version files, and generated clients.

Choose the smallest supported target satisfying the reason unless broader modernization is explicitly requested.

## Upgrade safely

- Establish the baseline with a frozen, locked, or no-update resolve; verify manifests and lockfiles remain unchanged.
- Run relevant build, type, lint, test, packaging, startup, smoke, and supported-runtime checks; record pre-existing failures.
- Change one dependency family or tightly coupled set at a time with the canonical package manager.
- Apply only migrations required by the selected interval and keep cleanup separate.
- Inspect lockfile changes for unexpected packages, sources, checksums, platforms, or major versions.
- Do not hand-edit generated lockfiles or suppress resolver, peer, compiler, or security warnings without a safety explanation.

For security upgrades, prove the vulnerable resolved version is absent; a manifest constraint alone is insufficient. Treat unit tests as insufficient when the dependency participates only at build, startup, serialization, database, browser, native, or remote boundaries.
