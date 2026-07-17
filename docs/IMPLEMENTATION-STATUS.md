# ColdSigner v0.1 implementation status

This file records implementation evidence. It does not replace the release gates in the PRD or imply that unfinished or unaudited code is safe for real funds.

| Milestone | Status | Current evidence | Remaining gate |
|---|---|---|---|
| M0 repository and architecture | Implemented | XcodeGen manifest, exact package pins, CI, banned-network scan, redacted errors, public fixture schema | Green iOS CI on each change |
| M1 key lifecycle and onboarding | Implemented, device verification pending | BDK BIP39/BIP84 vectors, encrypted vault, Keychain access control, create/restore/backup challenge, lock, public export, authenticated wipe | Two-device security behavior tests |
| M2 optical transport | Implemented | Bounded BC-UR `crypto-psbt`/`psbt`, bounded BBQr `P` with H/2/Z receive, camera scanner, format-locked sessions, matching signed-result QR, cancellation/disorder/loss vectors | Camera/device profiling and expanded fuzz corpus |
| M3 PSBT policy and signing | Implemented, independent review pending | Strict PSBT v0 parser, duplicate/unsupported-field rejection, BIP84 ownership and change proof, full review, immutable commitment, strict BDK partial signing, 60-second cleanup; GitHub iOS/core/transport CI green | Public coordinator fixtures, accessibility/UI tests and independent review |
| M4 interoperability | In progress | Origin xpub and BIP84 zpub exports; BC-UR and BBQr paths; deterministic testnet C03 unsigned/signed/optical fixture; source-level Sparrow/BlueWallet/Nunchuk evidence | Exact stable-version device round trips, coordinator-produced fixtures, second tester |
| M5 hardening and alpha release | Not started | Security baseline and release checklist exist | Device matrix, coverage, soak, external review, tag and checksums |

## Verified locally

- `make check`: required files, secret-fixture guard, and first-party network/API guard.
- `make core-test`: 25 deterministic checks covering BIP39/BIP84 and public exports, redaction, strict PSBT structure/policy, a 512-case mutation smoke corpus, ownership/change, mutation defense, deterministic testnet C03 fixture/signing, wrong-seed/UTXO rejection, AES-GCM integrity/profile binding, and backup challenges.
- Transport tests cover canonical BC-UR, fountain disorder/loss, BBQr H/2/Z vectors, exact multipart reassembly, conflicting duplicates, limits, format detection, and cancellation.
- `make generate`: clean Xcode project generation from `project.yml`.

## Non-negotiable release blockers

- No real-funds recommendation before independent Bitcoin/security review.
- No “Supported” wallet label without checked-in fixtures and recorded live version results.
- No release while any P0 policy rejection, state cleanup, backup exclusion, authentication, or network-isolation test is missing.
