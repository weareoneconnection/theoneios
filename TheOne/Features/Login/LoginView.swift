import AuthenticationServices
import SwiftUI

struct LoginView: View {
    @EnvironmentObject private var session: AppSession
    @Environment(\.horizontalSizeClass) private var sizeClass
    @AppStorage("theone.native.locale") private var locale = AppLanguage.preferred.rawValue
    @State private var emailExpanded = false
    @State private var email = ""
    @State private var code = ""
    @State private var codeSent = false
    @State private var emailBusy = false
    @State private var emailMessage = ""
    @State private var emailError = ""
    @FocusState private var focusedField: EmailField?

    var body: some View {
        GeometryReader { proxy in
            ZStack {
                background
                ScrollView {
                    VStack(spacing: 0) {
                        Spacer(minLength: max(56, proxy.size.height * 0.10))

                        BrandMark(size: 72)
                        Text("TheOne")
                            .font(.system(size: 34, weight: .bold, design: .rounded))
                            .foregroundStyle(Brand.ink)
                            .padding(.top, 18)

                        VStack(spacing: 5) {
                            Text(language.text("真正会执行的 AI", "AI that gets work done"))
                            Text(language.text("把目标变成结果", "Turn goals into results"))
                        }
                        .font(.system(size: sizeClass == .regular ? 38 : 31, weight: .bold))
                        .tracking(-0.8)
                        .lineLimit(1)
                        .minimumScaleFactor(0.82)
                        .multilineTextAlignment(.center)
                        .foregroundStyle(Brand.ink)
                        .padding(.top, 44)

                        Text(language.text(
                            "从对话、研究到编程与长期目标。\n每一步都有权限边界、证据和你的最终决定。",
                            "From conversation and research to code and long-running goals.\nEvery step stays within authority, evidence, and your final say."
                        ))
                            .font(.system(size: 17))
                            .foregroundStyle(Brand.muted)
                            .multilineTextAlignment(.center)
                            .lineSpacing(6)
                            .padding(.top, 16)

                        VStack(spacing: 12) {
                            SignInWithAppleButton(.continue) { request in
                                session.prepareAppleSignIn(request)
                            } onCompletion: { result in
                                session.completeAppleSignIn(result)
                            }
                            .signInWithAppleButtonStyle(.black)
                            .frame(height: 54)
                            .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))

                            Button(action: session.signInWithGitHub) {
                                Label(language.text("使用 GitHub 登录", "Continue with GitHub"), systemImage: "chevron.left.forwardslash.chevron.right")
                            }
                            .buttonStyle(PrimaryButtonStyle())

                            if emailExpanded {
                                emailPanel
                                    .transition(.opacity.combined(with: .move(edge: .top)))
                            } else {
                                Button {
                                    withAnimation(.easeOut(duration: 0.22)) { emailExpanded = true }
                                    focusedField = .email
                                } label: {
                                    Label(language.text("使用邮箱登录", "Continue with email"), systemImage: "envelope")
                                        .font(.system(size: 17, weight: .semibold))
                                        .frame(maxWidth: .infinity)
                                        .frame(height: 54)
                                        .foregroundStyle(Brand.ink)
                                        .background(.white.opacity(0.78), in: RoundedRectangle(cornerRadius: 18, style: .continuous))
                                        .overlay(RoundedRectangle(cornerRadius: 18, style: .continuous).stroke(Brand.border))
                                }
                            }
                        }
                        .frame(maxWidth: 520)
                        .padding(.top, 42)

                        HStack(spacing: 16) {
                            Link(language.text("隐私政策", "Privacy"), destination: session.configuration.url(path: "/privacy"))
                            Text("·")
                            Link(language.text("服务条款", "Terms"), destination: session.configuration.url(path: "/terms"))
                        }
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(Brand.muted)
                        .padding(.top, 28)
                        .padding(.bottom, 28)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.horizontal, 28)
                }

                VStack {
                    HStack {
                        Spacer()
                        Button(language == .zh ? "EN" : "中") {
                            locale = language == .zh ? AppLanguage.en.rawValue : AppLanguage.zh.rawValue
                            UISelectionFeedbackGenerator().selectionChanged()
                        }
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(Brand.ink)
                        .frame(width: 44, height: 44)
                        .background(.white.opacity(0.72), in: Circle())
                        .overlay(Circle().stroke(Brand.border))
                    }
                    Spacer()
                }
                .padding(.horizontal, 20)
                .padding(.top, 4)
            }
        }
    }

    private var language: AppLanguage { AppLanguage(rawValue: locale) ?? .preferred }

    private var emailPanel: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text(language.text("邮箱登录", "Email sign-in"))
                    .font(.system(size: 17, weight: .bold))
                Spacer()
                Button {
                    focusedField = nil
                    withAnimation(.easeOut(duration: 0.2)) { emailExpanded = false }
                } label: {
                    Image(systemName: "xmark")
                        .font(.system(size: 13, weight: .bold))
                        .frame(width: 32, height: 32)
                }
                .foregroundStyle(Brand.muted)
                .accessibilityLabel(language.text("关闭邮箱登录", "Close email sign-in"))
            }

            TextField(language.text("你的邮箱", "Email address"), text: $email)
                .textContentType(.emailAddress)
                .keyboardType(.emailAddress)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                .focused($focusedField, equals: .email)
                .submitLabel(codeSent ? .next : .send)
                .onSubmit {
                    if codeSent { focusedField = .code } else { requestCode() }
                }
                .emailFieldStyle()

            if codeSent {
                TextField(language.text("6 位验证码", "6-digit code"), text: $code)
                    .textContentType(.oneTimeCode)
                    .keyboardType(.numberPad)
                    .focused($focusedField, equals: .code)
                    .onChange(of: code) { _, value in
                        code = String(value.filter(\.isNumber).prefix(6))
                    }
                    .emailFieldStyle()
            }

            if !emailError.isEmpty {
                Label(emailError, systemImage: "exclamationmark.circle.fill")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(.red)
                    .fixedSize(horizontal: false, vertical: true)
            } else if !emailMessage.isEmpty {
                Label(emailMessage, systemImage: "checkmark.circle.fill")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(.green)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Button {
                if codeSent { verifyCode() } else { requestCode() }
            } label: {
                HStack(spacing: 9) {
                    if emailBusy { ProgressView().tint(.white) }
                    Text(codeSent ? language.text("登录", "Sign in") : language.text("发送验证码", "Send code"))
                }
                .frame(maxWidth: .infinity)
            }
            .buttonStyle(PrimaryButtonStyle())
            .disabled(emailBusy || !emailReady || (codeSent && code.count != 6))
            .opacity(emailBusy || !emailReady || (codeSent && code.count != 6) ? 0.48 : 1)

            if codeSent {
                Button(language.text("重新发送验证码", "Send a new code"), action: requestCode)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(Brand.muted)
                    .frame(maxWidth: .infinity)
                    .disabled(emailBusy)
            }
        }
        .padding(18)
        .background(.white.opacity(0.78), in: RoundedRectangle(cornerRadius: 22, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 22, style: .continuous).stroke(Brand.border))
    }

    private var emailReady: Bool {
        let value = email.trimmingCharacters(in: .whitespacesAndNewlines)
        return value.contains("@") && value.contains(".") && value.count <= 200
    }

    private func requestCode() {
        guard emailReady, !emailBusy else { return }
        focusedField = nil
        emailBusy = true
        emailError = ""
        Task {
            do {
                emailMessage = try await session.requestEmailCode(email: email, language: language)
                codeSent = true
                focusedField = .code
                UISelectionFeedbackGenerator().selectionChanged()
            } catch {
                emailError = error.localizedDescription
                UINotificationFeedbackGenerator().notificationOccurred(.error)
            }
            emailBusy = false
        }
    }

    private func verifyCode() {
        guard emailReady, code.count == 6, !emailBusy else { return }
        focusedField = nil
        emailBusy = true
        emailError = ""
        Task {
            do {
                try await session.verifyEmailCode(email: email, code: code, language: language)
            } catch {
                emailError = error.localizedDescription
                UINotificationFeedbackGenerator().notificationOccurred(.error)
            }
            emailBusy = false
        }
    }

    private var background: some View {
        ZStack {
            Brand.canvas
            RadialGradient(
                colors: [Brand.accent.opacity(0.13), .clear],
                center: .topLeading,
                startRadius: 10,
                endRadius: 430
            )
            Canvas { context, size in
                var path = Path()
                stride(from: 0.0, through: size.width, by: 44).forEach {
                    path.move(to: CGPoint(x: $0, y: 0)); path.addLine(to: CGPoint(x: $0, y: size.height))
                }
                stride(from: 0.0, through: size.height, by: 44).forEach {
                    path.move(to: CGPoint(x: 0, y: $0)); path.addLine(to: CGPoint(x: size.width, y: $0))
                }
                context.stroke(path, with: .color(.black.opacity(0.027)), lineWidth: 0.5)
            }
        }
        .ignoresSafeArea()
    }
}

private enum EmailField: Hashable {
    case email
    case code
}

private extension View {
    func emailFieldStyle() -> some View {
        self
            .font(.system(size: 17))
            .foregroundStyle(Brand.ink)
            .padding(.horizontal, 16)
            .frame(height: 52)
            .background(.white, in: RoundedRectangle(cornerRadius: 15, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 15, style: .continuous).stroke(Brand.border))
    }
}
