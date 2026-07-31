# Coldbank / ColdSigner

Coldbank turns a spare iPhone into an open-source, air-gapped Bitcoin transaction
signer. `ColdSignerApp` is the offline signer; `Coordinator` is the optional
first-party PWA that creates and broadcasts transactions without requiring
Sparrow, BlueWallet, or another wallet application.

> **Status: pre-alpha. Do not use with real funds.** The repository contains a working offline key, BC-UR/BBQr transport, PSBT review, and partial-signing path, but live coordinator/device testing and independent security review are not complete.

## v0.1 target

- Native Swift and SwiftUI app, iOS 16+
- BIP39 key creation and recovery
- BIP84 single-signature wallets (`wpkh`, mainnet first)
- PSBT v0 import and export over animated BC-UR or BBQr QR
- Human-verifiable transaction review before signing
- Sparrow end-to-end compatibility as the release gate
- BlueWallet and Nunchuk compatibility tracked with explicit test fixtures
- No networking code, telemetry, cloud sync, clipboard export, or transaction broadcast

The network prohibition applies to the offline app and core packages. The
Coordinator is separately built, deployed, and reviewed; it never receives
private key material.

ColdSigner is a software signer running on a general-purpose phone. It is not equivalent to a dedicated hardware wallet and does not claim that Bitcoin secp256k1 keys are held inside the Secure Enclave.

## Repository map

```text
ColdSignerApp/            SwiftUI application and iOS security adapters
Sources/ColdSignerCore/   security and Bitcoin core package
Coordinator/              first-party PWA and Cloudflare API gateway
Tests/                    cross-platform core tests
ColdSignerAppTests/       iOS application tests
Fixtures/Public/          deterministic public interoperability vectors
docs/                     PRD, UX, security, compatibility, and backlog
scripts/                  local and CI validation
.github/                  issue templates and CI
project.yml               XcodeGen project definition
```

Start with:

- [ColdSigner v0.1 PRD](docs/PRD-v0.1.md)
- [User flows and screen map](docs/UX-FLOWS.md)
- [UI specification](docs/UI-SPEC.md)
- [Security baseline](docs/SECURITY-BASELINE.md)
- [Compatibility matrix](docs/COMPATIBILITY.md)
- [Development backlog](docs/DEVELOPMENT-PLAN.md)
- [Implementation status](docs/IMPLEMENTATION-STATUS.md)
- [First-party coordinator decision](docs/decisions/ADR-0005-first-party-web-coordinator.md)
- [GitHub repository setup](docs/GITHUB-SETUP.md)

## Local setup

Requirements: Xcode, Swift 6-capable toolchain, and [XcodeGen](https://github.com/yonaskolb/XcodeGen).

```bash
brew install xcodegen
make bootstrap
open ColdSigner.xcodeproj
```

Run repository checks with:

```bash
make check
make core-test
```

## Architecture decision for v0.1

The initial implementation uses `bdk-swift` for descriptors, PSBT parsing, and signing, `URKit` for UR fountain transport, and the platform zlib for bounded BBQr decompression. `libwally-core` remains a documented fallback, not a second active signing stack. Keeping one signing implementation reduces audit surface and avoids divergent transaction interpretation.

The separate Coordinator uses pinned `@scure/bip32` and
`@scure/btc-signer` packages for public derivation and PSBT construction. It
queries mempool.space through a same-origin Cloudflare Worker and falls back to
Blockstream Esplora only after retryable failures.

Dependencies are pinned in the root and transport `Package.swift` manifests; changes require an ADR and compatibility regression run.

## Contributing and security

See [CONTRIBUTING.md](CONTRIBUTING.md). Do not open a public issue for a suspected vulnerability; follow [SECURITY.md](SECURITY.md).

## License

[MIT](LICENSE)
