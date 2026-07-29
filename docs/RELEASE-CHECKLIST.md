# ColdSigner v0.1 release checklist

This checklist separates machine evidence from human/device evidence. A release owner records links, device identifiers, versions, dates, and reviewer names. An unchecked external gate must never be converted into a marketing claim.

## Machine gates

- [x] Exact direct SwiftPM versions and committed lockfiles.
- [x] BIP39/BIP84 vectors and public xpub/zpub/vpub exports.
- [x] Strict PSBT v0 parser, policy, review commitment, and deterministic partial signing corpus.
- [x] BC-UR and BBQr H/2/Z transport tests, bounds, cancellation, disorder, and format-confusion rejection.
- [x] Deterministic testnet C03 unsigned/signed/semantic/optical fixture.
- [x] Fifty varied deterministic software signing and optical transport round trips.
- [x] Dependency-light strict PSBT parser has deterministic ASan and coverage-guided libFuzzer harnesses.
- [x] First-party network/API/configuration guard.
- [ ] Final app binary linked-framework, undefined-symbol, Info.plist, and entitlement audit on release commit.
- [ ] Sanitizer/fuzzer run artifact attached to the release candidate.
- [ ] Clean release archive includes source tag, checksums, MIT license, third-party notices, lockfiles, and SBOM.

## Coordinator gates

- [ ] Sparrow exact stable version: C01–C12 recorded, including finalize/broadcast on testnet or signet.
- [ ] BlueWallet exact stable version: supported scenarios and explicit limitations recorded.
- [ ] Nunchuk exact stable version: supported scenarios and explicit limitations recorded.
- [ ] Coordinator-produced public fixtures committed with reproduction steps.
- [ ] A second tester reproduces at least one full round trip per Supported coordinator.

## Device and lifecycle gates

- [ ] Oldest supported iPhone/OS profile completes [`DEVICE-TEST-PLAN.md`](DEVICE-TEST-PLAN.md).
- [ ] Create, restore, backup challenge, relaunch, unlock, two-minute auto-lock, background lock, and wipe pass on two physical devices.
- [ ] Keychain item is non-synchronizable and ThisDeviceOnly; vault file is complete-protection and backup-excluded on device.
- [ ] Camera scan and signed QR playback pass at 2/5/10 fps under normal and low light.
- [ ] Fifty varied testnet/signing round trips complete without mismatch or retained session state.
- [ ] VoiceOver, Dynamic Type, Reduce Motion explanation, and 44-point touch targets pass manual review.

## Review and release gates

- [ ] Independent Bitcoin/security reviewer completes [`EXTERNAL-REVIEW-SCOPE.md`](EXTERNAL-REVIEW-SCOPE.md).
- [ ] Every critical/high finding is resolved and re-reviewed; lower findings have an explicit disposition.
- [ ] Threat model, user guide, compatibility table, SECURITY.md, and product copy are frozen against shipped behavior.
- [ ] Private vulnerability reporting channel is enabled and tested.
- [ ] Distribution method, signing identity, minimum OS, and supported device list are recorded.
- [ ] Release commit is clean, CI is green, signed tag exists, and published artifact checksums are independently verified.

## Release decision

| Field | Evidence |
|---|---|
| Release commit | Pending |
| Candidate tag | Pending |
| CI run | Pending |
| Device matrix | Pending |
| Coordinator matrix | Pending |
| External reviewer | Pending |
| Decision / date / owner | Pending |
