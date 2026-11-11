import Foundation
import Combine
#if canImport(UIKit)
import UIKit
#endif

// MARK: - Data Models

public struct HomeworkItem: Identifiable, Codable, Hashable {
    public var id: String
    public var title: String
    public var filename: String
    public var releaseDate: String
    public var deadline: String?
    public var status: String // "pending", "submitted", "optional"
    public var pointsMax: Int
    public var submissionFormat: String
    public var description: String
    public var subtasks: [String]
    public var fileSize: String
    public var downloadUrl: String
    public var completed: Bool

    public init(
        id: String,
        title: String,
        filename: String,
        releaseDate: String,
        deadline: String?,
        status: String = "pending",
        pointsMax: Int = 20,
        submissionFormat: String = "PDF-Upload",
        description: String = "",
        subtasks: [String] = [],
        fileSize: String = "180 KB",
        downloadUrl: String = "",
        completed: Bool = false
    ) {
        self.id = id
        self.title = title
        self.filename = filename
        self.releaseDate = releaseDate
        self.deadline = deadline
        self.status = status
        self.pointsMax = pointsMax
        self.submissionFormat = submissionFormat
        self.description = description
        self.subtasks = subtasks
        self.fileSize = fileSize
        self.downloadUrl = downloadUrl
        self.completed = completed
    }

    public var deadlineRemainingText: String {
        if completed || status == "submitted" {
            return "Erledigt"
        }
        guard let dl = deadline, !dl.isEmpty else {
            return "Freies Übungsblatt"
        }
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withFullDate, .withTime, .withDashSeparatorInDate, .withColonSeparatorInTime]
        let cleanDl = dl.contains("+") || dl.hasSuffix("Z") ? dl : dl + "+01:00"
        if let date = formatter.date(from: cleanDl) {
            let diff = date.timeIntervalSinceNow
            if diff <= 0 {
                return "Frist abgelaufen"
            }
            let days = Int(diff) / 86400
            let hours = (Int(diff) % 86400) / 3600
            if days > 0 {
                return "Abgabe in \(days)d \(hours)h"
            } else {
                let mins = max(1, (Int(diff) % 3600) / 60)
                return "Abgabe in \(hours)h \(mins)m"
            }
        }
        return "Frist: \(dl.replacingOccurrences(of: "T", with: " "))"
    }

    public var isUrgent: Bool {
        if completed || status == "submitted" { return false }
        guard let dl = deadline, !dl.isEmpty else { return false }
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withFullDate, .withTime, .withDashSeparatorInDate, .withColonSeparatorInTime]
        let cleanDl = dl.contains("+") || dl.hasSuffix("Z") ? dl : dl + "+01:00"
        if let date = formatter.date(from: cleanDl) {
            let diff = date.timeIntervalSinceNow
            return diff > 0 && diff < 72 * 3600
        }
        return false
    }
}

public struct LectureSlideItem: Identifiable, Codable, Hashable {
    public var id: String
    public var title: String
    public var filename: String
    public var date: String
    public var pages: Int
    public var size: String
    public var url: String
    public var chapterBadge: String

    public init(
        id: String,
        title: String,
        filename: String,
        date: String,
        pages: Int,
        size: String,
        url: String,
        chapterBadge: String = "VL"
    ) {
        self.id = id
        self.title = title
        self.filename = filename
        self.date = date
        self.pages = pages
        self.size = size
        self.url = url
        self.chapterBadge = chapterBadge
    }
}

public struct MaterialCourse: Identifiable, Codable, Hashable {
    public var id: String { courseId }
    public var courseId: String
    public var title: String
    public var shortTitle: String
    public var lecturer: String
    public var platform: String
    public var platformHost: String
    public var platformIcon: String
    public var courseUrl: String
    public var folderColor: String
    public var homeworkFolderTitle: String
    public var slidesFolderTitle: String
    public var homework: [HomeworkItem]
    public var lectureSlides: [LectureSlideItem]

    public var pendingCount: Int {
        homework.filter { !$0.completed && $0.status == "pending" }.count
    }

    public var completedCount: Int {
        homework.filter { $0.completed || $0.status == "submitted" }.count
    }

    public var totalFilesCount: Int {
        homework.count + lectureSlides.count
    }
}

// MARK: - Course Materials Service (iOS)

@MainActor
public class CourseMaterialsService: ObservableObject {
    public static let shared = CourseMaterialsService()

    @Published public var courses: [MaterialCourse] = []
    @Published public var isSyncingMoodle: Bool = false
    @Published public var lastSyncStatus: String? = nil

    private let kCompletedHomeworkKey = "unibody_completed_homework_ids"
    private let session: URLSession

    /// Mapping from canonical/requested filenames to bundled resource names in `BundledMaterials`
    private let bundledPDFMapping: [String: String] = [
        "übung 1.pdf": "EWInf_Uebung_1",
        "uebung 1.pdf": "EWInf_Uebung_1",
        "uebung_1.pdf": "EWInf_Uebung_1",
        "ewinf_uebung_1.pdf": "EWInf_Uebung_1",
        "ewi übung 1.pdf": "EWInf_Uebung_1",
        "übung 2.pdf": "EWInf_Uebung_2",
        "uebung 2.pdf": "EWInf_Uebung_2",
        "uebung_2.pdf": "EWInf_Uebung_2",
        "ewinf_uebung_2.pdf": "EWInf_Uebung_2",
        "ewi übung 2.pdf": "EWInf_Uebung_2",
        "bl01.pdf": "bl01",
        "bl02.pdf": "bl02",
        "pr01.pdf": "pr01",
        "kap_01-1_rub.pdf": "kap_01-1_rub",
        "kap_01-2_rub.pdf": "kap_01-2_rub",
        "kap_01-3_rub.pdf": "kap_01-3_rub",
        "ebwl_uebungsblatt_01_rechtsformen.pdf": "EBWL_Uebungsblatt_01_Rechtsformen",
        "ebwl - 1. hausaufgaben.pdf": "EBWL_Uebungsblatt_01_Rechtsformen"
    ]

    private init() {
        let config = URLSessionConfiguration.default
        config.httpCookieAcceptPolicy = .always
        config.httpShouldSetCookies = true
        config.httpCookieStorage = HTTPCookieStorage.shared
        self.session = URLSession(configuration: config)
        loadBuiltInMaterials()
        restorePersistedCourses()
    }

    // MARK: - Unicode & Path Sanitization (SEC-03)

    public static func sanitizeFilename(_ raw: String) -> String {
        let cleaned = raw.replacingOccurrences(of: "\\", with: "/")
        let base = URL(fileURLWithPath: cleaned).lastPathComponent
        let safe = base.trimmingCharacters(in: CharacterSet(charactersIn: ". "))
        if safe.isEmpty { return "Material.pdf" }
        return safe.lowercased().hasSuffix(".pdf") ? safe : "\(safe).pdf"
    }

    public static func normalizeKey(_ name: String) -> String {
        let lower = name.precomposedStringWithCanonicalMapping.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
        return lower
            .replacingOccurrences(of: "ä", with: "ae")
            .replacingOccurrences(of: "ö", with: "oe")
            .replacingOccurrences(of: "ü", with: "ue")
            .replacingOccurrences(of: "ß", with: "ss")
    }

