import SwiftUI

struct HomeView: View {
    private let demoProfile = WalletProfile.placeholder

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    HStack {
                        Label("Offline mode: user confirmed", systemImage: "airplane")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(.secondary)

                        Spacer()

                        Text(demoProfile.network.displayName)
                            .font(.caption.monospaced().weight(.semibold))
                    }

                    VStack(alignment: .leading, spacing: 8) {
                        Text("Offline signer")
                            .font(.largeTitle.bold())

                        Text("Fingerprint  \(demoProfile.fingerprint)")
                            .font(.body.monospaced())

                        Text("BIP84 · \(demoProfile.accountPath)")
                            .foregroundStyle(.secondary)
                    }

                    Button("Scan transaction") {}
                        .buttonStyle(PrimaryButtonStyle())
                        .disabled(true)

                    NoticeCard(
                        title: "Scaffold only",
                        message: "Key creation and signing are intentionally disabled until the policy engine and test vectors are implemented.",
                        systemImage: "hammer.fill"
                    )

                    VStack(alignment: .leading, spacing: 16) {
                        Label("Export watch-only wallet", systemImage: "qrcode")
                        Label("Security & settings", systemImage: "lock.shield")
                    }
                    .foregroundStyle(.secondary)

                    Text("No balance is shown because this device is intentionally offline.")
                        .font(.footnote)
                        .foregroundStyle(.tertiary)
                }
                .padding(24)
            }
            .navigationTitle("ColdSigner")
            .navigationBarTitleDisplayMode(.inline)
        }
    }
}

#Preview {
    HomeView()
        .preferredColorScheme(.dark)
}
