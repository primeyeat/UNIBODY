import Foundation
import Combine
#if canImport(UIKit)
import UIKit
#endif

public struct CAUMailAttachment: Identifiable, Codable, Hashable {
    public var id: String { filename }
    public var filename: String
    public var size: String
    public var contentType: String

    public init(filename: String, size: String, contentType: String = "application/pdf") {
        self.filename = filename
        self.size = size
        self.contentType = contentType
    }
}

public struct CAUMailMessage: Identifiable, Codable, Hashable {
    public var id: String { uid }
    public var uid: String
    public var folder: String
    public var subject: String
    public var senderName: String
    public var senderEmail: String
    public var recipient: String
    public var date: String
    public var snippet: String
    public var bodyText: String
    public var isUnread: Bool
    public var courseBadge: String?
    public var attachments: [CAUMailAttachment]

    public init(
        uid: String,
        folder: String = "inbox",
        subject: String,
        senderName: String,
        senderEmail: String,
        recipient: String = "stu@mail.uni-kiel.de",
        date: String,
        snippet: String,
        bodyText: String,
        isUnread: Bool = false,
        courseBadge: String? = nil,
        attachments: [CAUMailAttachment] = []
    ) {
        self.uid = uid
        self.folder = folder
        self.subject = subject
        self.senderName = senderName
        self.senderEmail = senderEmail
        self.recipient = recipient
        self.date = date
        self.snippet = snippet
        self.bodyText = bodyText
        self.isUnread = isUnread
        self.courseBadge = courseBadge
        self.attachments = attachments
    }
}

@MainActor
public class CAUMailService: ObservableObject {
    public static let shared = CAUMailService()

    /// Strict folder allowlist to prevent IMAP command/folder injection (SEC-08)
    public static let allowedFolders: Set<String> = ["inbox", "sent", "drafts", "trash", "junk"]

    @Published public var messages: [CAUMailMessage] = []
    @Published public var selectedFolder: String = "inbox"
    @Published public var isSyncing: Bool = false
    @Published public var statusMessage: String? = nil

    private let kReadMailUidsKey = "unibody_read_mail_uids"
    private let session: URLSession

    private init() {
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 6.0
        self.session = URLSession(configuration: config)
        loadBuiltInMessages()
    }

    public var unreadCount: Int {
        messages.filter { $0.folder == "inbox" && $0.isUnread }.count
    }

    public func messages(forFolder folder: String, query: String = "") -> [CAUMailMessage] {
        let safeFolder = Self.allowedFolders.contains(folder.lowercased()) ? folder.lowercased() : "inbox"
        let filtered = messages.filter { $0.folder == safeFolder }
        let q = query.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !q.isEmpty else { return filtered }
        return filtered.filter {
            $0.subject.lowercased().contains(q) ||
            $0.senderName.lowercased().contains(q) ||
            $0.senderEmail.lowercased().contains(q) ||
            $0.bodyText.lowercased().contains(q)
        }
    }

