import SwiftUI

struct ReadinessView: View {
    @State private var confirmations = Array(repeating: false, count: items.count)
    let errorMessage: String?
    let onBack: () -> Void
    let onContinue: () -> Void

    private static let items = [
        "这台 iPhone 已抹除，或已专门准备用作签名器",
        "已启用设备密码；ColdSigner 会在解锁和擦除时验证机主",
        "Wi‑Fi、蓝牙、蜂窝网络/eSIM、AirDrop 和个人热点已关闭",
        "助记词只会记录在非数字介质上，不拍照、不上传云端",
        "我理解应用无法验证所有无线电状态，这些项目属于用户确认",
        "首次交易将使用测试网，或仅使用可承受损失的小额主网资金",
    ]

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                FlowHeader(
                    title: "设备准备检查",
                    subtitle: "逐项确认后才能创建或恢复签名器。"
                )

                ForEach(Self.items.indices, id: \.self) { index in
                    Toggle(isOn: $confirmations[index]) {
                        Text(Self.items[index])
                            .font(.body)
                    }
                    .toggleStyle(.switch)
                    .padding(14)
                    .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 14))
                }

                if let errorMessage {
                    ErrorCard(message: errorMessage)
                }

                Button("继续") { onContinue() }
                    .buttonStyle(PrimaryButtonStyle())
                    .disabled(!confirmations.allSatisfy { $0 })

                Button("返回", action: onBack)
                    .buttonStyle(SecondaryButtonStyle())
            }
            .padding(24)
        }
    }
}
