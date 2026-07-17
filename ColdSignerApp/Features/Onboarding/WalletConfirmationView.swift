import ColdSignerCore
import SwiftUI

struct WalletConfirmationView: View {
    let profile: WalletProfile
    let isWorking: Bool
    let errorMessage: String?
    let onCancel: () -> Void
    let activate: () async -> Void
    @State private var confirmsFingerprint = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                FlowHeader(
                    title: "确认钱包身份",
                    subtitle: "以后与 Sparrow 配对时，必须再次核对同一个 master fingerprint。"
                )

                ProfileSummaryCard(profile: profile)

                VStack(alignment: .leading, spacing: 8) {
                    Text("首个收款地址")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Text(profile.firstReceiveAddress)
                        .font(.footnote.monospaced())
                        .textSelection(.disabled)
                }
                .padding(16)
                .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 14))

                Toggle("我已记录 fingerprint，并理解必须在协调钱包上核对", isOn: $confirmsFingerprint)
                    .padding(14)
                    .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 14))

                if let errorMessage {
                    ErrorCard(message: errorMessage)
                }

                Button {
                    Task { await activate() }
                } label: {
                    if isWorking {
                        ProgressView()
                            .frame(maxWidth: .infinity)
                    } else {
                        Text("加密并激活签名器")
                            .frame(maxWidth: .infinity)
                    }
                }
                .buttonStyle(PrimaryButtonStyle())
                .disabled(!confirmsFingerprint || isWorking)

                Button("取消并清除", role: .destructive, action: onCancel)
                    .buttonStyle(SecondaryButtonStyle())
                    .disabled(isWorking)
            }
            .padding(24)
        }
    }
}
