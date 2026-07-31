"use client";

import { useCallback, useEffect, useMemo, useRef, useState } from "react";
import { AnimatedQR } from "@/components/animated-qr";
import { QRScanner } from "@/components/qr-scanner";
import { BBQrDecoder, encodeBBQr } from "@/lib/bbqr";
import {
  broadcastTransaction,
  getFees,
  scanWallet,
  type FeeRecommendation,
  type WalletSnapshot,
} from "@/lib/chain";
import {
  createSpendPlan,
  finalizeSignedPSBT,
  type SpendPlan,
} from "@/lib/psbt";
import {
  formatBtc,
  parseBtcAmount,
  parsePublicAccount,
  type PublicAccount,
} from "@/lib/wallet";

const WALLET_STORAGE_KEY = "coldbank.public-account.v1";

type ScannerMode = "wallet" | "signed" | null;

function networkLabel(account: PublicAccount): string {
  return account.network === "bitcoin" ? "Bitcoin 主网" : "Bitcoin Testnet";
}

function explorerURL(account: PublicAccount, txid: string): string {
  const prefix = account.network === "bitcoin" ? "" : "/testnet";
  return `https://mempool.space${prefix}/tx/${txid}`;
}

export function Coordinator() {
  const [account, setAccount] = useState<PublicAccount | null>(null);
  const [walletInput, setWalletInput] = useState("");
  const [snapshot, setSnapshot] = useState<WalletSnapshot | null>(null);
  const [fees, setFees] = useState<FeeRecommendation | null>(null);
  const [syncProgress, setSyncProgress] = useState("");
  const [busy, setBusy] = useState(false);
  const [error, setError] = useState("");
  const [scannerMode, setScannerMode] = useState<ScannerMode>(null);
  const [scanProgress, setScanProgress] = useState("");
  const [recipient, setRecipient] = useState("");
  const [amount, setAmount] = useState("");
  const [feePreset, setFeePreset] =
    useState<keyof Pick<FeeRecommendation, "fastest" | "standard" | "economy">>(
      "standard",
    );
  const [plan, setPlan] = useState<SpendPlan | null>(null);
  const [frames, setFrames] = useState<string[]>([]);
  const [signed, setSigned] = useState<{
    rawTransactionHex: string;
    txid: string;
  } | null>(null);
  const [broadcasted, setBroadcasted] = useState<{
    txid: string;
    provider: string;
  } | null>(null);
  const decoderRef = useRef(new BBQrDecoder());

  useEffect(() => {
    const saved = window.localStorage.getItem(WALLET_STORAGE_KEY);
    let restoreTimer: number | undefined;
    if (saved) {
      try {
        const restored = parsePublicAccount(saved);
        restoreTimer = window.setTimeout(() => setAccount(restored), 0);
      } catch {
        window.localStorage.removeItem(WALLET_STORAGE_KEY);
      }
    }
    if ("serviceWorker" in navigator) {
      navigator.serviceWorker.register("/sw.js").catch(() => undefined);
    }
    return () => {
      if (restoreTimer !== undefined) window.clearTimeout(restoreTimer);
    };
  }, []);

  const synchronize = useCallback(async (current: PublicAccount) => {
    setBusy(true);
    setError("");
    setSyncProgress("正在读取公开地址…");
    try {
      const [wallet, recommendation] = await Promise.all([
        scanWallet(current, 20, (completed, total) =>
          setSyncProgress(`正在同步地址 ${completed}/${total}`),
        ),
        getFees(current.network),
      ]);
      setSnapshot(wallet);
      setFees(recommendation);
      setSyncProgress("");
    } catch (caught) {
      setError(caught instanceof Error ? caught.message : "同步失败。");
      setSyncProgress("");
    } finally {
      setBusy(false);
    }
  }, []);

  const importWallet = useCallback(
    (value: string) => {
      try {
        const parsed = parsePublicAccount(value);
        setAccount(parsed);
        setWalletInput(value.trim());
        window.localStorage.setItem(WALLET_STORAGE_KEY, value.trim());
        setSnapshot(null);
        setPlan(null);
        setSigned(null);
        setBroadcasted(null);
        setScannerMode(null);
        setError("");
        void synchronize(parsed);
      } catch (caught) {
        setError(caught instanceof Error ? caught.message : "公开钱包格式无效。");
      }
    },
    [synchronize],
  );

  const handleScan = useCallback(
    (value: string) => {
      if (scannerMode === "wallet") {
        importWallet(value);
        return;
      }
      if (scannerMode !== "signed" || !plan) return;
      try {
        const progress = decoderRef.current.receive(value);
        setScanProgress(`已扫描 ${progress.collected}/${progress.total} 帧`);
        if (progress.psbt) {
          const finalized = finalizeSignedPSBT(progress.psbt, plan);
          setSigned(finalized);
          setScannerMode(null);
          setScanProgress("");
          setError("");
        }
      } catch (caught) {
        setError(caught instanceof Error ? caught.message : "扫码失败。");
      }
    },
    [importWallet, plan, scannerMode],
  );

  const prepareTransaction = useCallback(() => {
    if (!account || !snapshot || !fees) return;
    try {
      const next = createSpendPlan(
        account,
        snapshot.coins,
        recipient,
        parseBtcAmount(amount),
        fees[feePreset],
        snapshot.nextChange,
      );
      setPlan(next);
      setFrames(encodeBBQr(next.psbt));
      setSigned(null);
      setBroadcasted(null);
      setError("");
    } catch (caught) {
      setError(caught instanceof Error ? caught.message : "无法创建交易。");
    }
  }, [account, amount, feePreset, fees, recipient, snapshot]);

  const startSignedScan = useCallback(() => {
    decoderRef.current.reset();
    setScanProgress("请对准离线 iPhone 上的签名 BBQr");
    setScannerMode("signed");
  }, []);

  const doBroadcast = useCallback(async () => {
    if (!account || !signed) return;
    setBusy(true);
    setError("");
    try {
      const result = await broadcastTransaction(
        account.network,
        signed.rawTransactionHex,
        signed.txid,
      );
      setBroadcasted(result);
      setPlan(null);
      setSigned(null);
      setFrames([]);
      setAmount("");
      setRecipient("");
      await synchronize(account);
    } catch (caught) {
      setError(caught instanceof Error ? caught.message : "广播失败。");
    } finally {
      setBusy(false);
    }
  }, [account, signed, synchronize]);

  const feeChoices = useMemo(
    () =>
      fees
        ? [
            { key: "fastest" as const, label: "快", value: fees.fastest },
            { key: "standard" as const, label: "标准", value: fees.standard },
            { key: "economy" as const, label: "省", value: fees.economy },
          ]
        : [],
    [fees],
  );

  function forgetWallet() {
    window.localStorage.removeItem(WALLET_STORAGE_KEY);
    setAccount(null);
    setSnapshot(null);
    setFees(null);
    setPlan(null);
    setSigned(null);
    setBroadcasted(null);
    setWalletInput("");
    setError("");
  }

  return (
    <main className="app-shell">
      <header className="topbar">
        <a className="brand" href="#" aria-label="Coldbank 首页">
          <span className="brand-mark" aria-hidden="true">
            C
          </span>
          <span>
            <strong>Coldbank</strong>
            <small>Air-gapped Bitcoin</small>
          </span>
        </a>
        <span className="status-pill">
          <i />
          私钥始终离线
        </span>
      </header>

      <section className="hero">
        <p className="eyebrow">两个 iPhone，一个简单流程</p>
        <h1>
          在线创建交易。
          <br />
          离线确认签名。
        </h1>
        <p className="hero-copy">
          不注册账户，不上传助记词。网页只保存公开钱包，离线 iPhone
          负责检查地址、金额和矿工费。
        </p>
        <div className="flow-strip" aria-label="使用流程">
          <span><b>1</b> 导入公开钱包</span>
          <i>→</i>
          <span><b>2</b> 创建 PSBT</span>
          <i>→</i>
          <span><b>3</b> 离线签名</span>
        </div>
      </section>

      <div className="warning-banner">
        <strong>Pre-alpha · 请先使用 Testnet</strong>
        <span>尚未完成独立安全审计，不建议存放真实资金。</span>
      </div>

      {!account ? (
        <section className="panel import-panel">
          <div className="panel-heading">
            <p className="step-label">步骤 1</p>
            <h2>连接离线钱包</h2>
            <p>
              在离线 iPhone 打开「导出只读钱包」，选择 Origin xpub
              并扫描。它不能用于花费比特币。
            </p>
          </div>
          <button
            className="primary-button"
            onClick={() => {
              setError("");
              setScannerMode("wallet");
            }}
          >
            <span aria-hidden="true">⌗</span>
            扫描公开钱包
          </button>
          <details className="manual-entry">
            <summary>无法使用相机？手动输入</summary>
            <textarea
              value={walletInput}
              onChange={(event) => setWalletInput(event.target.value)}
              placeholder="[73C5DA0A/84h/1h/0h]tpub…"
              spellCheck={false}
            />
            <button
              className="secondary-button"
              onClick={() => importWallet(walletInput)}
            >
              验证并导入
            </button>
          </details>
        </section>
      ) : (
        <>
          <section className="wallet-bar">
            <div>
              <p className="step-label">已连接公开钱包</p>
              <h2>{networkLabel(account)}</h2>
            </div>
            <dl>
              <div>
                <dt>Fingerprint</dt>
                <dd>{account.fingerprintHex}</dd>
              </div>
              <div>
                <dt>路径</dt>
                <dd>{account.accountPathLabel}</dd>
              </div>
            </dl>
            <button className="text-button" onClick={forgetWallet}>
              移除
            </button>
          </section>

          <section className="dashboard-grid">
            <article className="panel balance-card">
              <div className="card-topline">
                <span>可用余额</span>
                <button
                  className="refresh-button"
                  disabled={busy}
                  onClick={() => void synchronize(account)}
                >
                  {busy ? "同步中…" : "刷新"}
                </button>
              </div>
              <strong className="balance">
                {snapshot ? formatBtc(snapshot.balance) : "—"}
                <small> BTC</small>
              </strong>
              <p className="provider-note">
                {syncProgress ||
                  (snapshot
                    ? `${snapshot.coins.length} 个 UTXO · ${snapshot.provider}`
                    : "尚未同步")}
              </p>
            </article>

            <article className="panel receive-card">
              <div className="card-topline">
                <span>下一个收款地址</span>
                <span className="safe-label">只读</span>
              </div>
              <p className="address">
                {snapshot?.nextReceive.address ?? "同步后显示"}
              </p>
              <small>{snapshot?.nextReceive.pathLabel}</small>
            </article>
          </section>

          <section className="panel send-panel">
            <div className="panel-heading compact">
              <p className="step-label">步骤 2</p>
              <h2>创建交易</h2>
              <p>只支持一个收款人。最终内容以离线 iPhone 显示为准。</p>
            </div>
            <div className="form-grid">
              <label className="field wide">
                <span>收款地址</span>
                <input
                  value={recipient}
                  onChange={(event) => setRecipient(event.target.value.trim())}
                  placeholder={
                    account.network === "bitcoin" ? "bc1q…" : "tb1q…"
                  }
                  autoCapitalize="none"
                  autoCorrect="off"
                  spellCheck={false}
                />
              </label>
              <label className="field">
                <span>金额</span>
                <div className="input-suffix">
                  <input
                    value={amount}
                    onChange={(event) => setAmount(event.target.value)}
                    placeholder="0.001"
                    inputMode="decimal"
                  />
                  <b>BTC</b>
                </div>
              </label>
              <fieldset className="fee-field">
                <legend>矿工费率</legend>
                <div className="segmented">
                  {feeChoices.map((choice) => (
                    <button
                      key={choice.key}
                      type="button"
                      className={feePreset === choice.key ? "active" : ""}
                      onClick={() => setFeePreset(choice.key)}
                    >
                      <strong>{choice.label}</strong>
                      <small>{choice.value} sat/vB</small>
                    </button>
                  ))}
                </div>
              </fieldset>
            </div>
            <button
              className="primary-button"
              disabled={!snapshot || !fees || busy}
              onClick={prepareTransaction}
            >
              创建待签名交易
            </button>
          </section>
        </>
      )}

      {plan && (
        <section className="signing-panel">
          <div className="signing-copy">
            <p className="step-label light">步骤 3</p>
            <h2>用离线 iPhone 扫描</h2>
            <p>
              离线设备会独立显示收款地址、金额和费用。逐项核对后再签名。
            </p>
            <dl className="transaction-summary">
              <div><dt>发送</dt><dd>{formatBtc(plan.amount)} BTC</dd></div>
              <div><dt>矿工费</dt><dd>{plan.fee.toString()} sats</dd></div>
              <div><dt>费率</dt><dd>{plan.feeRate} sat/vB</dd></div>
              <div><dt>输入</dt><dd>{plan.selected.length}</dd></div>
            </dl>
            {!signed ? (
              <button className="light-button" onClick={startSignedScan}>
                扫描签名结果
              </button>
            ) : (
              <div className="signed-actions">
                <p className="success-message">✓ 签名和原交易完全匹配</p>
                <button
                  className="light-button"
                  disabled={busy}
                  onClick={() => void doBroadcast()}
                >
                  {busy ? "正在广播…" : "广播交易"}
                </button>
              </div>
            )}
          </div>
          <AnimatedQR frames={frames} />
        </section>
      )}

      {broadcasted && account && (
        <section className="success-panel">
          <span className="success-icon">✓</span>
          <div>
            <p className="step-label">广播完成 · {broadcasted.provider}</p>
            <h2>交易已提交</h2>
            <a
              href={explorerURL(account, broadcasted.txid)}
              target="_blank"
              rel="noreferrer"
            >
              在 mempool.space 查看 {broadcasted.txid.slice(0, 12)}…
            </a>
          </div>
        </section>
      )}

      {error && (
        <div className="toast" role="alert">
          <strong>操作未完成</strong>
          <span>{error}</span>
          <button onClick={() => setError("")} aria-label="关闭提示">×</button>
        </div>
      )}

      <QRScanner
        open={scannerMode !== null}
        title={scannerMode === "wallet" ? "扫描 Origin xpub" : "扫描签名结果"}
        hint={
          scannerMode === "wallet"
            ? "公开钱包是静态二维码，只需扫描一次。"
            : "保持相机对准动画二维码，直到所有帧收集完成。"
        }
        progress={scannerMode === "signed" ? scanProgress : undefined}
        onResult={handleScan}
        onClose={() => {
          decoderRef.current.reset();
          setScannerMode(null);
          setScanProgress("");
        }}
      />

      <footer>
        <span>Coldbank 是开源的 air-gapped software signer。</span>
        <span>助记词和私钥永不进入本网页。</span>
      </footer>
    </main>
  );
}
