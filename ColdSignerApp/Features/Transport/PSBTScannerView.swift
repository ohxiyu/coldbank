import ColdSignerCore
import SwiftUI
import UIKit

struct PSBTScannerView: View {
    let profile: WalletProfile
    let vault: any WalletVault

    @StateObject private var model: PSBTScannerModel
    @State private var cameraAccess: CameraAccessState = .checking
    @State private var cameraError: String?
    @State private var framesPerSecond = 5.0
    @State private var originalBrightness: CGFloat?
    @State private var usesMaximumBrightness = false
    @Environment(\.dismiss) private var dismiss
    @Environment(\.scenePhase) private var scenePhase

    init(profile: WalletProfile, vault: any WalletVault) {
        self.profile = profile
        self.vault = vault
        _model = StateObject(
            wrappedValue: PSBTScannerModel(profile: profile, vault: vault)
        )
    }

    var body: some View {
        Group {
            if let signedPSBT = model.signedPSBT {
                signedResult(signedPSBT)
            } else if let review = model.review {
                transactionReview(review)
            } else {
                scanner
                    .padding(20)
            }
        }
        .navigationTitle(navigationTitle)
        .navigationBarTitleDisplayMode(.inline)
        .task {
            cameraAccess = await CameraQRCodeScannerView.requestAccess()
        }
        .onChange(of: scenePhase) { phase in
            guard phase != .active else { return }
            model.cancel()
            restoreBrightness()
        }
        .onDisappear {
            model.cancel()
            restoreBrightness()
        }
        .sensitiveCaptureShield()
    }

    private var navigationTitle: String {
        if model.signedPSBT != nil { return "返回签名 PSBT" }
        if model.review != nil { return "复核交易" }
        return "扫描 PSBT"
    }

    @ViewBuilder
    private var scanner: some View {
        VStack(spacing: 18) {
            ZStack {
                RoundedRectangle(cornerRadius: 20)
                    .fill(.black)
                    .aspectRatio(1, contentMode: .fit)

                switch cameraAccess {
                case .checking:
                    ProgressView("正在检查相机权限…")
                case .authorized:
                    CameraQRCodeScannerView(
                        onCode: model.receive,
                        onFailure: { cameraError = $0 }
                    )
                    .clipShape(RoundedRectangle(cornerRadius: 20))
                    .aspectRatio(1, contentMode: .fit)

                    Image(systemName: "viewfinder")
                        .resizable()
                        .scaledToFit()
                        .foregroundStyle(.white.opacity(0.85))
                        .padding(54)
                        .allowsHitTesting(false)
                case .denied:
                    cameraMessage("请在系统设置中允许 ColdSigner 使用相机。")
                case .unavailable:
                    cameraMessage("这台设备没有可用的二维码相机。")
                }
            }

            VStack(spacing: 8) {
                ProgressView(value: model.percentComplete)
                HStack {
                    Text("已处理 \(model.processedPartCount) 帧")
                    Spacer()
                    if let expected = model.expectedPartCount {
                        Text("目标约 \(expected) 片")
                    } else {
                        Text("等待 BC-UR")
                    }
                }
                .font(.caption.monospacedDigit())
                .foregroundStyle(.secondary)
            }

            if let message = model.errorMessage ?? cameraError {
                ErrorCard(message: message)
                Button("重新开始") {
                    cameraError = nil
                    model.restart()
                }
                .buttonStyle(SecondaryButtonStyle())
            } else {
                NoticeCard(
                    title: "扫描后先复核，绝不直接签名",
                    message: "只接受受限 PSBT v0。相机画面不会保存；无效、取消、超时或离开页面都会清空内存状态。",
                    systemImage: "lock.shield"
                )
            }

            Button("取消扫描") {
                model.cancel()
                dismiss()
            }
            .buttonStyle(SecondaryButtonStyle())
        }
    }

    private func transactionReview(_ review: PSBTReview) -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                VStack(alignment: .leading, spacing: 5) {
                    Text("你将发送")
                        .font(.caption.weight(.bold))
                        .foregroundStyle(.secondary)
                    Text(bitcoinAmount(review.outgoingSatoshis))
                        .font(.largeTitle.monospacedDigit().bold())
                    Text("\(review.outgoingSatoshis.formatted()) sats")
                        .font(.body.monospacedDigit())
                        .foregroundStyle(.secondary)
                }