    // MARK: - Load Built-in Materials (Strict 2-Folder Structure)

    public func loadBuiltInMaterials() {
        let completedIds = Set(UserDefaults.standard.stringArray(forKey: kCompletedHomeworkKey) ?? [])

        var initialCourses: [MaterialCourse] = [
            // 1. Inf-Math-A
            MaterialCourse(
                courseId: "Inf-Math-A",
                title: "Mathematik für die Informatik A (8 LP)",
                shortTitle: "Mathematik für die Informatik A",
                lecturer: "Dr. Barbara Langfeld",
                platform: "OpenOlat",
                platformHost: "lms.uni-kiel.de",
                platformIcon: "building.columns.fill",
                courseUrl: "https://lms.uni-kiel.de/url/RepositoryEntry/5804556477",
                folderColor: "blue",
                homeworkFolderTitle: "📝 Übungsblätter (blXX.pdf)",
                slidesFolderTitle: "📊 Vorlesungsfolien",
                homework: [
                    HomeworkItem(
                        id: "hw-matha-01",
                        title: "Blatt 01 – Präsenz- & Hausaufgaben (bl01.pdf)",
                        filename: "bl01.pdf",
                        releaseDate: "2026-10-21",
                        deadline: "2026-10-30T20:00:00",
                        status: "pending",
                        pointsMax: 40,
                        submissionFormat: "PDF-Upload im OpenOLAT (Baustein 'Abgabe') bis Fr 20:00 Uhr",
                        description: "Originales Übungsblatt 01 aus dem OpenOLAT-Ordner 'Material / Übungsblätter' (Aussagenlogik, Wahrheitstafeln, Mengenoperationen & De Morgan).",
                        subtasks: [
                            "Aufgabe 1.1: Aussagenlogische Äquivalenzen & Wahrheitstafeln (10 P.)",
                            "Aufgabe 1.2: Mengeninklusionen & Potenzmengen beweisen (10 P.)",
                            "Aufgabe 1.3: De Morgansche Regeln für beliebige Mengensysteme (10 P.)",
                            "Aufgabe 1.4: Kartesisches Produkt & Gegenbeispiele konstruieren (10 P.)"
                        ],
                        fileSize: "262 KB",
                        downloadUrl: "https://lms.uni-kiel.de/url/RepositoryEntry/5804556477"
                    ),
                    HomeworkItem(
                        id: "hw-matha-02",
                        title: "Blatt 02 – Relationen & Abbildungen (bl02.pdf)",
                        filename: "bl02.pdf",
                        releaseDate: "2026-10-28",
                        deadline: "2026-11-06T20:00:00",
                        status: "pending",
                        pointsMax: 40,
                        submissionFormat: "PDF-Upload im OpenOLAT (Baustein 'Abgabe') bis Fr 20:00 Uhr",
                        description: "Originales Übungsblatt 02 aus dem OpenOLAT-Ordner 'Material / Übungsblätter' (Injektivität, Surjektivität, Bijektivität, Urbilder & Äquivalenzrelationen).",
                        subtasks: [
                            "Aufgabe 2.1: Eigenschaften von Abbildungen (injektiv, surjektiv, bijektiv) prüfen (10 P.)",
                            "Aufgabe 2.2: Bild- und Urbildmengen unter Komposition von Abbildungen (10 P.)",
                            "Aufgabe 2.3: Äquivalenzrelationen, Partitionen & Restklassen (10 P.)",
                            "Aufgabe 2.4: Vollständige Induktion & Summenformeln (10 P.)"
                        ],
                        fileSize: "267 KB",
                        downloadUrl: "https://lms.uni-kiel.de/url/RepositoryEntry/5804556477"
                    ),
                    HomeworkItem(
                        id: "hw-matha-pr01",
                        title: "Präsenzblatt 01 (pr01.pdf)",
                        filename: "pr01.pdf",
                        releaseDate: "2026-10-21",
                        deadline: nil,
                        status: "optional",
                        pointsMax: 0,
                        submissionFormat: "Gemeinsame Bearbeitung in der Präsenzübung (keine Abgabe nötig)",
                        description: "Präsenzaufgaben für die erste Übungswoche aus dem OpenOLAT-Ordner 'Material / Übungsblätter'.",
                        subtasks: [
                            "Präsenzaufgabe P1.1: Aufwärmaufgaben zu Quantoren & Verneinung",
                            "Präsenzaufgabe P1.2: Elementare Beweistechniken (Direkter Beweis & Kontraposition)"
                        ],
                        fileSize: "192 KB",
                        downloadUrl: "https://lms.uni-kiel.de/url/RepositoryEntry/5804556477"
                    )
                ],
                lectureSlides: [
                    LectureSlideItem(
                        id: "sl-matha-01",
                        title: "Mengentheoretische Grundlagen 1 (64 Folien)",
                        filename: "kap_01-1_rub.pdf",
                        date: "2026-10-21",
                        pages: 64,
                        size: "300 KB",
                        url: "https://lms.uni-kiel.de/url/RepositoryEntry/5804556477",
                        chapterBadge: "KAP 01-1"
                    ),
                    LectureSlideItem(
                        id: "sl-matha-02",
                        title: "Einige Konstruktionen auf Mengen 2 (55 Folien)",
                        filename: "kap_01-2_rub.pdf",
                        date: "2026-10-23",
                        pages: 55,
                        size: "302 KB",
                        url: "https://lms.uni-kiel.de/url/RepositoryEntry/5804556477",
                        chapterBadge: "KAP 01-2"
                    ),
                    LectureSlideItem(
                        id: "sl-matha-03",
                        title: "Potenzmengen und Kardinalitäten 3 (43 Folien)",
                        filename: "kap_01-3_rub.pdf",
                        date: "2026-10-28",
                        pages: 43,
                        size: "259 KB",
                        url: "https://lms.uni-kiel.de/url/RepositoryEntry/5804556477",
                        chapterBadge: "KAP 01-3"
                    )
                ]
            ),

            // 2. infEWInf-01a (Einführung in die Wirtschaftsinformatik — #module-29808 Übung X)
            MaterialCourse(
                courseId: "infEWInf-01a",
                title: "Einführung in die Wirtschaftsinformatik (E-Business)",
                shortTitle: "Wirtschaftsinformatik (E-Business)",
                lecturer: "Prof. Dr. Ann-Kristin Cordes",
                platform: "Moodle",
                platformHost: "elearn.informatik.uni-kiel.de",
                platformIcon: "bolt.fill",
                courseUrl: "https://elearn.informatik.uni-kiel.de/course/view.php?id=472#module-29808",
                folderColor: "teal",
                homeworkFolderTitle: "📝 Übungen (Übung X)",
                slidesFolderTitle: "📊 Vorlesungsfolien",
                homework: [
                    HomeworkItem(
                        id: "hw-ewinf-01",
                        title: "Übung 1",
                        filename: "Übung 1.pdf",
                        releaseDate: "2026-10-22",
                        deadline: "2026-11-04T10:00:00",
                        status: "pending",
                        pointsMax: 25,
                        submissionFormat: "PDF-Aufgabenblatt im Moodle (#module-29808)",
                        description: "Originales Aufgabenblatt 'Übung 1' aus dem Moodle-Kurs Einführung in die Wirtschaftsinformatik (course/view.php?id=472#module-29808).",
                        subtasks: [
                            "Übung 1: Aufgabenblatt herunterladen & für das Tutorium vorbereiten",
                            "Fallstudie & Diskussionsfragen zur Wirtschaftsinformatik bearbeiten"
                        ],
                        fileSize: "883 KB",
                        downloadUrl: "https://elearn.informatik.uni-kiel.de/mod/resource/view.php?id=29891"
                    ),
                    HomeworkItem(
                        id: "hw-ewinf-02",
                        title: "Übung 2",
                        filename: "Übung 2.pdf",
                        releaseDate: "2026-10-29",
                        deadline: "2026-11-11T10:00:00",
                        status: "pending",
                        pointsMax: 25,
                        submissionFormat: "PDF-Aufgabenblatt im Moodle (#module-29808)",
                        description: "Originales Aufgabenblatt 'Übung 2' aus dem Moodle-Kurs Einführung in die Wirtschaftsinformatik (course/view.php?id=472#module-29808).",
                        subtasks: [
                            "Übung 2: Aufgabenblatt herunterladen & für das Tutorium vorbereiten",
                            "Aufgaben zur Geschäftsprozessmodellierung & Digitalisierung lösen"
                        ],
                        fileSize: "178 KB",
                        downloadUrl: "https://elearn.informatik.uni-kiel.de/mod/resource/view.php?id=30026"
                    )
                ],
                lectureSlides: [
                    LectureSlideItem(
                        id: "sl-ewinf-01",
                        title: "VL 01 – Organisation & Einführung in die Wirtschaftsinformatik",
                        filename: "EWInf_VL01_Organisation.pdf",
                        date: "2026-10-22",
                        pages: 42,
                        size: "4.3 MB",
                        url: "https://elearn.informatik.uni-kiel.de/mod/resource/view.php?id=29963",
                        chapterBadge: "VL 01"
                    ),
                    LectureSlideItem(
                        id: "sl-ewinf-02",
                        title: "VL 02 – Industrie 4.0, AR/VR & Human-Computer Interaction",
                        filename: "EWInf_VL02_Industrie40_AR_VR.pdf",
                        date: "2026-10-29",
                        pages: 58,
                        size: "5.7 MB",
                        url: "https://elearn.informatik.uni-kiel.de/mod/resource/view.php?id=30025",
                        chapterBadge: "VL 02"
                    ),
                    LectureSlideItem(
                        id: "sl-ewinf-03",
                        title: "VL 03 – Cybersicherheit & Informationssicherheits-Management",
                        filename: "EWInf_VL02_Cybersicherheit.pdf",
                        date: "2026-11-02",
                        pages: 49,
                        size: "6.3 MB",
                        url: "https://elearn.informatik.uni-kiel.de/mod/resource/view.php?id=29980",
                        chapterBadge: "VL 03"
                    )
                ]
            ),

            // 3. infEInf-02a (Einführung in die Informatik)
            MaterialCourse(
                courseId: "infEInf-02a",
                title: "Einführung in die Informatik",
                shortTitle: "Einführung in die Informatik",
                lecturer: "Prof. Dr. Andreas Mühling, Dr.-Ing. Sandro Esquivel",
                platform: "Moodle",
                platformHost: "elearn.informatik.uni-kiel.de",
                platformIcon: "bolt.fill",
                courseUrl: "https://elearn.informatik.uni-kiel.de/course/view.php?id=470",
                folderColor: "indigo",
                homeworkFolderTitle: "📝 Hausaufgaben & Abgaben",
                slidesFolderTitle: "📊 Vorlesungsfolien",
                homework: [
                    HomeworkItem(
                        id: "hw-einf-01",
                        title: "Übungsblatt 01 – Algorithmen, Zahlensysteme & Zweierkomplement",
                        filename: "EInf_Blatt01_Zahlensysteme.pdf",
                        releaseDate: "2026-10-20",
                        deadline: "2026-10-27T12:00:00",
                        status: "submitted",
                        pointsMax: 20,
                        submissionFormat: "PDF-Upload + Code-Abgabe im Moodle",
                        description: "Umrechnung zwischen Binär-, Oktal- und Hexadezimalsystem, Zweierkomplement-Arithmetik sowie Entwurf erster Algorithmen.",
                        subtasks: [
                            "Aufgabe 1.1: Zahlensystem-Konvertierung & Festkommadarstellung (5 P.)",
                            "Aufgabe 1.2: Zweierkomplement-Addition & Überlauferkennung (5 P.)",
                            "Aufgabe 1.3: IEEE-754 Gleitkommazahlen (Single Precision) (5 P.)",
                            "Aufgabe 1.4: Algorithmus in Pseudocode & Flussdiagramm (5 P.)"
                        ],
                        fileSize: "215 KB",
                        downloadUrl: "https://elearn.informatik.uni-kiel.de/course/view.php?id=470",
                        completed: true
                    ),
                    HomeworkItem(
                        id: "hw-einf-02",
                        title: "Übungsblatt 02 – Kontrollstrukturen, Typen & Rekursion",
                        filename: "EInf_Blatt02_Rekursion.pdf",
                        releaseDate: "2026-10-27",
                        deadline: "2026-11-05T12:00:00",
                        status: "pending",
                        pointsMax: 20,
                        submissionFormat: "PDF + Quellcode (.zip) im Moodle bis Do 12:00 Uhr",
                        description: "Auswertung von Ausdrücken, Typsicherheit, Schleifeninvarianten und rekursive Funktionen (Euklidischer Algorithmus & Fibonacci).",
                        subtasks: [
                            "Aufgabe 2.1: Typinferenz & Auswertungsreihenfolge (5 P.)",
                            "Aufgabe 2.2: Iteration vs. Endrekursion (ggt & kgV) (5 P.)",
                            "Aufgabe 2.3: Terminierungsbeweis & Laufzeitabschätzung (5 P.)",
                            "Aufgabe 2.4: Programmieraufgabe: Sieb des Eratosthenes (5 P.)"
                        ],
                        fileSize: "248 KB",
                        downloadUrl: "https://elearn.informatik.uni-kiel.de/course/view.php?id=470"
                    )
                ],
                lectureSlides: [
                    LectureSlideItem(
                        id: "sl-einf-01",
                        title: "VL 01 – Organisatorisches & Was ist Informatik?",
                        filename: "EInf_VL01_Einfuehrung.pdf",
                        date: "2026-10-19",
                        pages: 48,
                        size: "3.1 MB",
                        url: "https://elearn.informatik.uni-kiel.de/course/view.php?id=470",
                        chapterBadge: "VL 01"
                    ),
                    LectureSlideItem(
                        id: "sl-einf-02",
                        title: "VL 02 – Informationsdarstellung, Codes & Zahlensysteme",
                        filename: "EInf_VL02_Zahlensysteme.pdf",
                        date: "2026-10-23",
                        pages: 62,
                        size: "4.2 MB",
                        url: "https://elearn.informatik.uni-kiel.de/course/view.php?id=470",
                        chapterBadge: "VL 02"
                    ),
                    LectureSlideItem(
                        id: "sl-einf-03",
                        title: "VL 03 – Algorithmen, Kontrollstrukturen & Rekursion",
                        filename: "EInf_VL03_Algorithmen.pdf",
                        date: "2026-10-26",
                        pages: 54,
                        size: "3.8 MB",
                        url: "https://elearn.informatik.uni-kiel.de/course/view.php?id=470",
                        chapterBadge: "VL 03"
                    )
                ]
            ),

            // 4. BWL-EinfBWL (Einführung in die BWL)
            MaterialCourse(
                courseId: "BWL-EinfBWL",
                title: "Einführung in die BWL (5 LP)",
                shortTitle: "Einführung in die BWL",
                lecturer: "Prof. Dr. Achim Walter",
                platform: "OpenOlat",
                platformHost: "lms.uni-kiel.de",
                platformIcon: "building.columns.fill",
                courseUrl: "https://lms.uni-kiel.de/auth/RepositoryEntry/5846466590",
                folderColor: "orange",
                homeworkFolderTitle: "📝 Hausaufgaben & Fallstudien",
                slidesFolderTitle: "📊 Vorlesungsfolien",
                homework: [
                    HomeworkItem(
                        id: "hw-bwl-01",
                        title: "1. Hausaufgaben – Konstitutive Entscheidungen & Rechtsformen",
                        filename: "EBWL_Uebungsblatt_01_Rechtsformen.pdf",
                        releaseDate: "2026-10-21",
                        deadline: "2026-11-05T12:00:00",
                        status: "pending",
                        pointsMax: 30,
                        submissionFormat: "Besprechung in der Übungsgruppe (Woche A/B)",
                        description: "Originales Aufgabenblatt 'EBWL - 1. Hausaufgaben.pdf' aus dem OpenOLAT: Standortwahl mit Nutzwertanalyse, Rechtsformvergleich (GmbH, AG, KG) und Unternehmenszusammenschlüsse.",
                        subtasks: [
                            "Aufgabe 1: Ökonomisches Prinzip (Minimal- vs. Maximalprinzip) an Fallbeispielen",
                            "Aufgabe 2: Nutzwertanalyse zur internationalen Standortwahl berechnen",
                            "Aufgabe 3: Haftungs- und Finanzierungsvergleich: UG, GmbH, AG & GmbH & Co. KG"
                        ],
                        fileSize: "244 KB",
                        downloadUrl: "https://lms.uni-kiel.de/auth/RepositoryEntry/5846466590"
                    )
                ],
                lectureSlides: [
                    LectureSlideItem(
                        id: "sl-bwl-01",
                        title: "Kapitel 1 – Gegenstand & Grundlagen der BWL",
                        filename: "EBWL_Kap01_Grundlagen.pdf",
                        date: "2026-10-20",
                        pages: 52,
                        size: "2.4 MB",
                        url: "https://lms.uni-kiel.de/auth/RepositoryEntry/5846466590",
                        chapterBadge: "KAP 01"
                    ),
                    LectureSlideItem(
                        id: "sl-bwl-02",
                        title: "Kapitel 2 – Konstitutive Entscheidungen (Rechtsform & Standort)",
                        filename: "EBWL_Kap02_Rechtsformen.pdf",
                        date: "2026-10-27",
                        pages: 68,
                        size: "3.1 MB",
                        url: "https://lms.uni-kiel.de/auth/RepositoryEntry/5846466590",
                        chapterBadge: "KAP 02"
                    )
                ]
            ),

            // 5. Inf-InfRecht (Informatikrecht)
            MaterialCourse(
                courseId: "Inf-InfRecht",
                title: "Informatikrecht (2 LP)",
                shortTitle: "Informatikrecht",
                lecturer: "Dr. Hermann Lindhorst",
                platform: "OpenOlat",
                platformHost: "lms.uni-kiel.de",
                platformIcon: "building.columns.fill",
                courseUrl: "https://lms.uni-kiel.de/url/RepositoryEntry/5397086478",
                folderColor: "purple",
                homeworkFolderTitle: "📝 Fallbesprechungen & Begleitmaterial",
                slidesFolderTitle: "📊 Vorlesungsfolien",
                homework: [
                    HomeworkItem(
                        id: "hw-infrecht-01",
                        title: "Fallstudie 01 – Softwarevertragsrecht & Urheberrecht (§§ 69a ff. UrhG)",
                        filename: "InfRecht_Fallstudie_01_UrhG.pdf",
                        releaseDate: "2026-10-26",
                        deadline: nil,
                        status: "optional",
                        pointsMax: 0,
                        submissionFormat: "Freiwillige Lektüre zur Vorlesung (keine Abgabe erforderlich)",
                        description: "Begleitender Übungsfall zur Einordnung von Individual- und Standardsoftware, Open-Source-Lizenzen (GPL/MIT) und Schrankenbestimmungen.",
                        subtasks: [
                            "Sachverhalt 1: Schutzfähigkeit von Quellcode, APIs und Datenstrukturen nach § 69a UrhG",
                            "Sachverhalt 2: Mängelgewährleistung bei SaaS- und Cloud-Verträgen"
                        ],
                        fileSize: "195 KB",
                        downloadUrl: "https://lms.uni-kiel.de/url/RepositoryEntry/5397086478"
                    )
                ],
                lectureSlides: [
                    LectureSlideItem(
                        id: "sl-infrecht-01",
                        title: "Einheit 01 – Einführung ins IT-Recht & Rechtssystematik",
                        filename: "InfRecht_VL01_Einfuehrung.pdf",
                        date: "2026-10-26",
                        pages: 45,
                        size: "1.9 MB",
                        url: "https://lms.uni-kiel.de/url/RepositoryEntry/5397086478",
                        chapterBadge: "VL 01"
                    ),
                    LectureSlideItem(
                        id: "sl-infrecht-02",
                        title: "Einheit 02 – Urheberrechtlicher Schutz von Computerprogrammen",
                        filename: "InfRecht_VL02_Urheberrecht.pdf",
                        date: "2026-11-02",
                        pages: 56,
                        size: "2.3 MB",
                        url: "https://lms.uni-kiel.de/url/RepositoryEntry/5397086478",
                        chapterBadge: "VL 02"
                    )
                ]
            )
        ]

        // Apply persisted completion state
        for cIdx in 0..<initialCourses.count {
            for hIdx in 0..<initialCourses[cIdx].homework.count {
                let hwId = initialCourses[cIdx].homework[hIdx].id
                if completedIds.contains(hwId) {
                    initialCourses[cIdx].homework[hIdx].completed = true
                    initialCourses[cIdx].homework[hIdx].status = "submitted"
                }
            }
        }

        self.courses = initialCourses
    }

