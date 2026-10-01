import XCTest
@testable import TheOne

final class AppCoreTests: XCTestCase {
    func testProductionEndpointsStayOnTheOneOrigin() {
        let configuration = AppConfiguration.production
        XCTAssertEqual(configuration.baseURL.absoluteString, "https://www.the1os.io")
        XCTAssertEqual(configuration.githubSignInURL(challenge: String(repeating: "a", count: 43)).host, "www.the1os.io")
        XCTAssertEqual(configuration.exchangeURL(code: String(repeating: "b", count: 43), verifier: String(repeating: "c", count: 43)).path, "/api/auth/desktop/exchange")
    }

    func testPKCEChallengeIsURLSafeAndDeterministic() {
        let verifier = String(repeating: "v", count: 43)
        let first = AuthenticationCoordinator.challenge(for: verifier)
        XCTAssertEqual(first, AuthenticationCoordinator.challenge(for: verifier))
        XCTAssertEqual(first.count, 43)
        XCTAssertNil(first.range(of: "[^A-Za-z0-9_-]", options: .regularExpression))
    }

    func testAppleNonceIsSHA256Hex() {
        let hash = AuthenticationCoordinator.nonceHash(for: "test-nonce")
        XCTAssertEqual(hash, "ed04c4e9ea6c49cf9ceb39098787c5b9842524f96b07ef45305476a11caec9b4")
        XCTAssertEqual(hash.count, 64)
        XCTAssertNil(hash.range(of: "[^a-f0-9]", options: .regularExpression))
    }

    func testRedirectDoesNotReplayOneTimeInitialURL() {
        let exchange = URL(string: "https://www.the1os.io/api/auth/desktop/exchange?code=once")!
        let workspace = URL(string: "https://www.the1os.io/os")!
        var state = InitialNavigationState()

        XCTAssertTrue(state.shouldLoad(exchange))
        // WebKit may redirect to the workspace, but SwiftUI still owns the
        // same initial request and must not load it a second time.
        XCTAssertFalse(state.shouldLoad(exchange))
        XCTAssertTrue(state.shouldLoad(workspace))
        XCTAssertFalse(state.shouldLoad(workspace))
    }
}
