# ADR-0002: Narrow v0.1 wallet and transaction policy

- Status: Accepted for implementation baseline
- Date: 2026-07-17

## Decision

v0.1 supports one BIP84 P2WPKH single-signature account, PSBT v0, `SIGHASH_ALL`, and BC-UR v2 `crypto-psbt`. Sparrow is the first supported coordinator. BlueWallet and Nunchuk remain explicit compatibility targets but are not advertised as supported until their current releases pass the repository matrix.

Taproot, multisig, Miniscript, PSBT v2, BIP39 passphrases, and multiple wallets are deferred.

## Rationale

The main security property is that ColdSigner can explain and independently verify every transaction effect before signing. Each additional script and policy multiplies derivation, sighash, change-detection, UX, and interoperability cases. The narrow profile gives v0.1 a testable release boundary.

## Revisit condition

Expand only after v0.1 P0 gates pass and the new feature has threat analysis, reference vectors, coordinator fixtures, and a UI treatment that does not hide its signing semantics.
