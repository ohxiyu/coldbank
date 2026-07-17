import ColdSignerCore
import SwiftUI

struct PSBTScannerView: View {
    let profile: WalletProfile

    @StateObject private var model = PSBTScannerModel()
    @State private var cameraAccess: CameraAccessState = .checking
    @State private var cameraError: String?
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(spacing: 18) {
            if let byteCount = model.completedPSBTByteCount {
                completion(byteCount: byteCount)
            } else {
                scanner
            }
        }
        .padding(20)
        .navigationTitle("扫描 PSBT")
        .navigationBarTitleDisplayMode(.inline)
        .task {
            cameraAccess = await CameraQRCodeScannerView.requestAccess()
        }
        .onDisappear {
            model.cancel()
        }
    }

    @ViewBuilder
    private var scanner: some View {
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
                title: "只接受 PSBT UR",
                message: "支持 crypto-psbt 与 psbt。相机画面不会保存；取消或离开后会清空未完成片段。",
                systemImage: "lock.shield"
            )
        }

        Button("取消扫描") {
            model.cancel()
            dismiss()
        }
        .buttonStyle(SecondaryButtonStyle())
    }

    private func completion(byteCount: Int) -> some View {
        VStack(spacing: 20) {
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 54))
                .foregroundStyle(.green)

            Text("BC-UR 扫描完成")
                .font(.title2.bold())

            VStack(spacing: 10) {
                LabeledContent("PSBT 大小", value: "\(byteCount) bytes")
                if let digest = model.completedPSBTDigest {
                    LabeledContent("摘要", value: digest)
                        .font(.body.monospaced())
                }
                LabeledContent("钱包", value: profile.fingerprint)
                    .font(.body.monospaced())
            }
            .padding(16)
            .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 16))

            NoticeCard(
                title: "尚未审查或签名",
                message: "当前只验证了光学传输与 PSBT 文件头。M3 策略引擎完成前，应用不会解析交易含义或生成签名。",
                systemImage: "hand.raised.fill"
            )

            Button("完成并清空") {
                model.cancel()
                dismiss()
            }
            .buttonStyle(PrimaryButtonStyle())

            Button("扫描另一个") {
                model.restart()
            }
            .buttonStyle(SecondaryButtonStyle())
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
}
