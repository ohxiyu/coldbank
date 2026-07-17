import ColdSignerCore
import SwiftUI

struct BackupVerificationView: View {
    let challenge: BackupChallenge
    let errorMessage: String?
    let onCancel: () -> Void
    let verify: ([Int: String]) -> Bool
    @State private var answers: [Int: String] = [:]
    @State private var activePositionIndex = 0

    private var activePosition: Int { challenge.positions[activePositionIndex] }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                FlowHeader(
                    title: "验证纸质备份",
                    subtitle: "从纸质备份中选择指定位置的单词。不要依赖刚才的屏幕记忆。"
                )

                HStack(spacing: 8) {
                    ForEach(challenge.positions.indices, id: \.self) { index in
                        Button {
                            activePositionIndex = index
                        } label: {
                            VStack(spacing: 4) {
                                Text("第 \(challenge.positions[index] + 1) 个")
                                    .font(.caption)
                                Text(answers[challenge.positions[index]] ?? "未选择")
                                    .font(.body.monospaced().weight(.semibold))
                                    .lineLimit(1)
                            }
                            .frame(maxWidth: .infinity, minHeight: 62)
                        }
                        .buttonStyle(.bordered)
                        .tint(index == activePositionIndex ? .blue : .secondary)
                    }
                }

                LocalWordPicker(prompt: "选择第 \(activePosition + 1) 个单词") { word in
                    answers[activePosition] = word
                    if activePositionIndex < challenge.positions.count - 1 {
                        activePositionIndex += 1
                    }
                }

                if let errorMessage {
                    ErrorCard(message: errorMessage)
                }

                Button("验证备份") {
                    _ = verify(answers)
                }
                .buttonStyle(PrimaryButtonStyle())
                .disabled(answers.count != challenge.positions.count)

                Button("取消并丢弃此钱包", role: .destructive, action: onCancel)
                    .buttonStyle(SecondaryButtonStyle())
            }
            .padding(24)
        }
        .sensitiveCaptureShield()
    }
}
