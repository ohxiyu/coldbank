# ADR-0004: Optical coordinator formats

- Status: Accepted for v0.1 implementation
- Date: 2026-07-18

## Context

The v0.1 product must interoperate with current Sparrow, BlueWallet, and Nunchuk coordinators without adding files, clipboard, radio, or network transfer. Sparrow and BlueWallet expose BC-UR PSBT workflows. Current Nunchuk Android source uses BBQr for transaction QR exchange and a key-origin account xpub for air-gapped signer import.

Treating BC-UR as the only optical envelope would make the Nunchuk target aspirational rather than implementable. Automatically switching decoders inside one scan session would also create a format-confusion surface.

References:

- <https://bbqr.org/BBQr.html>
- <https://github.com/BlueWallet/BlueWallet/blob/master/blue_modules/ur/index.js>
- <https://github.com/nunchuk-io/nunchuk-android/blob/master/nunchuk-domain/src/main/java/com/nunchuk/android/usecase/qr/ExportBBQRTransactionUseCase.kt>
- <https://sparrowwallet.com/features/>

## Decision

- Accept only BC-UR PSBT (`crypto-psbt` or `psbt`) and BBQr PSBT (`P`) optical payloads.
- Detect the first valid frame, lock the session to that envelope family, and fail/reset if a later frame switches family.
- Return the signed PSBT using the same envelope family as the unsigned input.
- For BBQr import, implement the required uppercase `H`, `2`, and raw-DEFLATE `Z` encodings; validate Base36 counts, equal fragment sizing, canonical alphabets/padding, duplicate consistency, PSBT magic, and bounded aggregate/decompressed size.
- Emit uppercase BBQr `H` for v0.1. This favors a smaller auditable encoder over compression efficiency; fragment count remains bounded.
- Never expose generic BBQr file types or pass decoded bytes to signing policy before PSBT magic and transport bounds succeed.

## Consequences

Nunchuk has a source-compatible transport path and Sparrow/BlueWallet retain their BC-UR path. The app can describe progress exactly for BBQr and only approximately for fountain UR. zlib becomes a platform dependency solely for bounded decoding, adding a decompression surface that requires bomb, truncation, and trailing-input tests. Live released-version round trips remain mandatory before any coordinator is labeled Supported.
