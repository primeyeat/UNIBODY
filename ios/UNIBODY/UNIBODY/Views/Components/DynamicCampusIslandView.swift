import SwiftUI
import MapKit

public struct DynamicCampusIslandView: View {
    @EnvironmentObject var appState: AppState
    public let event: ScheduleEvent
    public var onClose: () -> Void = {}
    
    @State private var mapDisplayMode: MapDisplayMode = .campusPlan
    @State private var isExpanded: Bool = true
    @State private var pulseAnimation: Bool = false
    @State private var walkingPathPhase: CGFloat = 0.0
    
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
        VStack(spacing: 0) {
            if isExpanded {
                expandedIslandView
                    .transition(.asymmetric(
                        insertion: .scale(scale: 0.85, anchor: .top).combined(with: .opacity),
                        removal: .scale(scale: 0.85, anchor: .top).combined(with: .opacity)
                    ))
            } else {
                compactIslandPill
                    .transition(.scale(scale: 0.9, anchor: .top).combined(with: .opacity))
            }
        }
        .animation(.spring(response: 0.42, dampingFraction: 0.78), value: isExpanded)
        .animation(.spring(response: 0.35, dampingFraction: 0.8), value: mapDisplayMode)
        .onAppear {
            pulseAnimation = true
            withAnimation(.linear(duration: 1.5).repeatForever(autoreverses: false)) {
                walkingPathPhase = 20
            }
        }
    }
    
    // MARK: - Compact Dynamic Island Notch Pill
    private var compactIslandPill: some View {
        Button {
            #if canImport(UIKit)
            UIImpactFeedbackGenerator(style: .medium).impactOccurred()
            #endif
            withAnimation {
                isExpanded = true
            }
        } label: {
            HStack(spacing: 10) {
                HStack(spacing: 6) {
                    Image(systemName: resolvedRoom.building.iconName)
                        .font(.caption.weight(.bold))
                        .foregroundColor(AeroTheme.emerald)
                    Text("\(resolvedRoom.building.id) · \(resolvedRoom.roomName)")
                        .font(.system(.caption, design: .rounded).weight(.bold))
                        .foregroundColor(.white)
                        .lineLimit(1)
                }
                
                Spacer()
                
                HStack(spacing: 6) {
                    Circle()
                        .fill(AeroTheme.emerald)
                        .frame(width: 7, height: 7)
                        .scaleEffect(pulseAnimation ? 1.3 : 0.8)
                        .opacity(pulseAnimation ? 1.0 : 0.5)
                        .animation(.easeInOut(duration: 0.9).repeatForever(autoreverses: true), value: pulseAnimation)
                    
                    Text("\(resolvedRoom.building.walkingMinutes) Min")
                        .font(.system(.caption2, design: .rounded).weight(.bold))
                        .foregroundColor(AeroTheme.skyBlue)
                    
                    Image(systemName: "chevron.down")
                        .font(.caption2.weight(.bold))
                        .foregroundColor(.white.opacity(0.6))
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .background(
                Capsule()
                    .fill(Color.black.opacity(0.92))
                    .overlay(
                        Capsule()
                            .strokeBorder(
                                LinearGradient(
                                    colors: [AeroTheme.skyBlue.opacity(0.7), AeroTheme.emerald.opacity(0.5)],
                                    startPoint: .leading,
                                    endPoint: .trailing
                                ),
                                lineWidth: 1.2
                            )
                    )
                    .shadow(color: Color.black.opacity(0.5), radius: 12, y: 6)
            )
        }
        .buttonStyle(.plain)
        .padding(.horizontal, 24)
        .padding(.top, 4)
    }
    
    // MARK: - Expanded Detailed Dynamic Island Campus Navigator
    private var expandedIslandView: some View {
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
                        #if canImport(UIKit)
                        UIImpactFeedbackGenerator(style: .light).impactOccurred()
                        #endif
                        withAnimation {
                            isExpanded = false
                        }
                    } label: {
                        Image(systemName: "chevron.up.circle.fill")
                            .font(.title3)
                            .foregroundColor(.white.opacity(0.7))
                    }
                    
                    Button {
                        #if canImport(UIKit)
                        UIImpactFeedbackGenerator(style: .light).impactOccurred()
                        #endif
                        onClose()
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.title3)
                            .foregroundColor(.white.opacity(0.7))
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
                Color.black.opacity(0.96)
                LinearGradient(
                    colors: [Color(red: 0.02, green: 0.1, blue: 0.2).opacity(0.6), Color.black.opacity(0.9)],
                    startPoint: .top,
                    endPoint: .bottom
                )
            }
            .clipShape(RoundedRectangle(cornerRadius: 30, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 30, style: .continuous)
                    .strokeBorder(
                        LinearGradient(
                            colors: [AeroTheme.skyBlue.opacity(0.6), AeroTheme.emerald.opacity(0.4), Color.clear],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: 1.5
                    )
            )
            .shadow(color: Color.black.opacity(0.65), radius: 24, y: 10)
        )
        .padding(.horizontal, 12)
        .padding(.top, 4)
    }
}

