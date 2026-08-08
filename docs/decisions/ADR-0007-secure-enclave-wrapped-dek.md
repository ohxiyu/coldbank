# ADR-0007: 种子数据加密密钥由 Secure Enclave 包裹

## 状态

已接受（2026-08）

## 背景

v0.1 最初把 32 字节 AES-GCM 数据加密密钥（DEK）作为 Keychain generic
password 直接存储（`ThisDeviceOnly` + `userPresence`）。该设计依赖 Keychain
的软件访问控制：任何能离线提取 Keychain 数据的攻击者可以直接获得 DEK。

Secure Enclave 不支持 secp256k1，不能充当 Bitcoin 签名器（见
SECURITY-BASELINE 的诚实硬件声明），但它可以持有一把 P-256 密钥为 DEK
做 ECIES 包裹，使"提取种子"从软件问题变成必须攻破该台设备 SE 的硬件问题。

## 决策

- 激活时生成 SE 内 P-256 密钥（`kSecAttrTokenIDSecureEnclave`，
  `privateKeyUsage + userPresence`，`WhenPasscodeSetThisDeviceOnly`）。
- DEK 用 `eciesEncryptionCofactorVariableIVX963SHA256AESGCM` 包裹后存入
  Keychain（service `org.coldsigner.seed-wrapping-key.v2`）；裸 DEK 不落盘。
- 解包需要 SE 私钥使用权，由系统在解密时触发设备所有者认证。
- 没有可用 SE 的设备（或密钥创建失败）**阻断钱包激活**，不静默降级为
  软件密钥。
- 删除路径同时清理 v2 包裹密文、SE 密钥与遗留 v1 明文密钥项。

## 后果

- 预发布阶段无正式用户，v1 → v2 不提供迁移；旧开发安装需要重新恢复钱包。
- SE 密钥不可备份、不随设备迁移——这正是设计意图：vault 只在这台设备上
  可解，纸质助记词备份仍是唯一恢复途径。
- 真机上的 Keychain/SE 行为矩阵（含认证失败、密钥被系统淘汰等）仍需
  M1 的两设备验证覆盖。
