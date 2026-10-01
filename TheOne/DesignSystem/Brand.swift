import SwiftUI

enum Brand {
    static let ink = Color(red: 0.10, green: 0.09, blue: 0.08)
    static let muted = Color(red: 0.43, green: 0.40, blue: 0.36)
    static let accent = Color(red: 0.78, green: 0.28, blue: 0.13)
    static let warm = Color(red: 0.98, green: 0.97, blue: 0.94)
    static let canvas = Color(red: 0.985, green: 0.979, blue: 0.962)
    static let border = Color.black.opacity(0.085)
}

struct BrandMark: View {
    var size: CGFloat = 64

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: size * 0.27, style: .continuous)
                .fill(Brand.ink)
            Circle()
                .trim(from: 0.08, to: 0.84)
                .stroke(.white, style: StrokeStyle(lineWidth: size * 0.09, lineCap: .round))
                .padding(size * 0.23)
                .rotationEffect(.degrees(-42))
            Circle()
                .fill(Color(red: 0.92, green: 0.36, blue: 0.16))
                .frame(width: size * 0.16, height: size * 0.16)
                .offset(x: size * 0.17, y: -size * 0.18)
        }
        .frame(width: size, height: size)
        .accessibilityHidden(true)
    }
}

struct PrimaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 17, weight: .semibold))
            .frame(maxWidth: .infinity)
            .frame(height: 56)
            .foregroundStyle(.white)
            .background(Brand.ink.opacity(configuration.isPressed ? 0.82 : 1), in: RoundedRectangle(cornerRadius: 18, style: .continuous))
            .scaleEffect(configuration.isPressed ? 0.985 : 1)
            .animation(.easeOut(duration: 0.12), value: configuration.isPressed)
    }
}