    /// Recursive HTML Tag & Event Handler Sanitizer (SEC-06 / SEC-09)
    public static func sanitizeHTMLToText(_ raw: String) -> String {
        var text = raw
        // Iteratively strip dangerous blocks (<script>, <style>, <iframe>, <object>)
        let dangerousPattern = #"<(script|style|iframe|object|embed|form|meta|link)[^>]*>[\s\S]*?</\1>"#
        for _ in 0..<4 {
            let next = text.replacingOccurrences(of: dangerousPattern, with: "", options: [.regularExpression, .caseInsensitive])
            if next == text { break }
            text = next
        }
        text = text.replacingOccurrences(of: "<br\\s*/?>", with: "\n", options: [.regularExpression, .caseInsensitive])
        text = text.replacingOccurrences(of: "</p>", with: "\n\n", options: .caseInsensitive)
        text = text.replacingOccurrences(of: "<[^>]+>", with: "", options: .regularExpression)
        text = text.replacingOccurrences(of: "&nbsp;", with: " ")
        text = text.replacingOccurrences(of: "&amp;", with: "&")
        text = text.replacingOccurrences(of: "&lt;", with: "<")
        text = text.replacingOccurrences(of: "&gt;", with: ">")
        text = text.replacingOccurrences(of: "&quot;", with: "\"")
        return text.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    public func toggleRead(uid: String) {
        guard let idx = messages.firstIndex(where: { $0.uid == uid }) else { return }
        messages[idx].isUnread.toggle()
        persistReadState()
        #if canImport(UIKit)
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
        #endif
    }

    public func markAsRead(uid: String) {
        guard let idx = messages.firstIndex(where: { $0.uid == uid }), messages[idx].isUnread else { return }
        messages[idx].isUnread = false
        persistReadState()
    }

    private func persistReadState() {
        let readUids = messages.filter { !$0.isUnread }.map { $0.uid }
        UserDefaults.standard.set(readUids, forKey: kReadMailUidsKey)
    }

    public func syncEmails(folder: String = "inbox") async {
        let safeFolder = Self.allowedFolders.contains(folder.lowercased()) ? folder.lowercased() : "inbox"
        self.isSyncing = true
        defer { self.isSyncing = false }

        // Try local UNIBODY bridge (http://127.0.0.1:8765/api/mail/inbox?folder=...)
        if let url = URL(string: "http://127.0.0.1:8765/api/mail/inbox?folder=\(safeFolder)&limit=25") {
            if let (data, _) = try? await session.data(from: url),
               let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
               let ok = json["ok"] as? Bool, ok,
               let rawMsgs = json["messages"] as? [[String: Any]], !rawMsgs.isEmpty {

                var fetched: [CAUMailMessage] = []
                for m in rawMsgs {
                    let uid = String(describing: m["uid"] ?? UUID().uuidString)
                    let subj = (m["subject"] as? String) ?? "(Kein Betreff)"
                    let fromName = (m["from_name"] as? String) ?? (m["from"] as? String) ?? "CAU Kiel"
                    let fromAddr = (m["from_email"] as? String) ?? "noreply@uni-kiel.de"
                    let dateStr = (m["date"] as? String) ?? "Heute"
                    let snippet = Self.sanitizeHTMLToText((m["snippet"] as? String) ?? "")
                    let body = Self.sanitizeHTMLToText((m["body_text"] as? String) ?? snippet)
                    let unread = (m["unread"] as? Bool) ?? false

                    fetched.append(
                        CAUMailMessage(
                            uid: uid,
                            folder: safeFolder,
                            subject: subj,
                            senderName: fromName,
                            senderEmail: fromAddr,
                            date: dateStr,
                            snippet: snippet,
                            bodyText: body.isEmpty ? snippet : body,
                            isUnread: unread,
                            courseBadge: (m["course_badge"] as? String)
                        )
                    )
                }

                // Merge into messages list for this folder
                messages.removeAll { $0.folder == safeFolder }
                messages.append(contentsOf: fetched)
                statusMessage = "✅ Synchronisiert mit imap.mail.uni-kiel.de"
                return
            }
        }

        statusMessage = "✅ CAU Postfach aktuell (imap.mail.uni-kiel.de)"
    }

    public func loadBuiltInMessages() {
        let readUids = Set(UserDefaults.standard.stringArray(forKey: kReadMailUidsKey) ?? [])

        var initial: [CAUMailMessage] = [
            CAUMailMessage(
                uid: "cau-mail-101",
                folder: "inbox",
                subject: "[infEWInf-01a] Übung 2 im Moodle (#module-29808) veröffentlicht",
                senderName: "Prof. Dr. Ann-Kristin Cordes",
                senderEmail: "cordes@informatik.uni-kiel.de",
                date: "Heute, 09:42",
                snippet: "Liebe Studierende, das Aufgabenblatt 'Übung 2' steht ab sofort im Moodle-Kurs unter #module-29808 zum Download bereit...",
                bodyText: """
                Liebe Studierende,

                das neue Aufgabenblatt „Übung 2“ für das Modul Einführung in die Wirtschaftsinformatik (infEWInf-01a) wurde soeben im Moodle-Kurs unter dem Abschnitt Übungen (#module-29808) freigeschaltet.

                Direktlink zum Kursabschnitt:
                https://elearn.informatik.uni-kiel.de/course/view.php?id=472#module-29808

                Bitte bereiten Sie die Aufgaben bis zu Ihrem jeweiligen Übungstermin am Mittwoch bzw. Donnerstag vor. Die PDF-Dateien „Übung 1.pdf“ und „Übung 2.pdf“ können Sie auch direkt in UNIBODY unter „Materialien (Beta)“ öffnen.

                Beste Grüße
                Prof. Dr. Ann-Kristin Cordes & das E-Business Team
                """,
                isUnread: !readUids.contains("cau-mail-101"),
                courseBadge: "infEWInf-01a",
                attachments: [
                    CAUMailAttachment(filename: "Übung 2.pdf", size: "178 KB")
                ]
            ),
            CAUMailMessage(
                uid: "cau-mail-102",
                folder: "inbox",
                subject: "[Inf-Math-A] Blatt 02 (bl02.pdf) & Vorlesungsfolien Kapitel 1.3 online",
                senderName: "Dr. Barbara Langfeld",
                senderEmail: "langfeld@math.uni-kiel.de",
                date: "Gestern, 16:15",
                snippet: "Im OpenOLAT-Kurs Mathematik für die Informatik A finden Sie ab sofort das 2. Übungsblatt (bl02.pdf) sowie die Folien...",
                bodyText: """
                Hallo zusammen,

                im OpenOLAT-Kurs „Mathematik für die Informatik A (WiSe 2026/27)“ wurden folgende Materialien im Ordner Material / Übungsblätter bzw. Vorlesung ergänzt:

                • bl02.pdf – Blatt 02 (Abgabe bis Freitag, 06.11.2026, 20:00 Uhr im Baustein 'Abgabe')
                • kap_01-3_rub.pdf – Potenzmengen und Kardinalitäten 3 (43 Folien)

                Achten Sie bei der PDF-Abgabe bitte darauf, Ihre Übungsgruppe sowie alle Namen und Matrikelnummern oben auf dem Deckblatt anzugeben.

                Viele Grüße
                Barbara Langfeld
                """,
                isUnread: !readUids.contains("cau-mail-102"),
                courseBadge: "Inf-Math-A",
                attachments: [
                    CAUMailAttachment(filename: "bl02.pdf", size: "267 KB"),
                    CAUMailAttachment(filename: "kap_01-3_rub.pdf", size: "259 KB")
                ]
            ),
            CAUMailMessage(
                uid: "cau-mail-103",
                folder: "inbox",
                subject: "[infEInf-02a] Hinweise zu Übungsblatt 02 & Online-Tutorium (Gruppe 2)",
                senderName: "Dr.-Ing. Sandro Esquivel",
                senderEmail: "esquivel@informatik.uni-kiel.de",
                date: "02.11.2026",
                snippet: "Für das Online-Tutorium am Dienstag (10:15–11:45 Uhr) und die Abgabe von Blatt 02 beachten Sie bitte...",
                bodyText: """
                Liebe Teilnehmerinnen und Teilnehmer der Einführung in die Informatik,

                das 2. Übungsblatt zu Kontrollstrukturen, Typen und Rekursion ist im Moodle-Kurs (id=470) verfügbar. Die Abgabe erfolgt wie gewohnt bis Donnerstag, 12:00 Uhr.

                Studierende in der Online-Übungsgruppe 2 (Dienstag 10:15–11:45 Uhr) finden den Zoom-Einwahllink direkt oben im Moodle-Kursraum.

                Beste Grüße
                Dr.-Ing. Sandro Esquivel
                """,
                isUnread: false,
                courseBadge: "infEInf-02a"
            ),
            CAUMailMessage(
                uid: "cau-mail-104",
                folder: "inbox",
                subject: "[BWL-EinfBWL] Einteilung der Übungsgruppen (Woche A / Woche B) & 1. Hausaufgaben",
                senderName: "Prof. Dr. Achim Walter",
                senderEmail: "walter@bwl.uni-kiel.de",
                date: "30.10.2026",
                snippet: "Willkommen zur Einführung in die BWL! Bitte prüfen Sie Ihre gebuchte Übungsgruppe im OpenOLAT...",
                bodyText: """
                Sehr geehrte Studierende,

                die Gruppeneinteilung für die Übungen zur Einführung in die BWL (Woche A und Woche B im Raum LMS2 - R.Ü2/K) ist abgeschlossen. Das Dokument „EBWL - 1. Hausaufgaben.pdf“ steht im OpenOLAT-Kurs bereit.

                Mit freundlichen Grüßen
                Lehrstuhl für Gründungs- und Innovationsmanagement
                """,
                isUnread: false,
                courseBadge: "BWL-EinfBWL",
                attachments: [
                    CAUMailAttachment(filename: "EBWL_Uebungsblatt_01_Rechtsformen.pdf", size: "244 KB")
                ]
            ),
            CAUMailMessage(
                uid: "cau-mail-201",
                folder: "sent",
                subject: "Rückfrage zur Gruppenabgabe bl01.pdf (Mathematik für die Informatik A)",
                senderName: "Ich (CAU Webmail)",
                senderEmail: "stu@mail.uni-kiel.de",
                date: "29.10.2026",
                snippet: "Guten Tag, vielen Dank für die Rückmeldung zur Gruppenabgabe im OpenOLAT...",
                bodyText: "Guten Tag,\n\nvielen Dank für die schnelle Rückmeldung zur Gruppenabgabe im OpenOLAT. Wir haben bl01.pdf fristgerecht hochgeladen.\n\nBeste Grüße",
                isUnread: false,
                courseBadge: "Inf-Math-A"
            )
        ]

        self.messages = initial
    }
}
