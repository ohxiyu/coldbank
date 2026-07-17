# ColdSigner v0.1 security baseline

This document is normative for v0.1. Product copy and implementation must not claim stronger guarantees.

## Security objective

ColdSigner aims to keep Bitcoin signing secrets off network-connected coordinators and make the exact effect of a proposed transaction visible before local signing.

## Trust boundary

Trusted for v0.1:

- the specific iPhone hardware and installed iOS build;
- the ColdSigner binary and pinned dependencies;
- the device passcode and device-owner authentication policy;
- the user’s physical seed backup and visual review;
- Apple-provided CSPRNG, Keychain/data-protection mechanisms, and camera stack.

Untrusted:

- the online coordinator and its PSBT metadata;
- every scanned QR payload;
- keyboard/clipboard/cloud/network conveniences;
- transaction labels and “change” claims supplied by another wallet;
- a jailbroken device, compromised OS, malicious build toolchain, or physical attacker with advanced extraction capability.

## Honest hardware statement

The Secure Enclave supports Apple-selected algorithms and does not directly act as a Bitcoin secp256k1 signer. ColdSigner’s seed and derived Bitcoin keys necessarily exist in app-addressable memory while signing. Device security can protect a local wrapping key and gate access, but this is not equivalent to a hardware wallet that keeps secp256k1 private keys inside a dedicated signing element.

## Threats and controls

| Threat | v0.1 control | Residual risk |
|---|---|---|
| Malicious coordinator changes recipient/amount | Parse independently; show every output; revalidate review digest | User may not compare addresses carefully |
| Malicious change label | Derive path and match script locally | Large/novel derivations are rejected |
| Fee theft | Require all UTXO data; calculate fee locally; show sats and sat/vB | A valid but high fee can still be approved |
| Unsupported signing semantics | Allowlist BIP84 P2WPKH + SIGHASH_ALL + PSBT v0 | Narrow compatibility |
| QR parser denial/exploit | Payload/count/depth limits; strict parser; fuzz corpus | Camera/third-party decoder bugs remain |
| Seed theft at rest | Encrypted secret file; ThisDeviceOnly Keychain key; complete file protection | Compromised OS or unlocked device can read memory |
| Seed leakage through OS features | No copy/share; no analytics/logs; privacy cover; backup exclusion | Screenshots and physical cameras cannot be guaranteed blocked |
| Radio/network exfiltration | No networking code or entitlements; CI symbol scan; operational offline checklist | iOS and dependencies are still general-purpose software |
| Dependency compromise | Exact version pinning, checksums/lockfile in release builds, review on bumps | Upstream or build-chain compromise remains |
| Device theft | Passcode, owner auth, auto-lock, encrypted state | Weak passcode and forensic extraction remain |
| Memory remanence | Minimize lifetime/copies; clear buffers where APIs allow; clear flow on background | Swift copy-on-write/runtime prevents a perfect zeroization guarantee |
| Malicious replacement build | Published source/tag/hash; future reproducible-build work | v0.1 distribution may not be fully reproducible |

## Secret lifecycle

1. **Creation:** entropy comes from the selected audited library backed by the OS CSPRNG. No timestamps, gestures, camera images, or custom PRNG are mixed in.
2. **Display:** mnemonic is displayed only during explicit create/backup. It is never placed in pasteboard, logs, accessibility custom actions, analytics, or share sheets.
3. **Persistence:** serialize only the minimum seed material. Encrypt using AES-GCM with a random data-encryption key stored as a non-synchronizable Keychain item using a `ThisDeviceOnly` accessibility class and device-owner access control. Store ciphertext in an app-private, backup-excluded file with complete protection.
4. **Unlock:** authenticate first, decrypt as late as possible, derive only needed keys, sign, and release references immediately.
5. **Background/timeout:** cancel authentication, cover UI, destroy transaction/session state, and lock the wallet.
6. **Wipe:** delete Keychain key and ciphertext, clear derived public cache and partial QR state. Document that flash wear leveling prevents a guarantee of physical overwriting; recommend full device erase on retirement.

The concrete Keychain accessibility/access-control combination requires device testing because some combinations conflict. A failing configuration must block wallet activation; it must not silently fall back to a synchronizable or weaker item.

## PSBT policy invariants

- Treat all PSBT metadata as claims to verify.
- Never sign an input merely because it contains the wallet fingerprint.
- Match derivation origin, derived public key, previous output script, and active descriptor.
- Compute input values from validated witness UTXOs (and non-witness transactions when required by the library/policy).
- Detect duplicate PSBT keys and inconsistent UTXO forms.
- Display every output exactly once as recipient or verified change.
- Sign only owned inputs; preserve unrelated valid inputs without modifying their semantics.
- Recompute the review commitment immediately before calling the signing library.
- Never finalize or broadcast in v0.1.

## Network isolation controls

Source and build controls:

- no `Network`, `NetworkExtension`, `WebKit`, networking URLSession task APIs, sockets, Bonjour, MultipeerConnectivity, CloudKit, StoreKit, telemetry, or remote logging;
- no background modes, associated domains, push notifications, local-network usage string, arbitrary-load exception, or iCloud entitlements;
- a CI script scans first-party sources and project configuration for banned capabilities;
- release review inspects linked frameworks and the final entitlements, not just imports;
- third-party dependencies are reviewed for runtime network behavior.

Operational controls:

- the user keeps Wi-Fi, Bluetooth, cellular/eSIM, AirDrop, hotspot, and VPN disabled;
- the signer device is not used for browsing, messaging, password management, or daily apps;
- OS/app installation and update are treated as temporary re-entry into a connected trust domain, followed by verification and radio disablement.

“No network code in ColdSigner” is testable. “The iPhone has no possible radio path” is not an app-level guarantee.

## Logging and diagnostics

Production builds contain no verbose logging. Development logging uses event codes and counts only. Forbidden diagnostic values include mnemonic/seed/xprv, raw or encoded PSBT, signatures, full descriptors, full xpubs, full addresses, camera frames, Keychain errors containing data, and authentication context.

Crash upload SDKs are forbidden. User-exportable diagnostics are out of v0.1 unless a separate redaction design is reviewed.

## Release gates

- Threat-model review updated for every P0 feature.
- Static banned-API and entitlement checks pass.
- Parser property tests and fuzz corpus pass under sanitizers where available.
- Known BIP32/BIP39/BIP84/PSBT vectors pass.
- Cross-wallet golden fixtures pass byte/semantic comparison.
- Oldest supported device passes memory, camera, auto-lock, background, and wipe tests.
- At least one independent cryptography/Bitcoin review before any “real funds” recommendation.