    // MARK: - Toggle Homework Completion

    public func toggleHomeworkCompleted(courseId: String, homeworkId: String) {
        guard let cIdx = courses.firstIndex(where: { $0.courseId == courseId }),
              let hIdx = courses[cIdx].homework.firstIndex(where: { $0.id == homeworkId }) else {
            return
        }
        courses[cIdx].homework[hIdx].completed.toggle()
        let isDone = courses[cIdx].homework[hIdx].completed
        if courses[cIdx].homework[hIdx].status != "optional" {
            courses[cIdx].homework[hIdx].status = isDone ? "submitted" : "pending"
        }

        var completedIds = Set(UserDefaults.standard.stringArray(forKey: kCompletedHomeworkKey) ?? [])
        if isDone {
            completedIds.insert(homeworkId)
        } else {
            completedIds.remove(homeworkId)
        }
        UserDefaults.standard.set(Array(completedIds), forKey: kCompletedHomeworkKey)
        persistCourses()

        #if canImport(UIKit)
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
        #endif
    }

    // MARK: - Live Moodle Scraper for infEWInf-01a (#module-29808 -> Übung X, X=1..20)

    public func syncEWInfExercisesFromMoodle(username: String, password: String) async {
        let trimmedUser = username.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedUser.isEmpty, !password.isEmpty else { return }

        self.isSyncingMoodle = true
        defer { self.isSyncingMoodle = false }

        do {
            // 1. Authenticate on Moodle if needed
            let loggedIn = await authenticateMoodleSession(username: trimmedUser, password: password)
            guard loggedIn else { return }

            // 2. Fetch course page id=472
            guard let courseURL = URL(string: "https://elearn.informatik.uni-kiel.de/course/view.php?id=472") else { return }
            var req = URLRequest(url: courseURL)
            req.timeoutInterval = 8.0
            req.setValue("Mozilla/5.0 (iPhone; CPU iPhone OS 27_0 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Mobile/15E148 UNIBODY-iOS", forHTTPHeaderField: "User-Agent")

            let (data, _) = try await session.data(for: req)
            guard let html = String(data: data, encoding: .utf8) ?? String(data: data, encoding: .isoLatin1) else { return }

            // Narrow down to #module-29808 section if present, else scan full course HTML
            let searchScope: String
            if let modRange = html.range(of: "id=\"module-29808\"") {
                let start = modRange.lowerBound
                let end = html.index(start, offsetBy: min(45000, html.distance(from: start, to: html.endIndex)))
                searchScope = String(html[start..<end])
            } else {
                searchScope = html
            }

            // Match resource links whose label is "Übung X" (X in 1..20)
            let pattern = #"href=["'](https?://elearn\.informatik\.uni-kiel\.de/mod/resource/view\.php\?id=(\d+))["'][^>]*>([\s\S]*?)</a>"#
            guard let regex = try? NSRegularExpression(pattern: pattern, options: [.caseInsensitive]) else { return }
            let nsScope = searchScope as NSString
            let matches = regex.matches(in: searchScope, options: [], range: NSRange(location: 0, length: nsScope.length))

            var discovered: [(num: Int, resId: String, url: String)] = []
            var seenNums = Set<Int>()

            let uebungPattern = #"(?:^|\b)(?:Übung|Uebung)\s*(\d{1,2})(?:\b|$)"#
            let uebungRegex = try? NSRegularExpression(pattern: uebungPattern, options: [.caseInsensitive])

            for match in matches {
                guard match.numberOfRanges >= 4 else { continue }
                let href = nsScope.substring(with: match.range(at: 1))
                let resId = nsScope.substring(with: match.range(at: 2))
                let rawInner = nsScope.substring(with: match.range(at: 3))
                let cleanText = rawInner
                    .replacingOccurrences(of: "<[^>]+>", with: " ", options: .regularExpression)
                    .replacingOccurrences(of: "\\s+", with: " ", options: .regularExpression)
                    .trimmingCharacters(in: .whitespacesAndNewlines)

                let lowerText = cleanText.lowercased()
                if lowerText.contains("folie") || lowerText.contains("vorlesung") || lowerText.contains("lösung") {
                    continue
                }

                if let uRegex = uebungRegex,
                   let uMatch = uRegex.firstMatch(in: cleanText, options: [], range: NSRange(location: 0, length: (cleanText as NSString).length)),
                   uMatch.numberOfRanges >= 2 {
                    let numStr = (cleanText as NSString).substring(with: uMatch.range(at: 1))
                    if let num = Int(numStr), (1...20).contains(num), !seenNums.contains(num) {
                        seenNums.insert(num)
                        discovered.append((num: num, resId: resId, url: href))
                    }
                }
            }

            guard !discovered.isEmpty else { return }
            discovered.sort { $0.num < $1.num }

            let completedIds = Set(UserDefaults.standard.stringArray(forKey: kCompletedHomeworkKey) ?? [])
            if let cIdx = courses.firstIndex(where: { $0.courseId == "infEWInf-01a" }) {
                var updatedHw: [HomeworkItem] = []
                for item in discovered {
                    let hwId = String(format: "hw-ewinf-%02d", item.num)
                    let existing = courses[cIdx].homework.first(where: { $0.id == hwId })
                    let isDone = completedIds.contains(hwId) || (existing?.completed ?? false)
                    updatedHw.append(
                        HomeworkItem(
                            id: hwId,
                            title: "Übung \(item.num)",
                            filename: "Übung \(item.num).pdf",
                            releaseDate: existing?.releaseDate ?? "2026-11-03",
                            deadline: existing?.deadline,
                            status: isDone ? "submitted" : "pending",
                            pointsMax: 25,
                            submissionFormat: "PDF-Aufgabenblatt im Moodle (#module-29808)",
                            description: "Originales Aufgabenblatt 'Übung \(item.num)' aus dem Moodle-Kurs Einführung in die Wirtschaftsinformatik (course/view.php?id=472#module-29808).",
                            subtasks: [
                                "Übung \(item.num): Aufgabenblatt herunterladen & für das Tutorium vorbereiten",
                                "Aufgaben & Fallstudien zur Wirtschaftsinformatik bearbeiten"
                            ],
                            fileSize: existing?.fileSize ?? "PDF",
                            downloadUrl: item.url,
                            completed: isDone
                        )
                    )
                }
                courses[cIdx].homework = updatedHw
                self.lastSyncStatus = "✅ \(updatedHw.count) Übungen aus #module-29808 synchronisiert"
            }
        } catch {
            print("Moodle EWInf exercise sync error: \(error.localizedDescription)")
        }
    }

