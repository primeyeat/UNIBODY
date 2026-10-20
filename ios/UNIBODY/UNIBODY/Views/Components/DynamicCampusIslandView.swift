import SwiftUI
import MapKit

public struct DynamicCampusIslandView: View {
    @EnvironmentObject var appState: AppState
    public let event: ScheduleEvent
    public var onClose: () -> Void = {}
    
    @State private var mapDisplayMode: MapDisplayMode = .campusPlan
    @State private var isExpanded: Bool
    @State private var pulseAnimation: Bool = false
    @State private var isNotchPressed: Bool = false
    
    public enum MapDisplayMode: String, CaseIterable, Identifiable {
        case campusPlan = "Campus-Plan"
        case appleMaps = "Apple Maps"
        case floorBlueprint = "Raumplan"
        
        public var id: String { rawValue }
        public var icon: String {
            switch self {
            case .campusPlan: return "map.fill"
            case .appleMaps: return "location.north.line.fill"
            case .floorBlueprint: return "square.split.bottomrightquarter.fill"
            }
        }
    }
    
    private var resolvedRoom: ResolvedCampusRoom {
        CampusLocationEngine.resolve(room: event.room)
    }
    
    public init(event: ScheduleEvent, startExpanded: Bool = false, onClose: @escaping () -> Void = {}) {
        self.event = event
        self._isExpanded = State(initialValue: startExpanded)
        self.onClose = onClose
    }
    
    public var body: some View {
        GeometryReader { geo in
            let centerX = geo.size.width / 2
            
            ZStack(alignment: .top) {
                // Dimming backdrop when island is expanded
                if isExpanded {
                    Color.black.opacity(0.45)
                        .ignoresSafeArea()
                        .onTapGesture {
                            minimizeToIsland()
                        }
                        .transition(.opacity)
                }
                
                // NATIVE DYNAMIC ISLAND:
                // Anchored directly at the physical iPhone TrueDepth camera notch (y = 11pt, height = 37pt).
                // Minimized: Compact black pill hugging the camera sensor cutout.
                // Expanded: Full campus navigator card morphing directly out of the camera notch.
                if isExpanded {
                    expandedIslandCard(in: geo)
                        .padding(.top, 11)
                        .padding(.horizontal, 14)
                        .transition(.asymmetric(
                            insertion: .scale(scale: 0.88, anchor: .top).combined(with: .opacity),
                            removal: .scale(scale: 0.88, anchor: .top).combined(with: .opacity)
                        ))
                } else {
                    compactIslandHardwareNotch(in: geo)
                        .padding(.top, 11)
                        .transition(.asymmetric(
                            insertion: .scale(scale: 0.90, anchor: .top).combined(with: .opacity),
                            removal: .scale(scale: 0.90, anchor: .top).combined(with: .opacity)
                        ))
                }
                
                // ========================================================
                // NOTCH HARDWARE INTERACTION ZONE (Centered at camera cutout)
                // Width 260pt, Height 60pt (y: 0 to 60pt)
                // Catches Long Press directly on the camera notch to open and close!
                // ========================================================
                NotchHardwareTouchZone {
                    toggleIsland()
                }
                .frame(width: 260, height: 60)
                .position(x: centerX, y: 30) // Perfectly covers the camera notch and status bar area!
                .zIndex(1000)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
            .animation(.spring(response: 0.38, dampingFraction: 0.76), value: isExpanded)
            .animation(.spring(response: 0.30, dampingFraction: 0.82), value: mapDisplayMode)
            .onAppear {
                pulseAnimation = true
            }
        }
    }
    
    // Toggle Dynamic Island open and close with heavy haptic feedback
    private func toggleIsland() {
        #if canImport(UIKit)
        UIImpactFeedbackGenerator(style: .heavy).impactOccurred()
        #endif
        withAnimation(.spring(response: 0.38, dampingFraction: 0.76)) {
            isExpanded.toggle()
        }
    }
    
    private func expandFromIsland() {
        #if canImport(UIKit)
        UIImpactFeedbackGenerator(style: .heavy).impactOccurred()
        #endif
        withAnimation(.spring(response: 0.38, dampingFraction: 0.76)) {
            isExpanded = true
        }
    }
    
    private func minimizeToIsland() {
        #if canImport(UIKit)
        UIImpactFeedbackGenerator(style: .heavy).impactOccurred()
        #endif
        withAnimation(.spring(response: 0.38, dampingFraction: 0.76)) {
            isExpanded = false
        }
    }
    
    // MARK: - 1. Compact Notch Island (Physically wraps around the TrueDepth camera cutout)
    private func compactIslandHardwareNotch(in geo: GeometryProxy) -> some View {
        HStack(spacing: 0) {
            // Leading flank: Left of camera sensor
            HStack(spacing: 5) {
                Image(systemName: resolvedRoom.building.iconName)
                    .font(.system(size: 13, weight: .bold))
                    .foregroundColor(AeroTheme.emerald)
                Text(resolvedRoom.building.code)
                    .font(.system(size: 13, weight: .black, design: .rounded))
                    .foregroundColor(.white)
            }
            .padding(.leading, 14)
            
            // Center space: Where the physical camera hardware cutout sits
            Spacer(minLength: 80)
            
            // Trailing flank: Right of camera sensor
            HStack(spacing: 6) {
                Text("\(resolvedRoom.building.walkingMinutes) Min")
                    .font(.system(size: 12, weight: .bold, design: .rounded))
                    .foregroundColor(AeroTheme.skyBlue)
                
                Circle()
                    .fill(AeroTheme.emerald)
                    .frame(width: 7, height: 7)
                    .scaleEffect(pulseAnimation ? 1.3 : 0.85)
                    .opacity(pulseAnimation ? 1.0 : 0.6)
                    .animation(.easeInOut(duration: 0.9).repeatForever(autoreverses: true), value: pulseAnimation)
            }
            .padding(.trailing, 14)
        }
        .frame(width: 236, height: 37) // Standard compact Dynamic Island hardware footprint
        .background(
            Capsule()
                .fill(Color.black)
                .overlay(
                    Capsule()
                        .strokeBorder(
                            LinearGradient(
                                colors: [
                                    AeroTheme.skyBlue.opacity(0.6),
                                    AeroTheme.emerald.opacity(0.5),
                                    Color.white.opacity(0.15)
                                ],
                                startPoint: .leading,
                                endPoint: .trailing
                            ),
                            lineWidth: 1.0
                        )
                )
                .shadow(color: Color.black.opacity(0.85), radius: 10, y: 4)
        )
        .contentShape(Rectangle())
        .onLongPressGesture(minimumDuration: 0.2, maximumDistance: 50) {
            toggleIsland()
        }
        .simultaneousGesture(
            TapGesture().onEnded {
                toggleIsland()
            }
        )
    }
    
    // MARK: - 2. Expanded Island Card (Expands seamlessly downwards from the camera notch)
    private func expandedIslandCard(in geo: GeometryProxy) -> some View {
        VStack(spacing: 11) {
            // ============================================
            // TOP CAMERA NOTCH ROW (Physically sitting right at the camera cutout)
            // ============================================
            HStack(spacing: 0) {
                // Leading flank: Left of camera
                HStack(spacing: 5) {
                    Circle()
                        .fill(AeroTheme.emerald)
                        .frame(width: 7, height: 7)
                    Text("CAMPUS-RADAR")
                        .font(.system(size: 9.5, weight: .black, design: .rounded))
                        .foregroundColor(AeroTheme.emerald)
                    Text("·")
                        .foregroundColor(.secondary)
                    Text(resolvedRoom.building.code)
                        .font(.system(size: 9.5, weight: .bold))
                        .foregroundColor(.white.opacity(0.85))
                }
                .padding(.leading, 16)
                
                Spacer(minLength: 16)
                
                // Center Camera Notch Touch Zone (where camera is physically located!)
                ZStack {
                    Capsule()
                        .fill(Color.white.opacity(0.08))
                        .frame(width: 80, height: 24)
                        .overlay(
                            Capsule()
                                .strokeBorder(Color.white.opacity(0.15), lineWidth: 0.8)
                        )
                    
                    HStack(spacing: 4) {
                        Image(systemName: "chevron.up")
                            .font(.system(size: 9, weight: .heavy))
                            .foregroundColor(.white.opacity(0.7))
                    }
                }
                .contentShape(Rectangle())
                .onLongPressGesture(minimumDuration: 0.2, maximumDistance: 50) {
                    toggleIsland()
                }
                .simultaneousGesture(
                    TapGesture().onEnded {
                        toggleIsland()
                    }
                )
                
                Spacer(minLength: 16)
                
                // Trailing flank: Right of camera (Minimize & Close buttons)
                HStack(spacing: 8) {
                    Button {
                        minimizeToIsland()
                    } label: {
                        Image(systemName: "chevron.up.circle.fill")
                            .font(.system(size: 17))
                            .foregroundColor(.white.opacity(0.75))
                    }
                    
                    Button {
                        #if canImport(UIKit)
                        UIImpactFeedbackGenerator(style: .light).impactOccurred()
                        #endif
                        onClose()
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 17))
                            .foregroundColor(.white.opacity(0.75))
                    }
                }
                .padding(.trailing, 16)
            }
            .frame(height: 37) // Exact height matching the camera notch
            .padding(.top, 4)
            .contentShape(Rectangle())
            .onLongPressGesture(minimumDuration: 0.2, maximumDistance: 50) {
                toggleIsland()
            }
            
            // ============================================
            // EVENT & LOCATION HEADER
            // ============================================
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 3) {
                    Text(event.title)
                        .font(.system(.headline, design: .rounded).weight(.bold))
                        .foregroundColor(.white)
                        .lineLimit(1)
                    
                    HStack(spacing: 6) {
                        AeroBadge(resolvedRoom.building.code, icon: resolvedRoom.building.iconName, color: AeroTheme.emerald)
                        AeroBadge(resolvedRoom.roomName, color: AeroTheme.solarOrange)
                        AeroBadge(resolvedRoom.floor, color: AeroTheme.skyBlue)
                    }
                    .padding(.top, 2)
                }
                
