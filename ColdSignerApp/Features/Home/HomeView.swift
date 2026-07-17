import ColdSignerCore
import SwiftUI

struct HomeView: View {
    let profile: WalletProfile
    let vault: any WalletVault
    let onLock: () -> Void
    let onWipe: () async -> Bool

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    HStack {
                        Label("离线模式：用户确认", systemImage: "airplane")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(.secondary)

                        Spacer()

                        Text(profile.network.displayName)
                            .font(.caption.monospaced().weight(.semibold))
                    }

                    VStack(alignment: .leading, spacing: 8) {
                        Text("离线签名器")
                            .font(.largeTitle.bold())

                        Text("Fingerprint  \(formattedFingerprint)")
                            .font(.body.monospaced())

                        Text("BIP84 · \(profile.accountPath)")
                            .foregroundStyle(.secondary)
                    }

                    NavigationLink {
                        PSBTScannerView(profile: profile, vault: vault)
                    } label: {
                        Text("扫描待签名交易")
                    }
                    .buttonStyle(PrimaryButtonStyle())

                    NoticeCard(
                        title: "扫描 → 复核 → 长按签名",
                        message: "签名前会逐项显示所有输出、费用与已验证找零，并在设备认证后再次校验 PSBT。",
                        systemImage: "checkmark.shield"
                    )

                    VStack(spacing: 4) {
                        NavigationLink {
                            PublicWalletExportView(profile: profile)
                        } label: {
                            HomeRow(title: "导出只读钱包", systemImage: "qrcode")
                        }

                        NavigationLink {
                            SecurityView(profile: profile, onLock: onLock, onWipe: onWipe)
                        } label: {
                            HomeRow(title: "安全与设置", systemImage: "lock.shield")
                        }
                    }

                    Text("本机不会联网查询余额、费率或交易历史。")
                        .font(.footnote)
                        .foregroundStyle(.tertiary)
                }
                .padding(24)
            }
            .navigationTitle("ColdSigner")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("锁定", action: onLock)
                }
            }
        }
    }

    private var formattedFingerprint: String {
        profile.fingerprint.enumerated().reduce(into: "") { result, item in
            if item.offset == 4 { result.append(" ") }
            result.append(item.element)
        }
    }
}

private struct HomeRow: View {
    let title: String
    let systemImage: String

    var body: some View {
        HStack {
            Label(title, systemImage: systemImage)
            Spacer()
            Image(systemName: "chevron.right")
                .font(.caption.weight(.bold))
                .foregroundStyle(.tertiary)
        }
        .frame(minHeight: 52)
        .contentShape(Rectangle())
    }
}

#Preview {
    HomeView(
        profile: .placeholder,
        vault: PreviewWalletVault(),
        onLock: {},
        onWipe: { true }
    )
        .preferredColorScheme(.dark)
}
