import SwiftUI
import CoreLocation
#if canImport(UIKit)
import UIKit
#endif

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
public struct FloorRoom: Identifiable, Hashable {
    public let id = UUID()
    public let name: String
    public let code: String
    public let isTarget: Bool
    public let xFraction: CGFloat
    public let yFraction: CGFloat
    public let widthFraction: CGFloat
    public let heightFraction: CGFloat
    public let details: String
    
    public func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
    
    public static func == (lhs: FloorRoom, rhs: FloorRoom) -> Bool {
        lhs.id == rhs.id
    }
}

// MARK: - Resolved Campus Room
public struct ResolvedCampusRoom: Identifiable, Hashable {
    public let id = UUID()
    public let rawRoomString: String
    public let building: CampusBuilding
    public let roomName: String
    public let floor: String
    public let isOnline: Bool
    public let floorRooms: [FloorRoom]
    public let walkingDistanceMeters: Int
    public let navigationTip: String
    
    public func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
    
    public static func == (lhs: ResolvedCampusRoom, rhs: ResolvedCampusRoom) -> Bool {
        lhs.id == rhs.id
    }
    
    public var displayTitle: String {
        let clean = roomName.trimmingCharacters(in: .whitespacesAndNewlines)
        let cleanNorm = clean.replacingOccurrences(of: " ", with: "").lowercased()
        let codeNorm = building.code.replacingOccurrences(of: " ", with: "").lowercased()
        
        if clean.isEmpty || cleanNorm == codeNorm || codeNorm.contains(cleanNorm) {
            return building.code
        }
        
        if cleanNorm.contains("paulsen") || cleanNorm.contains("audimax") {
            return building.code
        }
        
        let baseCode = building.code.components(separatedBy: " (").first ?? building.code
        return "\(baseCode) (\(clean))"
    }
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
        code: "CAP 2 (Audimax)",
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
    
