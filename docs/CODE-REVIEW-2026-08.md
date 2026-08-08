# Coldbank / ColdSigner 整体代码评审（2026-08）

本文是对仓库 `main`（截至 commit `1077388`）的整体评审：总结现状、指出不足、给出改进路径，并回答"如何做到安全稳定的 iPhone 冷钱包方案"。发现按优先级排列，P0 为发布前必须处理，P1 为强烈建议，P2 为可择机改进。

---

## 一、总体评价

这个仓库的工程质量明显高于同类早期项目。值得肯定的地方：

- **威胁模型诚实且成文**（`docs/SECURITY-BASELINE.md`）：明确承认 Secure Enclave 不能做 secp256k1 签名、内存零化只能尽力而为、iOS 无法保证无电磁路径。产品文案不超卖安全性，这在钱包项目里非常少见。
- **PSBT 策略引擎是双源交叉验证**：自研 `StrictPSBTStructureParser` 与 BDK 的解析结果互相比对，输入所有权用 fingerprint + 派生路径 + 派生出的 scriptPubKey 三重匹配，change 输出必须本地重新派生证明，签名前用 SHA-256 commitment 重校验，签名后再对签名结果做结构不变性断言（`PSBTSigner.swift:114-137`）。这是教科书级别的纵深防御。
- **密钥生命周期设计合理**：AES-GCM + profile 作为 AAD 绑定密文与钱包身份；包裹密钥存 Keychain（`ThisDeviceOnly` + `userPresence`）；vault 文件 `completeFileProtection` + 排除备份；重装残留 Keychain 项在新建时主动清理（`IOSWalletVault.swift:40-41`）。
- **传输层有界**：BC-UR/BBQr 均有分片数、字节数上限，格式中途切换强制重扫，会话 60 秒超时清内存。
- **工程纪律**：Swift 6 + warnings-as-errors、依赖精确 pin、CI 覆盖 macOS/iOS/coordinator 三条线、`verify_no_network.sh` 静态扫描禁网 API、无剪贴板/无分享/无日志泄露路径、`MnemonicPhrase` 的 `description` 强制脱敏。
- **架构选择正确**：离线签名器 + 在线 watch-only 协调器（PWA），私钥永不触网；协调器只是"不被信任的提案方"，签名器独立解析并展示每个输出。

结论：**方向和骨架是对的，主要差距不在"写错了什么"，而在"还缺什么"——设备端验证、独立审计、可复现构建，以及下面列出的具体问题。**

---

## 二、问题清单

### P0-1 解锁流程不必要地解密种子

`AppModel.unlock()`（`ColdSignerApp/App/AppModel.swift:38-52`）调用 `vault.unlock()`，后者会**完整解密助记词**并返回 `WalletSetup`，但 `AppModel` 只用了其中的 `profile`，随即丢弃明文助记词。也就是说：用户每次解锁 App 进入首页，种子都会在内存中出现一次，而这次解密没有任何用途——真正签名时 `PSBTScannerModel.sign()` 会再次调用 `vault.unlock()`。

**影响**：违反自家安全基线第 4 条"decrypt as late as possible"。每多一次解密就多一次内存暴露窗口（且 Swift 值语义下 `WalletSetup` 副本无法可靠零化）。

**改法**：在 `WalletVault` 协议中拆出 `authenticate(localizedReason:) async throws`（只做 Keychain 读取验证 + 丢弃密钥，或干脆只做 `LAContext` 评估），`unlock()` 保留给签名路径专用。`UnlockView` 走 `authenticate`。

### P0-2 review 与 sign 的 UTXO 策略不一致

`PSBTPolicyEngine.resolvedUTXO`（`PSBTPolicyEngine.swift:245-275`）允许 witness-only 输入（`witnessUtxo ?? nonWitnessOutput`），而 `PSBTSigner.sign` 要求**每个输入同时具备** non-witness UTXO 和 witness UTXO（`PSBTSigner.swift:45-49`），BDK 在 `trustWitnessUtxo: false` 下也要求完整前序交易。

**影响**：一个 witness-only 的 PSBT 会通过审核、展示给用户确认，然后在签名时才失败。这不是资金安全漏洞（fail-closed），但它意味着策略存在两个真相来源，用户看到的"已审核"并不等于"可签名"。

**改法**：把"所有输入必须携带 non-witness UTXO（且与 witness UTXO 金额/脚本一致）"这条规则前移到 `review()` 中，`sign()` 里保留同一断言作为纵深。同时给协调器加对应的构造约束和 fixture。