    fileprivate func authenticateMoodleSessionForSync(username: String, password: String) async -> Bool {
        await authenticateMoodleSession(username: username, password: password)
    }

    private func authenticateMoodleSession(username: String, password: String) async -> Bool {
        guard let loginURL = URL(string: "https://elearn.informatik.uni-kiel.de/login/index.php") else { return false }
        do {
            var getReq = URLRequest(url: loginURL)
            getReq.timeoutInterval = 8.0
            getReq.setValue("Mozilla/5.0 (iPhone; CPU iPhone OS 27_0 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Mobile/15E148 UNIBODY-iOS", forHTTPHeaderField: "User-Agent")

            let (data, _) = try await session.data(for: getReq)
            guard let html = String(data: data, encoding: .utf8) ?? String(data: data, encoding: .isoLatin1) else { return false }

            if html.contains("/login/logout.php") {
                return true
            }

            var loginToken = ""
            if let tokenRange = html.range(of: "name=\"logintoken\" value=\"") {
                let sub = html[tokenRange.upperBound...]
                if let quoteEnd = sub.firstIndex(of: "\"") {
                    loginToken = String(sub[..<quoteEnd])
                }
            }
            guard !loginToken.isEmpty else { return false }

            var postReq = URLRequest(url: loginURL)
            postReq.httpMethod = "POST"
            postReq.timeoutInterval = 10.0
            postReq.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
            postReq.setValue("https://elearn.informatik.uni-kiel.de/login/index.php", forHTTPHeaderField: "Referer")

            var allowed = CharacterSet.alphanumerics
            allowed.insert(charactersIn: "-._~")
            let encUser = username.addingPercentEncoding(withAllowedCharacters: allowed) ?? username
            let encPass = password.addingPercentEncoding(withAllowedCharacters: allowed) ?? password
            let encToken = loginToken.addingPercentEncoding(withAllowedCharacters: allowed) ?? loginToken

            let body = "anchor=&logintoken=\(encToken)&username=\(encUser)&password=\(encPass)"
            postReq.httpBody = body.data(using: .utf8)

            let (authData, _) = try await session.data(for: postReq)
            if let authHtml = String(data: authData, encoding: .utf8) ?? String(data: authData, encoding: .isoLatin1) {
                return authHtml.contains("/login/logout.php") || !authHtml.contains("name=\"logintoken\"")
            }
        } catch {
            return false
        }
        return false
    }

