import SwiftUI
import CoreLocation

// MARK: - Campus Building Model
public struct CampusBuilding: Identifiable, Hashable {
    public let id: String
    public let code: String
    public let name: String
    public let address: String
    public let coordinate: CLLocationCoordinate2D
    public let area: String
    public let busStops: [String]
    public let walkingMinutes: Int
    public let description: String
    public let entranceTip: String
    public let iconName: String
    
    public func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
    
    public static func == (lhs: CampusBuilding, rhs: CampusBuilding) -> Bool {
        lhs.id == rhs.id
    }
}

// MARK: - Indoor Room Blueprint Model
public struct FloorRoom: Identifiable {
    public let id = UUID()
    public let name: String
    public let code: String
    public let isTarget: Bool
    public let xFraction: CGFloat
    public let yFraction: CGFloat
    public let widthFraction: CGFloat
    public let heightFraction: CGFloat
    public let details: String
}

// MARK: - Resolved Campus Room
public struct ResolvedCampusRoom: Identifiable {
    public let id = UUID()
    public let rawRoomString: String
    public let building: CampusBuilding
    public let roomName: String
    public let floor: String
    public let isOnline: Bool
    public let floorRooms: [FloorRoom]
    public let walkingDistanceMeters: Int
    public let navigationTip: String
}

// MARK: - Campus Location Engine
public enum CampusLocationEngine {
    
    // CAU Kiel Campus Buildings (Exact OpenStreetMap coordinates)
    public static let cap3 = CampusBuilding(
        id: "CAP3",
        code: "CAP 3",
        name: "Hörsaalgebäude CAP 3",
        address: "Christian-Albrechts-Platz 3, 24118 Kiel",
        coordinate: CLLocationCoordinate2D(latitude: 54.338464, longitude: 10.121958),
        area: "Campus Mitte (Hauptcampus)",
        busStops: ["Universitätsbibliothek (81, 60S, 61, 62)", "Mensa I (Westring)"],
        walkingMinutes: 2,
        description: "Zentrales Hörsaalgebäude der CAU mit Hörsaal 1, Hörsaal 2, Hörsaal 3 und Klaus-Murmann-Hörsaal.",
        entranceTip: "Haupteingang direkt am Christian-Albrechts-Platz. Hörsaal 2 liegt im Erdgeschoss.",
        iconName: "building.columns.fill"
    )
    
    public static let cap2 = CampusBuilding(
        id: "CAP2",
        code: "CAP 2",
        name: "Audimax (Auditorium Maximum)",
        address: "Christian-Albrechts-Platz 2, 24118 Kiel",
        coordinate: CLLocationCoordinate2D(latitude: 54.338236, longitude: 10.123757),
        area: "Campus Mitte (Hauptcampus)",
        busStops: ["Mensa I (Westring)", "Universitätsbibliothek"],
        walkingMinutes: 2,
        description: "Großes Hauptauditorium der CAU mit Frederik-Paulsen-Hörsaal und Hörsälen A bis K.",
        entranceTip: "Haupteingang über die Freitreppe am Christian-Albrechts-Platz / Westring ins Audimax-Foyer.",
        iconName: "building.columns.fill"
    )
    
    public static let mensa1 = CampusBuilding(
        id: "Mensa1",
        code: "Mensa I",
        name: "Mensa I & AStA",
        address: "Westring 385, 24118 Kiel",
        coordinate: CLLocationCoordinate2D(latitude: 54.337469, longitude: 10.122759),
        area: "Campus Mitte",
        busStops: ["Mensa I (Westring)"],
        walkingMinutes: 1,
        description: "Zentrale Universitätsmensa mit Cafeteria, Kaffeebar und AStA-Büros.",
        entranceTip: "Eingang über den Westring oder direkt von der Platzebene Christian-Albrechts-Platz.",
        iconName: "fork.knife"
    )
    
    public static let lms8 = CampusBuilding(
        id: "LMS8",
        code: "LMS 8",
        name: "Institut für Informatik & Geographie",
        address: "Ludewig-Meyn-Straße 8, 24118 Kiel",
        coordinate: CLLocationCoordinate2D(latitude: 54.337512, longitude: 10.121552),
        area: "Campus West (Informatik)",
        busStops: ["Universitätsbibliothek", "Leibnizstraße / Ludewig-Meyn-Str."],
        walkingMinutes: 4,
        description: "Institut für Informatik mit Seminar- und Übungsräumen, Linux-CIP-Pools und Serverräumen.",
        entranceTip: "Eingang über den Innenhof Ludewig-Meyn-Straße 8. Raum 018 liegt im Erdgeschoss rechts.",
        iconName: "desktopcomputer"
    )
    