                Spacer()
                
                VStack(alignment: .trailing, spacing: 2) {
                    Text(resolvedRoom.building.area)
                        .font(.system(size: 9.5, weight: .bold))
                        .foregroundColor(.white.opacity(0.75))
                    
                    Text("ca. \(resolvedRoom.walkingDistanceMeters) m")
                        .font(.system(size: 9, weight: .semibold))
                        .foregroundColor(AeroTheme.skyBlue)
                }
            }
            .padding(.horizontal, 16)
            
            // ============================================
            // 3-WAY MAP SELECTOR
            // ============================================
            HStack(spacing: 4) {
                ForEach(MapDisplayMode.allCases) { mode in
                    Button {
                        #if canImport(UIKit)
                        UIImpactFeedbackGenerator(style: .light).impactOccurred()
                        #endif
                        mapDisplayMode = mode
                    } label: {
                        HStack(spacing: 6) {
                            Image(systemName: mode.icon)
                                .font(.caption2)
                            Text(mode.rawValue)
                                .font(.system(.caption, design: .rounded).weight(.bold))
                        }
                        .foregroundColor(mapDisplayMode == mode ? .white : .secondary)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 7)
                        .background(
                            RoundedRectangle(cornerRadius: 10, style: .continuous)
                                .fill(mapDisplayMode == mode ? AeroTheme.skyBlue : Color.white.opacity(0.06))
                        )
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 16)
            
            // ============================================
            // MAP CANVAS
            // ============================================
            ZStack {
                switch mapDisplayMode {
                case .campusPlan:
                    VectorCampusMapView(targetBuilding: resolvedRoom.building, roomName: resolvedRoom.roomName)
                case .appleMaps:
                    LiveAppleMapView(coordinate: resolvedRoom.building.coordinate, title: resolvedRoom.building.name, subtitle: resolvedRoom.roomName)
                case .floorBlueprint:
                    FloorBlueprintView(resolvedRoom: resolvedRoom)
                }
            }
            .frame(height: 220)
            .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .strokeBorder(Color.white.opacity(0.18), lineWidth: 1)
            )
            .padding(.horizontal, 16)
            
            // ============================================
            // NAVIGATION TIP BANNER
            // ============================================
            HStack(alignment: .top, spacing: 10) {
                Image(systemName: "figure.walk.motion")
                    .font(.title3)
                    .foregroundColor(AeroTheme.emerald)
                    .padding(.top, 2)
                
                VStack(alignment: .leading, spacing: 2) {
                    HStack {
                        Text("Wegbeschreibung & Ankunft")
                            .font(.system(.caption, design: .rounded).weight(.bold))
                            .foregroundColor(AeroTheme.emerald)
                        Spacer()
                        Text("\(resolvedRoom.building.walkingMinutes) Min. Gehzeit")
                            .font(.caption2.weight(.bold))
                            .foregroundColor(.white.opacity(0.9))
                    }
                    
                    Text(resolvedRoom.navigationTip)
                        .font(.caption2)
                        .foregroundColor(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            .padding(11)
            .background(RoundedRectangle(cornerRadius: 12).fill(Color.white.opacity(0.06)))
            .padding(.horizontal, 16)
            
            // ============================================
            // ACTION BUTTONS
            // ============================================
            HStack(spacing: 12) {
                Button {
                    let destName = "Christian-Albrechts-Universität \(resolvedRoom.building.address)"
                        .addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? ""
                    let lat = resolvedRoom.building.coordinate.latitude
                    let lon = resolvedRoom.building.coordinate.longitude
                    if let url = URL(string: "http://maps.apple.com/?daddr=\(lat),\(lon)&dirflg=w&q=\(destName)") {
                        UIApplication.shared.open(url)
                    }
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: "location.fill")
                        Text("In Apple Maps navigieren")
                    }
                    .font(.system(.subheadline, design: .rounded).weight(.bold))
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 11)
                    .glossyButton(gradient: AeroTheme.auroraGradient, cornerRadius: 14)
                }
                
                Button {
                    UIPasteboard.general.string = "\(resolvedRoom.building.code): \(resolvedRoom.roomName) (\(resolvedRoom.building.address))"
                    #if canImport(UIKit)
                    UINotificationFeedbackGenerator().notificationOccurred(.success)
                    #endif
                } label: {
                    Image(systemName: "doc.on.doc.fill")
                        .font(.subheadline)
                        .foregroundColor(AeroTheme.skyBlue)
                        .padding(11)
                        .background(RoundedRectangle(cornerRadius: 14).fill(Color.white.opacity(0.08)))
                        .overlay(RoundedRectangle(cornerRadius: 14).strokeBorder(AeroTheme.skyBlue.opacity(0.4), lineWidth: 1))
                }
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 16)
        }
        .background(
            ZStack {
                Color.black.opacity(0.97)
                LinearGradient(
                    colors: [
                        Color(red: 0.02, green: 0.08, blue: 0.16).opacity(0.95),
                        Color.black.opacity(0.98)
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )
            }
            .clipShape(
                RoundedRectangle(cornerRadius: 38, style: .continuous)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 38, style: .continuous)
                    .strokeBorder(
                        LinearGradient(
                            colors: [
                                AeroTheme.skyBlue.opacity(0.65),
                                AeroTheme.emerald.opacity(0.45),
                                Color.white.opacity(0.15)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: 1.2
                    )
            )
            .shadow(color: Color.black.opacity(0.85), radius: 24, y: 12)
        )
    }
}

