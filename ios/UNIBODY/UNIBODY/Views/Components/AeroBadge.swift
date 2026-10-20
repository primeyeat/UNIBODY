import SwiftUI

public struct AeroBadge: View {
    public let text: String
    public var icon: String? = nil
    public var color: Color = AeroTheme.skyBlue
    
    public init(_ text: String, icon: String? = nil, color: Color = AeroTheme.skyBlue) {
        self.text = text
        self.icon = icon
        self.color = color
    }
    
    public var body: some View {
        HStack(spacing: 4) {
            if let icon = icon {
                Image(systemName: icon)
                    .font(.caption2.weight(.bold))
            }
            Text(text)
                .font(.caption2.weight(.semibold))
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .foregroundColor(color)
        .background(
            Capsule()
                .fill(color.opacity(0.15))
        )
        .overlay(
            Capsule()
                .strokeBorder(color.opacity(0.35), lineWidth: 0.8)
        )
    }
}

// MARK: - Easter Egg: Für Claire Modal View
public struct ClaireEasterEggModalView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var heartScale: CGFloat = 1.0
    @State private var haloScale: CGFloat = 0.9
    @State private var haloOpacity: Double = 0.4
    @State private var floatingParticles: [ParticleItem] = []
    
    struct ParticleItem: Identifiable {
        let id = UUID()
        let symbol: String
        let xOffset: CGFloat
        var yOffset: CGFloat
        var opacity: Double
    }
    
    public init() {}
    
    public var body: some View {
        ZStack {
            // Dreamy Frutiger Aero Pink Glass Gradient
            LinearGradient(
                colors: [
                    Color(red: 1.0, green: 0.94, blue: 0.97),
                    Color(red: 1.0, green: 0.82, blue: 0.90),
                    Color(red: 1.0, green: 0.72, blue: 0.83)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()
            
            // Floating background sparkles & hearts
            ForEach(floatingParticles) { p in
                Text(p.symbol)
                    .font(.system(size: 24))
                    .position(x: p.xOffset, y: p.yOffset)
                    .opacity(p.opacity)
            }
            
            // Specular gloss reflection at top
            VStack {
                LinearGradient(
                    colors: [
                        Color.white.opacity(0.85),
                        Color.white.opacity(0.08)
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )
                .frame(height: 160)
                .cornerRadius(32)
                .padding(.horizontal, 8)
                .padding(.top, 4)
                Spacer()
            }
            .allowsHitTesting(false)
            
            // Main Content
            VStack(spacing: 16) {
                HStack {
                    Spacer()
                    Button {
                        #if canImport(UIKit)
                        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                        #endif
                        dismiss()
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.title2)
                            .foregroundColor(Color(red: 0.75, green: 0.08, blue: 0.24).opacity(0.8))
                    }
                    .padding(.top, 16)
                    .padding(.trailing, 20)
                }
                
                Spacer()
                
                // Pulsing Center Heart
                ZStack {
                    Circle()
                        .fill(
                            RadialGradient(
                                colors: [
                                    Color(red: 1.0, green: 0.41, blue: 0.71).opacity(haloOpacity),
                                    Color.clear
                                ],
                                center: .center,
                                startRadius: 10,
                                endRadius: 90
                            )
                        )
                        .frame(width: 170, height: 170)
                        .scaleEffect(haloScale)
                    
                    Text("💖")
                        .font(.system(size: 78))
                        .scaleEffect(heartScale)
                        .shadow(color: Color(red: 0.9, green: 0.1, blue: 0.4).opacity(0.45), radius: 16, y: 8)
                }
                .onAppear {
                    withAnimation(
                        .easeInOut(duration: 0.9)
                        .repeatForever(autoreverses: true)
                    ) {
                        heartScale = 1.16
                    }
                    withAnimation(
                        .easeInOut(duration: 1.5)
                        .repeatForever(autoreverses: true)
                    ) {
                        haloScale = 1.3
                        haloOpacity = 0.85
                    }
                    startParticles()
                }
                
                // Title: Für Claire
                Text("Für Claire")
                    .font(.system(size: 36, weight: .heavy, design: .rounded))
                    .foregroundStyle(
                        LinearGradient(
                            colors: [
                                Color(red: 0.88, green: 0.11, blue: 0.28),
                                Color(red: 0.86, green: 0.15, blue: 0.47),
                                Color(red: 0.62, green: 0.09, blue: 0.3)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .shadow(color: Color(red: 0.9, green: 0.1, blue: 0.4).opacity(0.2), radius: 4, y: 2)
                
                // Subtitle Tag
                HStack(spacing: 6) {
                    Text("💕 Von Herzen gemacht ✨")
                        .font(.system(.caption, design: .rounded).weight(.bold))
                        .foregroundColor(Color(red: 0.75, green: 0.07, blue: 0.24))
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 6)
                .background(
                    Capsule()
                        .fill(Color.white.opacity(0.9))
                        .overlay(Capsule().stroke(Color(red: 1.0, green: 0.41, blue: 0.71).opacity(0.5), lineWidth: 1))
                        .shadow(color: Color.pink.opacity(0.2), radius: 6, y: 2)
                )
                
                // Warm Romantic Message
                Text("Du bringst Licht in jeden Tag – ganz egal ob im Daylight- oder im Dark-Mode. 🌸")
                    .font(.system(.subheadline, design: .rounded).weight(.medium))
                    .multilineTextAlignment(.center)
                    .foregroundColor(Color(red: 0.3, green: 0.02, blue: 0.1))
                    .padding(.horizontal, 32)
                    .lineSpacing(4)
                
                // Decorative row
                HStack(spacing: 16) {
                    Text("🌸").font(.title3)
                    Text("✨").font(.title3)
                    Text("💖").font(.title3)
                    Text("✨").font(.title3)
                    Text("🌷").font(.title3)
                }
                .padding(.top, 4)
                
                Spacer()
                
                // Sweet Dismiss Action Button
                Button {
                    #if canImport(UIKit)
                    UINotificationFeedbackGenerator().notificationOccurred(.success)
                    #endif
                    dismiss()
                } label: {
                    Text("Hab dich lieb! 💖")
                        .font(.system(.headline, design: .rounded).weight(.bold))
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(
                            LinearGradient(
                                colors: [
                                    Color(red: 1.0, green: 0.4, blue: 0.6),
                                    Color(red: 1.0, green: 0.2, blue: 0.47),
                                    Color(red: 0.88, green: 0.05, blue: 0.32)
                                ],
                                startPoint: .top,
                                endPoint: .bottom
                            )
                        )
                        .clipShape(Capsule())
                        .overlay(
                            Capsule()
                                .strokeBorder(Color.white.opacity(0.6), lineWidth: 1)
                        )
                        .shadow(color: Color(red: 0.88, green: 0.05, blue: 0.32).opacity(0.45), radius: 12, y: 6)
                }
                .padding(.horizontal, 32)
                .padding(.bottom, 24)
            }
        }
    }
    
    private func startParticles() {
        let symbols = ["💖", "💕", "🌸", "✨", "💗", "🌷", "🤍"]
        for _ in 0..<12 {
            let p = ParticleItem(
                symbol: symbols.randomElement() ?? "💖",
                xOffset: CGFloat.random(in: 40...340),
                yOffset: CGFloat.random(in: 200...650),
                opacity: Double.random(in: 0.4...0.85)
            )
            floatingParticles.append(p)
        }
    }
}
