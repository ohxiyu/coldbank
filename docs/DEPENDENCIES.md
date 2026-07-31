# Dependency provenance

ColdSigner pins direct dependencies exactly. A version change requires an ADR, license review, golden-vector run, and interoperability regression.

| Dependency | Pinned version | Purpose | Upstream | License | Security note |
|---|---:|---|---|---|---|
| bdk-swift | 3.0.0 | BIP39/BIP32, descriptors, PSBT, signing | `bitcoindevkit/bdk-swift` | MIT / Apache-2.0 upstream components | Rust-backed binary XCFramework; checksum is verified by SwiftPM |
| URKit | 9.0.0 | BC-UR bytewords and fountain transport | `BlockchainCommons/URKit` | BSD-2-Clause-Patent | Upstream describes the library as pre-production; ColdSigner adds limits, fixtures, and negative testing |
| zlib (`libz`) | Apple platform SDK | Decode required BBQr raw-DEFLATE `Z` input | Apple SDK system library | zlib | No bundled binary; output, compressed staging bytes, parts, and decode work are bounded |

The networked `Coordinator` is a separate deliverable with its own exact npm
lockfile:

| Dependency | Pinned version | Purpose | Upstream | Security note |
|---|---:|---|---|---|
| `@scure/bip32` | 2.2.0 | Public child-key derivation from account xpub/tpub | `paulmillr/scure-bip32` | Public data only; exact version and lockfile |
| `@scure/btc-signer` | 2.2.0 | Address validation, PSBT v0 construction/finalization | `paulmillr/scure-btc-signer` | No network code; public transaction data only |
| `qr-scanner` | 1.4.2 | Browser camera QR decoding | `nimiq/qr-scanner` | Camera frames remain in the browser |
| `qrcode` | 1.5.4 | Render BBQr frames | `soldair/node-qrcode` | Encodes unsigned public PSBT data |
| vinext / React / Cloudflare Vite plugin | exact versions in `Coordinator/package.json` | PWA UI and Worker build | respective upstreams | Not linked into the offline iOS binary |

## Review requirements

- Commit `Package.resolved` after resolution.
- Record package URLs, resolved revisions, binary checksums, and transitive license files in the release SBOM.
- Review generated/linked binaries for unexpected networking or dynamic loading.
- Do not use floating branches, revision ranges, or unreviewed binary mirrors.
- Keep BDK types behind `ColdSignerCore`; UI and feature code consume normalized domain values only.

## Architectural boundary

`BitcoinDevKit` owns cryptographic primitives and Bitcoin serialization. `URKit` owns generic UR fragmentation. The platform zlib performs only bounded raw-DEFLATE expansion for BBQr. ColdSigner owns optical framing, transaction policy, size/complexity limits, error handling, user-visible review semantics, and compatibility claims.

Separate packages expose `ColdSignerCore` and `ColdSignerTransport`. This keeps Bitcoin/key-policy tests independent of camera/UR integration and isolates upstream toolchain compatibility failures. URKit 9.0.0 is known not to compile under the pre-release Swift 6.4/macOS 27 SDK because Foundation changed `Data.bytes`; supported Xcode CI remains the release authority until an upstream or reviewed local compatibility patch is adopted.

`Coordinator` is intentionally outside those packages. Its dependency graph,
network permissions, storage, and release artifact must never be merged into the
offline iOS application target.