// MARK: - Notch Hardware Touch Zone (UIKit Gesture Recognizer hooked directly to the notch)
struct NotchHardwareTouchZone: UIViewRepresentable {
    var onToggle: () -> Void
    
    func makeUIView(context: Context) -> UIView {
        let view = TouchPassThroughView()
        view.backgroundColor = .clear
        view.isUserInteractionEnabled = true
        
        let longPress = UILongPressGestureRecognizer(target: context.coordinator, action: #selector(Coordinator.handleLongPress(_:)))
        longPress.minimumPressDuration = 0.20
        longPress.allowableMovement = 60.0
        longPress.cancelsTouchesInView = false
        view.addGestureRecognizer(longPress)
        
        let tap = UITapGestureRecognizer(target: context.coordinator, action: #selector(Coordinator.handleTap(_:)))
        tap.cancelsTouchesInView = false
        view.addGestureRecognizer(tap)
        
        return view
    }
    
    func updateUIView(_ uiView: UIView, context: Context) {
        context.coordinator.onToggle = onToggle
    }
    
    func makeCoordinator() -> Coordinator {
        Coordinator(onToggle: onToggle)
    }
    
    class Coordinator: NSObject {
        var onToggle: () -> Void
        private var lastTriggerTime: Date = .distantPast
        
        init(onToggle: @escaping () -> Void) {
            self.onToggle = onToggle
        }
        
        @objc func handleLongPress(_ gesture: UILongPressGestureRecognizer) {
            if gesture.state == .began {
                guard Date().timeIntervalSince(lastTriggerTime) > 0.35 else { return }
                lastTriggerTime = Date()
                onToggle()
            }
        }
        
        @objc func handleTap(_ gesture: UITapGestureRecognizer) {
            guard Date().timeIntervalSince(lastTriggerTime) > 0.35 else { return }
            lastTriggerTime = Date()
            onToggle()
        }
    }
}

class TouchPassThroughView: UIView {
    override func point(inside point: CGPoint, with event: UIEvent?) -> Bool {
        return self.bounds.contains(point)
    }
}

// MARK: - Big Detailed Vector Campus Map View (Authentic CAU Kiel Zentralcampus Layout)
private struct VectorCampusMapView: View {
    let targetBuilding: CampusBuilding
    let roomName: String
    
    @State private var radarPulse = false
    @State private var dashOffset: CGFloat = 0
    
    var body: some View {
        GeometryReader { geo in
            let w = geo.size.width
            let h = geo.size.height
            
            ZStack {
                // CAU Campus Green Lawn Ground
                Color(red: 0.03, green: 0.09, blue: 0.14)
                
                // ============================================
                // 1. ROADS & STREETS OF CAU KIEL (Geographically Grounded)
                // ============================================
                
                // Westring (Major North-South avenue along the East edge)
                Path { path in
                    path.move(to: CGPoint(x: w * 0.88, y: h))
                    path.addLine(to: CGPoint(x: w * 0.88, y: 0))
                }
                .stroke(Color.white.opacity(0.18), style: StrokeStyle(lineWidth: 18, lineCap: .butt))
                
                // Olshausenstraße (Diagonal Artery running North-West through Campus)
                Path { path in
                    path.move(to: CGPoint(x: w * 0.88, y: h * 0.68))
                    path.addLine(to: CGPoint(x: 0, y: h * 0.25))
                }
                .stroke(Color.white.opacity(0.20), style: StrokeStyle(lineWidth: 18, lineCap: .round, lineJoin: .round))
                
                // Ludewig-Meyn-Straße (Branches West from CAP towards LMS 8)
                Path { path in
                    path.move(to: CGPoint(x: w * 0.36, y: h * 0.64))
                    path.addLine(to: CGPoint(x: 0, y: h * 0.68))
                }
                .stroke(Color.white.opacity(0.16), style: StrokeStyle(lineWidth: 14, lineCap: .round))
                
                // Street Dashed Lane Dividers
                Path { path in
                    path.move(to: CGPoint(x: w * 0.88, y: h))
                    path.addLine(to: CGPoint(x: w * 0.88, y: 0))
                    path.move(to: CGPoint(x: w * 0.88, y: h * 0.68))
                    path.addLine(to: CGPoint(x: 0, y: h * 0.25))
                    path.move(to: CGPoint(x: w * 0.36, y: h * 0.64))
                    path.addLine(to: CGPoint(x: 0, y: h * 0.68))
                }
                .stroke(Color.white.opacity(0.35), style: StrokeStyle(lineWidth: 1.2, dash: [5, 5]))
                
                // Street Name Labels
                Text("Westring")
                    .font(.system(size: 8, weight: .bold))
                    .foregroundColor(Color.white.opacity(0.45))
                    .rotationEffect(.degrees(90))
                    .position(x: w * 0.93, y: h * 0.40)
                
                Text("Olshausenstraße")
                    .font(.system(size: 8, weight: .bold))
                    .foregroundColor(Color.white.opacity(0.55))
                    .rotationEffect(.degrees(-26))
                    .position(x: w * 0.42, y: h * 0.42)
                
                Text("Ludewig-Meyn-Str.")
                    .font(.system(size: 7, weight: .bold))
                    .foregroundColor(Color.white.opacity(0.40))
                    .position(x: w * 0.16, y: h * 0.62)
                
                // ============================================
                // 2. CENTRAL PEDESTRIAN PLAZA (Christian-Albrechts-Platz)
                // ============================================
                // Large paved pedestrian square connecting Mensa I, Audimax, CAP 3 & CAP 4
                RoundedRectangle(cornerRadius: 14)
                    .fill(
                        LinearGradient(
                            colors: [
                                Color(red: 0.08, green: 0.20, blue: 0.28).opacity(0.8),
                                Color(red: 0.05, green: 0.14, blue: 0.22).opacity(0.9)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 14)
                            .strokeBorder(Color.white.opacity(0.12), lineWidth: 1)
                    )
                    .frame(width: w * 0.58, height: h * 0.44)
                    .position(x: w * 0.54, y: h * 0.72)
                
                Text("Christian-Albrechts-Platz")
                    .font(.system(size: 7.5, weight: .black, design: .rounded))
                    .foregroundColor(Color.white.opacity(0.35))
                    .position(x: w * 0.54, y: h * 0.74)
                
                // ============================================
                // 3. CAMPUS BUILDINGS (Accurate Relative Geography)
                // ============================================
                
                // CAP 4: Uni-Hochhaus (North edge of Christian-Albrechts-Platz)
                let isCAP4 = targetBuilding.id == "CAP4"
                CampusBuildingBlock(
                    title: "Uni-Hochhaus",
                    code: "CAP 4",
                    isTarget: isCAP4,
                    rect: CGRect(x: w * 0.46, y: h * 0.51, width: w * 0.16, height: h * 0.12)
                )
                
                // CAP 3: Hörsaalgebäude (West side of Christian-Albrechts-Platz with Hörsaal 1, 2, 3)
                let isCAP3 = targetBuilding.id == "CAP3"
                CampusBuildingBlock(
                    title: "Hörsäle 1, 2, 3",
                    code: "CAP 3",
                    isTarget: isCAP3,
                    rect: CGRect(x: w * 0.26, y: h * 0.64, width: w * 0.20, height: h * 0.16)
                )
                
                // CAP 2: Audimax (East side of Christian-Albrechts-Platz facing Westring)
                let isCAP2 = targetBuilding.id == "CAP2"
                CampusBuildingBlock(
                    title: "Audimax CAU",
                    code: "CAP 2",
                    isTarget: isCAP2,
                    rect: CGRect(x: w * 0.63, y: h * 0.64, width: w * 0.21, height: h * 0.16)
                )
                
                // Mensa I: Westring 385 (South edge of Christian-Albrechts-Platz)
                let isMensa = targetBuilding.id == "Mensa1"
                CampusBuildingBlock(
                    title: "Mensa I & AStA",
                    code: "Mensa I",
                    isTarget: isMensa,
                    rect: CGRect(x: w * 0.40, y: h * 0.82, width: w * 0.28, height: h * 0.14)
                )
                
                // LMS 8: Institut für Informatik & Geographie (West along Ludewig-Meyn-Straße)
                let isLMS8 = targetBuilding.id == "LMS8"
                CampusBuildingBlock(
                    title: "Informatik",
                    code: "LMS 8",
                    isTarget: isLMS8,
                    rect: CGRect(x: w * 0.03, y: h * 0.62, width: w * 0.20, height: h * 0.18)
                )
                
                // OS 40: Chemiezentrum / Otto-Hahn-Platz (North-West across Olshausenstraße)
                let isOH14 = targetBuilding.id == "OH14"
                CampusBuildingBlock(
                    title: "OS 40 (Chemie)",
                    code: "OS 40",
                    isTarget: isOH14,
                    rect: CGRect(x: w * 0.16, y: h * 0.12, width: w * 0.22, height: h * 0.16)
                )
                
                // WSP 7: WiSo-Hochhaus / Wilhelm-Seelig-Platz (North-Center across Olshausenstraße)
                let isWSP7 = targetBuilding.id == "WSP7"
                CampusBuildingBlock(
                    title: "WSP 7 (WiSo)",
                    code: "WSP 7",
                    isTarget: isWSP7,
                    rect: CGRect(x: w * 0.45, y: h * 0.12, width: w * 0.20, height: h * 0.16)
                )
                
                // HHP 6: Physik & Mathematik / Heinrich-Hecht-Platz (North-East corner)
                let isHHP6 = targetBuilding.id == "HHP6"
                CampusBuildingBlock(
                    title: "HHP 6 (Mathe/Physik)",
                    code: "HHP 6",
                    isTarget: isHHP6,
                    rect: CGRect(x: w * 0.68, y: h * 0.04, width: w * 0.22, height: h * 0.16)
                )
                
                // ============================================
                // 4. ANIMATED WALKING PATH TO TARGET
                // ============================================
                if isCAP3 {
                    // Path from Mensa/Westring across CAP to CAP 3 entrance
                    Path { path in
                        path.move(to: CGPoint(x: w * 0.54, y: h * 0.84))
                        path.addLine(to: CGPoint(x: w * 0.44, y: h * 0.76))
                        path.addLine(to: CGPoint(x: w * 0.36, y: h * 0.72))
                    }
                    .stroke(AeroTheme.emerald, style: StrokeStyle(lineWidth: 2.5, lineCap: .round, dash: [4, 4], dashPhase: dashOffset))
                    .onAppear {
                        withAnimation(.linear(duration: 1.2).repeatForever(autoreverses: false)) {
                            dashOffset = -16
                        }
                    }
                } else if isCAP2 {
                    // Path to Audimax
                    Path { path in
                        path.move(to: CGPoint(x: w * 0.54, y: h * 0.84))
                        path.addLine(to: CGPoint(x: w * 0.65, y: h * 0.76))
                        path.addLine(to: CGPoint(x: w * 0.73, y: h * 0.72))
                    }
                    .stroke(AeroTheme.emerald, style: StrokeStyle(lineWidth: 2.5, lineCap: .round, dash: [4, 4], dashPhase: dashOffset))
                } else if isLMS8 {
                    // Path to LMS 8
                    Path { path in
                        path.move(to: CGPoint(x: w * 0.44, y: h * 0.76))
                        path.addLine(to: CGPoint(x: w * 0.26, y: h * 0.68))
                        path.addLine(to: CGPoint(x: w * 0.13, y: h * 0.71))
                    }
                    .stroke(AeroTheme.emerald, style: StrokeStyle(lineWidth: 2.5, lineCap: .round, dash: [4, 4], dashPhase: dashOffset))
                }
                
                // ============================================
                // 5. TARGET RADAR PIN ON SELECTED BUILDING
                // ============================================
                let targetPos = getBuildingPosition(building: targetBuilding, in: geo.size)
                
                ZStack {
                    // Pulsing radar ripple
                    Circle()
                        .stroke(AeroTheme.emerald, lineWidth: 2)
                        .frame(width: radarPulse ? 70 : 20, height: radarPulse ? 70 : 20)
                        .opacity(radarPulse ? 0.0 : 0.9)
                    
                    // Pin badge
                    VStack(spacing: 2) {
                        Image(systemName: "mappin.circle.fill")
                            .font(.system(size: 26))
                            .foregroundColor(AeroTheme.emerald)
                            .shadow(color: AeroTheme.emerald, radius: 10)
                        
                        Text(roomName)
                            .font(.system(size: 9, weight: .black, design: .rounded))
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Capsule().fill(Color.black.opacity(0.85)))
                            .overlay(Capsule().stroke(AeroTheme.emerald, lineWidth: 1))
                            .foregroundColor(.white)
                    }
                    .offset(y: -24)
                }
                .position(targetPos)
                .onAppear {
                    withAnimation(.easeOut(duration: 1.6).repeatForever(autoreverses: false)) {
                        radarPulse = true
                    }
                }
                
                // Compass Rose & Scale in corner
                VStack(alignment: .trailing, spacing: 4) {
                    HStack(spacing: 4) {
                        Image(systemName: "location.north.circle.fill")
                            .font(.caption2)
                            .foregroundColor(AeroTheme.skyBlue)
                        Text("N")
                            .font(.system(size: 9, weight: .bold))
                            .foregroundColor(AeroTheme.skyBlue)
                    }
                    
                    HStack(spacing: 2) {
                        Rectangle()
                            .fill(Color.white.opacity(0.8))
                            .frame(width: 32, height: 2)
                        Text("100 m")
                            .font(.system(size: 8, weight: .semibold))
                            .foregroundColor(.white.opacity(0.7))
                    }
                }
                .position(x: w - 38, y: h - 18)
            }
        }
    }
    
    private func getBuildingPosition(building: CampusBuilding, in size: CGSize) -> CGPoint {
        switch building.id {
        case "CAP3":
            return CGPoint(x: size.width * 0.36, y: size.height * 0.72)
        case "CAP2":
            return CGPoint(x: size.width * 0.74, y: size.height * 0.72)
        case "Mensa1":
            return CGPoint(x: size.width * 0.54, y: size.height * 0.89)
        case "LMS8":
            return CGPoint(x: size.width * 0.13, y: size.height * 0.71)
        case "HHP6":
            return CGPoint(x: size.width * 0.79, y: size.height * 0.12)
        case "OH14":
            return CGPoint(x: size.width * 0.27, y: size.height * 0.20)
        case "WSP7":
            return CGPoint(x: size.width * 0.55, y: size.height * 0.20)
        default:
            return CGPoint(x: size.width * 0.36, y: size.height * 0.72)
        }
    }
}

// MARK: - Campus Building Block Element
private struct CampusBuildingBlock: View {
    let title: String
    let code: String
    let isTarget: Bool
    let rect: CGRect
    
    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: isTarget
                            ? [Color(red: 0.1, green: 0.45, blue: 0.35), Color(red: 0.05, green: 0.3, blue: 0.22)]
                            : [Color(red: 0.12, green: 0.22, blue: 0.34), Color(red: 0.08, green: 0.16, blue: 0.26)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .strokeBorder(
                            isTarget ? AeroTheme.emerald : Color.white.opacity(0.2),
                            lineWidth: isTarget ? 2 : 1
                        )
                )
                .shadow(color: isTarget ? AeroTheme.emerald.opacity(0.4) : Color.black.opacity(0.3), radius: isTarget ? 8 : 4)
            
            VStack(spacing: 2) {
                Text(code)
                    .font(.system(size: 11, weight: .black, design: .rounded))
                    .foregroundColor(isTarget ? AeroTheme.emerald : .white)
                
                Text(title)
                    .font(.system(size: 7, weight: .medium))
                    .foregroundColor(.white.opacity(0.75))
                    .lineLimit(1)
            }
            .padding(4)
        }
        .frame(width: rect.width, height: rect.height)
        .position(x: rect.midX, y: rect.midY)
    }
}

