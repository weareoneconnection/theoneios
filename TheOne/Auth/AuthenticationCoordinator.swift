import AuthenticationServices
import CryptoKit
import Foundation
import Security
import UIKit

struct AuthenticationRequest: Sendable {
    let callbackURL: URL
    let verifier: String
}

enum AuthenticationError: LocalizedError {
    case cancelled
    case invalidCallback
    case unavailable

    var errorDescription: String? {
        switch self {
        case .cancelled: "你取消了登录。"
        case .invalidCallback: "登录返回的信息无效，请重新尝试。"
        case .unavailable: "当前无法打开安全登录窗口。"
        }
    }
}

@MainActor
final class AuthenticationCoordinator: NSObject, ASWebAuthenticationPresentationContextProviding {
    private let configuration: AppConfiguration
    private var webSession: ASWebAuthenticationSession?

    init(configuration: AppConfiguration) {
        self.configuration = configuration
    }

    func start() async throws -> AuthenticationRequest {
        let verifier = Self.randomVerifier()
        let challenge = Self.challenge(for: verifier)
        let signInURL = configuration.githubSignInURL(challenge: challenge)

        return try await withCheckedThrowingContinuation { continuation in
            let session = ASWebAuthenticationSession(
                url: signInURL,
                callbackURLScheme: configuration.callbackScheme
            ) { callbackURL, error in
                if let authError = error as? ASWebAuthenticationSessionError,
                   authError.code == .canceledLogin {
                    continuation.resume(throwing: AuthenticationError.cancelled)
                    return
                }
                guard error == nil, let callbackURL else {
                    continuation.resume(throwing: AuthenticationError.unavailable)
                    return
                }
                continuation.resume(returning: AuthenticationRequest(callbackURL: callbackURL, verifier: verifier))
            }
            session.presentationContextProvider = self
            session.prefersEphemeralWebBrowserSession = false
            webSession = session
            if !session.start() {
                continuation.resume(throwing: AuthenticationError.unavailable)
            }
        }
    }

    func presentationAnchor(for session: ASWebAuthenticationSession) -> ASPresentationAnchor {
        UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .flatMap(\.windows)
            .first(where: \.isKeyWindow) ?? ASPresentationAnchor()
    }

    nonisolated static func challenge(for verifier: String) -> String {
        let digest = SHA256.hash(data: Data(verifier.utf8))
        return Data(digest).base64URLEncodedString()
    }

    nonisolated static func nonceHash(for nonce: String) -> String {
        SHA256.hash(data: Data(nonce.utf8)).map { String(format: "%02x", $0) }.joined()
    }

    nonisolated static func randomVerifier() -> String {
        var bytes = [UInt8](repeating: 0, count: 32)
        let status = SecRandomCopyBytes(kSecRandomDefault, bytes.count, &bytes)
        precondition(status == errSecSuccess, "Secure random generator unavailable")
        return Data(bytes).base64URLEncodedString()
    }
}

private extension Data {
    func base64URLEncodedString() -> String {
        base64EncodedString()
            .replacingOccurrences(of: "+", with: "-")
            .replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: "=", with: "")
    }
}
