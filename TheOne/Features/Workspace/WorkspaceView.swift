import SwiftUI

struct WorkspaceView: View {
    @EnvironmentObject private var session: AppSession
    @StateObject private var network = NetworkMonitor()
    @State private var loadState: WebLoadState = .loading
    @State private var reloadToken = UUID()
    @AppStorage("theone.native.locale") private var locale = AppLanguage.preferred.rawValue
    let initialURL: URL

    var body: some View {
        ZStack(alignment: .top) {
            AppWebView(
                initialURL: initialURL,
                allowedHost: session.configuration.baseURL.host ?? "",
                reloadToken: reloadToken,
                onNavigation: session.recordNavigation,
                onStateChange: { loadState = $0 },
                onSignOut: session.signOut
            )
            .ignoresSafeArea(.container, edges: .bottom)

            if !network.isConnected {
                statusPill(language.text("离线。消息会在网络恢复后继续发送。", "Offline. Messages will continue when the network returns."), systemImage: "wifi.slash")
                    .transition(.move(edge: .top).combined(with: .opacity))
            } else if case .failed = loadState {
                Button { reloadToken = UUID() } label: {
                    statusPill(language.text("载入失败，点按重试", "Couldn’t load. Tap to retry."), systemImage: "arrow.clockwise")
                }
                .buttonStyle(.plain)
            }
        }
        .background(Brand.canvas)
        .animation(.easeOut(duration: 0.22), value: network.isConnected)
        .toolbar(.hidden, for: .navigationBar)
    }

    private var language: AppLanguage { AppLanguage(rawValue: locale) ?? .preferred }

    private func statusPill(_ title: String, systemImage: String) -> some View {
        Label(title, systemImage: systemImage)
            .font(.system(size: 13, weight: .semibold))
            .foregroundStyle(Brand.ink)
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .background(.ultraThinMaterial, in: Capsule())
            .overlay(Capsule().stroke(Brand.border))
            .shadow(color: .black.opacity(0.08), radius: 18, y: 8)
            .padding(.top, 8)
    }
}