    // MARK: - Resolve & Download Real PDF File URL for Native iOS QuickLook / Share

    public func resolvePDFFileURL(
        courseId: String,
        filename: String,
        title: String,
        downloadUrl: String,
        username: String,
        password: String
    ) async -> URL? {
        let safeFilename = Self.sanitizeFilename(filename)
        let safeCourse = courseId.lowercased().replacingOccurrences(of: "[^a-z0-9_-]", with: "", options: .regularExpression)

        let fm = FileManager.default
        let docsDir = fm.urls(for: .documentDirectory, in: .userDomainMask).first ?? fm.temporaryDirectory
        let courseDir = docsDir.appendingPathComponent("Materials", isDirectory: true).appendingPathComponent(safeCourse, isDirectory: true)
        try? fm.createDirectory(at: courseDir, withIntermediateDirectories: true)

        let destinationURL = courseDir.appendingPathComponent(safeFilename)

        // 1. Check if already cached in Documents/Materials/<courseId>/<safeFilename>
        if fm.fileExists(atPath: destinationURL.path),
           let data = try? Data(contentsOf: destinationURL),
           data.count > 1000,
           String(data: data.prefix(5), encoding: .ascii) == "%PDF-" {
            return destinationURL
        }

        // 2. Check bundled real PDFs inside UNIBODY.app (100% real university PDFs, works offline!)
        let lowerKey = safeFilename.precomposedStringWithCanonicalMapping.lowercased()
        let normKey = Self.normalizeKey(safeFilename)
        if let bundleBase = bundledPDFMapping[lowerKey] ?? bundledPDFMapping[normKey] {
            if let bundledURL = Bundle.main.url(forResource: bundleBase, withExtension: "pdf") ??
                                Bundle.main.url(forResource: bundleBase, withExtension: "pdf", subdirectory: "BundledMaterials") {
                if let data = try? Data(contentsOf: bundledURL), data.count > 1000 {
                    try? data.write(to: destinationURL, options: .atomic)
                    return destinationURL
                }
            }
        }

        // 3. Try downloading live from Moodle if downloadUrl is a Moodle resource link
        if downloadUrl.contains("elearn.informatik.uni-kiel.de/mod/resource/view.php") {
            let redirectUrlStr = downloadUrl.contains("redirect=1") ? downloadUrl : "\(downloadUrl)&redirect=1"
            if let remoteURL = URL(string: redirectUrlStr) {
                if !username.isEmpty && !password.isEmpty {
                    _ = await authenticateMoodleSession(username: username, password: password)
                }
                if let (data, _) = try? await session.data(from: remoteURL),
                   data.count > 1000,
                   String(data: data.prefix(5), encoding: .ascii) == "%PDF-" {
                    try? data.write(to: destinationURL, options: .atomic)
                    return destinationURL
                }
            }
        }

        // 4. Try local UNIBODY server if running on same Mac/Simulator (http://127.0.0.1:8765)
        var comps = URLComponents(string: "http://127.0.0.1:8765/api/materials/download")
        comps?.queryItems = [
            URLQueryItem(name: "course_id", value: courseId),
            URLQueryItem(name: "filename", value: safeFilename),
            URLQueryItem(name: "title", value: title)
        ]
        if let localURL = comps?.url {
            var localReq = URLRequest(url: localURL)
            localReq.timeoutInterval = 3.5
            if let (data, _) = try? await session.data(for: localReq),
               data.count > 500,
               String(data: data.prefix(5), encoding: .ascii) == "%PDF-" {
                try? data.write(to: destinationURL, options: .atomic)
                return destinationURL
            }
        }

        // 5. Fallback: Generate a clean native PDF overview document so QuickLook always succeeds
        if let generatedData = generateNativeSummaryPDF(courseId: courseId, title: title, filename: safeFilename, portalUrl: downloadUrl) {
            try? generatedData.write(to: destinationURL, options: .atomic)
            return destinationURL
        }

        return nil
    }

