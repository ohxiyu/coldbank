# ADR-0006: vault 记录中的公开 profile 以明文存储

## 状态

已接受（2026-08）

## 背景

`wallet.vault` 记录包含两部分：AES-GCM 加密的助记词密文，以及明文的
`WalletProfile`（fingerprint、公开 descriptor、账户 xpub、首地址）。profile
不含任何签名能力，但泄露后可以完整还原钱包的地址集合与交易历史，属于隐私
数据而非资金风险。

## 决策

v0.1 保持 profile 明文存储，理由：

- 锁屏页（`UnlockView`）需要在解锁前展示 fingerprint 与网络，供用户确认
  设备身份；加密 profile 将迫使锁屏页失去这一确认能力，或引入一把无需
  用户在场即可使用的第二把密钥——后者会稀释"Keychain 项仅在认证后可读"
  的单一模型。
- 文件本身受 `completeFileProtection` 与备份排除保护；设备锁定时不可读。
- profile 同时作为 AES-GCM 的 AAD 绑定密文，明文可见性不降低密文安全性。

## 后果

- 设备解锁状态下取得文件系统访问权的攻击者可以读取 xpub 并监控钱包。
  该威胁已记录在 SECURITY-BASELINE 的威胁表中（设备被攻破一档）。
- 若未来锁屏页确认需求消失，可重新评估对 profile 的独立加密。