// MARK: - Big Detailed Vector Campus Map View
private struct VectorCampusMapView: View {
    let targetBuilding: CampusBuilding
    let roomName: String
    
    @State private var radarPulse = false
    
    var body: some View {
        GeometryReader { geo in
            let w = geo.size.width
            let h = geo.size.height
            
            ZStack {
                // Campus grass/ground background
                Color(red: 0.04, green: 0.12, blue: 0.18)
                
                // Campus streets & pathways (Olshausenstraße, Ludewig-Meyn-Str, Christian-Albrechts-Platz)
                Path { path in
                    // Olshausenstraße (diagonal main artery)
                    path.move(to: CGPoint(x: 0, y: h * 0.72))
                    path.addLine(to: CGPoint(x: w, y: h * 0.48))
                    
                    // Ludewig-Meyn-Straße
                    path.move(to: CGPoint(x: w * 0.52, y: h * 0.58))
                    path.addLine(to: CGPoint(x: w * 0.52, y: h * 0.05))
                    
                    // Heinrich-Hecht-Platz access
                    path.move(to: CGPoint(x: w * 0.52, y: h * 0.22))
                    path.addLine(to: CGPoint(x: w * 0.90, y: h * 0.22))
                    
                    // Christian-Albrechts-Platz promenade
                    path.move(to: CGPoint(x: w * 0.22, y: h * 0.68))
                    path.addLine(to: CGPoint(x: w * 0.22, y: h * 0.35))
                }
                .stroke(Color.white.opacity(0.22), style: StrokeStyle(lineWidth: 18, lineCap: .round, lineJoin: .round))
                
                // Pedestrian walkway markings (central dash)
                Path { path in
                    path.move(to: CGPoint(x: 0, y: h * 0.72))
                    path.addLine(to: CGPoint(x: w, y: h * 0.48))
                    path.move(to: CGPoint(x: w * 0.52, y: h * 0.58))
                    path.addLine(to: CGPoint(x: w * 0.52, y: h * 0.05))
                }
                .stroke(Color.white.opacity(0.35), style: StrokeStyle(lineWidth: 1.5, dash: [6, 6]))
                
                // Street Labels
                Text("Olshausenstraße")
                    .font(.system(size: 9, weight: .bold))
                    .foregroundColor(Color.white.opacity(0.45))
                    .rotationEffect(.degrees(-13))
                    .position(x: w * 0.28, y: h * 0.69)
                
                Text("Ludewig-Meyn-Str.")
                    .font(.system(size: 8, weight: .bold))
                    .foregroundColor(Color.white.opacity(0.45))
                    .rotationEffect(.degrees(90))
                    .position(x: w * 0.48, y: h * 0.38)
                
                // Static Landmark: Mensa I & Uni-Bibliothek
                CampusBuildingBlock(
                    title: "Mensa I & UB",
                    code: "Mensa I",
                    isTarget: false,
                    rect: CGRect(x: w * 0.06, y: h * 0.42, width: w * 0.22, height: h * 0.22)
                )
                
                // Building: CAP 3 (Audimax)
                let isCAP3 = targetBuilding.id == "CAP3"
                CampusBuildingBlock(
                    title: "CAP 3 (Audimax)",
                    code: "CAP 3",
                    isTarget: isCAP3,
                    rect: CGRect(x: w * 0.16, y: h * 0.18, width: w * 0.24, height: h * 0.22)
                )
                
                // Building: LMS 8 (Informatik / RZ)
                let isLMS8 = targetBuilding.id == "LMS8"
                CampusBuildingBlock(
                    title: "LMS 8 (Informatik)",
                    code: "LMS 8",
                    isTarget: isLMS8,
                    rect: CGRect(x: w * 0.56, y: h * 0.30, width: w * 0.22, height: h * 0.22)
                )
                
                // Building: HHP 6 (Physik & Mathematik)
                let isHHP6 = targetBuilding.id == "HHP6"
                CampusBuildingBlock(
                    title: "HHP 6 (Mathe/Physik)",
                    code: "HHP 6",
                    isTarget: isHHP6,
                    rect: CGRect(x: w * 0.72, y: h * 0.08, width: w * 0.24, height: h * 0.22)
                )
                
                // Building: OH 14 (Chemie)
                let isOH14 = targetBuilding.id == "OH14"
                CampusBuildingBlock(
                    title: "OH 14 (Chemie)",
                    code: "OH 14",
                    isTarget: isOH14,
                    rect: CGRect(x: w * 0.36, y: h * 0.76, width: w * 0.22, height: h * 0.18)
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
            return CGPoint(x: size.width * 0.28, y: size.height * 0.29)
        case "LMS8":
            return CGPoint(x: size.width * 0.67, y: size.height * 0.41)
        case "HHP6":
            return CGPoint(x: size.width * 0.84, y: size.height * 0.19)
        case "OH14":
            return CGPoint(x: size.width * 0.47, y: size.height * 0.85)
        default:
            return CGPoint(x: size.width * 0.28, y: size.height * 0.29)
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

// MARK: - Live Apple MapView (MapKit)
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
            span: MKCoordinateSpan(latitudeDelta: 0.0035, longitudeDelta: 0.0035)
        ))
    }
    
    struct CampusMapItem: Identifiable {
        let id = UUID()
        let coordinate: CLLocationCoordinate2D
        let title: String
        let subtitle: String
    }
    
    var body: some View {
        let items = [CampusMapItem(coordinate: coordinate, title: title, subtitle: subtitle)]
        
        Map(coordinateRegion: $region, annotationItems: items) { item in
            MapAnnotation(coordinate: item.coordinate) {
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
            }
        }
    }
}

// MARK: - Floor Blueprint Indoor Layout View
private struct FloorBlueprintView: View {
    let resolvedRoom: ResolvedCampusRoom
    
