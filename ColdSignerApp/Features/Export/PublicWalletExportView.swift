import ColdSignerCore
import SwiftUI

struct PublicWalletExportView: View {
    enum Payload: String, CaseIterable, Identifiable {
        case originAccountKey = "Origin xpub"
        case bip84Zpub = "BIP84 zpub"
        case receiveDescriptor = "收款 descriptor"
        case changeDescriptor = "找零 descriptor"
        case accountXpub = "原始账户 xpub"

        var id: String { rawValue }

        var guidance: String {
            switch self {
            case .originAccountKey:
                "含 fingerprint 与 BIP84 origin；用于 Nunchuk Air-gapped key，也可在支持 key-origin 的协调器中导入。"
            case .bip84Zpub:
                "BIP84/SLIP-132 版本字节；用于 BlueWallet watch-only 导入。"
            case .receiveDescriptor:
                "带 origin 与 checksum 的外部分支 descriptor；用于 Sparrow 核对或高级导入。"
            case .changeDescriptor:
                "带 origin 与 checksum 的找零分支 descriptor；必须与收款 descriptor 成对核对。"
            case .accountXpub:
                "标准 BIP32 xpub/tpub。只在协调器明确要求时使用，并手动指定 BIP84 路径。"
            }
        }
    }

    let profile: WalletProfile
    @State private var payload: Payload = .originAccountKey

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                FlowHeader(
                    title: "导出只读钱包",
                    subtitle: "这些数据不能签名，但会暴露钱包地址和交易隐私。导入后必须核对 fingerprint 与首个地址。"
                )

                ProfileSummaryCard(profile: profile)

                Picker("协调器格式", selection: $payload) {
                    ForEach(Payload.allCases) { item in
                        Text(item.rawValue).tag(item)
                    }
                }
                .pickerStyle(.menu)
                .frame(maxWidth: .infinity, alignment: .leading)

                StaticQRCodeView(value: selectedValue)
                    .frame(maxWidth: 360)
                    .frame(maxWidth: .infinity)

                VStack(alignment: .leading, spacing: 8) {
                    Text(payload.rawValue)
                        .font(.caption.weight(.bold))
                        .foregroundStyle(.secondary)
                    Text(selectedValue)
                        .font(.caption2.monospaced())
                        .textSelection(.disabled)
                    Text(payload.guidance)
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
                .padding(14)
                .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 14))

                NoticeCard(
                    title: "不包含私钥",
                    message: "只导出公开 descriptor、账户 xpub/zpub 与 key origin；不提供 xprv、助记词、复制或分享按钮。",
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
        case .originAccountKey:
            WalletPublicExport.originAccountKey(profile: profile)
        case .bip84Zpub:
            (try? WalletPublicExport.bip84Slip132AccountKey(profile: profile))
                ?? profile.accountExtendedPublicKey
        case .receiveDescriptor:
            profile.receiveDescriptor
        case .changeDescriptor:
            profile.changeDescriptor
        case .accountXpub:
            profile.accountExtendedPublicKey
        }
    }
}
