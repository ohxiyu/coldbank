# Wallet compatibility and test matrix

Compatibility is a tested claim, not a format guess. A coordinator is “supported” only after its exact released version passes pairing, unsigned import, signed return, finalization, and broadcast rehearsal with recorded non-secret fixtures.

## v0.1 transport profile

| Concern | ColdSigner v0.1 profile |
|---|---|
| Wallet policy | BIP84 P2WPKH single signature |
| Account | `m/84'/coin_type'/0'` |
| Unsigned transaction | PSBT v0 |
| QR envelope | BC-UR v2 and BBQr |
| PSBT optical types | BC-UR `crypto-psbt` / `psbt`; BBQr `P` |
| Signed result | Partially/completely signed PSBT, not raw transaction |
| Return format | Same envelope family as the accepted unsigned PSBT |
| Primary public-wallet export | Descriptor with key origin + checksum |
| Compatibility public export | Origin account xpub and BIP84 SLIP-132 zpub static QR |

## Support tiers

| Coordinator | v0.1 target | Pairing route | PSBT route | Current claim |
|---|---|---|---|---|
| Sparrow | Required | Receive/change descriptors or origin account xpub | Animated BC-UR PSBT both directions | Source-compatible; live release matrix pending |
| BlueWallet | Required candidate | BIP84 zpub watch-only import | Animated `crypto-psbt` BC-UR both directions | Source-compatible; live release matrix pending |
| Nunchuk | Required candidate | `[fingerprint/84h/coinh/0h]xpub` air-gapped key | Animated BBQr `P` both directions | Source-compatible; live release matrix pending |

“Source-compatible” means the implemented payload matches the coordinator's public source or documentation as inspected on 2026-07-18. It is not a Supported claim. UI routes and accepted payloads can change independently, so fixture metadata records app version, platform, export route, optical type, and result.

## Source-level evidence

| Coordinator | Evidence inspected | ColdSigner implementation consequence |
|---|---|---|
| Sparrow | [Features](https://sparrowwallet.com/features/) describe PSBT and air-gapped fountain UR; [official repository](https://github.com/sparrowwallet/sparrow) is the release source | Emit/accept bounded BC-UR PSBT and export descriptors |
| BlueWallet | [UR module](https://github.com/BlueWallet/BlueWallet/blob/master/blue_modules/ur/index.js) creates/decodes `CryptoPSBT`; [scanner](https://github.com/BlueWallet/BlueWallet/blob/master/screen/send/ScanQRCode.tsx) accepts `UR:CRYPTO-PSBT`; [watch-only wallet](https://github.com/BlueWallet/BlueWallet/blob/master/class/wallets/watch-only-wallet.ts) recognizes zpub as native SegWit; [offline-signing guide](https://bluewallet.io/docs/sign-offline/) documents the workflow | Emit `crypto-psbt`; export the BIP84 zpub watch-only key |
| Nunchuk | [BBQr transaction export use case](https://github.com/nunchuk-io/nunchuk-android/blob/master/nunchuk-domain/src/main/java/com/nunchuk/android/usecase/qr/ExportBBQRTransactionUseCase.kt) uses BBQr; [signer model](https://github.com/nunchuk-io/nunchuk-android/blob/master/nunchuk-core/src/main/java/com/nunchuk/android/core/signer/SignerModel.kt) parses key-origin xpub text | Accept/emit BBQr `P`; export the exact origin account key shape |

BBQr parsing follows the [BBQr specification](https://bbqr.org/BBQr.html): uppercase `B$` header, PSBT file type `P`, Base36 part counters, and required `H`, `2`, and raw-DEFLATE `Z` receive encodings. ColdSigner emits `H` in v0.1 for the smallest codec surface.

The checked-in [`coldsigner-testnet-c03`](../Fixtures/Public/coldsigner-testnet-c03/) reference fixes one unsigned PSBT, deterministic partial signature, normalized review, and exact BC-UR/BBQr frames. It proves ColdSigner's two internal optical paths agree on identical bytes; it does not substitute for a coordinator-produced live fixture.

## Mandatory scenarios per coordinator

| ID | Scenario | Expected result |
|---|---|---|
| C01 | Pair fresh mainnet BIP84 wallet | Fingerprint and first receive address match |
| C02 | Pair testnet BIP84 wallet | Fingerprint and first address match |
| C03 | One input, one recipient, one change | Sign, return, finalize, txid matches reference |
| C04 | Multiple wallet inputs | All and only owned inputs signed |
| C05 | Two recipients plus change | All outputs visible and correctly classified |
| C06 | No-change send | No phantom change; outgoing total correct |
| C07 | Large PSBT requiring multipart optical QR | Recovers with reordered/duplicate frames; BC-UR also tolerates fountain loss |
| C08 | Non-default locktime/RBF sequence | Displayed accurately; policy outcome stable |
| C09 | High but valid fee | Warning shown; calculated amount matches coordinator |
| C10 | Foreign input mixed with owned input | Owned-only behavior matches policy and coordinator |
| C11 | Coordinator scans signed PSBT | Finalizes without metadata loss required by coordinator |
| C12 | App version upgrade | Existing fixture remains compatible or change is documented |

## Negative and adversarial fixtures

- Wrong network descriptor and wrong-network recipient.
- Taproot, legacy P2PKH, wrapped SegWit, multisig, Miniscript, and unknown script inputs.
- SIGHASH values other than the v0.1 allowlist.
- Missing witness UTXO, inconsistent witness/non-witness UTXO, wrong previous txid/index.
- Forged fingerprint, derivation path, public key, or change metadata.
- Duplicate PSBT map keys, unknown/proprietary fields, finalized input, and malformed compact sizes.
- Input sum below output sum, arithmetic boundary values, dust outputs, zero-value output, extreme fee.
- Oversized PSBT, excessive input/output counts, deep paths, invalid CBOR, wrong UR type, fragment flood.
- Invalid BBQr header/type/Base36 counts, non-canonical Base32/hex, DEFLATE bomb, conflicting duplicate, and mixed BC-UR/BBQr session.
- Mutation after review and background/foreground during authentication.

Every negative fixture states whether the correct outcome is `transport reject`, `parse reject`, `policy reject`, `warning`, or `sign`.

## Fixture storage rules

Public fixtures must use deterministic, publicly documented test keys and testnet/signet coins only. Each fixture directory contains:

```text
manifest.json          coordinator/version/network/expected outcome
unsigned.psbt          public test vector
signed.psbt            expected public test vector
decoded.json           normalized, non-secret semantic expectation
qr-parts.txt           deterministic UR fragments when useful
README.md              reproduction steps
```

Never commit a mainnet private key, a mnemonic used elsewhere, real addresses linked to a person, or an unpublished transaction.

## Promotion rule

A wallet moves from Experimental to Supported only when:

1. all mandatory scenarios applicable to the wallet pass on its current stable release;
2. failures in unsupported scenarios are safe and understandable;
3. fixtures run in CI where technically possible;
4. the documentation gives exact pairing steps and version tested;
5. at least one round trip is reproduced by a second tester.