    var body: some View {
        GeometryReader { geo in
            let w = geo.size.width
            let h = geo.size.height
            
            ZStack {
                // Blueprint background (Architectural grid)
                Color(red: 0.02, green: 0.08, blue: 0.16)
                
                // Blueprint Grid lines
                Path { path in
                    let step: CGFloat = 20
                    for x in stride(from: CGFloat(0), to: w, by: step) {
                        path.move(to: CGPoint(x: x, y: 0))
                        path.addLine(to: CGPoint(x: x, y: h))
                    }
                    for y in stride(from: CGFloat(0), to: h, by: step) {
                        path.move(to: CGPoint(x: 0, y: y))
                        path.addLine(to: CGPoint(x: w, y: y))
                    }
                }
                .stroke(Color.white.opacity(0.05), lineWidth: 1)
                
                // Building outer footprint boundary
                RoundedRectangle(cornerRadius: 14)
                    .strokeBorder(AeroTheme.skyBlue.opacity(0.6), lineWidth: 2)
                    .padding(12)
                
                // Rooms layout
                ForEach(resolvedRoom.floorRooms) { room in
                    let rx = w * room.xFraction
                    let ry = h * room.yFraction
                    let rw = w * room.widthFraction
                    let rh = h * room.heightFraction
                    
                    ZStack {
                        RoundedRectangle(cornerRadius: 6)
                            .fill(
                                room.isTarget
                                    ? Color(red: 0.05, green: 0.45, blue: 0.3).opacity(0.55)
                                    : Color.white.opacity(0.06)
                            )
                            .overlay(
                                RoundedRectangle(cornerRadius: 6)
                                    .strokeBorder(
                                        room.isTarget ? AeroTheme.emerald : Color.white.opacity(0.25),
                                        lineWidth: room.isTarget ? 2 : 1
                                    )
                            )
                            .shadow(color: room.isTarget ? AeroTheme.emerald.opacity(0.5) : Color.clear, radius: 8)
                        
                        VStack(spacing: 2) {
                            HStack(spacing: 3) {
                                if room.isTarget {
                                    Image(systemName: "checkmark.circle.fill")
                                        .font(.system(size: 9))
                                        .foregroundColor(AeroTheme.emerald)
                                }
                                Text(room.code)
                                    .font(.system(size: 10, weight: .heavy, design: .rounded))
                                    .foregroundColor(room.isTarget ? AeroTheme.emerald : .white)
                            }
                            
                            Text(room.name)
                                .font(.system(size: 7, weight: .medium))
                                .foregroundColor(.white.opacity(0.75))
                                .lineLimit(1)
                        }
                        .padding(4)
                    }
                    .frame(width: rw, height: rh)
                    .position(x: rx + rw / 2, y: ry + rh / 2)
                }
                
                // Floor level indicator
                HStack(spacing: 6) {
                    Image(systemName: "stairs")
                        .font(.caption2)
                    Text(resolvedRoom.floor)
                        .font(.system(size: 9, weight: .bold))
                }
                .foregroundColor(AeroTheme.skyBlue)
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(Capsule().fill(Color.black.opacity(0.75)))
                .overlay(Capsule().stroke(AeroTheme.skyBlue.opacity(0.4), lineWidth: 1))
                .position(x: w * 0.24, y: h * 0.16)
            }
        }
    }
}
