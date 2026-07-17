import SwiftUI

struct WelcomeView: View {
    let onContinue: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 24) {
            Spacer()

            Image(systemName: "bitcoinsign.circle.fill")
                .font(.system(size: 56, weight: .semibold))
                .foregroundStyle(.orange)
                .accessibilityHidden(true)

            Text("ColdSigner")
                .font(.largeTitle.bold())

            Text("把一台闲置 iPhone 变成只负责审阅和签名的离线 Bitcoin 签名器。")
                .font(.title3)
                .foregroundStyle(.secondary)

            NoticeCard(
                title: "这是软件签名器",
                message: "它不是硬件钱包，也无法防御已被攻破的 iOS。正式审计完成前，请勿用于真实资金。",
                systemImage: "exclamationmark.triangle.fill"
            )

            Spacer()

            Button("准备这台 iPhone", action: onContinue)
                .buttonStyle(PrimaryButtonStyle())
        }
        .padding(24)
    }
}