### P0-3 包裹密钥是裸 AES 密钥，未经 Secure Enclave 包裹

`KeychainWrappingKeyStore.create()` 用 `SecRandomCopyBytes` 生成 32 字节裸密钥，直接以 `kSecValueData` 存入 Keychain。这依赖 Keychain 的软件访问控制；密钥本身从未被硬件绑定。

**改法**：用 Secure Enclave 生成一把 P-256 密钥（`kSecAttrTokenIDSecureEnclave` + `SecAccessControlCreateWithFlags(.privateKeyUsage | .userPresence)`），对 DEK 做 ECIES 包裹（`SecKeyCreateEncryptedData` / `eciesEncryptionCofactorX963SHA256AESGCM`），Keychain 里只存包裹后的密文。这样即使 Keychain 数据被离线提取，没有该台设备的 SE 也无法解出 DEK——把"提取种子"从软件问题变成硬件问题。README 里"不声称密钥在 SE 内"的诚实表述可以保留，但 DEK 包裹是当前架构下能拿到的最大增量，成本很低。

顺带评估 `.userPresence` vs `.biometryCurrentSet`：前者允许纯密码回退、且生物特征录入变化后不失效。至少应写一条 ADR 记录这个取舍；若面向高价值用户，提供"绑定当前生物特征"的可选项。

### P1-1 协调器 CSP 允许 `unsafe-inline` 脚本

`Coordinator/worker/index.ts:367`：`script-src 'self' 'unsafe-inline'`。协调器虽然拿不到私钥，但它决定用户"看到什么收款地址、构造什么交易"，XSS 可以在构造阶段替换地址（签名器审核是最后防线，但用户可能照抄协调器展示的地址去比对）。**改法**：改用 hash/nonce-based CSP；vinext/Next 的内联脚本可以枚举出 hash。上线前做一次 `wrangler` 产物审计。

### P1-2 worker 上游响应大小依赖 `content-length` 头

`relayJSON`（`worker/index.ts:133-135`）只检查 `content-length` 头；chunked 响应没有该头即通过，随后 `response.json()` 无界读取。`relayText` 是读完才检查。**改法**：用 `response.body` 流式读取并在累计超过上限时 abort。同时给 `/broadcast` 加基本速率限制（Cloudflare rate limiting rule 即可）。

### P1-3 禁网扫描存在盲区

`scripts/verify_no_network.sh` 的正则覆盖了 `URLSession`/`Network`/`NWConnection` 等，但检不到：Darwin 层 `socket()/connect()/getaddrinfo`、`dlopen` 动态加载、`NWListener`、`CFStream`（`CFSocket` 之外的变体）。它也只扫第一方源码，不扫依赖（文档已注明靠发布审查）。**改法**：把发布审查里"检查最终二进制链接的框架与符号"落成脚本：对 `.ipa` 产物跑 `nm`/`otool -L` 断言不链接 `libnetwork`、`CFNetwork`、`Network.framework`，并把它加入发布 checklist 的机器可验证部分。

### P1-4 内存中的助记词大量经过 String

`unsafeJoinedWords`、`words.joined(separator:)`（`PSBTSigner.swift:51-53`、`AESGCMSeedCipher.swift:20`）、`String(data:)` 解密路径——Swift `String` 不可零化且会被 COW 复制。基线文档已承认这是残余风险，但可以再收窄：核心路径尽量以 `Data`/`ContiguousBytes` 传递，`MnemonicPhrase` 内部持有 `Data` 而非 `[String]`，只在 UI 显示的一刻转 String；BDK 接口需要 String 的地方无法避免，注明即可。

### P1-5 主网硬编码，测试网无法在 App 内走通

`OnboardingModel.createWallet/restoreWallet` 固定 `network: .bitcoin`，而 M4 里程碑要求"funded testnet PWA round trip"，协调器也支持 testnet。当前 App 无法创建 testnet 钱包，端到端演练只能靠 fixture。**改法**：加一个仅 Debug/内部构建可见的网络选择（Release 强制 mainnet），否则 M4 的验收门无法真正执行。

### P2（择机改进）

