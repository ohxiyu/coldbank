# Wallet compatibility and test matrix

Compatibility is a tested claim, not a format guess. A coordinator is “supported” only after its exact released version passes pairing, unsigned import, signed return, finalization, and broadcast rehearsal with recorded non-secret fixtures.

## v0.1 transport profile

| Concern | ColdSigner v0.1 profile |
|---|---|
| Wallet policy | BIP84 P2WPKH single signature |
| Account | `m/84'/coin_type'/0'` |
| Unsigned transaction | PSBT v0 |
| QR envelope | BC-UR v2 |
| PSBT UR type | `crypto-psbt` |
| Signed result | Partially/completely signed PSBT, not raw transaction |
| Primary public-wallet export | Descriptor with key origin + checksum |
| Compatibility public export | Account xpub/zpub static QR where required |

## Support tiers

| Coordinator | v0.1 target | Pairing route | PSBT route | Release claim |
|---|---|---|---|---|
| Sparrow | Required | Descriptor / supported air-gapped account QR | Animated `ur:crypto-psbt` both directions | Supported after full matrix |
| BlueWallet | Required candidate | Watch-only account extended public key | BC-UR PSBT scan/return | Experimental until current-version matrix passes |
| Nunchuk | Required candidate | Air-gapped key import format selected from live app | BC-UR PSBT where accepted | Experimental until current-version matrix passes |

The repository does not yet claim BlueWallet or Nunchuk support. Their UI and accepted payloads can change independently, so fixture metadata records app version, platform, export route, UR type, and result.

## Mandatory scenarios per coordinator

| ID | Scenario | Expected result |
|---|---|---|
| C01 | Pair fresh mainnet BIP84 wallet | Fingerprint and first receive address match |
| C02 | Pair testnet BIP84 wallet | Fingerprint and first address match |
| C03 | One input, one recipient, one change | Sign, return, finalize, txid matches reference |
| C04 | Multiple wallet inputs | All and only owned inputs signed |
| C05 | Two recipients plus change | All outputs visible and correctly classified |
| C06 | No-change send | No phantom change; outgoing total correct |
| C07 | Large PSBT requiring multipart UR | Recovers with reordered/duplicate frames |
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
