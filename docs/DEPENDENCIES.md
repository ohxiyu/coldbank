# Dependency provenance

ColdSigner pins direct dependencies exactly. A version change requires an ADR, license review, golden-vector run, and interoperability regression.

The release inventory is published as a CycloneDX 1.5 document in
[`SBOM-v0.1.json`](SBOM-v0.1.json); attribution and redistribution notes are in
[`../THIRD_PARTY_NOTICES.md`](../THIRD_PARTY_NOTICES.md).

| Dependency | Pinned version | Purpose | Upstream | License | Security note |
|---|---:|---|---|---|---|
| bdk-swift | 3.0.0 | BIP39/BIP32, descriptors, PSBT, signing | `bitcoindevkit/bdk-swift` | MIT / Apache-2.0 upstream components | Rust-backed binary XCFramework; checksum is verified by SwiftPM |
| URKit | 9.0.0 | BC-UR bytewords and fountain transport | `BlockchainCommons/URKit` | BSD-2-Clause-Patent | Upstream describes the library as pre-production; ColdSigner adds limits, fixtures, and negative testing |
| zlib (`libz`) | Apple platform SDK | Decode required BBQr raw-DEFLATE `Z` input | Apple SDK system library | zlib | No bundled binary; output, compressed staging bytes, parts, and decode work are bounded |

## Review requirements

- Commit `Package.resolved` after resolution.
- Record package URLs, resolved revisions, binary checksums, and transitive license files in the release SBOM.
- Review generated/linked binaries for unexpected networking or dynamic loading.
- Do not use floating branches, revision ranges, or unreviewed binary mirrors.
- Keep BDK types behind `ColdSignerCore`; UI and feature code consume normalized domain values only.

## Architectural boundary

`BitcoinDevKit` owns cryptographic primitives and signing after review. The
dependency-light `ColdSignerPSBT` target owns strict parsing and normalization
of the supported PSBT v0 subset; it depends only on the platform Foundation and
CryptoKit modules plus `ColdSignerDomain`. `URKit` owns generic UR fragmentation.
The platform zlib performs only bounded raw-DEFLATE expansion for BBQr.
ColdSigner owns optical framing, transaction policy, size/complexity limits,
error handling, user-visible review semantics, and compatibility claims.

Separate targets isolate domain limits, hostile PSBT parsing, BDK-backed signing,
and optical transport. This lets sanitizer/libFuzzer exercise the untrusted-input
boundary without loading the BDK binary XCFramework. The Swift.org 6.3.3
toolchain used by the CI fuzz job is a test-only tool and does not build the iOS
artifact. URKit 9.0.0 is known not to compile under the pre-release Swift
6.4/macOS 27 SDK because Foundation changed `Data.bytes`; supported Xcode CI
remains the release authority until an upstream or reviewed local compatibility
patch is adopted.