// MARK: - Live Apple MapView (MapKit with Real CAU Kiel Coordinates)
private struct LiveAppleMapView: View {
    let coordinate: CLLocationCoordinate2D
    let title: String
    let subtitle: String
    
    @State private var region: MKCoordinateRegion
    
    init(coordinate: CLLocationCoordinate2D, title: String, subtitle: String) {
        self.coordinate = coordinate
        self.title = title
        self.subtitle = subtitle
        _region = State(initialValue: MKCoordinateRegion(
            center: coordinate,
            span: MKCoordinateSpan(latitudeDelta: 0.0032, longitudeDelta: 0.0032)
        ))
    }
    
    struct CampusMapItem: Identifiable {
        let id = UUID()
        let coordinate: CLLocationCoordinate2D
        let title: String
        let subtitle: String
        let isTarget: Bool
    }
    
    var body: some View {
        let landmarks: [(CLLocationCoordinate2D, String, String)] = [
            (CLLocationCoordinate2D(latitude: 54.338464, longitude: 10.121958), "CAP 3", "Hörsäle 1-3"),
            (CLLocationCoordinate2D(latitude: 54.338236, longitude: 10.123757), "CAP 2", "Audimax"),
            (CLLocationCoordinate2D(latitude: 54.338828, longitude: 10.122530), "CAP 4", "Uni-Hochhaus"),
            (CLLocationCoordinate2D(latitude: 54.337469, longitude: 10.122759), "Mensa I", "Westring 385"),
            (CLLocationCoordinate2D(latitude: 54.337512, longitude: 10.121552), "LMS 8", "Informatik"),
            (CLLocationCoordinate2D(latitude: 54.339409, longitude: 10.121270), "OS 40", "Chemie"),
            (CLLocationCoordinate2D(latitude: 54.339718, longitude: 10.123655), "WSP 7", "WiSo"),
            (CLLocationCoordinate2D(latitude: 54.341271, longitude: 10.124403), "HHP 6", "Mathe & Physik")
        ]
        
        var items: [CampusMapItem] = [
            CampusMapItem(coordinate: coordinate, title: title, subtitle: subtitle, isTarget: true)
        ]
        
        for lm in landmarks {
            let dLat = abs(lm.0.latitude - coordinate.latitude)
            let dLon = abs(lm.0.longitude - coordinate.longitude)
            if dLat > 0.0003 || dLon > 0.0003 {
                items.append(CampusMapItem(coordinate: lm.0, title: lm.1, subtitle: lm.2, isTarget: false))
            }
        }
        
        return ZStack(alignment: .bottomTrailing) {
            Map(coordinateRegion: $region, annotationItems: items) { item in
                MapAnnotation(coordinate: item.coordinate) {
                    if item.isTarget {
                        VStack(spacing: 2) {
                            ZStack {
                                Circle()
                                    .fill(AeroTheme.emerald.opacity(0.3))
                                    .frame(width: 32, height: 32)
                                Image(systemName: "mappin.circle.fill")
                                    .font(.title2)
                                    .foregroundColor(AeroTheme.emerald)
                                    .background(Circle().fill(Color.black).padding(2))
                            }
                            
                            VStack(spacing: 1) {
                                Text(item.title)
                                    .font(.system(size: 8, weight: .black))
                                    .foregroundColor(AeroTheme.emerald)
                                Text(item.subtitle)
                                    .font(.system(size: 7.5, weight: .bold))
                                    .foregroundColor(.white)
                            }
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Capsule().fill(Color.black.opacity(0.85)))
                            .overlay(Capsule().stroke(AeroTheme.emerald.opacity(0.6), lineWidth: 1))
                        }
                    } else {
                        VStack(spacing: 1) {
                            Text(item.title)
                                .font(.system(size: 7.5, weight: .bold))
                            Text(item.subtitle)
                                .font(.system(size: 6.5, weight: .medium))
                        }
                        .padding(.horizontal, 5)
                        .padding(.vertical, 2)
                        .background(Capsule().fill(Color(red: 0.08, green: 0.16, blue: 0.24).opacity(0.88)))
                        .overlay(Capsule().stroke(Color.white.opacity(0.15), lineWidth: 0.8))
                        .foregroundColor(.white.opacity(0.85))
                    }
                }
            }
            
            // Re-center button
            Button {
                withAnimation {
                    region = MKCoordinateRegion(
                        center: coordinate,
                        span: MKCoordinateSpan(latitudeDelta: 0.0032, longitudeDelta: 0.0032)
                    )
                }
            } label: {
                Image(systemName: "location.fill")
                    .font(.caption)
                    .foregroundColor(AeroTheme.skyBlue)
                    .padding(8)
                    .background(Circle().fill(Color.black.opacity(0.8)))
                    .overlay(Circle().stroke(AeroTheme.skyBlue.opacity(0.5), lineWidth: 1))
            }
            .padding(8)
        }
    }
}

