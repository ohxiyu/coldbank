import SwiftUI
import UIKit

struct NoticeCard: View {
    let title: String
    let message: String
    let systemImage: String

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: systemImage)
                .foregroundStyle(.orange)
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 6) {
                Text(title)
                    .font(.headline)

                Text(message)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 16))
    }
}

struct PrimaryButtonStyle: ButtonStyle {
    @Environment(\.isEnabled) private var isEnabled
    var color: Color = .blue

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.headline)
            .frame(maxWidth: .infinity, minHeight: 52)
            .background(configuration.isPressed ? color.opacity(0.75) : color)
            .foregroundStyle(.white)
            .clipShape(RoundedRectangle(cornerRadius: 14))
            .opacity(isEnabled ? 1 : 0.45)
    }
}

struct SecondaryButtonStyle: ButtonStyle {
    @Environment(\.isEnabled) private var isEnabled

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.headline)
            .frame(maxWidth: .infinity, minHeight: 50)
            .background(Color.secondary.opacity(configuration.isPressed ? 0.24 : 0.14))
            .clipShape(RoundedRectangle(cornerRadius: 14))
            .opacity(isEnabled ? 1 : 0.45)
    }
}

struct FlowHeader: View {
    let title: String
    let subtitle: String

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.largeTitle.bold())
            Text(subtitle)
                .font(.body)
                .foregroundStyle(.secondary)
        }
    }
}

struct ErrorCard: View {
    let message: String

    var body: some View {
        Label {
            Text(message)
                .font(.subheadline)
        } icon: {
            Image(systemName: "xmark.octagon.fill")
        }
        .foregroundStyle(.red)
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(14)
        .background(Color.red.opacity(0.12), in: RoundedRectangle(cornerRadius: 14))
    }
}

struct ChoiceCard: View {
    let title: String
    let detail: String
    let systemImage: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(alignment: .top, spacing: 14) {
                Image(systemName: systemImage)
                    .font(.title2)
                    .frame(width: 30)
                VStack(alignment: .leading, spacing: 5) {
                    Text(title)
                        .font(.headline)
                    Text(detail)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.leading)
                }
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.caption.bold())
                    .foregroundStyle(.tertiary)
            }
            .padding(16)
            .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 16))
        }
        .buttonStyle(.plain)
    }
}

struct ProfileSummaryCard: View {
    let profile: WalletProfile

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            LabeledContent("Master fingerprint") {
                Text(profile.fingerprint)
                    .font(.body.monospaced().weight(.bold))
            }
            LabeledContent("网络", value: profile.network.displayName)
            LabeledContent("脚本", value: "BIP84 · P2WPKH")
            LabeledContent("账户路径") {
                Text(profile.accountPath).font(.body.monospaced())
            }
        }
        .padding(16)
        .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 16))
    }
}

private struct SensitiveCaptureShield: ViewModifier {
    @State private var isCaptured = UIScreen.main.isCaptured

    func body(content: Content) -> some View {
        content
            .overlay {
                if isCaptured {
                    ZStack {
                        Color.black.ignoresSafeArea()
                        ErrorCard(message: "检测到屏幕录制或镜像，敏感内容已隐藏。停止录制后再继续。")
                            .padding(24)
                    }
                }
            }
            .onReceive(NotificationCenter.default.publisher(for: UIScreen.capturedDidChangeNotification)) { _ in
                isCaptured = UIScreen.main.isCaptured
            }
    }
}

extension View {
    func sensitiveCaptureShield() -> some View {
        modifier(SensitiveCaptureShield())
    }
}
