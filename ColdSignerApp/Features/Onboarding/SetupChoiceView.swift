import ColdSignerCore
import SwiftUI

struct SetupChoiceView: View {
    @Binding var network: WalletProfile.Network
    let create: () -> Void
    let restore: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            FlowHeader(
                title: "设置签名器",
                subtitle: "每次安装仅支持一个 BIP84 单签钱包。"
            )

            ChoiceCard(
                title: "创建新钱包",
                detail: "使用系统安全随机数生成新的 12 或 24 个 BIP39 单词。",
                systemImage: "sparkles",
                action: create
            )

            ChoiceCard(
                title: "恢复已有钱包",
                detail: "使用本地单词键盘输入 12 或 24 个 BIP39 单词。",
                systemImage: "arrow.clockwise",
                action: restore
            )

            NoticeCard(
                title: "固定钱包策略",
                message: "v0.1 仅支持主网 BIP84 P2WPKH，账户路径 m/84'/0'/0'。",
                systemImage: "scope"
            )

            #if DEBUG
            VStack(alignment: .leading, spacing: 8) {
                Text("开发构建专用")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(.secondary)
                Picker("网络", selection: $network) {
                    Text(WalletProfile.Network.bitcoin.displayName)
                        .tag(WalletProfile.Network.bitcoin)
                    Text(WalletProfile.Network.testnet.displayName)
                        .tag(WalletProfile.Network.testnet)
                }
                .pickerStyle(.segmented)
                Text("Release 构建固定为主网；此选择器仅用于测试网端到端演练。")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
            .padding(14)
            .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 14))
            #endif

            Spacer()
        }
        .padding(24)
    }
}
