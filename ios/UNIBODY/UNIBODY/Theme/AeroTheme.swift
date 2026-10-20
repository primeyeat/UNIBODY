import SwiftUI

public enum AeroTheme {
    // Primary Frutiger Aero palette
    public static let skyBlue = Color(red: 0.0, green: 0.635, blue: 1.0)
    public static let deepOcean = Color(red: 0.012, green: 0.078, blue: 0.141)
    public static let auroraGreen = Color(red: 0.063, green: 0.725, blue: 0.506)
    public static let emerald = Color(red: 0.133, green: 0.773, blue: 0.369)
    public static let solarOrange = Color(red: 1.0, green: 0.55, blue: 0.0)
    public static let rubyRed = Color(red: 0.94, green: 0.27, blue: 0.27)
    public static let vaporWhite = Color.white.opacity(0.92)
    
    // Gradients
    public static let oceanGradient = LinearGradient(
        colors: [Color(red: 0.0, green: 0.55, blue: 0.95), Color(red: 0.0, green: 0.3, blue: 0.75)],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )
    
    public static let auroraGradient = LinearGradient(
        colors: [Color(red: 0.05, green: 0.75, blue: 0.55), Color(red: 0.0, green: 0.55, blue: 0.95)],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )
    
    public static let darkSpaceGradient = LinearGradient(
        colors: [Color(red: 0.02, green: 0.06, blue: 0.12), Color(red: 0.01, green: 0.03, blue: 0.07)],
        startPoint: .top,
        endPoint: .bottom
    )
}

public struct FrutigerGlassModifier: ViewModifier {
    var cornerRadius: CGFloat = 16
    var isInteractive: Bool = false
    
    public func body(content: Content) -> some View {
        content
            .background(
                ZStack {
                    RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                        .fill(.ultraThinMaterial)
                    
                    // Specular gloss reflection across the top
                    RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                        .fill(
                            LinearGradient(
                                colors: [
                                    Color.white.opacity(0.35),
                                    Color.white.opacity(0.08),
                                    Color.clear
                                ],
                                startPoint: .top,
                                endPoint: .center
                            )
                        )
                    
                    // Luminous glass border
                    RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                        .strokeBorder(
                            LinearGradient(
                                colors: [
                                    Color.white.opacity(0.6),
                                    Color.white.opacity(0.15),
                                    AeroTheme.skyBlue.opacity(0.3)
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            lineWidth: 1
                        )
                }
            )
            .shadow(color: Color.black.opacity(0.12), radius: 10, x: 0, y: 5)
    }
}

public struct GlossyButtonModifier: ViewModifier {
    var gradient: LinearGradient = AeroTheme.oceanGradient
    var cornerRadius: CGFloat = 14
    
    public func body(content: Content) -> some View {
        content
            .font(.system(.body, design: .rounded).weight(.semibold))
            .foregroundColor(.white)
            .padding(.horizontal, 20)
            .padding(.vertical, 12)
            .background(
                ZStack {
                    RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                        .fill(gradient)
                    
                    // Gel bubble top specular highlight
                    VStack {
                        RoundedRectangle(cornerRadius: cornerRadius - 2, style: .continuous)
                            .fill(
                                LinearGradient(
                                    colors: [Color.white.opacity(0.55), Color.white.opacity(0.05)],
                                    startPoint: .top,
                                    endPoint: .bottom
                                )
                            )
                            .frame(height: 18)
                            .padding(.horizontal, 2)
                            .padding(.top, 2)
                        Spacer()
                    }
                    
                    RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                        .strokeBorder(Color.white.opacity(0.4), lineWidth: 1)
                }
            )
            .shadow(color: AeroTheme.skyBlue.opacity(0.35), radius: 8, x: 0, y: 4)
    }
}

public extension View {
    func frutigerGlass(cornerRadius: CGFloat = 16) -> some View {
        modifier(FrutigerGlassModifier(cornerRadius: cornerRadius))
    }
    
    func glossyButton(gradient: LinearGradient = AeroTheme.oceanGradient, cornerRadius: CGFloat = 14) -> some View {
        modifier(GlossyButtonModifier(gradient: gradient, cornerRadius: cornerRadius))
    }
}
