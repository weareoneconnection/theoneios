import AuthenticationServices
import Foundation
import SwiftUI
import WebKit

enum AppLanguage: String, CaseIterable {
    case zh
    case en

    static var preferred: AppLanguage {
        Locale.preferredLanguages.first?.lowercased().hasPrefix("zh") == true ? .zh : .en
    }

    func text(_ zh: String, _ en: String) -> String {
        self == .zh ? zh : en
    }
}

struct AppConfiguration: Sendable {
    let baseURL: URL
    let callbackScheme: String

    static let production = AppConfiguration(
        baseURL: URL(string: "https://www.the1os.io")!,
        callbackScheme: "theone"
    )

    func url(path: String, query: [URLQueryItem] = []) -> URL {
        var components = URLComponents(url: baseURL.appending(path: path), resolvingAgainstBaseURL: false)!
        components.queryItems = query.isEmpty ? nil : query
        return components.url!
    }

    func githubSignInURL(challenge: String) -> URL {
        url(path: "/api/auth/github", query: [
            URLQueryItem(name: "desktop", value: challenge),
            URLQueryItem(name: "returnTo", value: "/os"),
            URLQueryItem(name: "surface", value: "ios")
        ])
    }

    func exchangeURL(code: String, verifier: String) -> URL {
        url(path: "/api/auth/desktop/exchange", query: [
            URLQueryItem(name: "code", value: code),
            URLQueryItem(name: "verifier", value: verifier),
            URLQueryItem(name: "returnTo", value: "/os")
        ])
    }

    var appleNativeSignInURL: URL {
        url(path: "/api/auth/apple/native")
    }

    var emailSignInURL: URL {
        url(path: "/api/auth/email")
    }

    var emailVerifyURL: URL {
        url(path: "/api/auth/email/verify")
    }
}

enum AppRoute: Equatable {
    case signedOut
    case authenticating
    case workspace(URL)

    var id: String {
        switch self {
        case .signedOut: "signed-out"
        case .authenticating: "authenticating"
        case .workspace(let url): "workspace:\(url.absoluteString)"
        }
    }
}

@MainActor
final class AppSession: ObservableObject {
    @Published var route: AppRoute
    @Published var showAlert = false
    @Published private(set) var alertTitle = ""
    @Published private(set) var alertMessage = ""

    let configuration: AppConfiguration
    private var authentication: AuthenticationCoordinator?
    private var pendingVerifier: String?
    private var appleNonce: String?
    private var appleVerifier: String?
    private let defaults: UserDefaults

    init(
        configuration: AppConfiguration = .production,
        defaults: UserDefaults = .standard
    ) {
        self.configuration = configuration
        self.defaults = defaults
        route = defaults.bool(forKey: "theone.hasAuthenticatedSession")
            ? .workspace(configuration.url(path: "/os"))
            : .signedOut
    }

    func signInWithGitHub() {
        guard case .signedOut = route else { return }
        route = .authenticating

        let coordinator = AuthenticationCoordinator(configuration: configuration)
        authentication = coordinator
        Task {
            do {
                let request = try await coordinator.start()
                pendingVerifier = request.verifier
                handleCallback(request.callbackURL)
            } catch AuthenticationError.cancelled {
                route = .signedOut
            } catch {
                route = .signedOut
                present(title: "登录没有完成", message: error.localizedDescription)
            }
            authentication = nil
        }
    }

    func requestEmailCode(email: String, language: AppLanguage) async throws -> String {
        var request = URLRequest(url: configuration.emailSignInURL)
        request.httpMethod = "POST"
        request.timeoutInterval = 30
        request.setValue("application/json", forHTTPHeaderField: "content-type")
        request.httpBody = try JSONEncoder().encode(EmailCodeRequest(
            email: email.trimmingCharacters(in: .whitespacesAndNewlines).lowercased(),
            returnTo: "/os",
            locale: language.rawValue
        ))
        let payload: EmailAuthResponse = try await performEmailRequest(request)
        guard payload.ok else { throw EmailAuthenticationError.server(payload.error) }
        return payload.message ?? language.text("验证码已发送，请检查邮箱。", "Code sent. Check your email.")
    }

    func verifyEmailCode(email: String, code: String, language: AppLanguage) async throws {
        let verifier = AuthenticationCoordinator.randomVerifier()
        let challenge = AuthenticationCoordinator.challenge(for: verifier)
        var request = URLRequest(url: configuration.emailVerifyURL)
        request.httpMethod = "POST"
        request.timeoutInterval = 30
        request.setValue("application/json", forHTTPHeaderField: "content-type")
        request.httpBody = try JSONEncoder().encode(EmailCodeVerificationRequest(
            email: email.trimmingCharacters(in: .whitespacesAndNewlines).lowercased(),
            code: code.filter(\.isNumber),
            returnTo: "/os",
            locale: language.rawValue,
            challenge: challenge
        ))
        let payload: EmailAuthResponse = try await performEmailRequest(request)
        guard payload.ok, let handoffCode = payload.code else {
            throw EmailAuthenticationError.server(payload.error)
        }
        route = .workspace(configuration.exchangeURL(code: handoffCode, verifier: verifier))
        UINotificationFeedbackGenerator().notificationOccurred(.success)
    }

    func prepareAppleSignIn(_ request: ASAuthorizationAppleIDRequest) {
        let nonce = AuthenticationCoordinator.randomVerifier()
        appleNonce = nonce
        appleVerifier = AuthenticationCoordinator.randomVerifier()
        request.requestedScopes = [.fullName, .email]
        request.nonce = AuthenticationCoordinator.nonceHash(for: nonce)
        route = .authenticating
    }

