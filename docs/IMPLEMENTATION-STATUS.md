# ColdSigner v0.1 implementation status

This file records implementation evidence. It does not replace the release gates in the PRD or imply that unfinished or unaudited code is safe for real funds.

| Milestone | Status | Current evidence | Remaining gate |
|---|---|---|---|
| M0 repository and architecture | Implemented | XcodeGen manifest, exact package pins, CI, banned-network scan, redacted errors, public fixture schema | Green iOS CI on each change |
| M1 key lifecycle and onboarding | In verification | BDK BIP39/BIP84 vectors, encrypted vault, Keychain access control, create/restore/backup challenge, lock, public export, authenticated wipe | iOS CI, simulator UI tests, two-device security behavior tests |
| M2 BC-UR transport | Started | Separate pinned transport package and centralized limits | Encoder/decoder, animated QR UI, golden/property/fuzz tests |
| M3 PSBT policy and signing | Not started | Stable policy errors and limits only | Full P0 parser, policy, review, signing and cleanup scope |
| M4 interoperability | Not started | Compatibility claims are explicitly unverified | Sparrow fixtures and live runs; BlueWallet/Nunchuk evidence |
| M5 hardening and alpha release | Not started | Security baseline and release checklist exist | Device matrix, coverage, soak, external review, tag and checksums |

## Verified locally

- `make check`: required files, secret-fixture guard, and first-party network/API guard.
- `make core-test`: 11 deterministic checks covering the official BIP84 vector, invalid BIP39 checksum, redaction, policy limits, AES-GCM integrity/profile binding, and backup challenges.
- `make generate`: clean Xcode project generation from `project.yml`.

## Non-negotiable release blockers

- No real-funds recommendation before independent Bitcoin/security review.
- No “Supported” wallet label without checked-in fixtures and recorded live version results.
- No release while any P0 policy rejection, state cleanup, backup exclusion, authentication, or network-isolation test is missing.
