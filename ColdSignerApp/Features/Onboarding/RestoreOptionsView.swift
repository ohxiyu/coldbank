import SwiftUI

struct RestoreOptionsView: View {
    let onBack: () -> Void
    let choose: (Int) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            FlowHeader(
                title: "恢复已有钱包",
                subtitle: "只支持英文 BIP39 助记词和 BIP84 账户 0，不支持 BIP39 passphrase。"
            )

            ChoiceCard(
                title: "恢复 12 个单词",
                detail: "应用将在本机校验 BIP39 checksum。",
                systemImage: "12.circle",
                action: { choose(12) }
            )

            ChoiceCard(
                title: "恢复 24 个单词",
                detail: "应用将在本机校验 BIP39 checksum。",
                systemImage: "24.circle",
                action: { choose(24) }
            )

            NoticeCard(
                title: "先确认钱包类型",
                message: "同一助记词在不同路径会产生不同钱包。请确认原钱包使用 m/84'/0'/0'。",
                systemImage: "point.3.connected.trianglepath.dotted"
            )

            Spacer()
            Button("返回", action: onBack)
                .buttonStyle(SecondaryButtonStyle())
        }
        .padding(24)
    }
}