    private func generateNativeSummaryPDF(courseId: String, title: String, filename: String, portalUrl: String) -> Data? {
        #if canImport(UIKit)
        let pageRect = CGRect(x: 0, y: 0, width: 595.2, height: 841.8) // A4
        let renderer = UIGraphicsPDFRenderer(bounds: pageRect)
        return renderer.pdfData { ctx in
            ctx.beginPage()
            let titleAttrs: [NSAttributedString.Key: Any] = [
                .font: UIFont.boldSystemFont(ofSize: 18),
                .foregroundColor: UIColor(red: 0.05, green: 0.22, blue: 0.45, alpha: 1.0)
            ]
            let subAttrs: [NSAttributedString.Key: Any] = [
                .font: UIFont.systemFont(ofSize: 12),
                .foregroundColor: UIColor.darkGray
            ]
            let header = "UNIBODY (Inoffizielles Studierenden-Tool) · Materialien (Beta) · \(courseId)"
            header.draw(in: CGRect(x: 48, y: 48, width: 500, height: 24), withAttributes: subAttrs)
            title.draw(in: CGRect(x: 48, y: 80, width: 500, height: 60), withAttributes: titleAttrs)

            let bodyText = """
            Dateiname: \(filename)
            Modul: \(courseId)
            Quelle: \(portalUrl)

            Hinweis:
            Dieses Dokument wurde als lokale Vorschau generiert. Sobald du im Tab 'Login & Tresor' deine CAU-Zugangsdaten hinterlegt hast, lädt UNIBODY die Original-PDFs direkt von Moodle bzw. OpenOLAT herunter.
            """
            bodyText.draw(in: CGRect(x: 48, y: 155, width: 500, height: 400), withAttributes: subAttrs)
        }
        #else
        return nil
        #endif
    }
}