// MARK: - Floor Blueprint Indoor Layout View (Realistic Architectural Auditorium & Lab Layout)
private struct FloorBlueprintView: View {
    let resolvedRoom: ResolvedCampusRoom
    
    var body: some View {
        GeometryReader { geo in
            let w = geo.size.width
            let h = geo.size.height
            
            ZStack {
                // Blueprint architectural grid background
                Color(red: 0.02, green: 0.08, blue: 0.16)
                
                // Architectural grid lines
                Path { path in
                    let step: CGFloat = 18
                    for x in stride(from: CGFloat(0), to: w, by: step) {
                        path.move(to: CGPoint(x: x, y: 0))
                        path.addLine(to: CGPoint(x: x, y: h))
                    }
                    for y in stride(from: CGFloat(0), to: h, by: step) {
                        path.move(to: CGPoint(x: 0, y: y))
                        path.addLine(to: CGPoint(x: w, y: y))
                    }
                }
                .stroke(Color.white.opacity(0.04), lineWidth: 1)
                
                // Outer building perimeter wall
                RoundedRectangle(cornerRadius: 14)
                    .strokeBorder(AeroTheme.skyBlue.opacity(0.6), lineWidth: 2)
                    .padding(10)
                
                // Specialized Building Architecture: CAP 3 Hörsäle vs CAP 2 Audimax vs LMS 8 Informatik vs Generic
                if resolvedRoom.building.id == "CAP3" {
                    cap3ArchitecturalLayout(w: w, h: h)
                } else if resolvedRoom.building.id == "CAP2" {
                    cap2AudimaxArchitecturalLayout(w: w, h: h)
                } else if resolvedRoom.building.id == "LMS8" {
                    lms8ArchitecturalLayout(w: w, h: h)
                } else {
                    genericFloorLayout(w: w, h: h)
                }
                
                // Floor level indicator badge
                HStack(spacing: 6) {
                    Image(systemName: "stairs")
                        .font(.caption2)
                    Text(resolvedRoom.floor)
                        .font(.system(size: 9, weight: .bold))
                }
                .foregroundColor(AeroTheme.skyBlue)
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(Capsule().fill(Color.black.opacity(0.85)))
                .overlay(Capsule().stroke(AeroTheme.skyBlue.opacity(0.4), lineWidth: 1))
                .position(x: w * 0.26, y: h * 0.12)
            }
        }
    }
    
