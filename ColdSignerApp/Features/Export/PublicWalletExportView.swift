import ColdSignerCore
import SwiftUI

struct PublicWalletExportView: View {
    enum Payload: String, CaseIterable, Identifiable {
        case receiveDescriptor = "收款 descriptor"
        case changeDescriptor = "找零 descriptor"
        case accountXpub = "账户 xpub"

        var id: String { rawValue }
    }

    let profile: WalletProfile
    @State private var payload: Payload = .receiveDescriptor

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                FlowHeader(
                    title: "导出只读钱包",
                    subtitle: "这些数据不能签名，但会暴露钱包地址和交易隐私。请在 Sparrow 中核对 fingerprint 与首个地址。"
                )

                ProfileSummaryCard(profile: profile)

                Picker("导出内容", selection: $payload) {
                    ForEach(Payload.allCases) { item in
                        Text(item.rawValue).tag(item)
                    }
                }
                .pickerStyle(.segmented)

                StaticQRCodeView(value: selectedValue)
                    .frame(maxWidth: 360)
                    .frame(maxWidth: .infinity)

                VStack(alignment: .leading, spacing: 8) {
                    Text(payload.rawValue)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Text(selectedValue)
                        .font(.caption2.monospaced())
                        .textSelection(.disabled)
                }
                .padding(14)
                .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 14))

                NoticeCard(
                    title: "不包含私钥",
                    message: "ColdSigner 只导出带 origin 与 checksum 的公开 descriptor 或账户 xpub，不提供 xprv、助记词、复制或分享按钮。",
                    systemImage: "checkmark.shield.fill"
                )
            }
            .padding(24)
        }
        .navigationTitle("只读导出")
        .navigationBarTitleDisplayMode(.inline)
    }

    private var selectedValue: String {
        switch payload {
        case .receiveDescriptor: profile.receiveDescriptor
        case .changeDescriptor: profile.changeDescriptor
        case .accountXpub: profile.accountExtendedPublicKey
        }
    }
}
