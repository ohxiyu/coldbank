# Dependency provenance

ColdSigner pins direct dependencies exactly. A version change requires an ADR, license review, golden-vector run, and interoperability regression.

| Dependency | Pinned version | Purpose | Upstream | License | Security note |
|---|---:|---|---|---|---|
| bdk-swift | 3.0.0 | BIP39/BIP32, descriptors, PSBT, signing | `bitcoindevkit/bdk-swift` | MIT / Apache-2.0 upstream components | Rust-backed binary XCFramework; checksum is verified by SwiftPM |
| URKit | 9.0.0 | BC-UR bytewords and fountain transport | `BlockchainCommons/URKit` | BSD-2-Clause-Patent | Upstream describes the library as pre-production; ColdSigner adds limits, fixtures, and negative testing |

## Review requirements

- Commit `Package.resolved` after resolution.
- Record package URLs, resolved revisions, binary checksums, and transitive license files in the release SBOM.
- Review generated/linked binaries for unexpected networking or dynamic loading.
- Do not use floating branches, revision ranges, or unreviewed binary mirrors.
- Keep BDK types behind `ColdSignerCore`; UI and feature code consume normalized domain values only.

## Architectural boundary

`BitcoinDevKit` owns cryptographic primitives and Bitcoin serialization. `URKit` owns generic UR fragmentation. ColdSigner owns transaction policy, size/complexity limits, error handling, user-visible review semantics, and compatibility claims.

Separate packages expose `ColdSignerCore` and `ColdSignerTransport`. This keeps Bitcoin/key-policy tests independent of camera/UR integration and isolates upstream toolchain compatibility failures. URKit 9.0.0 is known not to compile under the pre-release Swift 6.4/macOS 27 SDK because Foundation changed `Data.bytes`; supported Xcode CI remains the release authority until an upstream or reviewed local compatibility patch is adopted.
