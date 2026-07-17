import SwiftUI

struct SetupChoiceView: View {
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

            Spacer()
        }
        .padding(24)
    }
}