// MARK: - Persistence & live sync for ALL courses (Moodle via URLSession, OpenOlat via on-device crawler)

extension CourseMaterialsService {

    private static let moodleHost = "elearn.informatik.uni-kiel.de"
    private static let openOlatHost = "lms.uni-kiel.de"

    private static var coursesFileURL: URL? {
        guard let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first else { return nil }
        return base.appendingPathComponent("UNIBODY", isDirectory: true).appendingPathComponent("materials.json")
    }

    /// Restores the synced course materials from disk. Built-in courses missing in the saved file are kept.
    func restorePersistedCourses() {
        guard let url = Self.coursesFileURL,
              let data = try? Data(contentsOf: url),
              let saved = try? JSONDecoder().decode([MaterialCourse].self, from: data), !saved.isEmpty else { return }
        let savedIds = Set(saved.map { $0.courseId.lowercased() })
        courses = saved + courses.filter { !savedIds.contains($0.courseId.lowercased()) }
    }

    func persistCourses() {
        guard let url = Self.coursesFileURL, let data = try? JSONEncoder().encode(courses) else { return }
        try? FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        try? data.write(to: url, options: [.atomic, .completeFileProtectionUnlessOpen])
        ReminderService.shared.materialsChanged()
    }

    // MARK: Classification helpers

    private static func firstMatch(_ pattern: String, in text: String, group: Int = 1) -> String? {
        guard let regex = try? NSRegularExpression(pattern: pattern, options: [.caseInsensitive]) else { return nil }
        let ns = text as NSString
        guard let match = regex.firstMatch(in: text, range: NSRange(location: 0, length: ns.length)),
              match.numberOfRanges > group, match.range(at: group).location != NSNotFound else { return nil }
        return ns.substring(with: match.range(at: group))
    }

