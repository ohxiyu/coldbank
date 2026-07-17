import ColdSignerCore
import SwiftUI
import UIKit

struct SeedDisplayView: View {
    let mnemonic: MnemonicPhrase
    let onCancel: () -> Void
    let onContinue: () -> Void
    @State private var isCaptured = UIScreen.main.isCaptured

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                FlowHeader(
                    title: "备份助记词",
                    subtitle: "按顺序抄写到纸张或金属板。离开此流程后，应用不再显示这些单词。"
                )

                NoticeCard(
                    title: "任何拿到这些单词的人都能花费你的 bitcoin",
                    message: "不要截图、拍照、复制、打印、朗读给他人或存入密码管理器。",
                    systemImage: "exclamationmark.triangle.fill"
                )

                if isCaptured {
                    ErrorCard(message: "检测到屏幕录制或镜像。已隐藏助记词；停止录制后再继续。iOS 无法保证阻止系统截图或外部相机。")
                } else {
                    mnemonic.withUnsafeWords { words in
                        LazyVGrid(
                            columns: [GridItem(.adaptive(minimum: 138), spacing: 10)],
                            spacing: 10
                        ) {
                            ForEach(words.indices, id: \.self) { index in
                                HStack(spacing: 10) {
                                    Text("\(index + 1)")
                                        .font(.caption.monospaced())
                                        .foregroundStyle(.secondary)
                                        .frame(width: 24, alignment: .trailing)
                                    Text(words[index])
                                        .font(.body.monospaced().weight(.semibold))
                                    Spacer()
                                }
                                .padding(12)
                                .background(Color.secondary.opacity(0.12), in: RoundedRectangle(cornerRadius: 10))
                            }
                        }
                    }
                    .privacySensitive()
                    .accessibilityHint("敏感助记词。请确保周围没有摄像设备或旁观者。")
                }

                Button("我已按顺序抄写", action: onContinue)
                    .buttonStyle(PrimaryButtonStyle())
                    .disabled(isCaptured)

                Button("取消并丢弃此钱包", role: .destructive, action: onCancel)
                    .buttonStyle(SecondaryButtonStyle())
            }
            .padding(24)
        }
        .onReceive(NotificationCenter.default.publisher(for: UIScreen.capturedDidChangeNotification)) { _ in
            isCaptured = UIScreen.main.isCaptured
        }
    }
}
