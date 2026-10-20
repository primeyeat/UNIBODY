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
