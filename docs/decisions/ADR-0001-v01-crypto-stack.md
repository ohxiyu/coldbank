# ADR-0001: One Bitcoin signing stack in v0.1

- Status: Accepted for implementation baseline
- Date: 2026-07-17

## Context

The initial direction considered both BDK and libwally. Shipping both would create two parsers/signers, duplicate binary integration, and a risk that review data and signing behavior are interpreted differently.

## Decision

Use the pinned `bdk-swift` release for descriptors, BIP39/BIP32 operations, PSBT parsing, and signing in v0.1. Use `URKit` only for BC-UR transport. Normalize library output into ColdSigner-owned domain types before policy evaluation or UI rendering.

Keep `libwally-core` as a contingency. Introduce it only through a new ADR if BDK cannot meet a documented P0 requirement or independent verification justifies the added audit surface.

## Consequences

- Smaller initial cryptographic and FFI surface.
- Dependency on BDK Swift API/release cadence.
- ColdSigner must test its own policy invariants rather than treating library parse success as approval.
- A future stack change requires golden-vector equivalence and interoperability reruns.
