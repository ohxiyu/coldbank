import ColdSignerCore
import SwiftUI

struct UnlockView: View {
    let profile: WalletProfile
    let unlock: () async -> Void
    @State private var isWorking = false

    var body: some View {
        VStack(alignment: .leading, spacing: 22) {
            Spacer()

            Image(systemName: "lock.fill")
                .font(.system(size: 48))
                .foregroundStyle(.blue)

            FlowHeader(
                title: "签名器已锁定",
                subtitle: "使用设备密码、Face ID 或 Touch ID 解锁。失败时不会降级为应用自定义 PIN。"
            )

            ProfileSummaryCard(profile: profile)

            Spacer()

            Button {
                isWorking = true
                Task {
                    await unlock()
                    isWorking = false
                }
            } label: {
                if isWorking {
                    ProgressView().frame(maxWidth: .infinity)
                } else {
                    Label("解锁 ColdSigner", systemImage: "faceid")
                        .frame(maxWidth: .infinity)
                }
            }
            .buttonStyle(PrimaryButtonStyle())
            .disabled(isWorking)
        }
        .padding(24)
    }
}
