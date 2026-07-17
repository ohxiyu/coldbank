import SwiftUI

struct WelcomeView: View {
    let onContinue: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 24) {
            Spacer()

            Image(systemName: "iphone.gen3.radiowaves.left.and.right")
                .font(.system(size: 52, weight: .semibold))
                .foregroundStyle(.blue)
                .accessibilityHidden(true)

            Text("ColdSigner")
                .font(.largeTitle.bold())

            Text("Turn a spare iPhone into an offline Bitcoin transaction signer.")
                .font(.title3)
                .foregroundStyle(.secondary)

            NoticeCard(
                title: "Pre-alpha software",
                message: "Do not use this build with real funds. An iPhone software signer is not equivalent to a dedicated hardware wallet.",
                systemImage: "exclamationmark.triangle.fill"
            )

            Spacer()

            Button("Review device requirements", action: onContinue)
                .buttonStyle(PrimaryButtonStyle())
        }
        .padding(24)
    }
}
