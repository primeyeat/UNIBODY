import SwiftUI
import MapKit

public struct DynamicCampusIslandView: View {
    @EnvironmentObject var appState: AppState
    public let event: ScheduleEvent
    public var onClose: () -> Void = {}
    
    @State private var mapDisplayMode: MapDisplayMode = .campusPlan
    @State private var isExpanded: Bool = true
    @State private var pulseAnimation: Bool = false
    @State private var islandPressed: Bool = false
    
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
    
    public init(event: ScheduleEvent, onClose: @escaping () -> Void = {}) {
        self.event = event
        self.onClose = onClose
    }
    
    public var body: some View {
        ZStack(alignment: .top) {
            // Background dimming scrim when expanded
            if isExpanded {
                Color.black.opacity(0.45)
                    .ignoresSafeArea()
                    .onTapGesture {
                        toggleIslandExpansion()
                    }
                    .transition(.opacity)
            }
            
            VStack(spacing: 8) {
                // 1. HARDWARE DYNAMIC ISLAND PILL (Fixed at top notch position)
                dynamicIslandHardwarePill
                    .zIndex(100)
                
                // 2. EXPANDED CAMPUS NAVIGATOR CARD (Hanging cleanly below notch)
                if isExpanded {
                    expandedIslandCard
                        .transition(.asymmetric(
                            insertion: .scale(scale: 0.88, anchor: .top).combined(with: .opacity).combined(with: .move(edge: .top)),
                            removal: .scale(scale: 0.88, anchor: .top).combined(with: .opacity).combined(with: .move(edge: .top))
                        ))
                }
            }
            .padding(.top, 11) // Exact physical position of iPhone 14 Pro/15/16 Dynamic Island
            .animation(.spring(response: 0.38, dampingFraction: 0.76), value: isExpanded)
            .animation(.spring(response: 0.32, dampingFraction: 0.8), value: mapDisplayMode)
        }
        .onAppear {
            pulseAnimation = true
        }
    }
    
    // Toggle expand/minimize with heavy haptic feedback as requested
    private func toggleIslandExpansion() {
        #if canImport(UIKit)
        UIImpactFeedbackGenerator(style: .heavy).impactOccurred()
        #endif
        withAnimation(.spring(response: 0.38, dampingFraction: 0.76)) {
            isExpanded.toggle()
        }
    }
    
    // MARK: - Dynamic Island Hardware Pill (Responsive to Long Press & Tap)
    private var dynamicIslandHardwarePill: some View {
        HStack(spacing: 8) {
            // Leading Island Sensor Flank
            HStack(spacing: 5) {
                Image(systemName: resolvedRoom.building.iconName)
                    .font(.system(size: 13, weight: .bold))
                    .foregroundColor(AeroTheme.emerald)
                Text("\(resolvedRoom.building.code) · \(resolvedRoom.roomName)")
                    .font(.system(size: 12, weight: .bold, design: .rounded))
                    .foregroundColor(.white)
                    .lineLimit(1)
            }
            
            Spacer(minLength: 10)
            
            // Trailing Island Sensor Flank
            HStack(spacing: 6) {
                Circle()
                    .fill(AeroTheme.emerald)
                    .frame(width: 7, height: 7)
                    .scaleEffect(pulseAnimation ? 1.3 : 0.85)
                    .opacity(pulseAnimation ? 1.0 : 0.6)
                    .animation(.easeInOut(duration: 0.9).repeatForever(autoreverses: true), value: pulseAnimation)
                
                Text("\(resolvedRoom.building.walkingMinutes) Min")
                    .font(.system(size: 12, weight: .bold, design: .rounded))
                    .foregroundColor(AeroTheme.skyBlue)
                
                Image(systemName: isExpanded ? "chevron.up.circle.fill" : "chevron.down.circle.fill")
                    .font(.system(size: 13, weight: .bold))
                    .foregroundColor(.white.opacity(0.8))
            }
        }
        .padding(.horizontal, 14)
        .frame(width: isExpanded ? 300 : 252, height: 37) // Dynamic Island Hardware Width
        .background(
            Capsule()
                .fill(Color.black)
                .overlay(
                    Capsule()
                        .strokeBorder(
                            LinearGradient(
                                colors: [
                                    AeroTheme.skyBlue.opacity(0.7),
                                    AeroTheme.emerald.opacity(0.6),
                                    Color.white.opacity(0.2)
                                ],
                                startPoint: .leading,
                                endPoint: .trailing
                            ),
                            lineWidth: 1.2
                        )
                )
                .shadow(color: Color.black.opacity(0.85), radius: 10, y: 4)
        )
        .scaleEffect(islandPressed ? 0.96 : 1.0)
        // User requested: Long press on Dynamic Island toggles expansion
        .onLongPressGesture(minimumDuration: 0.25, pressing: { pressing in
            withAnimation(.easeInOut(duration: 0.15)) {
                islandPressed = pressing
            }
        }, perform: {
            toggleIslandExpansion()
        })
        .onTapGesture {
            toggleIslandExpansion()
        }
    }
    