    // CAP 3 Hörsaalgebäude Architecture (Hörsaal 1, Hörsaal 2, Hörsaal 3, KMH)
    @ViewBuilder
    private func cap3ArchitecturalLayout(w: CGFloat, h: CGFloat) -> some View {
        let isH2 = resolvedRoom.roomName.contains("2") || (!resolvedRoom.roomName.contains("1") && !resolvedRoom.roomName.contains("3"))
        let isH3 = resolvedRoom.roomName.contains("3")
        let isH1 = resolvedRoom.roomName.contains("1") && !isH2 && !isH3
        
        // 1. Hörsaal 1 (400 Plätze, Left Lecture Wing)
        LectureHallAuditoriumBlock(
            code: "Hörsaal 1",
            capacity: "400 Plätze",
            isTarget: isH1,
            rect: CGRect(x: w * 0.08, y: h * 0.18, width: w * 0.40, height: h * 0.54)
        )
        
        // 2. Hörsaal 2 (280 Plätze, Right Upper Wing - TARGET FOR VL INF-MATH)
        LectureHallAuditoriumBlock(
            code: "Hörsaal 2",
            capacity: "280 Plätze (Seminar & VL)",
            isTarget: isH2,
            rect: CGRect(x: w * 0.52, y: h * 0.18, width: w * 0.40, height: h * 0.32)
        )
        
        // 3. Hörsaal 3 (120 Plätze, Right Lower Wing)
        LectureHallAuditoriumBlock(
            code: "Hörsaal 3",
            capacity: "120 Plätze",
            isTarget: isH3,
            rect: CGRect(x: w * 0.52, y: h * 0.53, width: w * 0.40, height: h * 0.20)
        )
        
        // 4. Foyer / Haupteingang Christian-Albrechts-Platz (Bottom Hallway)
        ZStack {
            RoundedRectangle(cornerRadius: 6)
                .fill(Color.white.opacity(0.05))
                .overlay(RoundedRectangle(cornerRadius: 6).strokeBorder(Color.white.opacity(0.18), lineWidth: 1))
            
            HStack(spacing: 8) {
                Image(systemName: "arrow.up")
                    .font(.caption2)
                    .foregroundColor(AeroTheme.emerald)
                Text("CAP 3 FOYER & EINGANG (Christian-Albrechts-Platz)")
                    .font(.system(size: 8, weight: .heavy, design: .rounded))
                    .foregroundColor(.white.opacity(0.85))
            }
        }
        .frame(width: w * 0.84, height: h * 0.15)
        .position(x: w * 0.50, y: h * 0.82)
    }
    