- **锁定策略固定**：120 秒自动锁、60 秒签名会话超时均为硬编码；活动检测只有 `DragGesture`。可配置化（只允许更严不允许更松）。
- **vault 文件中 profile 为明文**：xpub/描述符/首地址未加密（有 `completeFileProtection`，但设备解锁状态下可读）。泄露的是隐私（全部交易历史可查）而非资金。可考虑对 profile 也加密，代价是锁屏页无法显示钱包指纹——记一条 ADR 说明取舍即可。
- **缺 `com.apple.developer.default-data-protection` entitlement**：目前逐文件设置 complete protection，加上全局 entitlement 是零成本的双保险。
- **备份验证只抽 3 词且无失败次数限制**：从纸质备份抽验 3 词对"抄错"的检出率有限（尤其 24 词）。建议 24 词抽 4-6 个，或增加"全量重输验证"选项。
- **签名器缺任意索引收款地址验证 UI**：目前只展示首地址。用户核对协调器给出的第 N 个收款地址时没有离线依据。这是对"协调器展示假地址"威胁的直接补强，建议进 v0.2。
- **无 BIP39 passphrase 支持**：路线图问题，但威胁模型里"设备被物理提取"一档，passphrase 是唯一还能顶住的层。
- **费率/输出数警戒阈值硬编码**（100k sats、100 sat/vB、20 outputs）：v0.1 可接受，注明来源即可。

---

## 三、如何做到"安全稳定的 iPhone 冷钱包"——整体方案

把它分成五层，本仓库已覆盖的标注 ✅：

**1. 设备与操作层（决定下限）**
- 专机专用：一台重置过的备用 iPhone，只装 ColdSigner，永不登录 iCloud、不装其他 App ✅（文档已写入操作清单）
- 首次配置后：抹除网络设置 → 飞行模式 + 关 Wi-Fi/蓝牙/AirDrop/热点 → 不插 SIM。系统更新视为"临时回到联网信任域"，更新后重新走离线检查 ✅（SECURITY-BASELINE 已覆盖）
- 强密码（非 6 位数字）、生物特征、10 次错误抹除。这些应做成 App 内的 Readiness 检查项提示（目前 `ReadinessView` 可再加一步"检测到 SIM/网络状态"的自检——App 无法直接读 radio 状态，但可以用清单式确认）。

**2. 密钥层**
- 熵来源只用 OS CSPRNG ✅；DEK 用 Secure Enclave 包裹（P0-3，最重要的单项增量）；解密尽可能晚、次数尽可能少（P0-1）
- 备份：纸/金属板，抽验 + 可选全量复核；大额资产上 BIP39 passphrase 或直接换多签
- 明确告知用户：软件签名器 ≤ 硬件钱包 ≤ 多签，本项目最适合"中等金额 + 已有闲置 iPhone"的场景 ✅（README 已如实声明）

**3. 交易验证层（本仓库最强的一层）**
- 一切 PSBT 元数据视为待验证的声明 ✅；change 必须本地派生证明 ✅；费用本地计算 ✅；review-commitment 防 TOCTOU ✅
- 补强：统一 review/sign 策略（P0-2）、离线地址验证 UI（P2）、把 fuzz 语料持续扩充并在 CI 里跑 sanitizer

**4. 传输与协调层**
- 只走光学通道（QR），有界解码 ✅；协调器视为不可信 ✅
- 协调器自身仍要按"会被攻破"来加固：严格 CSP（P1-1）、上游响应限界（P1-2）、依赖 pin + `npm ci --ignore-scripts` ✅、广播 txid 回验 ✅
- 用户教育：地址核对以**签名器屏幕**为准，不以协调器为准

**5. 供应链与发布层（当前最大的缺口）**
- 可复现构建（或至少：发布 tag + 源码哈希 + 构建日志），TestFlight/自签发布策略成文
- 依赖升级必须过 ADR + 兼容性回归 ✅（已规定）；对最终 `.ipa` 做链接框架/符号断言（P1-3）
- **独立安全审计是"可用于真实资金"之前的硬门槛** ✅（IMPLEMENTATION-STATUS 已列为 non-negotiable）——这条不要妥协

---

## 四、建议的执行顺序

1. P0-1 拆分 `authenticate`/`unlock`（小改动，纯收益）
2. P0-2 统一 UTXO 策略到 review（小改动 + fixture）
3. P0-3 Secure Enclave 包裹 DEK（中等改动，需真机测试 Keychain/SE 组合，基线文档已预留"失败必须阻断激活，不得静默降级"的要求）
4. P1-1/P1-2 协调器 CSP 与响应限界
5. P1-3 二进制级禁网断言进发布脚本
6. P1-5 Debug 构建开放 testnet，把 M4 的真机往返验收真正跑起来
7. 其余 P2 按 v0.2 路线图排期

以上改动均未在本次评审中直接实施：签名路径的任何修改都应在具备 Xcode + 真机验证条件下进行，并附带对应测试与 fixture 更新。