    static func sheetNumber(in text: String) -> Int? {
        if let n = firstMatch(#"\b(?:bl|pr)[-_]?0*(\d+)"#, in: text) { return Int(n) }
        if let n = firstMatch(#"(?:blatt|übung|uebung|aufgabe|hausaufgabe|assignment|serie)\s*#?\s*0*(\d+)"#, in: text) { return Int(n) }
        return nil
    }

    static func isSolution(_ text: String) -> Bool {
        firstMatch(#"(l(?:ö|oe)sung|solution|musterl)"#, in: text, group: 1) != nil
    }

    static func isExerciseSheet(_ text: String) -> Bool {
        firstMatch(#"(\b(?:bl|pr)[-_]?\d+|blatt|übung|uebung|hausaufgabe|aufgabe|assignment|serie)"#, in: text, group: 1) != nil
    }

    private static func decodeEntities(_ text: String) -> String {
        text.replacingOccurrences(of: "&amp;", with: "&")
            .replacingOccurrences(of: "&nbsp;", with: " ")
            .replacingOccurrences(of: "&quot;", with: "\"")
            .replacingOccurrences(of: "&#039;", with: "'")
    }

    private func knownURLs(of course: MaterialCourse) -> Set<String> {
        Set(course.homework.map { $0.downloadUrl } + course.lectureSlides.map { $0.url })
    }

    /// Files one discovered document into the course. Returns true if something new was added.
    private func registerFile(courseIndex: Int, id: String, label: String, filename: String, url: String, size: String = "PDF") -> Bool {
        let combined = "\(label) \(filename)"
        let today = ISO8601DateFormatter().string(from: Date()).prefix(10)

        if Self.isSolution(combined) {
            courses[courseIndex].lectureSlides.append(
                LectureSlideItem(id: id, title: label, filename: filename, date: String(today), pages: 0, size: size, url: url, chapterBadge: "LÖSUNG")
            )
            return true
        }
        if Self.isExerciseSheet(combined) {
            courses[courseIndex].homework.append(
                HomeworkItem(
                    id: id,
                    title: label,
                    filename: filename,
                    releaseDate: String(today),
                    deadline: nil,
                    status: "pending",
                    pointsMax: 0,
                    submissionFormat: "Beim Live-Abgleich im Kursraum gefunden",
                    description: "Aufgabenblatt aus dem Kursraum (\(courses[courseIndex].platformHost)).",
                    subtasks: [],
                    fileSize: size,
                    downloadUrl: url,
                    completed: false
                )
            )
            return true
        }
        courses[courseIndex].lectureSlides.append(
            LectureSlideItem(id: id, title: label, filename: filename, date: String(today), pages: 0, size: size, url: url, chapterBadge: "LIVE")
        )
        return true
    }

    // MARK: Moodle (any course)

    private func fetchMoodleHTML(_ urlString: String) async -> String? {
        guard let url = URL(string: urlString), url.host?.lowercased() == Self.moodleHost else { return nil }
        var request = URLRequest(url: url)
        request.timeoutInterval = 10
        guard let (data, _) = try? await session.data(for: request) else { return nil }
        return String(data: data, encoding: .utf8) ?? String(data: data, encoding: .isoLatin1)
    }

    /// Reads file resources and assignment deadlines of one Moodle course. Returns the number of new entries.
    private func syncMoodleCourse(at index: Int) async -> Int {
        guard let number = Self.firstMatch(#"/course/view\.php\?(?:[^#]*&)?id=(\d+)"#, in: courses[index].courseUrl),
              let html = await fetchMoodleHTML("https://\(Self.moodleHost)/course/view.php?id=\(number)") else { return 0 }

        var added = 0
        let pattern = #"<li\s+class="activity[^"]*modtype_resource[^"]*"\s+id="module-\d+"[^>]*>([\s\S]*?)</li>"#
        if let regex = try? NSRegularExpression(pattern: pattern, options: [.caseInsensitive]) {
            let ns = html as NSString
            for match in regex.matches(in: html, range: NSRange(location: 0, length: ns.length)) {
                let body = ns.substring(with: match.range(at: 1))
                if body.contains("Not available unless") || body.contains("Nicht verfügbar, es sei denn") { continue }
                guard let url = Self.firstMatch(#"href="(https://elearn\.informatik\.uni-kiel\.de/mod/resource/view\.php\?id=\d+)""#, in: body),
                      let resId = Self.firstMatch(#"view\.php\?id=(\d+)"#, in: url),
                      let rawLabel = Self.firstMatch(#"view\.php\?id=\d+"[^>]*>([\s\S]*?)</a>"#, in: body) else { continue }
                if knownURLs(of: courses[index]).contains(url) { continue }
                let label = Self.decodeEntities(
                    rawLabel
                        .replacingOccurrences(of: #"<span[^>]*accesshide[^>]*>[\s\S]*?</span>"#, with: " ", options: .regularExpression)
                        .replacingOccurrences(of: "<[^>]+>", with: " ", options: .regularExpression)
                        .replacingOccurrences(of: "\\s+", with: " ", options: .regularExpression)
                        .trimmingCharacters(in: .whitespacesAndNewlines)
                )
                guard !label.isEmpty else { continue }
                if registerFile(courseIndex: index, id: "mdl-\(resId)", label: label, filename: Self.sanitizeFilename(label), url: url) {
                    added += 1
                }
            }
        }

        // Assignment deadlines from the course calendar ("upcoming events")
        if let calendar = await fetchMoodleHTML("https://\(Self.moodleHost)/calendar/view.php?view=upcoming&course=\(number)") {
            let formatter = ISO8601DateFormatter()
            formatter.timeZone = TimeZone(identifier: "Europe/Berlin") ?? .current
            for part in calendar.components(separatedBy: "data-type=\"event\"").dropFirst() {
                let head = String(part.prefix(while: { $0 != ">" }))
                guard head.contains("data-event-component=\"mod_assign\"") || head.contains("data-event-eventtype=\"due\""),
                      let rawTitle = Self.firstMatch(#"data-event-title="([^"]*)""#, in: head),
                      let stamp = Self.firstMatch(#"[?&;]time=(\d{9,11})"#, in: part),
                      let seconds = TimeInterval(stamp) else { continue }
                let title = Self.decodeEntities(rawTitle)
                    .replacingOccurrences(of: #"\s*(ist fällig|is due|Fälligkeit)\s*$"#, with: "", options: [.regularExpression, .caseInsensitive])
                let deadline = formatter.string(from: Date(timeIntervalSince1970: seconds))
                let eventId = Self.firstMatch(#"data-event-id="(\d+)""#, in: head) ?? title
                let hwId = "mdl-due-\(eventId)"
                let sheet = Self.sheetNumber(in: title)

                if let hIdx = courses[index].homework.firstIndex(where: { $0.id == hwId })
                    ?? courses[index].homework.firstIndex(where: { sheet != nil && Self.sheetNumber(in: "\($0.title) \($0.filename)") == sheet }) {
                    if courses[index].homework[hIdx].deadline != deadline {
                        courses[index].homework[hIdx].deadline = deadline
                        added += 1
                    }
                } else {
                    courses[index].homework.append(
                        HomeworkItem(
                            id: hwId, title: title, filename: Self.sanitizeFilename(title), releaseDate: String(deadline.prefix(10)),
                            deadline: deadline, status: "pending", pointsMax: 0,
                            submissionFormat: "Abgabe im Moodle", description: "Abgabefrist aus dem Moodle-Kalender.",
                            subtasks: [], fileSize: "–", downloadUrl: "https://\(Self.moodleHost)/course/view.php?id=\(number)", completed: false
                        )
                    )
                    added += 1
                }
            }
        }
        return added
    }

    /// Live sync for every Moodle course (one shared login). Returns the number of new or updated entries.
    @discardableResult
    public func syncAllMoodleCourses(username: String, password: String) async -> Int {
        let user = username.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !user.isEmpty, !password.isEmpty else { return 0 }

        await syncEWInfExercisesFromMoodle(username: user, password: password)
        isSyncingMoodle = true
        defer { isSyncingMoodle = false }

        guard await authenticateMoodleSessionForSync(username: user, password: password) else { return 0 }
        var added = 0
        for index in courses.indices where courses[index].platformHost == Self.moodleHost && courses[index].courseId != "infEWInf-01a" {
            added += await syncMoodleCourse(at: index)
        }
        persistCourses()
        return added
    }

    // MARK: OpenOlat (any course)

    private func materialsDirectory(for courseId: String) -> URL {
        let safeCourse = courseId.lowercased().replacingOccurrences(of: "[^a-z0-9_-]", with: "", options: .regularExpression)
        let fm = FileManager.default
        let docs = fm.urls(for: .documentDirectory, in: .userDomainMask).first ?? fm.temporaryDirectory
        return docs.appendingPathComponent("Materials", isDirectory: true).appendingPathComponent(safeCourse, isDirectory: true)
    }

    /// Crawls every OpenOlat course and stores new PDFs on the device. Returns the number of new files.
    private func syncAllOpenOlatCourses(username: String, password: String) async -> (newFiles: Int, unreachable: Int) {
        var newFiles = 0
        var unreachable = 0
        let fm = FileManager.default

        for index in courses.indices where courses[index].platformHost == Self.openOlatHost {
            guard let courseURL = URL(string: courses[index].courseUrl) else { continue }
            lastSyncStatus = "🔄 \(courses[index].shortTitle): Kursraum wird durchsucht …"
            guard let files = await OpenOlatMaterialsCrawler.shared.crawl(courseURL: courseURL, username: username, password: password) else {
                unreachable += 1
                continue
            }

            let directory = materialsDirectory(for: courses[index].courseId)
            try? fm.createDirectory(at: directory, withIntermediateDirectories: true)
            var downloaded = 0
            let syncedKey = "unibody_olat_synced_files"
            var synced = Set(UserDefaults.standard.stringArray(forKey: syncedKey) ?? [])

            for file in files where downloaded < 40 {
                let filename = Self.sanitizeFilename(file.name)
                let destination = directory.appendingPathComponent(filename)
                // Only files this crawler stored itself count as present; a generated preview gets replaced
                let marker = "\(courses[index].courseId.lowercased())/\(Self.normalizeKey(filename))"
                if synced.contains(marker), fm.fileExists(atPath: destination.path) { continue }
                guard let data = await OpenOlatMaterialsCrawler.shared.download(file) else { continue }
                guard (try? data.write(to: destination, options: .atomic)) != nil else { continue }
                downloaded += 1
                synced.insert(marker)
                UserDefaults.standard.set(Array(synced), forKey: syncedKey)

                let size = "\(max(1, data.count / 1024)) KB"
                let key = Self.normalizeKey(filename)
                if let hIdx = courses[index].homework.firstIndex(where: { Self.normalizeKey($0.filename) == key }) {
                    courses[index].homework[hIdx].fileSize = size
                } else if let sIdx = courses[index].lectureSlides.firstIndex(where: { Self.normalizeKey($0.filename) == key }) {
                    courses[index].lectureSlides[sIdx].size = size
                } else {
                    let label = file.path.isEmpty ? filename : "\(filename) · \(file.path)"
                    _ = registerFile(
                        courseIndex: index,
                        id: "olat-\(courses[index].courseId.lowercased())-\(key)",
                        label: label,
                        filename: filename,
                        url: courses[index].courseUrl,
                        size: size
                    )
                }
            }
            newFiles += downloaded
        }
        return (newFiles, unreachable)
    }

    /// Full live sync: all Moodle courses plus all OpenOlat courses.
    public func syncAllCourses(username: String, password: String) async {
        let user = username.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !user.isEmpty, !password.isEmpty else {
            lastSyncStatus = "⚠️ Bitte zuerst die Zugangsdaten im Tab 'Login & Tresor' hinterlegen."
            return
        }
        let moodleChanges = await syncAllMoodleCourses(username: user, password: password)

        isSyncingMoodle = true
        defer { isSyncingMoodle = false }
        let olat = await syncAllOpenOlatCourses(username: user, password: password)
        persistCourses()

        var summary = "✅ Abgleich fertig: \(moodleChanges) Moodle-Änderungen, \(olat.newFiles) neue OpenOlat-Dateien"
        if olat.unreachable > 0 {
            summary += " · \(olat.unreachable) Kursraum/-räume nicht erreichbar"
        }
        lastSyncStatus = summary
    }
}