    // CAP 2 Audimax Architecture (Frederik-Paulsen-Hörsaal & Hörsäle A-K)
    @ViewBuilder
    private func cap2AudimaxArchitecturalLayout(w: CGFloat, h: CGFloat) -> some View {
        // Frederik-Paulsen-Hörsaal (1250 Plätze amphitheater)
        LectureHallAuditoriumBlock(
            code: "Audimax (Paulsen-HS)",
            capacity: "Frederik-Paulsen-HS · 1250 Plätze",
            isTarget: true,
            rect: CGRect(x: w * 0.08, y: h * 0.18, width: w * 0.54, height: h * 0.54)
        )
        
        // Hörsäle A & B
        LectureHallAuditoriumBlock(
            code: "Hörsaal A/B",
            capacity: "Hörsaal A & B · 120 Plätze",
            isTarget: false,
            rect: CGRect(x: w * 0.66, y: h * 0.18, width: w * 0.26, height: h * 0.54)
        )
        
        // Audimax Freitreppe & Foyer
        ZStack {
            RoundedRectangle(cornerRadius: 6)
                .fill(Color.white.opacity(0.05))
                .overlay(RoundedRectangle(cornerRadius: 6).strokeBorder(Color.white.opacity(0.18), lineWidth: 1))
            
            HStack(spacing: 8) {
                Image(systemName: "arrow.up")
                    .font(.caption2)
                    .foregroundColor(AeroTheme.emerald)
                Text("AUDIMAX FOYER & FREITREPPE (Christian-Albrechts-Platz)")
                    .font(.system(size: 8, weight: .heavy, design: .rounded))
                    .foregroundColor(.white.opacity(0.85))
            }
        }
        .frame(width: w * 0.84, height: h * 0.15)
        .position(x: w * 0.50, y: h * 0.82)
    }
    
