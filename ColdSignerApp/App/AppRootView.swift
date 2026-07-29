import SwiftUI

struct AppRootView: View {
    @ObservedObject var model: AppModel
    @Environment(\.scenePhase) private var scenePhase
    @State private var showsPrivacyCover = true

    var body: some View {
        ZStack {
            content

            if showsPrivacyCover {
                PrivacyCoverView()
                    .transition(.opacity)
                    .zIndex(100)
            }
        }
        .preferredColorScheme(.dark)
        .simultaneousGesture(
            DragGesture(minimumDistance: 0)
                .onChanged { _ in model.recordActivity() }
        )
        .task {
            await model.load()
            showsPrivacyCover = scenePhase != .active
        }
        .onChange(of: scenePhase) { newPhase in
            switch newPhase {
            case .active:
                showsPrivacyCover = false
            case .inactive, .background:
                showsPrivacyCover = true
                model.lock()
            @unknown default:
                showsPrivacyCover = true
                model.lock()
            }
        }
    }

    @ViewBuilder
    private var content: some View {
        switch model.phase {
        case .loading:
            ProgressView("正在检查本地签名器…")
        case .needsOnboarding:
            OnboardingFlow(vault: model.vault) { profile in
                model.didActivate(
                    profile: profile,
                    unlocked: scenePhase == .active
                )
            }
        case .locked(let profile):
            UnlockView(profile: profile) {
                await model.unlock()
            }
        case .ready(let profile):
            HomeView(
                profile: profile,
                vault: model.vault,
                onLock: model.lock,
                onWipe: {
                    await model.wipe()
                }
            )
        case .failed(let message):
            FatalErrorView(message: message) {
                await model.load()
            }
        }
    }
}

private struct PrivacyCoverView: View {
    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            VStack(spacing: 14) {
                Image(systemName: "eye.slash.fill")
                    .font(.system(size: 34))
                Text("ColdSigner 已隐藏")
                    .font(.headline)
                Text("返回应用后需要重新解锁。")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
        }
        .accessibilityElement(children: .combine)
    }
}

private struct FatalErrorView: View {
    let message: String
    let retry: () async -> Void

    var body: some View {
        VStack(spacing: 20) {
            Image(systemName: "xmark.octagon.fill")
                .font(.system(size: 42))
                .foregroundStyle(.red)
            Text("无法打开签名器")
                .font(.title2.bold())
            Text(message)
                .multilineTextAlignment(.center)
                .foregroundStyle(.secondary)
            Button("重试") {
                Task { await retry() }
            }
            .buttonStyle(PrimaryButtonStyle())
        }
        .padding(24)
    }
}

#Preview {
    AppRootView(model: AppModel(vault: PreviewWalletVault()))
}
