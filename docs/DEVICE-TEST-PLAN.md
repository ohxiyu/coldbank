# Physical-device security and interoperability plan

Use testnet/signet only. Record iPhone model, SoC, iOS version/build, battery health, free storage, ColdSigner commit, coordinator version/platform, lighting, and tester for every run. Never attach a real mnemonic or personally linked transaction.

## Required devices

- Oldest device that will be advertised as supported, on the minimum supported iOS release.
- A current Face ID device on the latest stable iOS.
- Prefer a second biometric class (Touch ID) before beta.

## Lifecycle cases

| ID | Test | Pass condition |
|---|---|---|
| D01 | Fresh create and backup challenge | Activation is blocked until correct verification |
| D02 | Restore 12 and 24 words | Fingerprint/address match independent reference |
| D03 | Relaunch while locked | No seed/review screen appears before authentication |
| D04 | Background from seed/review/signed QR | Privacy cover is immediate; wallet and PSBT session are locked/cleared |
| D05 | Two-minute inactivity | Ready wallet returns to lock screen |
| D06 | Authentication cancel/failure | No weaker fallback and no partial signature |
| D07 | Screen recording/mirroring | Sensitive view is covered; stopping allows an explicit safe retry |
| D08 | Wipe and reinstall | Vault is absent; stale Keychain item cannot resurrect wallet |
| D09 | Backup inspection | Vault and Keychain secret do not synchronize or appear in backup |
| D10 | Device reboot | Complete-protection state remains unavailable until first unlock |

## Optical and resource cases

| ID | Test | Pass condition |
|---|---|---|
| D11 | BC-UR small and multipart at 2/5/10 fps | Reconstructed PSBT bytes match fixture |
| D12 | BBQr H and coordinator Z input | Reconstructed PSBT bytes match fixture; signed result returns BBQr |
| D13 | Reorder/duplicate/drop/format switch | BC-UR recovers loss; BBQr handles order/duplicates; mixed family requires restart |
| D14 | Low light, glare, minimum/maximum brightness | No silent corruption; user can recover or receives bounded error |
| D15 | Largest accepted practical PSBT | Peak memory, time, temperature, and UI responsiveness recorded |
| D16 | Repeated cancel/background/scan loop | No monotonic memory growth across 50 cycles |

## Coordinator record

For each applicable C01–C12 scenario in [`COMPATIBILITY.md`](COMPATIBILITY.md), store:

- exact app version/build and download source;
- exact pairing export and optical type;
- unsigned and returned PSBT hashes;
- expected vs observed amounts, fee, warnings, change, signed input count, final txid;
- pass/fail, screenshots containing test-only data, and tester signature;
- public fixture when license/privacy permits.