                reviewSection("收款输出（\(review.recipients.count)）") {
                    ForEach(review.recipients, id: \.index) { output in
                        outputRow(output)
                    }
                }

                if !review.warnings.isEmpty {
                    VStack(alignment: .leading, spacing: 10) {
                        Text("必须逐项确认")
                            .font(.headline)
                        ForEach(review.warnings, id: \.self) { warning in
                            NoticeCard(
                                title: warningTitle(warning),
                                message: warningMessage(warning),
                                systemImage: "exclamationmark.triangle.fill"
                            )
                        }
                    }
                }

                reviewSection("矿工费") {
                    LabeledContent("绝对费用", value: "\(review.feeSatoshis.formatted()) sats")
                    LabeledContent(
                        "估算费率",
                        value: String(format: "%.2f sat/vB", review.estimatedFeeRate)
                    )
                    Text("费率基于 P2WPKH 签名后大小估算；绝对费用来自已验证输入。")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                reviewSection("已验证找零（\(review.change.count)）") {
                    if review.change.isEmpty {
                        Text("无找零输出")
                            .foregroundStyle(.secondary)
                    } else {
                        ForEach(review.change, id: \.index) { output in
                            outputRow(output)
                        }
                    }
                }

                DisclosureGroup("技术详情") {
                    VStack(spacing: 10) {
                        LabeledContent("输入 / 输出", value: "\(review.inputCount) / \(review.outputCount)")
                        LabeledContent("交易版本", value: "\(review.transactionVersion)")
                        LabeledContent("Locktime", value: "\(review.lockTime)")
                        LabeledContent("PSBT 摘要", value: review.commitment.displayValue)
                        LabeledContent("钱包 fingerprint", value: profile.fingerprint)
                        LabeledContent("网络", value: review.network.displayName)
                    }
                    .font(.subheadline.monospacedDigit())
                    .padding(.top, 12)
                }
                .padding(16)
                .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 16))

                if let message = model.errorMessage {
                    ErrorCard(message: message)
                }

                HoldToSignControl(isBusy: model.isSigning) {
                    Task { await model.sign() }
                }

                Text("长按完成后才会请求 Face ID / Touch ID / 设备密码；认证成功后会再次验证同一份 PSBT，再调用签名库。")
                    .font(.footnote)
                    .foregroundStyle(.secondary)

                Button("取消并清空") {
                    model.cancel()
                    dismiss()
                }
                .buttonStyle(SecondaryButtonStyle())
            }
            .padding(20)
        }
    }

    private func signedResult(_ signedPSBT: Data) -> some View {
        ScrollView {
            VStack(spacing: 18) {
                Image(systemName: "checkmark.shield.fill")
                    .font(.system(size: 44))
                    .foregroundStyle(.green)

                Text("已生成部分签名 PSBT")
                    .font(.title2.bold())
                Text("已签名 \(model.signedInputCount ?? 0) 个钱包输入；ColdSigner 未 finalize，也不会广播。")
                    .multilineTextAlignment(.center)
                    .foregroundStyle(.secondary)

                AnimatedPSBTQRCodeView(
                    psbt: signedPSBT,
                    framesPerSecond: framesPerSecond
                )

                Picker("帧率", selection: $framesPerSecond) {
                    Text("2 fps").tag(2.0)
                    Text("5 fps").tag(5.0)
                    Text("10 fps").tag(10.0)
                }
                .pickerStyle(.segmented)

                Button(usesMaximumBrightness ? "恢复屏幕亮度" : "二维码最大亮度") {
                    toggleBrightness()
                }
                .buttonStyle(SecondaryButtonStyle())

                NoticeCard(
                    title: "下一步在协调器中完成",
                    message: "让 Sparrow、BlueWallet 或 Nunchuk 扫描此二维码；由协调器检查签名、finalize 并广播。",
                    systemImage: "qrcode"
                )

                Button("完成并清空") {
                    model.cancel()
                    restoreBrightness()
                    dismiss()
                }
                .buttonStyle(PrimaryButtonStyle())
            }
            .padding(20)
        }
    }

    private func reviewSection<Content: View>(
        _ title: String,
        @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(title)
                .font(.headline)
            content()
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 16))
    }

    private func outputRow(_ output: PSBTReviewOutput) -> some View {
        VStack(alignment: .leading, spacing: 7) {
            HStack(alignment: .firstTextBaseline) {
                Text("输出 #\(output.index + 1)")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(.secondary)
                Spacer()
                Text("\(output.valueSatoshis.formatted()) sats")
                    .font(.body.monospacedDigit().bold())
            }
            Text(output.destination)
                .font(.caption.monospaced())
                .fixedSize(horizontal: false, vertical: true)
            if let path = output.derivationPath {
                Label(path, systemImage: "checkmark.shield.fill")
                    .font(.caption.monospaced())
                    .foregroundStyle(.green)
            }
        }
        .padding(.vertical, 4)
    }

    private func bitcoinAmount(_ satoshis: UInt64) -> String {
        String(
            format: "%llu.%08llu BTC",
            satoshis / 100_000_000,
            satoshis % 100_000_000
        )
    }

    private func warningTitle(_ warning: PSBTReviewWarning) -> String {
        switch warning {
        case .highAbsoluteFee: "矿工费绝对值较高"
        case .highEstimatedFeeRate: "估算费率较高"
        case .manyOutputs: "输出数量较多"
        case .replaceByFeeEnabled: "交易启用了 RBF"
        case .lockTimeEnabled: "交易启用了 Locktime"
        case .walletReceiveOutput: "存在钱包收款分支输出"
        case .nonAddressOutput: "存在无法显示为地址的脚本输出"
        }
    }

    private func warningMessage(_ warning: PSBTReviewWarning) -> String {
        switch warning {
        case .highAbsoluteFee:
            "费用达到静态安全阈值；请与协调器显示值逐位核对。"
        case .highEstimatedFeeRate:
            "估算费率至少为 100 sat/vB；离线设备无法判断当前市场费率。"
        case .manyOutputs:
            "至少有 20 个输出；请逐项确认，没有任何输出被折叠。"
        case .replaceByFeeEnabled:
            "该交易可在广播后被更高费率版本替换。"
        case .lockTimeEnabled:
            "交易包含非默认时间锁；请确认这是协调器的预期设置。"
        case .walletReceiveOutput:
            "该输出回到收款分支而非找零分支，仍按非找零金额计入发送总额。"
        case .nonAddressOutput:
            "请依据脚本摘要核对；ColdSigner 不会把它伪装成普通地址。"
        }
    }

    private func cameraMessage(_ message: String) -> some View {
        VStack(spacing: 12) {
            Image(systemName: "camera.fill")
                .font(.title)
            Text(message)
                .multilineTextAlignment(.center)
                .foregroundStyle(.secondary)
        }
        .padding(24)
    }

    private func toggleBrightness() {
        if usesMaximumBrightness {
            restoreBrightness()
        } else {
            originalBrightness = UIScreen.main.brightness
            UIScreen.main.brightness = 1
            usesMaximumBrightness = true
        }
    }

    private func restoreBrightness() {
        if let originalBrightness {
            UIScreen.main.brightness = originalBrightness
        }
        originalBrightness = nil
        usesMaximumBrightness = false
    }
}

private struct HoldToSignControl: View {
    let isBusy: Bool
    let action: () -> Void

    @State private var isHolding = false

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 14)
                .fill(isHolding ? Color.orange : Color.blue)
            HStack(spacing: 10) {
                if isBusy {
                    ProgressView()
                        .tint(.white)
                } else {
                    Image(systemName: isHolding ? "lock.open.fill" : "hand.tap.fill")
                }
                Text(isBusy ? "正在认证并签名…" : isHolding ? "继续按住…" : "长按 1.5 秒签名")
                    .font(.headline)
            }
            .foregroundStyle(.white)
        }
        .frame(maxWidth: .infinity, minHeight: 56)
        .contentShape(RoundedRectangle(cornerRadius: 14))
        .opacity(isBusy ? 0.65 : 1)
        .allowsHitTesting(!isBusy)
        .onLongPressGesture(
            minimumDuration: 1.5,
            maximumDistance: 36,
            pressing: { holding in
                withAnimation(.easeInOut(duration: 0.15)) {
                    isHolding = holding
                }
            },
            perform: action
        )
        .accessibilityLabel("长按签名")
        .accessibilityHint("按住一秒半后请求设备所有者认证")
    }
}