    // MARK: - Expanded Detailed Campus Navigator Card
    private var expandedIslandCard: some View {
        VStack(spacing: 12) {
            // Header Bar
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 3) {
                    HStack(spacing: 6) {
                        Circle()
                            .fill(AeroTheme.emerald)
                            .frame(width: 8, height: 8)
                        Text("LIVE-CAMPUS-RADAR")
                            .font(.system(size: 10, weight: .black, design: .rounded))
                            .foregroundColor(AeroTheme.emerald)
                        
                        Text("·")
                            .foregroundColor(.secondary)
                        
                        Text(resolvedRoom.building.area)
                            .font(.system(size: 10, weight: .bold))
                            .foregroundColor(.white.opacity(0.8))
                    }
                    
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
                
                // Minimize & Close Buttons
                HStack(spacing: 8) {
                    Button {
                        toggleIslandExpansion()
                    } label: {
                        Image(systemName: "chevron.up.circle.fill")
                            .font(.title3)
                            .foregroundColor(.white.opacity(0.75))
                    }
                    
                    Button {
                        #if canImport(UIKit)
                        UIImpactFeedbackGenerator(style: .light).impactOccurred()
                        #endif
                        onClose()
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.title3)
                            .foregroundColor(.white.opacity(0.75))
                    }
                }
            }
            .padding(.horizontal, 16)
            .padding(.top, 14)
            
            // Map Mode Segmented Switcher
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
            
            // Big Detailed Map Canvas
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
            .frame(height: 230)
            .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .strokeBorder(Color.white.opacity(0.18), lineWidth: 1)
            )
            .padding(.horizontal, 16)
            
            // Navigation Tip Banner
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
                        Text("ca. \(resolvedRoom.walkingDistanceMeters) m · \(resolvedRoom.building.walkingMinutes) Min.")
                            .font(.caption2.weight(.bold))
                            .foregroundColor(.white.opacity(0.9))
                    }
                    
                    Text(resolvedRoom.navigationTip)
                        .font(.caption2)
                        .foregroundColor(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            .padding(12)
            .background(RoundedRectangle(cornerRadius: 12).fill(Color.white.opacity(0.06)))
            .padding(.horizontal, 16)
            
            // Action Buttons
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
                Color.black.opacity(0.95)
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
                RoundedRectangle(cornerRadius: 26, style: .continuous)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 26, style: .continuous)
                    .strokeBorder(
                        LinearGradient(
                            colors: [
                                AeroTheme.skyBlue.opacity(0.6),
                                AeroTheme.emerald.opacity(0.4),
                                Color.white.opacity(0.15)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: 1.2
                    )
            )
            .shadow(color: Color.black.opacity(0.75), radius: 24, y: 12)
        )
        // Fully within display safe margins - NO cut-off borders!
        .padding(.horizontal, 12)
        .gesture(
            DragGesture(minimumDistance: 20)
                .onEnded { value in
                    if value.translation.height < -30 {
                        toggleIslandExpansion()
                    }
                }
        )
    }
}

// MARK: - Big Detailed Vector Campus Map View (Geographically Accurate to CAU Kiel)
private struct VectorCampusMapView: View {
    let targetBuilding: CampusBuilding
    let roomName: String
    
    @State private var radarPulse = false
    