    func completeAppleSignIn(_ result: Result<ASAuthorization, Error>) {
        guard case .success(let authorization) = result,
              let credential = authorization.credential as? ASAuthorizationAppleIDCredential,
              let identityData = credential.identityToken,
              let codeData = credential.authorizationCode,
              let identityToken = String(data: identityData, encoding: .utf8),
              let authorizationCode = String(data: codeData, encoding: .utf8),
              let nonce = appleNonce,
              let verifier = appleVerifier
        else {
            route = .signedOut
            appleNonce = nil
            appleVerifier = nil
            if case .failure(let error) = result,
               (error as? ASAuthorizationError)?.code != .canceled {
                present(title: localized("登录没有完成", "Sign-in didn’t finish"), message: error.localizedDescription)
            }
            return
        }

        let challenge = AuthenticationCoordinator.challenge(for: verifier)
        appleNonce = nil
        appleVerifier = nil
        Task {
            do {
                var request = URLRequest(url: configuration.appleNativeSignInURL)
                request.httpMethod = "POST"
                request.timeoutInterval = 30
                request.setValue("application/json", forHTTPHeaderField: "content-type")
                request.httpBody = try JSONEncoder().encode(AppleNativeSignInRequest(
                    identityToken: identityToken,
                    authorizationCode: authorizationCode,
                    nonce: nonce,
                    challenge: challenge
                ))
                let (data, response) = try await URLSession.shared.data(for: request)
                guard let http = response as? HTTPURLResponse,
                      (200..<300).contains(http.statusCode),
                      let payload = try? JSONDecoder().decode(AppleNativeSignInResponse.self, from: data),
                      payload.ok,
                      let code = payload.code
                else { throw AuthenticationError.invalidCallback }
                route = .workspace(configuration.exchangeURL(code: code, verifier: verifier))
                UINotificationFeedbackGenerator().notificationOccurred(.success)
            } catch {
                route = .signedOut
                present(
                    title: localized("Apple 登录失败", "Apple sign-in failed"),
                    message: localized("请检查网络后重试；如果账号尚未获邀，请联系团队管理员。", "Check your connection and try again. If you have not been invited, contact your team administrator.")
                )
            }
        }
    }

    func handleCallback(_ url: URL) {
        guard url.scheme == configuration.callbackScheme,
              url.host == "auth",
              let components = URLComponents(url: url, resolvingAgainstBaseURL: false),
              let code = components.queryItems?.first(where: { $0.name == "code" })?.value,
              code.range(of: "^[A-Za-z0-9_-]{43}$", options: .regularExpression) != nil,
              let verifier = pendingVerifier
        else { return }

        pendingVerifier = nil
        route = .workspace(configuration.exchangeURL(code: code, verifier: verifier))
        UINotificationFeedbackGenerator().notificationOccurred(.success)
    }

    func recordNavigation(_ url: URL) {
        guard url.host == configuration.baseURL.host else { return }
        if url.path == "/os" || url.path.hasPrefix("/chat") {
            defaults.set(true, forKey: "theone.hasAuthenticatedSession")
        } else if url.path == "/login" {
            defaults.set(false, forKey: "theone.hasAuthenticatedSession")
            let isNativeEmailFlow = URLComponents(url: url, resolvingAgainstBaseURL: false)?
                .queryItems?.contains(where: { $0.name == "surface" && $0.value == "ios" }) == true
            if !isNativeEmailFlow { route = .signedOut }
        }
    }

    func signOut() {
        defaults.set(false, forKey: "theone.hasAuthenticatedSession")
        let dataStore = WKWebsiteDataStore.default()
        dataStore.fetchDataRecords(ofTypes: WKWebsiteDataStore.allWebsiteDataTypes()) { records in
            dataStore.removeData(ofTypes: WKWebsiteDataStore.allWebsiteDataTypes(), for: records) { }
        }
        route = .signedOut
    }

    func dismissAlert() {
        showAlert = false
    }

    private func present(title: String, message: String) {
        alertTitle = title
        alertMessage = message
        showAlert = true
    }

    private func localized(_ zh: String, _ en: String) -> String {
        let raw = defaults.string(forKey: "theone.native.locale") ?? AppLanguage.preferred.rawValue
        return (AppLanguage(rawValue: raw) ?? .preferred).text(zh, en)
    }

    private func performEmailRequest(_ request: URLRequest) async throws -> EmailAuthResponse {
        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            guard let http = response as? HTTPURLResponse,
                  let payload = try? JSONDecoder().decode(EmailAuthResponse.self, from: data)
            else { throw EmailAuthenticationError.invalidResponse }
            if !(200..<300).contains(http.statusCode) || !payload.ok {
                throw EmailAuthenticationError.server(payload.error)
            }
            return payload
        } catch let error as EmailAuthenticationError {
            throw error
        } catch {
            throw EmailAuthenticationError.network
        }
    }
}

private struct AppleNativeSignInRequest: Encodable {
    let identityToken: String
    let authorizationCode: String
    let nonce: String
    let challenge: String
}

private struct AppleNativeSignInResponse: Decodable {
    let ok: Bool
    let code: String?
}

private struct EmailCodeRequest: Encodable {
    let email: String
    let returnTo: String
    let locale: String
}

private struct EmailCodeVerificationRequest: Encodable {
    let email: String
    let code: String
    let returnTo: String
    let locale: String
    let challenge: String
}

private struct EmailAuthResponse: Decodable {
    let ok: Bool
    let message: String?
    let error: String?
    let code: String?
}

private enum EmailAuthenticationError: LocalizedError {
    case server(String?)
    case invalidResponse
    case network

    var errorDescription: String? {
        switch self {
        case .server(let message): message ?? "Email sign-in failed."
        case .invalidResponse: "The server returned an invalid response."
        case .network: "Check your connection and try again."
        }
    }
}
