import SwiftUI

struct CreateOptionsView: View {
    let onBack: () -> Void
    let create: (Int) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            FlowHeader(
                title: "创建新钱包",
                subtitle: "12 个单词提供 128 位熵；24 个单词提供 256 位熵。两者都由 BDK 使用系统 CSPRNG 生成。"
            )

            ChoiceCard(
                title: "12 个单词",
                detail: "更容易准确备份，适合大多数单签使用场景。",
                systemImage: "12.circle",
                action: { create(12) }
            )

            ChoiceCard(
                title: "24 个单词",
                detail: "备份更长，抄写和恢复时更容易出错。",
                systemImage: "24.circle",
                action: { create(24) }
            )

            Spacer()
            Button("返回", action: onBack)
                .buttonStyle(SecondaryButtonStyle())
        }
        .padding(24)
    }
}
