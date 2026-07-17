# ColdSigner testnet C03 fixture

This is the deterministic one-input, one-recipient, one-change signing reference used before live coordinator promotion. It contains no live coin or personal wallet data.

The generator uses the published BIP39 vector `abandon` repeated eleven times followed by `about`, derives the testnet BIP84 account `m/84'/1'/0'`, constructs a synthetic previous transaction, reviews the unsigned PSBT, and produces one non-finalized `SIGHASH_ALL` partial signature.

Never use this mnemonic for funds. Its private key is public by design.

Reproduce the Base64 payloads:

```bash
swift run --scratch-path /tmp/coldsigner-swift-build \
  ColdSignerCoreTestRunner --emit-public-interop-fixture
```

Decode a PSBT for a coordinator that requires a binary file:

```bash
base64 --decode unsigned.psbt.base64 > /tmp/coldsigner-c03-unsigned.psbt
```

The repository stores Base64 text rather than opaque binary so diffs, secret scanning, and fixture verification remain deterministic. Optical fixture files are generated from exactly these decoded bytes.