    // LMS 8 Informatik Architecture (Raum 018, CIP-Pools, Courtyard)
    @ViewBuilder
    private func lms8ArchitecturalLayout(w: CGFloat, h: CGFloat) -> some View {
        let isCIP = resolvedRoom.roomName.lowercased().contains("cip")
        let isR018 = !isCIP
        
        // Linux CIP Pool
        LectureHallAuditoriumBlock(
            code: "CIP-Pool 1",
            capacity: "Linux CIP-Arbeitsplätze",
            isTarget: isCIP,
            rect: CGRect(x: w * 0.08, y: h * 0.18, width: w * 0.40, height: h * 0.52)
        )
        
        // Raum 018 Informatik Übungsraum
        LectureHallAuditoriumBlock(
            code: "Raum 018",
            capacity: "Informatik-Übungsraum",
            isTarget: isR018,
            rect: CGRect(x: w * 0.52, y: h * 0.18, width: w * 0.40, height: h * 0.52)
        )
        
        // Innenhof Eingang
        ZStack {
            RoundedRectangle(cornerRadius: 6)
                .fill(Color.white.opacity(0.05))
                .overlay(RoundedRectangle(cornerRadius: 6).strokeBorder(Color.white.opacity(0.18), lineWidth: 1))
            
            HStack(spacing: 8) {
                Image(systemName: "arrow.up")
                    .font(.caption2)
                    .foregroundColor(AeroTheme.emerald)
                Text("INNENHOF EINGANG (Ludewig-Meyn-Str. 8)")
                    .font(.system(size: 8, weight: .heavy, design: .rounded))
                    .foregroundColor(.white.opacity(0.85))
            }
        }
        .frame(width: w * 0.84, height: h * 0.16)
        .position(x: w * 0.50, y: h * 0.81)
    }
    
    // Generic Floor Blueprint
    @ViewBuilder
    private func genericFloorLayout(w: CGFloat, h: CGFloat) -> some View {
        ForEach(resolvedRoom.floorRooms) { room in
            let rx = w * room.xFraction
            let ry = h * room.yFraction
            let rw = w * room.widthFraction
            let rh = h * room.heightFraction
            
            LectureHallAuditoriumBlock(
                code: room.code,
                capacity: room.name,
                isTarget: room.isTarget,
                rect: CGRect(x: rx, y: ry, width: rw, height: rh)
            )
        }
    }
}

// MARK: - Authentic Lecture Hall / Auditorium Blueprint Component
private struct LectureHallAuditoriumBlock: View {
    let code: String
    let capacity: String
    let isTarget: Bool
    let rect: CGRect
    
    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 8)
                .fill(
                    isTarget
                        ? Color(red: 0.05, green: 0.38, blue: 0.28).opacity(0.7)
                        : Color.white.opacity(0.05)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .strokeBorder(
                            isTarget ? AeroTheme.emerald : Color.white.opacity(0.25),
                            lineWidth: isTarget ? 2 : 1
                        )
                )
                .shadow(color: isTarget ? AeroTheme.emerald.opacity(0.5) : Color.clear, radius: 10)
            
            VStack(spacing: 4) {
                // Front Blackboard / Speaker Stage line
                HStack(spacing: 4) {
                    Rectangle()
                        .fill(isTarget ? AeroTheme.emerald : Color.white.opacity(0.4))
                        .frame(height: 2)
                    Text("TAFEL")
                        .font(.system(size: 6, weight: .bold))
                        .foregroundColor(isTarget ? AeroTheme.emerald : Color.white.opacity(0.5))
                    Rectangle()
                        .fill(isTarget ? AeroTheme.emerald : Color.white.opacity(0.4))
                        .frame(height: 2)
                }
                .padding(.horizontal, 10)
                
                // Tiered row lines simulating seating
                VStack(spacing: 3) {
                    ForEach(0..<3) { _ in
                        Rectangle()
                            .fill(Color.white.opacity(isTarget ? 0.25 : 0.10))
                            .frame(height: 1.2)
                            .padding(.horizontal, 8)
                    }
                }
                
                Spacer()
                
                // Room Title & Capacity
                HStack(spacing: 4) {
                    if isTarget {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.system(size: 10))
                            .foregroundColor(AeroTheme.emerald)
                    }
                    Text(code)
                        .font(.system(size: 11, weight: .heavy, design: .rounded))
                        .foregroundColor(isTarget ? AeroTheme.emerald : .white)
                }
                
                Text(capacity)
                    .font(.system(size: 7, weight: .medium))
                    .foregroundColor(.white.opacity(0.8))
                    .lineLimit(1)
                
                Spacer()
            }
            .padding(6)
        }
        .frame(width: rect.width, height: rect.height)
        .position(x: rect.midX, y: rect.midY)
    }
}