    public static let cap4 = CampusBuilding(
        id: "CAP4",
        code: "CAP 4",
        name: "Hochhaus & Seminarräume CAP 4",
        address: "Christian-Albrechts-Platz 4, 24118 Kiel",
        coordinate: CLLocationCoordinate2D(latitude: 54.338920, longitude: 10.121980),
        area: "Campus Mitte",
        busStops: ["Christian-Albrechts-Platz", "Universitätsbibliothek"],
        walkingMinutes: 2,
        description: "Universitäts-Hochhaus mit Institutsräumen und Seminarräumen.",
        entranceTip: "Haupteingang Christian-Albrechts-Platz 4 über das Hochhausfoyer.",
        iconName: "building.2.fill"
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
    
    public static let mensa2 = CampusBuilding(
        id: "Mensa2",
        code: "Mensa II",
        name: "Mensa II (Campus Nord)",
        address: "Leibnizstraße 14, 24118 Kiel",
        coordinate: CLLocationCoordinate2D(latitude: 54.344400, longitude: 10.118600),
        area: "Campus Nord",
        busStops: ["Botanischer Garten", "Universitäts-Sportforum"],
        walkingMinutes: 7,
        description: "Mensa II im Norden des Campus an der Leibnizstraße.",
        entranceTip: "Haupteingang an der Leibnizstraße 14.",
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
        code: "LMS 2",
        name: "Geowissenschaften & Seminarräume LMS 2",
        address: "Ludewig-Meyn-Straße 2, 24118 Kiel",
        coordinate: CLLocationCoordinate2D(latitude: 54.337997, longitude: 10.121653),
        area: "Campus West",
        busStops: ["Christian-Albrechts-Platz", "Universitätsbibliothek"],
        walkingMinutes: 3,
        description: "Hörsäle und Übungsräume für Geowissenschaften und Naturwissenschaften.",
        entranceTip: "Haupteingang Ludewig-Meyn-Straße 2, Treppenaufgang zum Hochparterre.",
        iconName: "globe.europe.africa.fill"
    )
    
    public static let lms4 = CampusBuilding(
        id: "LMS4",
        code: "LMS 4",
        name: "Mathematik & Informatik LMS 4",
        address: "Ludewig-Meyn-Straße 4, 24118 Kiel",
        coordinate: CLLocationCoordinate2D(latitude: 54.337850, longitude: 10.121600),
        area: "Campus West",
        busStops: ["Universitätsbibliothek", "Christian-Albrechts-Platz"],
        walkingMinutes: 3,
        description: "Seminarräume und Rechenpools LMS 4.",
        entranceTip: "Eingang Ludewig-Meyn-Straße 4.",
        iconName: "desktopcomputer"
    )
    
    public static let lms6 = CampusBuilding(
        id: "LMS6",
        code: "LMS 6",
        name: "Geowissenschaften LMS 6",
        address: "Ludewig-Meyn-Straße 6, 24118 Kiel",
        coordinate: CLLocationCoordinate2D(latitude: 54.337680, longitude: 10.121570),
        area: "Campus West",
        busStops: ["Universitätsbibliothek"],
        walkingMinutes: 3,
        description: "Seminarräume und Hörsäle LMS 6.",
        entranceTip: "Eingang Ludewig-Meyn-Straße 6.",
        iconName: "building.2"
    )
    
    public static let lms11a = CampusBuilding(
        id: "LMS11",
        code: "LMS 11a",
        name: "Bio- & Agrarwissenschaften LMS 11a",
        address: "Ludewig-Meyn-Straße 11a, 24118 Kiel",
        coordinate: CLLocationCoordinate2D(latitude: 54.336900, longitude: 10.122100),
        area: "Campus West",
        busStops: ["Mensa I (Westring)", "Universitätsbibliothek"],
        walkingMinutes: 4,
        description: "Übungsräume LMS 11a.",
        entranceTip: "Eingang Ludewig-Meyn-Straße 11a.",
        iconName: "leaf.fill"
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
    
    public static let os75 = CampusBuilding(
        id: "OS75",
        code: "OS 75",
        name: "Hörsaalgebäude OS 75",
        address: "Olshausenstraße 75, 24118 Kiel",
        coordinate: CLLocationCoordinate2D(latitude: 54.345406, longitude: 10.105659),
        area: "Campus Nord (Bremerskamp)",
        busStops: ["Bremerskamp", "Botanischer Garten"],
        walkingMinutes: 5,
        description: "Großes Hörsaalgebäude an der Olshausenstraße 75 (Hörsaal 1, 2 und Hans-Heinrich-Driftmann-Hörsaal / HS 3).",
        entranceTip: "Haupteingang an der Olshausenstraße 75.",
        iconName: "building.columns.fill"
    )
    
    public static let ohp5 = CampusBuilding(
        id: "OHP5",
        code: "OHP 5",
        name: "Otto-Hahn-Platz 5 (Chemie II)",
        address: "Otto-Hahn-Platz 5, 24118 Kiel",
        coordinate: CLLocationCoordinate2D(latitude: 54.339832, longitude: 10.126442),
        area: "Campus Ost",
        busStops: ["Universitätsbibliothek", "Waitzstraße"],
        walkingMinutes: 5,
        description: "Chemie II Institut am Otto-Hahn-Platz 5.",
        entranceTip: "Eingang über den Otto-Hahn-Platz.",
        iconName: "atom"
    )
    
    public static let wsp3 = CampusBuilding(
        id: "WSP3",
        code: "WSP 3",
        name: "Seminarräume Wilhelm-Seelig-Platz 3",
        address: "Wilhelm-Seelig-Platz 3, 24118 Kiel",
        coordinate: CLLocationCoordinate2D(latitude: 54.339550, longitude: 10.123500),
        area: "Campus Nord (WiSo)",
        busStops: ["Wilhelm-Seelig-Platz", "Universitätsbibliothek"],
        walkingMinutes: 3,
        description: "Seminarräume am Wilhelm-Seelig-Platz 3.",
        entranceTip: "Eingang Wilhelm-Seelig-Platz 3.",
        iconName: "chart.bar.fill"
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
    
    public static let allBuildings = [cap3, cap2, cap4, mensa1, mensa2, lms8, lms2, lms4, lms6, lms11a, hhp6, os75, oh14, ohp5, wsp3, wsp7]
    
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
        if lower.contains("cap3") || lower.contains("cap 3") || lower.contains("christian-albrechts-platz 3") {
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
        
        // 4. CAP 4 (Hochhaus)
        if lower.contains("cap4") || lower.contains("cap 4") || lower.contains("christian-albrechts-platz 4") {
            let rName = extractRoomName(from: raw, fallback: "CAP 4")
            return ResolvedCampusRoom(
                rawRoomString: raw,
                building: cap4,
                roomName: rName,
                floor: "Christian-Albrechts-Platz 4",
                isOnline: false,
                floorRooms: [],
                walkingDistanceMeters: 220,
                navigationTip: "Hochhaus Christian-Albrechts-Platz 4."
            )
        }
        
        // 5. LMS 11a / LMS 11
        if lower.contains("lms11") || lower.contains("lms 11") {
            let rName = extractRoomName(from: raw, fallback: "LMS 11a")
            return ResolvedCampusRoom(
                rawRoomString: raw,
                building: lms11a,
                roomName: rName,
                floor: "Erdgeschoss",
                isOnline: false,
                floorRooms: [],
                walkingDistanceMeters: 350,
                navigationTip: "Ludewig-Meyn-Straße 11a."
            )
        }
        
        // 6. LMS 8 (Informatik)
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
        
        // 7. LMS 6
        if lower.contains("lms6") || lower.contains("lms 6") {
            let rName = extractRoomName(from: raw, fallback: "LMS 6")
            return ResolvedCampusRoom(
                rawRoomString: raw,
                building: lms6,
                roomName: rName,
                floor: "Ludewig-Meyn-Straße 6",
                isOnline: false,
                floorRooms: [],
                walkingDistanceMeters: 360,
                navigationTip: "Ludewig-Meyn-Straße 6."
            )
        }
        
        // 8. LMS 4
        if lower.contains("lms4") || lower.contains("lms 4") {
            let rName = extractRoomName(from: raw, fallback: "LMS 4")
            return ResolvedCampusRoom(
                rawRoomString: raw,
                building: lms4,
                roomName: rName,
                floor: "Ludewig-Meyn-Straße 4",
                isOnline: false,
                floorRooms: [],
                walkingDistanceMeters: 340,
                navigationTip: "Ludewig-Meyn-Straße 4."
            )
        }
        
        // 9. LMS 2
        if lower.contains("lms2") || lower.contains("lms 2") || lower.contains("ludewig-meyn-str. 2") {
            let rName = extractRoomName(from: raw, fallback: "LMS 2")
            return ResolvedCampusRoom(
                rawRoomString: raw,
                building: lms2,
                roomName: rName,
                floor: "Ludewig-Meyn-Straße 2",
                isOnline: false,
                floorRooms: [],
                walkingDistanceMeters: 320,
                navigationTip: "Ludewig-Meyn-Straße 2, Hochparterre."
            )
        }
        
        // 10. HHP 6 (Mathematik & Physik)
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
        
        // 11. OS 75
        if lower.contains("os75") || lower.contains("os 75") || lower.contains("olshausenstr. 75") || lower.contains("olshausenstraße 75") {
            let rName = extractRoomName(from: raw, fallback: "Hörsaal 1")
            return ResolvedCampusRoom(
                rawRoomString: raw,
                building: os75,
                roomName: rName,
                floor: "Erdgeschoss",
                isOnline: false,
                floorRooms: [],
                walkingDistanceMeters: 520,
                navigationTip: "Hörsaalgebäude Olshausenstraße 75."
            )
        }
        
        // 12. OH 14 / OS 40 (Chemiezentrum)
        if lower.contains("oh14") || lower.contains("oh 14") || lower.contains("os40") || lower.contains("os 40") || lower.contains("olshausenstr. 40") || lower.contains("olshausenstraße 40") || lower.contains("chemie i") {
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
                navigationTip: "Olshausenstraße 40, gegenüber der Universitätsbibliothek."
            )
        }
        
        // 13. OHP 5 (Chemie II)
        if lower.contains("ohp5") || lower.contains("ohp 5") || lower.contains("ohp") || lower.contains("otto-hahn") || lower.contains("chemie ii") {
            let rName = extractRoomName(from: raw, fallback: "Chemie II")
            return ResolvedCampusRoom(
                rawRoomString: raw,
                building: ohp5,
                roomName: rName,
                floor: "Erdgeschoss",
                isOnline: false,
                floorRooms: [],
                walkingDistanceMeters: 310,
                navigationTip: "Otto-Hahn-Platz 5."
            )
        }
        
        // 14. WSP 3
        if lower.contains("wsp3") || lower.contains("wsp 3") {
            let rName = extractRoomName(from: raw, fallback: "SR 2")
            return ResolvedCampusRoom(
                rawRoomString: raw,
                building: wsp3,
                roomName: rName,
                floor: "Erdgeschoss",
                isOnline: false,
                floorRooms: [],
                walkingDistanceMeters: 300,
                navigationTip: "Wilhelm-Seelig-Platz 3."
            )
        }
        
        // 15. WSP 7
        if lower.contains("wsp7") || lower.contains("wsp 7") || lower.contains("wsp") || lower.contains("wilhelm-seelig") {
            let rName = extractRoomName(from: raw, fallback: "WSP 7")
            return ResolvedCampusRoom(
                rawRoomString: raw,
                building: wsp7,
                roomName: rName,
                floor: "Wilhelm-Seelig-Platz 7",
                isOnline: false,
                floorRooms: [],
                walkingDistanceMeters: 310,
                navigationTip: "Hochhaus Wilhelm-Seelig-Platz 7."
            )
        }
        
        // Default: CAP 3 / Christian-Albrechts-Platz 3
        let defName = raw.isEmpty ? "CAP 3" : raw
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
    
    // MARK: - Multi-Room Split & Resolution
    
    /// Splits composite room strings like "LMS6 - R.11 / CAP2" into individual room segments
    public static func splitRoomLocations(room: String) -> [String] {
        let trimmed = room.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return [] }
        
        let pattern = #"(?i)\s+/\s+|\s*[,;]\s*|\s+(?:oder|und)\s+|/(?=(?:cap|lms|hhp|wsp|ohp|os|mensa|audimax)(?:\b|\d|\s))"#
        guard let regex = try? NSRegularExpression(pattern: pattern) else {
            return [trimmed]
        }
        
        let nsString = trimmed as NSString
        let matches = regex.matches(in: trimmed, range: NSRange(location: 0, length: nsString.length))
        
        var results: [String] = []
        var lastIndex = 0
        for match in matches {
            let range = match.range
            let sub = nsString.substring(with: NSRange(location: lastIndex, length: range.location - lastIndex))
            let clean = sub.trimmingCharacters(in: .whitespacesAndNewlines)
            if !clean.isEmpty {
                results.append(clean)
            }
            lastIndex = range.location + range.length
        }
        if lastIndex < nsString.length {
            let tail = nsString.substring(from: lastIndex).trimmingCharacters(in: .whitespacesAndNewlines)
            if !tail.isEmpty {
                results.append(tail)
            }
        }
        
        return results.isEmpty ? [trimmed] : results
    }
    
    /// Resolves all distinct room locations for composite room strings
    public static func resolveAll(room: String) -> [ResolvedCampusRoom] {
        let parts = splitRoomLocations(room: room)
        if parts.isEmpty {
            return [resolve(room: room)]
        }
        
        var results: [ResolvedCampusRoom] = []
        var seenKeys = Set<String>()
        for part in parts {
            let res = resolve(room: part)
            let key = "\(res.building.id):\(res.roomName.lowercased())"
            if !seenKeys.contains(key) {
                seenKeys.insert(key)
                results.append(res)
            }
        }
        return results.isEmpty ? [resolve(room: room)] : results
    }
    
    // Generates direct Apple Maps URL for a specific resolved campus room
    public static func appleMapsURL(forResolved resolved: ResolvedCampusRoom) -> URL? {
        if resolved.isOnline { return nil }
        
        let building = resolved.building
        let label = building.code
        let lat = building.coordinate.latitude
        let lon = building.coordinate.longitude
        let encodedLabel = label.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? ""
        return URL(string: "http://maps.apple.com/?q=\(encodedLabel)&ll=\(lat),\(lon)&z=18")
    }
    
    // Generates direct Apple Maps URL targeting the first resolvable campus location
    public static func appleMapsURL(for room: String) -> URL? {
        if let first = resolveAll(room: room).first(where: { !$0.isOnline }) {
            return appleMapsURL(forResolved: first)
        }
        return nil
    }
    
    // Opens a specific resolved campus room in Apple Maps directly
    public static func openInAppleMaps(forResolved resolved: ResolvedCampusRoom) {
        guard let url = appleMapsURL(forResolved: resolved) else { return }
        #if canImport(UIKit)
        DispatchQueue.main.async {
            UIApplication.shared.open(url)
        }
        #endif
    }
    
    // Opens the campus location in Apple Maps directly (or the first available if multiple)
    public static func openInAppleMaps(for room: String) {
        if let first = resolveAll(room: room).first(where: { !$0.isOnline }) {
            openInAppleMaps(forResolved: first)
        }
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