    public static let lms2 = CampusBuilding(
        id: "LMS2",
        code: "LMS 2-4",
        name: "Geowissenschaften & Seminarräume",
        address: "Ludewig-Meyn-Straße 2, 24118 Kiel",
        coordinate: CLLocationCoordinate2D(latitude: 54.337997, longitude: 10.121653),
        area: "Campus West",
        busStops: ["Christian-Albrechts-Platz", "Universitätsbibliothek"],
        walkingMinutes: 3,
        description: "Hörsäle und Übungsräume für Geowissenschaften und Naturwissenschaften.",
        entranceTip: "Haupteingang Ludewig-Meyn-Straße 2, Treppenaufgang zum Hochparterre.",
        iconName: "globe.europe.africa.fill"
    )
    
    public static let hhp6 = CampusBuilding(
        id: "HHP6",
        code: "HHP 6",
        name: "Mathematik-Institut & Physikzentrum",
        address: "Heinrich-Hecht-Platz 6, 24118 Kiel",
        coordinate: CLLocationCoordinate2D(latitude: 54.341271, longitude: 10.124403),
        area: "Campus Nordost (Physik & Mathematik)",
        busStops: ["Universitäts-Sportforum", "Leibnizstraße"],
        walkingMinutes: 6,
        description: "Mathematisches Seminar & Physikalisches Institut mit Hörsaal 3 und Übungsräumen.",
        entranceTip: "Eingang über den Heinrich-Hecht-Platz. Raum EG.004 befindet sich im Erdgeschossflügel Mathematik.",
        iconName: "function"
    )
    
    public static let oh14 = CampusBuilding(
        id: "OH14",
        code: "OS 40 / OH 14",
        name: "Chemiezentrum & Geozentrum",
        address: "Olshausenstraße 40, 24118 Kiel",
        coordinate: CLLocationCoordinate2D(latitude: 54.339409, longitude: 10.121270),
        area: "Campus Nordwest (Chemie)",
        busStops: ["Universitätsbibliothek / Olshausenstraße", "Botanischer Garten"],
        walkingMinutes: 4,
        description: "Chemie-Hörsäle und Praktikumslabore mit großem Flachtrakt.",
        entranceTip: "Eingang über Olshausenstraße 40, Hörsäle im Erdgeschoss.",
        iconName: "atom"
    )
    
    public static let wsp7 = CampusBuilding(
        id: "WSP7",
        code: "WSP 7",
        name: "Wirtschafts- & Sozialwissenschaften",
        address: "Wilhelm-Seelig-Platz 7, 24118 Kiel",
        coordinate: CLLocationCoordinate2D(latitude: 54.339718, longitude: 10.123655),
        area: "Campus Nord (WiSo-Hochhaus)",
        busStops: ["Wilhelm-Seelig-Platz", "Universitätsbibliothek"],
        walkingMinutes: 3,
        description: "Hochhaus am Wilhelm-Seelig-Platz mit Hörsälen und Institutsräumen.",
        entranceTip: "Haupteingang Wilhelm-Seelig-Platz, Fahrstühle zu den Obergeschossen.",
        iconName: "chart.bar.fill"
    )
    
    public static let onlineBuilding = CampusBuilding(
        id: "ONLINE",
        code: "LMS Online",
        name: "Virtueller Hörsaal (OpenOlat / Moodle)",
        address: "lms.uni-kiel.de & elearn.informatik.uni-kiel.de",
        coordinate: CLLocationCoordinate2D(latitude: 54.338464, longitude: 10.121958),
        area: "Digitale Lehre",
        busStops: ["Keine Anfahrt nötig (Online)"],
        walkingMinutes: 0,
        description: "Digitale Lehrveranstaltung über BigBlueButton, Zoom oder LMS-Stream.",
        entranceTip: "Login über UNIBODY SSO direkt im Browser.",
        iconName: "video.fill"
    )
    
    public static let allBuildings = [cap3, cap2, mensa1, lms8, lms2, hhp6, oh14, wsp7]
    
