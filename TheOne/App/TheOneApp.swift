import SwiftUI

@main
struct TheOneApp: App {
    @StateObject private var session = AppSession()

    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(session)
                .preferredColorScheme(.light)
                .onOpenURL { session.handleCallback($0) }
        }
    }
}

private struct RootView: View {
    @EnvironmentObject private var session: AppSession

    var body: some View {
        ZStack {
            Brand.canvas.ignoresSafeArea()

            switch session.route {
            case .signedOut:
                LoginView()
                    .transition(.opacity.combined(with: .scale(scale: 0.985)))
            case .authenticating:
                LoginView()
                    .overlay { AuthenticationProgressView() }
            case .workspace(let initialURL):
                WorkspaceView(initialURL: initialURL)
                    .transition(.opacity)
            }
        }
        .animation(.easeOut(duration: 0.24), value: session.route.id)
        .alert(session.alertTitle, isPresented: $session.showAlert) {
            Button("好") { session.dismissAlert() }
        } message: {
            Text(session.alertMessage)
        }
    }
}

private struct AuthenticationProgressView: View {
    @AppStorage("theone.native.locale") private var locale = AppLanguage.preferred.rawValue

    var body: some View {
        ZStack {
            Color.black.opacity(0.12).ignoresSafeArea()
            VStack(spacing: 14) {
                ProgressView().tint(Brand.accent)
                Text(language.text("正在安全登录…", "Signing in securely…"))
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(Brand.ink)
            }
            .padding(.horizontal, 30)
            .padding(.vertical, 24)
            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 24, style: .continuous))
            .shadow(color: .black.opacity(0.12), radius: 30, y: 12)
        }
    }

    private var language: AppLanguage { AppLanguage(rawValue: locale) ?? .preferred }
}
