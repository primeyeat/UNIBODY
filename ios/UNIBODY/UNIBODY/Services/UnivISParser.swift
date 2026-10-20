import Foundation

public struct UnivISParser {
    
    private static let dayMap: [String: (Int, String)] = [
        "MO": (0, "Montag"),
        "TU": (1, "Dienstag"),
        "WE": (2, "Mittwoch"),
        "TH": (3, "Donnerstag"),
        "FR": (4, "Freitag"),
        "SA": (5, "Samstag"),
        "SU": (6, "Sonntag")
    ]
    
    /// Parses an iCalendar (.ics) string directly from UnivIS or LMS into ScheduleEvents
    public static func parseICS(_ icsText: String) -> [ScheduleEvent] {
        var events: [ScheduleEvent] = []
        let lines = icsText.components(separatedBy: .newlines)
        
        var inEvent = false
        var summary = ""
        var location = ""
        var dtStart = ""
        var dtEnd = ""
        var byDay = ""
        var weekType = "all"
        
        for line in lines {
            let trimmed = line.trimmingCharacters(in: .whitespacesAndNewlines)
            if trimmed == "BEGIN:VEVENT" {
                inEvent = true
                summary = ""
                location = ""
                dtStart = ""
                dtEnd = ""
                byDay = ""
                weekType = "all"
            } else if trimmed == "END:VEVENT" {
                if inEvent {
                    let ev = makeEvent(
                        summary: summary,
                        location: location,
                        dtStart: dtStart,
                        dtEnd: dtEnd,
                        byDay: byDay,
                        weekType: weekType
                    )
                    if let ev = ev {
                        events.append(ev)
                    }
                }
                inEvent = false
            } else if inEvent {
                if trimmed.starts(with: "SUMMARY:") {
                    summary = String(trimmed.dropFirst(8))
                } else if trimmed.starts(with: "LOCATION:") {
                    location = String(trimmed.dropFirst(9))
                } else if trimmed.contains("DTSTART") {
                    if let colon = trimmed.firstIndex(of: ":") {
                        dtStart = String(trimmed[trimmed.index(after: colon)...])
                    }
                } else if trimmed.contains("DTEND") {
                    if let colon = trimmed.firstIndex(of: ":") {
                        dtEnd = String(trimmed[trimmed.index(after: colon)...])
                    }
                } else if trimmed.starts(with: "RRULE:") {
                    if let dayRange = trimmed.range(of: "BYDAY=") {
                        let sub = trimmed[dayRange.upperBound...]
                        let dayCode = sub.prefix(2)
                        byDay = String(dayCode)
                    }
                }
            }
        }
        
        return events
    }
    
    private static func makeEvent(
        summary: String,
        location: String,
        dtStart: String,
        dtEnd: String,
        byDay: String,
        weekType: String
    ) -> ScheduleEvent? {
        guard !summary.isEmpty else { return nil }
        
        var dayIdx = 0
        var dayName = "Montag"
        
        if let mapping = dayMap[byDay.uppercased()] {
            dayIdx = mapping.0
            dayName = mapping.1
        }
        
        func extractTime(_ dt: String) -> String {
            if let tIdx = dt.firstIndex(of: "T") {
                let timePart = dt[dt.index(after: tIdx)...]
                if timePart.count >= 4 {
                    let hh = timePart.prefix(2)
                    let mm = timePart.dropFirst(2).prefix(2)
                    return "\(hh):\(mm)"
                }
            }
            return "10:15"
        }
        
        let start = extractTime(dtStart)
        let end = dtEnd.isEmpty ? "11:45" : extractTime(dtEnd)
        let isLecture = summary.lowercased().contains("vl") || summary.lowercased().contains("vorlesung")
        
        return ScheduleEvent(
            id: UUID().uuidString,
            title: summary,
            day: dayIdx,
            dayName: dayName,
            startTime: start,
            endTime: end,
            room: location,
            type: isLecture ? "lecture" : "exercise",
            enabled: true,
            weekType: weekType
        )
    }
}