    // Resolve any room string
    public static func resolve(room: String) -> ResolvedCampusRoom {
        let raw = room.trimmingCharacters(in: .whitespacesAndNewlines)
        let lower = raw.lowercased()
        
        // 1. Online check
        if lower.contains("online") || lower.contains("bbb") || lower.contains("zoom") || lower.contains("lms.uni-kiel") || lower.contains("virtuell") {
            return ResolvedCampusRoom(
                rawRoomString: raw,
                building: onlineBuilding,
                roomName: "Virtueller Kursraum (LMS)",
                floor: "Digital",
                isOnline: true,
                floorRooms: [],
                walkingDistanceMeters: 0,
                navigationTip: "Öffne diesen Kurs direkt im UNIBODY Browser."
            )
        }
        
        // 2. Audimax CAU (CAP 2)
        if lower.contains("audimax") || lower.contains("cap2") || lower.contains("cap 2") || lower.contains("paulsen") {
            let rName = extractRoomName(from: raw, fallback: "Frederik-Paulsen-Hörsaal")
            return ResolvedCampusRoom(
                rawRoomString: raw,
                building: cap2,
                roomName: rName,
                floor: "Erdgeschoss (EG)",
                isOnline: false,
                floorRooms: [
                    FloorRoom(name: "Frederik-Paulsen-Hörsaal (Audimax)", code: "AUDIMAX", isTarget: true, xFraction: 0.15, yFraction: 0.28, widthFraction: 0.70, heightFraction: 0.48, details: "Großes Auditorium Maximum · 1250 Plätze"),
                    FloorRoom(name: "Audimax Foyer & Treppe", code: "FOYER", isTarget: false, xFraction: 0.15, yFraction: 0.78, widthFraction: 0.70, heightFraction: 0.16, details: "Zugang Christian-Albrechts-Platz / Westring")
                ],
                walkingDistanceMeters: 180,
                navigationTip: "Am Christian-Albrechts-Platz über die Freitreppe ins Audimax-Foyer."
            )
        }
        
        // 3. CAP 3 (Hörsaalgebäude mit Hörsaal 1, 2, 3)
        if lower.contains("cap3") || lower.contains("cap 3") || lower.contains("christian-albrechts-platz") {
            let rName = extractRoomName(from: raw, fallback: "Hörsaal 2")
            let floor = lower.contains("og") ? "1. Obergeschoss (1. OG)" : "Erdgeschoss (EG)"
            return ResolvedCampusRoom(
                rawRoomString: raw,
                building: cap3,
                roomName: rName,
                floor: floor,
                isOnline: false,
                floorRooms: [
                    FloorRoom(name: "Hörsaal 1", code: "H1", isTarget: lower.contains("hörsaal 1") || lower.contains("hs 1") || (lower.contains("1") && !lower.contains("10")), xFraction: 0.12, yFraction: 0.22, widthFraction: 0.38, heightFraction: 0.52, details: "Großer Hörsaal 1 · 400 Plätze"),
                    FloorRoom(name: "Hörsaal 2", code: "H2", isTarget: lower.contains("2") || (!lower.contains("1") && !lower.contains("3")), xFraction: 0.54, yFraction: 0.22, widthFraction: 0.36, heightFraction: 0.30, details: "Hörsaal 2 · 280 Plätze"),
                    FloorRoom(name: "Hörsaal 3", code: "H3", isTarget: lower.contains("3"), xFraction: 0.54, yFraction: 0.56, widthFraction: 0.36, heightFraction: 0.20, details: "Hörsaal 3 · 120 Plätze"),
                    FloorRoom(name: "CAP 3 Foyer / Eingang", code: "EINGANG", isTarget: false, xFraction: 0.12, yFraction: 0.78, widthFraction: 0.78, heightFraction: 0.16, details: "Zugang Christian-Albrechts-Platz"),
                ],
                walkingDistanceMeters: 210,
                navigationTip: "Am Christian-Albrechts-Platz geradeaus ins CAP 3 Foyer. Der Hörsaal liegt direkt im Erdgeschoss."
            )
        }
        
        // 3. LMS 8 (Informatik)
        if lower.contains("lms8") || lower.contains("lms 8") || lower.contains("ludewig-meyn-str. 8") || lower.contains("cip") || lower.contains("018") || lower.contains("informatik") {
            let rName = extractRoomName(from: raw, fallback: "Raum 018")
            let floor = lower.contains("1. og") || lower.contains("og") ? "1. Obergeschoss (1. OG)" : "Erdgeschoss (EG)"
            return ResolvedCampusRoom(
                rawRoomString: raw,
                building: lms8,
                roomName: rName,
                floor: floor,
                isOnline: false,
                floorRooms: [
                    FloorRoom(name: "Raum 018 (Übungsraum)", code: "R.018", isTarget: lower.contains("018") || (!lower.contains("cip")), xFraction: 0.55, yFraction: 0.28, widthFraction: 0.35, heightFraction: 0.38, details: "Übungsraum Informatik · 35 Plätze"),
                    FloorRoom(name: "CIP-Pool Linux", code: "CIP-1", isTarget: lower.contains("cip"), xFraction: 0.15, yFraction: 0.28, widthFraction: 0.35, heightFraction: 0.38, details: "Linux Arbeitsplätze · Rechenzentrum"),
                    FloorRoom(name: "Treppenhaus & Aufzug", code: "LIFT", isTarget: false, xFraction: 0.15, yFraction: 0.72, widthFraction: 0.25, heightFraction: 0.22, details: "Zugang zu den Obergeschossen"),
                    FloorRoom(name: "Haupteingang Innenhof", code: "EINGANG", isTarget: false, xFraction: 0.45, yFraction: 0.72, widthFraction: 0.45, heightFraction: 0.22, details: "Ludewig-Meyn-Straße 8"),
                ],
                walkingDistanceMeters: 380,
                navigationTip: "In den Innenhof von LMS 8 gehen, durch die Glastür und im Erdgeschoss rechts in den Übungsraum."
            )
        }
        
        // 4. HHP 6 (Mathematik & Physik)
        if lower.contains("hhp6") || lower.contains("hhp 6") || lower.contains("heinrich-hecht") || lower.contains("060098") || lower.contains("eg.004") || lower.contains("mathe") {
            let rName = extractRoomName(from: raw, fallback: "R.EG.004")
            return ResolvedCampusRoom(
                rawRoomString: raw,
                building: hhp6,
                roomName: rName,
                floor: "Erdgeschoss (EG)",
                isOnline: false,
                floorRooms: [
                    FloorRoom(name: "Raum EG.004 (Mathematik)", code: "EG.004", isTarget: true, xFraction: 0.18, yFraction: 0.32, widthFraction: 0.38, heightFraction: 0.42, details: "Mathematisches Seminar · Übungsgruppe"),
                    FloorRoom(name: "Hörsaal 3 (Physik)", code: "HS 3", isTarget: false, xFraction: 0.60, yFraction: 0.32, widthFraction: 0.30, heightFraction: 0.42, details: "Physik-Hörsaal · 180 Plätze"),
                    FloorRoom(name: "Haupteingang", code: "EINGANG", isTarget: false, xFraction: 0.32, yFraction: 0.78, widthFraction: 0.36, heightFraction: 0.16, details: "Heinrich-Hecht-Platz 6"),
                ],
                walkingDistanceMeters: 550,
                navigationTip: "Vom Sportforum über den Heinrich-Hecht-Platz zum Mathematischen Institut. Der Raum EG.004 liegt im Erdgeschossflügel."
            )
        }
        
        // 5. OH 14 (Chemie)
        if lower.contains("oh14") || lower.contains("oh 14") || lower.contains("olshausenstr. 14") || lower.contains("chemie") {
            let rName = extractRoomName(from: raw, fallback: "Hörsaal Chemie")
            return ResolvedCampusRoom(
                rawRoomString: raw,
                building: oh14,
                roomName: rName,
                floor: "Erdgeschoss",
                isOnline: false,
                floorRooms: [
                    FloorRoom(name: "Hörsaal Chemie I", code: "HS CH1", isTarget: true, xFraction: 0.20, yFraction: 0.35, widthFraction: 0.60, heightFraction: 0.45, details: "Chemie Hörsaalzentrum"),
                ],
                walkingDistanceMeters: 290,
                navigationTip: "Olshausenstraße 14, direkt gegenüber der Universitätsbibliothek."
            )
        }
        
        // Default: CAP 3 / Campus Mitte
        let defName = raw.isEmpty ? "Hörsaal / Campus" : raw
        return ResolvedCampusRoom(
            rawRoomString: raw,
            building: cap3,
            roomName: defName,
            floor: "Campus Olshausenstraße",
            isOnline: false,
            floorRooms: [
                FloorRoom(name: defName, code: "RAUM", isTarget: true, xFraction: 0.25, yFraction: 0.35, widthFraction: 0.50, heightFraction: 0.45, details: "Veranstaltungsraum CAU Kiel"),
            ],
            walkingDistanceMeters: 250,
            navigationTip: "Campus Olshausenstraße, zentral am Christian-Albrechts-Platz erreichbar."
        )
    }
    
    private static func extractRoomName(from raw: String, fallback: String) -> String {
        if raw.contains(" - ") {
            let parts = raw.components(separatedBy: " - ")
            if parts.count > 1 {
                return parts[1].replacingOccurrences(of: "\\[.*?\\]", with: "", options: .regularExpression).trimmingCharacters(in: .whitespaces)
            }
        }
        return raw.isEmpty ? fallback : raw
    }
}
