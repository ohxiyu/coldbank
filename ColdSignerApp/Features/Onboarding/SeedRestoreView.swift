import SwiftUI

struct SeedRestoreView: View {
    let wordCount: Int
    let errorMessage: String?
    let onCancel: () -> Void
    let restore: ([String]) -> Void
    @State private var words: [String] = []

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                FlowHeader(
                    title: "输入 \(wordCount) 个单词",
                    subtitle: "按备份顺序逐个选择。单词不会进入系统键盘、粘贴板或日志。"
                )

                if words.isEmpty {
                    Text("尚未输入")
                        .foregroundStyle(.secondary)
                } else {
                    LazyVGrid(columns: [GridItem(.adaptive(minimum: 112), spacing: 8)], spacing: 8) {
                        ForEach(words.indices, id: \.self) { index in
                            HStack(spacing: 6) {
                                Text("\(index + 1)")
                                    .font(.caption.monospaced())
                                    .foregroundStyle(.secondary)
                                Text(words[index])
                                    .font(.body.monospaced())
                                Spacer(minLength: 0)
                            }
                            .padding(10)
                            .background(Color.secondary.opacity(0.12), in: RoundedRectangle(cornerRadius: 9))
                        }
                    }
                    .privacySensitive()
                }

                HStack {
                    ProgressView(value: Double(words.count), total: Double(wordCount))
                    Text("\(words.count)/\(wordCount)")
                        .font(.caption.monospaced())
                }

                if words.count < wordCount {
                    LocalWordPicker(prompt: "选择第 \(words.count + 1) 个单词") { word in
                        words.append(word)
                    }
                }

                if let errorMessage {
                    ErrorCard(message: errorMessage)
                }

                Button("校验并继续") {
                    restore(words)
                }
                .buttonStyle(PrimaryButtonStyle())
                .disabled(words.count != wordCount)

                Button("删除上一个单词") {
                    if !words.isEmpty { words.removeLast() }
                }
                .buttonStyle(SecondaryButtonStyle())
                .disabled(words.isEmpty)

                Button("取消恢复", role: .destructive, action: onCancel)
                    .buttonStyle(SecondaryButtonStyle())
            }
            .padding(24)
        }
        .sensitiveCaptureShield()
    }
}
