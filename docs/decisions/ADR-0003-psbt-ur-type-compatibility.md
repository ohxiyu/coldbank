# ADR-0003: PSBT UR type compatibility

- Status: Accepted for v0.1 implementation
- Date: 2026-07-18

## Context

ColdSigner v0.1 names Sparrow as its primary coordinator and the product baseline requires `ur:crypto-psbt`. Blockchain Commons' current implementation matrix records Sparrow support for `crypto-psbt`, while its newer PSBT developer guide describes the registered `ur:psbt` byte-string form.

The two forms carry the same canonical CBOR byte string containing the raw PSBT. Rejecting either form on import would create an avoidable compatibility failure. Changing the default output now would diverge from the v0.1 PRD and the existing Sparrow target before fixture testing is complete.

References:

- <https://developer.blockchaincommons.com/ur/implementations/>
- <https://developer.blockchaincommons.com/ur/psbts/>

## Decision

- Accept both `ur:crypto-psbt` and `ur:psbt` on import.
- Emit `ur:crypto-psbt` by default in v0.1.
- Encode the raw PSBT as one canonical CBOR byte string for both type names.
- Reject all other UR types, non-canonical or trailing CBOR, bad PSBT magic, oversized payloads, fragment floods, and mixed-type sequences.
- Keep the type choice explicit in the transport API so a verified coordinator profile can request `ur:psbt` without changing parsing or signing policy.

## Consequences

The input surface is slightly broader, but both accepted paths converge on exactly the same bounded PSBT bytes before parsing. Release claims still require current-version, fixture-backed round trips; accepting a type is not itself a compatibility claim.
