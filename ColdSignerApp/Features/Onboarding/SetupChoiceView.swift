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
                subtitle: "每次安装仅支持一个 BIP84 单签钱包。测试版默认使用 Testnet。"
            )

            VStack(alignment: .leading, spacing: 10) {
                Text("Bitcoin 网络")
                    .font(.headline)
                Picker("Bitcoin 网络", selection: $network) {
                    Text("Testnet 测试网").tag(WalletProfile.Network.testnet)
                    Text("Mainnet 主网").tag(WalletProfile.Network.bitcoin)
                }
                .pickerStyle(.segmented)
            }
            .padding(16)
            .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 16))

            if network == .bitcoin {
                NoticeCard(
                    title: "主网会产生真实资金风险",
                    message: "ColdSigner v0.1 尚未完成真机矩阵和独立安全审查。不要用它保护真实资金。",
                    systemImage: "exclamationmark.triangle.fill"
                )
            }

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
                message: "v0.1 仅支持 BIP84 P2WPKH；当前网络账户路径为 \(network.accountPath)。",
                systemImage: "scope"
            )

            Spacer()
        }
        .padding(24)
    }
}
