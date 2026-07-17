import ColdSignerCore
import SwiftUI

struct SecurityView: View {
    let profile: WalletProfile
    let onLock: () -> Void
    let onWipe: () async -> Bool
    @State private var showsWipe = false

    var body: some View {
        List {
            Section("签名器") {
                LabeledContent("Fingerprint", value: profile.fingerprint)
                LabeledContent("网络", value: profile.network.displayName)
                LabeledContent("路径", value: profile.accountPath)
                Button("立即锁定", action: onLock)
            }

            Section("本地保护") {
                Label("AES‑GCM 加密种子文件", systemImage: "checkmark.shield")
                Label("ThisDeviceOnly Keychain 包装密钥", systemImage: "checkmark.shield")
                Label("完整文件保护并排除设备备份", systemImage: "checkmark.shield")
            }

            Section("限制") {
                Text("iOS 无法保证阻止截图，也无法保证闪存删除后物理不可恢复。退役设备时应抹掉整台 iPhone。")
                    .foregroundStyle(.secondary)
            }

            Section {
                Button("擦除签名器", role: .destructive) {
                    showsWipe = true
                }
            }
        }
        .navigationTitle("安全与设置")
        .sheet(isPresented: $showsWipe) {
            WipeSignerView(onWipe: onWipe)
        }
    }
}

private struct WipeSignerView: View {
    let onWipe: () async -> Bool
    @Environment(\.dismiss) private var dismiss
    @State private var confirmation = ""
    @State private var isWorking = false

    var body: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: 20) {
                Image(systemName: "trash.slash.fill")
                    .font(.system(size: 42))
                    .foregroundStyle(.red)

                FlowHeader(
                    title: "永久擦除本机签名器",
                    subtitle: "将删除加密种子、Keychain 包装密钥和公开钱包资料。没有外部助记词备份就无法恢复。"
                )

                TextField("输入 WIPE", text: $confirmation)
                    .textInputAutocapitalization(.characters)
                    .autocorrectionDisabled()
                    .padding(14)
                    .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 12))

                NoticeCard(
                    title: "闪存删除是尽力而为",
                    message: "完成后如要退役设备，请在 iOS 设置中抹掉所有内容和设置。",
                    systemImage: "exclamationmark.triangle.fill"
                )

                Spacer()

                Button(role: .destructive) {
                    isWorking = true
                    Task {
                        if await onWipe() {
                            dismiss()
                        }
                        isWorking = false
                    }
                } label: {
                    if isWorking {
                        ProgressView().frame(maxWidth: .infinity)
                    } else {
                        Text("认证并擦除").frame(maxWidth: .infinity)
                    }
                }
                .buttonStyle(PrimaryButtonStyle(color: .red))
                .disabled(confirmation != "WIPE" || isWorking)
            }
            .padding(24)
            .navigationTitle("擦除")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("取消") { dismiss() }
                }
            }
        }
        .interactiveDismissDisabled(isWorking)
    }
}
