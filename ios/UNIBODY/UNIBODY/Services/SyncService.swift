import Foundation

public struct SyncResult {
    public let success: Bool
    public let message: String
    public let enrolledCount: Int
    public let eventsCount: Int
    public let host: String
    public let timestamp: Date
}

public class SyncService {
    public static let shared = SyncService()
    
    // Default candidate endpoints: Local Wi-Fi IP of host Mac + Simulator loopback
    public static let defaultCandidates: [String] = [
        "http://192.168.178.74:8765",
        "http://127.0.0.1:8765",
        "http://localhost:8765"
    ]
    
    /// Probes candidate server URLs to find the active UNIBODY Core server
    public func discoverActiveServer(preferredURL: String) async -> String? {
        var endpoints = [preferredURL]
        for c in SyncService.defaultCandidates {
            if !endpoints.contains(c) {
                endpoints.append(c)
            }
        }
        
        for ep in endpoints {
            guard let url = URL(string: "\(ep)/api/state") else { continue }
            var req = URLRequest(url: url)
            req.timeoutInterval = 2.0
            do {
                let (data, response) = try await URLSession.shared.data(for: req)
                if let http = response as? HTTPURLResponse, http.statusCode == 200,
                   let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                   let ok = json["ok"] as? Bool, ok {
                    return ep
                }
            } catch {
                continue
            }
        }
        return nil
    }
    
    /// Fetches live state from UNIBODY Core server
    public func fetchServerState(serverURL: String) async throws -> (schedule: [ScheduleEvent], enrolled: [String: String], jobs: [SniperJob]) {
        guard let url = URL(string: "\(serverURL)/api/state") else {
            throw URLError(.badURL)
        }
        
        var req = URLRequest(url: url)
        req.timeoutInterval = 5.0
        let (data, response) = try await URLSession.shared.data(for: req)
        
        guard let http = response as? HTTPURLResponse, http.statusCode == 200 else {
            throw URLError(.badServerResponse)
        }
        
        guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
              let ok = json["ok"] as? Bool, ok else {
            throw URLError(.cannotParseResponse)
        }
        
        // Parse enrolled groups map
        var enrolledMap: [String: String] = [:]
        if let rawEnrolled = json["enrolled_groups"] as? [String: Any] {
            for (k, v) in rawEnrolled {
                enrolledMap[k.lowercased()] = String(describing: v)
            }
        }
        
        // Parse schedule events
        var parsedEvents: [ScheduleEvent] = []
        if let rawSched = json["schedule"] as? [[String: Any]] {
            for item in rawSched {
                let id = String(describing: item["id"] ?? UUID().uuidString)
                let courseId = item["course_id"] as? String
                let groupId = item["group_id"] as? String
                let title = (item["title"] as? String) ?? "Termin"
                let day = (item["day"] as? Int) ?? 0
                let dayName = (item["day_name"] as? String) ?? "Montag"
                let start = (item["start_time"] as? String) ?? "10:15"
                let end = (item["end_time"] as? String) ?? "11:45"
                let room = (item["room"] as? String) ?? ""
                let type = (item["type"] as? String) ?? "lecture"
                let enabled = (item["enabled"] as? Bool) ?? true
                let weekType = (item["week_type"] as? String) ?? "all"
                
                let ev = ScheduleEvent(
                    id: id,
                    courseId: courseId,
                    groupId: groupId,
                    title: title,
                    day: day,
                    dayName: dayName,
                    startTime: start,
                    endTime: end,
                    room: room,
                    type: type,
                    enabled: enabled,
                    weekType: weekType
                )
                parsedEvents.append(ev)
            }
        }
        
        return (parsedEvents, enrolledMap, [])
    }
    
    /// Fetches direct calendar export from CAU UnivIS URL
    public func fetchUnivISCalendar(urlStr: String) async throws -> [ScheduleEvent] {
        guard let url = URL(string: urlStr) else { throw URLError(.badURL) }
        let (data, _) = try await URLSession.shared.data(from: url)
        guard let text = String(data: data, encoding: .utf8) ?? String(data: data, encoding: .isoLatin1) else {
            throw URLError(.cannotDecodeContentData)
        }
        return UnivISParser.parseICS(text)
    }
    
    /// Unenrolls a course on the local UNIBODY Core server and strictly verifies DOM cancellation
    public func postUnenroll(serverURL: String, courseId: String, force: Bool = false) async -> (success: Bool, message: String) {
        guard let url = URL(string: "\(serverURL)/api/course/unenroll") else {
            return (false, "Ungültige Server-URL.")
        }
        var req = URLRequest(url: url)
        req.httpMethod = "POST"
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        let payload: [String: Any] = ["course_id": courseId, "force": force]
        req.httpBody = try? JSONSerialization.data(withJSONObject: payload)
        req.timeoutInterval = 45.0
        do {
            let (data, response) = try await URLSession.shared.data(for: req)
            guard (response as? HTTPURLResponse)?.statusCode == 200 else {
                return (false, "Server antwortete mit Fehler.")
            }
            if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
                let ok = json["ok"] as? Bool ?? false
                let verified = json["unenroll_verified"] as? Bool ?? false
                let msg = json["message"] as? String ?? ""
                if ok && verified {
                    return (true, msg.isEmpty ? "Erfolgreich ausgetragen und im LMS verifiziert." : msg)
                } else {
                    return (false, msg.isEmpty ? "Austragung konnte im Browser nicht verifiziert werden." : msg)
                }
            }
            return (false, "Ungültige Server-Rückmeldung.")
        } catch {
            return (false, "Verbindungsfehler: \(error.localizedDescription)")
        }
    }
    
    public func postUnenroll(serverURL: String, courseId: String) async -> Bool {
        let (success, _) = await postUnenroll(serverURL: serverURL, courseId: courseId, force: false)
        return success
    }
}
