# ColdSigner v0.1 testnet alpha user guide

> ColdSigner is an unaudited air-gapped software signer. The v0.1 alpha is for testnet evaluation only. Do not protect real funds with it.

## 1. Prepare the spare iPhone

1. Use an iPhone supported by iOS 16 or later. Erase it first if it previously held personal data.
2. Install a reviewed ColdSigner build while the device is temporarily online.
3. Set a strong device passcode and enroll Face ID or Touch ID.
4. Disable Wi‑Fi, Bluetooth, cellular/eSIM, AirDrop, hotspot, VPN, Siri network features, and automatic cloud backup.
5. Keep the phone offline and do not install daily-use apps. Updating iOS or ColdSigner temporarily re-enters a connected trust domain and requires repeating the checks.

ColdSigner itself contains no network feature, but iOS is still a general-purpose operating system. Operational radio disablement remains the user's responsibility.

## 2. Choose the network, then create or restore

- Keep the default **Testnet** selection for alpha evaluation.
- Mainnet is visible only so the release candidate can exercise identical BIP84 behavior; it carries real-funds risk and is not recommended before the full release checklist passes.

- **Create:** choose 12 or 24 words, write them on a physical backup, then complete the random word challenge.
- **Restore:** enter 12 or 24 BIP39 English words using the bundled local word list.
- Never photograph, paste, message, print through a network printer, or store the words in a password manager.
- The testnet fixture mnemonic in the repository is public and must never receive funds.

After activation, ColdSigner shows the wallet fingerprint, network, BIP84 policy, account path, and first receive address. Record the fingerprint with the physical backup.

## 3. Pair a coordinator

Open **只读导出** and choose the format required by the coordinator:

| Coordinator target | ColdSigner export |
|---|---|
| Sparrow | receive/change descriptors; origin xpub as fallback |
| BlueWallet | BIP84 zpub/vpub watch-only key |
| Nunchuk | origin account key `[fingerprint/84h/coinh/0h]xpub` |

On the online coordinator, verify the fingerprint and first receive address before using the watch-only wallet. Exported public data cannot spend coins, but it reveals address and transaction privacy.

## 4. Review and sign a PSBT

1. Build an unsigned PSBT v0 in the online coordinator.
2. Display it as BC-UR PSBT or BBQr PSBT.
3. In ColdSigner choose **扫描待签名交易** and scan until reconstruction completes.
4. Verify the total outgoing amount, every recipient address and amount, absolute fee, estimated fee rate, every warning, and each locally verified change output.
5. Compare important values with the coordinator and the intended payment using an independent channel.
6. Hold the sign control for 1.5 seconds and complete device-owner authentication.
7. Scan the returned signed PSBT in the coordinator. ColdSigner returns the same optical family it received.
8. Let the coordinator verify, finalize, and broadcast. ColdSigner never broadcasts.

Cancel if any field is unexpected. Invalid input, backgrounding, cancellation, navigation away, format switching, or timeout clears the active PSBT session.

## 5. Lock, wipe, and retire

- ColdSigner locks immediately when backgrounded and after two minutes without activity.
- Use **安全与设置 → 立即锁定** when handing the device to another person.
- **擦除签名器** requires typing `WIPE` and device-owner authentication. It deletes the encrypted seed record and Keychain wrapping key.
- Flash wear leveling prevents a guarantee of physical overwrite. When retiring the phone, erase all content and settings from iOS after confirming the external seed backup.

## Known limitations

- BIP84 P2WPKH single-signature only; PSBT v0 and `SIGHASH_ALL` only.
- No Taproot, multisig, Miniscript, SeedQR, NFC, file, clipboard, share sheet, finalization, or broadcast.
- The seed exists in app-addressable memory while signing; Secure Enclave does not sign Bitcoin secp256k1 transactions.
- Screen capture detection hides sensitive views during recording/mirroring but cannot guarantee screenshot prevention.
- Sparrow, BlueWallet, and Nunchuk remain source-compatible rather than Supported until released-version device fixtures and a second tester pass the matrix.