    var body: some View {
        GeometryReader { geo in
            let w = geo.size.width
            let h = geo.size.height
            
            ZStack {
                // CAU Campus Green Grass backdrop
                Color(red: 0.03, green: 0.10, blue: 0.15)
                
                // Pedestrian Plaza: Christian-Albrechts-Platz (Center South-East)
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color(red: 0.07, green: 0.18, blue: 0.26).opacity(0.85))
                    .frame(width: w * 0.44, height: h * 0.34)
                    .position(x: w * 0.60, y: h * 0.72)
                
                Text("Christian-Albrechts-Platz")
                    .font(.system(size: 7.5, weight: .bold))
                    .foregroundColor(Color.white.opacity(0.35))
                    .position(x: w * 0.60, y: h * 0.72)
                
                // Streets of CAU Kiel (Accurate Orientation)
                Path { path in
                    // Westring: Runs North-South on the East (Right) edge
                    path.move(to: CGPoint(x: w * 0.84, y: h))
                    path.addLine(to: CGPoint(x: w * 0.84, y: h * 0.35))
                    
                    // Olshausenstraße: Branches from Westring at Mensa I / CAP and runs diagonally Northwest
                    path.move(to: CGPoint(x: w * 0.84, y: h * 0.74))
                    path.addLine(to: CGPoint(x: w * 0.06, y: h * 0.26))
                    
                    // Ludewig-Meyn-Straße: Branches off Olshausenstraße towards LMS 8 (Southwest)
                    path.move(to: CGPoint(x: w * 0.44, y: h * 0.42))
                    path.addLine(to: CGPoint(x: w * 0.20, y: h * 0.68))
                }
                .stroke(Color.white.opacity(0.20), style: StrokeStyle(lineWidth: 15, lineCap: .round, lineJoin: .round))
                
                // Central Dashed Street Markings
                Path { path in
                    path.move(to: CGPoint(x: w * 0.84, y: h))
                    path.addLine(to: CGPoint(x: w * 0.84, y: h * 0.35))
                    path.move(to: CGPoint(x: w * 0.84, y: h * 0.74))
                    path.addLine(to: CGPoint(x: w * 0.06, y: h * 0.26))
                    path.move(to: CGPoint(x: w * 0.44, y: h * 0.42))
                    path.addLine(to: CGPoint(x: w * 0.20, y: h * 0.68))
                }
                .stroke(Color.white.opacity(0.35), style: StrokeStyle(lineWidth: 1.2, dash: [5, 5]))
                
                // Street Labels
                Text("Westring")
                    .font(.system(size: 8, weight: .bold))
                    .foregroundColor(Color.white.opacity(0.45))
                    .rotationEffect(.degrees(90))
                    .position(x: w * 0.89, y: h * 0.58)
                
                Text("Olshausenstraße")
                    .font(.system(size: 8.5, weight: .bold))
                    .foregroundColor(Color.white.opacity(0.55))
                    .rotationEffect(.degrees(-31))
                    .position(x: w * 0.42, y: h * 0.35)
                
                Text("Ludewig-Meyn-Str.")
                    .font(.system(size: 7, weight: .bold))
                    .foregroundColor(Color.white.opacity(0.45))
                    .rotationEffect(.degrees(45))
                    .position(x: w * 0.32, y: h * 0.56)
                
                // ============================================
                // REALISTIC CAU KIEL BUILDINGS & FOOTPRINTS
                // ============================================
                
                // 1. Mensa I (Westring 385, South-East at Westring corner)
                CampusBuildingBlock(
                    title: "Mensa I & UB",
                    code: "Mensa I",
                    isTarget: false,
                    rect: CGRect(x: w * 0.66, y: h * 0.78, width: w * 0.22, height: h * 0.18)
                )
                
                // 2. CAP 2 (Audimax CAU - East side of Christian-Albrechts-Platz)
                CampusBuildingBlock(
                    title: "Audimax CAU",
                    code: "CAP 2",
                    isTarget: false,
                    rect: CGRect(x: w * 0.58, y: h * 0.58, width: w * 0.20, height: h * 0.18)
                )
                
                // 3. CAP 3 (Hörsaalgebäude / Hörsaal 1, 2, 3 - West side of CAP)
                let isCAP3 = targetBuilding.id == "CAP3"
                CampusBuildingBlock(
                    title: "CAP 3 (Hörsäle)",
                    code: "CAP 3",
                    isTarget: isCAP3,
                    rect: CGRect(x: w * 0.40, y: h * 0.58, width: w * 0.20, height: h * 0.20)
                )
                
                // 4. LMS 8 (Institut für Informatik & Geographie, Ludewig-Meyn-Str. Southwest)
                let isLMS8 = targetBuilding.id == "LMS8"
                CampusBuildingBlock(
                    title: "LMS 8 (Informatik)",
                    code: "LMS 8",
                    isTarget: isLMS8,
                    rect: CGRect(x: w * 0.10, y: h * 0.52, width: w * 0.20, height: h * 0.22)
                )
                
                // 5. WSP 7 (WiSo-Hochhaus, North of Olshausenstraße)
                let isWSP7 = targetBuilding.id == "WSP7"
                CampusBuildingBlock(
                    title: "WSP 7 (WiSo)",
                    code: "WSP 7",
                    isTarget: isWSP7,
                    rect: CGRect(x: w * 0.30, y: h * 0.10, width: w * 0.18, height: h * 0.18)
                )
                
                // 6. OS 40 / OH 14 (Chemiezentrum, North of Olshausenstraße)
                let isOH14 = targetBuilding.id == "OH14"
                CampusBuildingBlock(
                    title: "OS 40 (Chemie)",
                    code: "OS 40",
                    isTarget: isOH14,
                    rect: CGRect(x: w * 0.52, y: h * 0.14, width: w * 0.18, height: h * 0.17)
                )
                
                // 7. HHP 6 (Mathematik & Physik, Heinrich-Hecht-Platz North-East)
                let isHHP6 = targetBuilding.id == "HHP6"
                CampusBuildingBlock(
                    title: "HHP 6 (Mathe/Physik)",
                    code: "HHP 6",
                    isTarget: isHHP6,
                    rect: CGRect(x: w * 0.72, y: h * 0.04, width: w * 0.22, height: h * 0.17)
                )
                
                // Target Radar Pin on the selected building
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
                .position(x: w - 38, y: h - 22)
            }
        }
    }
    
    private func getBuildingPosition(building: CampusBuilding, in size: CGSize) -> CGPoint {
        switch building.id {
        case "CAP3":
            return CGPoint(x: size.width * 0.50, y: size.height * 0.68)
        case "LMS8":
            return CGPoint(x: size.width * 0.20, y: size.height * 0.63)
        case "HHP6":
            return CGPoint(x: size.width * 0.83, y: size.height * 0.12)
        case "OH14":
            return CGPoint(x: size.width * 0.61, y: size.height * 0.22)
        case "WSP7":
            return CGPoint(x: size.width * 0.39, y: size.height * 0.19)
        default:
            return CGPoint(x: size.width * 0.50, y: size.height * 0.68)
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
            span: MKCoordinateSpan(latitudeDelta: 0.0028, longitudeDelta: 0.0028)
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
        let items: [CampusMapItem] = [
            // Target Building
            CampusMapItem(coordinate: coordinate, title: title, subtitle: subtitle, isTarget: true),
            // Nearby reference CAU landmarks
            CampusMapItem(coordinate: CLLocationCoordinate2D(latitude: 54.337469, longitude: 10.122759), title: "Mensa I", subtitle: "Mensa I & Westring", isTarget: false),
            CampusMapItem(coordinate: CLLocationCoordinate2D(latitude: 54.338236, longitude: 10.123757), title: "Audimax", subtitle: "CAP 2 Audimax", isTarget: false),
            CampusMapItem(coordinate: CLLocationCoordinate2D(latitude: 54.337512, longitude: 10.121552), title: "LMS 8", subtitle: "Informatik", isTarget: false)
        ]
        
        Map(coordinateRegion: $region, annotationItems: items) { item in
            MapAnnotation(coordinate: item.coordinate) {
                if item.isTarget {
                    VStack(spacing: 2) {
                        Image(systemName: "mappin.circle.fill")
                            .font(.title2)
                            .foregroundColor(AeroTheme.emerald)
                            .background(Circle().fill(Color.black).padding(2))
                        
                        Text(item.subtitle)
                            .font(.system(size: 8, weight: .bold))
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Capsule().fill(Color.black.opacity(0.85)))
                            .foregroundColor(.white)
                    }
                } else {
                    Text(item.title)
                        .font(.system(size: 7.5, weight: .bold))
                        .padding(.horizontal, 5)
                        .padding(.vertical, 2)
                        .background(Capsule().fill(Color(red: 0.1, green: 0.2, blue: 0.3).opacity(0.85)))
                        .foregroundColor(.white.opacity(0.8))
                }
            }
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
                
                // Specialized Building Architecture: CAP 3 Hörsäle vs LMS 8 Informatik vs Generic
                if resolvedRoom.building.id == "CAP3" {
                    cap3ArchitecturalLayout(w: w, h: h)
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
    
    // CAP 3 Lecture Hall Architecture (Audimax / Hörsaal 1, 2, 3)
    @ViewBuilder
    private func cap3ArchitecturalLayout(w: CGFloat, h: CGFloat) -> some View {
        let isH2 = resolvedRoom.roomName.contains("2")
        let isH3 = resolvedRoom.roomName.contains("3")
        let isH1 = !isH2 && !isH3
        
        // 1. Hörsaal 1 (Audimax, 450 Plätze, Left Amphitheater Wing)
        LectureHallAuditoriumBlock(
            code: "Hörsaal 1",
            capacity: "450 Plätze (Audimax)",
            isTarget: isH1,
            rect: CGRect(x: w * 0.08, y: h * 0.18, width: w * 0.40, height: h * 0.54)
        )
        
        // 2. Hörsaal 2 (280 Plätze, Right Upper Wing)
        LectureHallAuditoriumBlock(
            code: "Hörsaal 2",
            capacity: "280 Plätze (Gestühl)",
            isTarget: isH2,
            rect: CGRect(x: w * 0.52, y: h * 0.18, width: w * 0.40, height: h * 0.32)
        )
        
        // 3. Hörsaal 3 (120 Plätze, Right Lower Wing)
        LectureHallAuditoriumBlock(
            code: "Hörsaal 3",
            capacity: "120 Plätze (Seminar)",
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
                Text("FOYER & EINGANG (Christian-Albrechts-Platz)")
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
