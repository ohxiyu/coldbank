# External Bitcoin and security review scope

The review target is the exact release-candidate commit and both resolved dependency graphs. Reviewers should assume the coordinator and every optical byte are malicious, while the iOS kernel, platform cryptography, code signing, and physical device are trusted as defined in the threat model.

## Required review areas

1. **Key lifecycle:** entropy, BIP39 validation, BIP32/BIP84 derivation, Keychain access control, AES-GCM envelope/profile binding, data protection, backup exclusion, unlock lifetime, wipe behavior, and Swift zeroization limits.
2. **PSBT parser:** compact-size canonicality, duplicate/unknown/proprietary fields, transaction/UTXO consistency, integer bounds, unsupported scripts/sighashes/finalization, and parser differential behavior against BDK.
3. **Ownership and review:** descriptor/origin/path/public-key/script proof, change classification, amount/fee arithmetic, address rendering, warning semantics, immutable commitment, and time-of-check/time-of-sign defense.
4. **Signing:** secret descriptor construction, BDK trust flags, SIGHASH policy, owned-input scope, deterministic result, metadata preservation, no finalization, and wrong-seed/UTXO rejection.
5. **Optical transport:** BC-UR canonical CBOR/types/fountain limits; BBQr header/Base36/H/2/Z parsing, compressed staging and inflation bounds, duplicates, reordering, format locking, cancellation, and session cleanup.
6. **iOS application:** authentication downgrade paths, scene transitions, capture handling, auto-lock, camera lifecycle, Keychain persistence across reinstall, file-protection timing, entitlements, linked frameworks, and supply-chain assumptions.
7. **User safety:** every displayed output, fee and warning; coordinator claim boundary; operational air-gap guide; honest hardware and deletion statements.

## Expected deliverables

- commit and toolchain reviewed;
- reproducible finding list with severity, affected invariant, exploit preconditions, and test vector where safe;
- confirmation that resolved critical/high fixes were re-reviewed;
- explicit exclusions and residual risks;
- permission statement controlling whether the project may name the reviewer or say only “independently reviewed.”

No “audited,” “production safe,” or real-funds recommendation may appear until the review is complete and the release checklist records its disposition.
