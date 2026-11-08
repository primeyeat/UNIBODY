import Foundation
import Combine

public struct OnlineBookingResult: Sendable {
    public let courseId: String
    public let courseTitle: String
    public let groupId: String
    public let groupName: String
    public let day: Int
    public let dayName: String
    public let startTime: String
    public let endTime: String
    public let room: String
    public let weekType: String
    public let platform: String
}

@MainActor
public class CAUOnlineAccountFetcher: ObservableObject {
    public static let shared = CAUOnlineAccountFetcher()
    
    @Published public var isFetching: Bool = false
    @Published public var progressStatus: String = ""
    @Published public var lastFetchResult: String? = nil
    
    private let session: URLSession
    
    public init() {
        let config = URLSessionConfiguration.default
        config.httpCookieAcceptPolicy = .always
        config.httpShouldSetCookies = true
        config.httpCookieStorage = HTTPCookieStorage.shared
        config.timeoutIntervalForRequest = 8.0
        self.session = URLSession(configuration: config)
    }
    
    /// High-speed parallel Moodle ChoiceGroup scanner (~0.3-0.5s total)
    /// Logs into elearn.informatik.uni-kiel.de once and fetches all Moodle choicegroup pages concurrently.
    public func fetchMoodleBookingsParallel(
        username: String,
        password: String,
        knownCourses: [Course]
    ) async -> [OnlineBookingResult] {
        let trimmedUser = username.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedUser.isEmpty, !password.isEmpty else { return [] }
        
        let moodleCourses = knownCourses.filter {
            $0.platformId.contains("moodle") || $0.platformHost.contains("elearn.informatik")
        }
        guard !moodleCourses.isEmpty else { return [] }
        
        // 1. Authenticate Moodle session
        let isAuthed = await authenticateMoodle(username: trimmedUser, password: password)
        guard isAuthed else { return [] }
        
        // 2. Also kick off background sync of EWInf Übung 1..20 PDFs (#module-29808)
        Task {
            await CourseMaterialsService.shared.syncEWInfExercisesFromMoodle(username: trimmedUser, password: password)
        }
        
        // 3. Fetch all Moodle ChoiceGroup pages in parallel
        let currentSession = self.session
        return await withTaskGroup(of: OnlineBookingResult?.self) { group in
            for course in moodleCourses {
                group.addTask {
                    await Self.scanSingleMoodleChoiceGroup(session: currentSession, course: course)
                }
            }
            var results: [OnlineBookingResult] = []
            for await res in group {
                if let valid = res {
                    results.append(valid)
                }
            }
            return results
        }
    }
    
    private func authenticateMoodle(username: String, password: String) async -> Bool {
        guard let loginURL = URL(string: "https://elearn.informatik.uni-kiel.de/login/index.php") else { return false }
        do {
            var req = URLRequest(url: loginURL)
            req.timeoutInterval = 6.0
            req.setValue("Mozilla/5.0 (iPhone; CPU iPhone OS 27_0 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Mobile/15E148 UNIBODY-iOS", forHTTPHeaderField: "User-Agent")
            
            let (data, _) = try await session.data(for: req)
            guard let html = String(data: data, encoding: .utf8) ?? String(data: data, encoding: .isoLatin1) else {
                return false
            }
            
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
            postReq.timeoutInterval = 8.0
            postReq.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
            postReq.setValue("https://elearn.informatik.uni-kiel.de/login/index.php", forHTTPHeaderField: "Referer")
            
            var allowed = CharacterSet.alphanumerics
            allowed.insert(charactersIn: "-._~")
            let encUser = username.addingPercentEncoding(withAllowedCharacters: allowed) ?? username
            let encPass = password.addingPercentEncoding(withAllowedCharacters: allowed) ?? password
            let encToken = loginToken.addingPercentEncoding(withAllowedCharacters: allowed) ?? loginToken
            
            let postBody = "anchor=&logintoken=\(encToken)&username=\(encUser)&password=\(encPass)"
            postReq.httpBody = postBody.data(using: .utf8)
            
            let (authData, _) = try await session.data(for: postReq)
            if let authHtml = String(data: authData, encoding: .utf8) ?? String(data: authData, encoding: .isoLatin1) {
                return authHtml.contains("/login/logout.php") || !authHtml.contains("name=\"logintoken\"")
            }
        } catch {
            print("Moodle parallel auth error: \(error.localizedDescription)")
        }
        return false
    }
    
    private static func scanSingleMoodleChoiceGroup(session: URLSession, course: Course) async -> OnlineBookingResult? {
        guard let url = URL(string: course.url) else { return nil }
        do {
            var req = URLRequest(url: url)
            req.timeoutInterval = 6.0
            req.setValue("Mozilla/5.0 (iPhone; CPU iPhone OS 27_0 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Mobile/15E148 UNIBODY-iOS", forHTTPHeaderField: "User-Agent")
            
            let (data, _) = try await session.data(for: req)
            guard let html = String(data: data, encoding: .utf8) ?? String(data: data, encoding: .isoLatin1) else {
                return nil
            }
            
            // Find checked radio input in Moodle choicegroup table
            let radioPattern = #"<input[^>]*type=["']radio["'][^>]*checked[^>]*>|<input[^>]*checked[^>]*type=["']radio["'][^>]*>"#
            guard let radioRegex = try? NSRegularExpression(pattern: radioPattern, options: [.caseInsensitive]) else {
                return nil
            }
            let nsHtml = html as NSString
            guard let radioMatch = radioRegex.firstMatch(in: html, options: [], range: NSRange(location: 0, length: nsHtml.length)) else {
                return nil
            }
            
            let radioTag = nsHtml.substring(with: radioMatch.range)
            var labelText = ""
            
            // Extract id="..." of the checked radio and find <label for="id">
            if let idRegex = try? NSRegularExpression(pattern: #"id=["']([^"']+)["']"#, options: [.caseInsensitive]),
               let idMatch = idRegex.firstMatch(in: radioTag, options: [], range: NSRange(location: 0, length: (radioTag as NSString).length)),
               idMatch.numberOfRanges >= 2 {
                let inputId = (radioTag as NSString).substring(with: idMatch.range(at: 1))
                let escapedId = NSRegularExpression.escapedPattern(for: inputId)
                let lblPattern = "<label[^>]*for=[\"']\(escapedId)[\"'][^>]*>([\\s\\S]*?)</label>"
                if let lblRegex = try? NSRegularExpression(pattern: lblPattern, options: [.caseInsensitive]),
                   let lblMatch = lblRegex.firstMatch(in: html, options: [], range: NSRange(location: 0, length: nsHtml.length)),
                   lblMatch.numberOfRanges >= 2 {
                    let rawLbl = nsHtml.substring(with: lblMatch.range(at: 1))
                    labelText = rawLbl
                        .replacingOccurrences(of: "<[^>]+>", with: " ", options: .regularExpression)
                        .replacingOccurrences(of: "\\s+", with: " ", options: .regularExpression)
                        .trimmingCharacters(in: .whitespacesAndNewlines)
                }
            }
            
            // Fallback: inspect 500 chars after the checked radio input
            if labelText.isEmpty {
                let startIdx = min(nsHtml.length, radioMatch.range.location + radioMatch.range.length)
                let len = min(600, nsHtml.length - startIdx)
                let tail = nsHtml.substring(with: NSRange(location: startIdx, length: len))
                if let lblRegex = try? NSRegularExpression(pattern: #"<label[^>]*>([\s\S]*?)</label>"#, options: [.caseInsensitive]),
                   let lblMatch = lblRegex.firstMatch(in: tail, options: [], range: NSRange(location: 0, length: (tail as NSString).length)),
                   lblMatch.numberOfRanges >= 2 {
                    let rawLbl = (tail as NSString).substring(with: lblMatch.range(at: 1))
                    labelText = rawLbl
                        .replacingOccurrences(of: "<[^>]+>", with: " ", options: .regularExpression)
                        .replacingOccurrences(of: "\\s+", with: " ", options: .regularExpression)
                        .trimmingCharacters(in: .whitespacesAndNewlines)
                }
            }
            
            guard !labelText.isEmpty else { return nil }
            
            // Match group number (e.g., "Übungsgruppe 3" -> 3, "Übung 2 online" -> 2)
            let numPattern = #"(?:übungsgruppe|gruppe|gr\.?|übung|tutorium)\s*0*(\d+)"#
            if let numRegex = try? NSRegularExpression(pattern: numPattern, options: [.caseInsensitive]),
               let numMatch = numRegex.firstMatch(in: labelText, options: [], range: NSRange(location: 0, length: (labelText as NSString).length)),
               numMatch.numberOfRanges >= 2 {
                let numStr = (labelText as NSString).substring(with: numMatch.range(at: 1))
                if let gNum = Int(numStr) {
                    // Find matching ExerciseGroup in course.groups
                    for cg in course.groups {
                        if let cgMatch = numRegex.firstMatch(in: cg.name, options: [], range: NSRange(location: 0, length: (cg.name as NSString).length)),
                           cgMatch.numberOfRanges >= 2 {
                            let cgNumStr = (cg.name as NSString).substring(with: cgMatch.range(at: 1))
                            if Int(cgNumStr) == gNum {
                                return OnlineBookingResult(
                                    courseId: course.courseId,
                                    courseTitle: course.title,
                                    groupId: cg.groupId,
                                    groupName: cg.name,
                                    day: cg.day,
                                    dayName: cg.dayName,
                                    startTime: cg.startTime,
                                    endTime: cg.endTime,
                                    room: cg.room,
                                    weekType: cg.weekType,
                                    platform: "Moodle"
                                )
                            }
                        }
                    }
                    if gNum >= 1 && gNum <= course.groups.count {
                        let cg = course.groups[gNum - 1]
                        return OnlineBookingResult(
                            courseId: course.courseId,
                            courseTitle: course.title,
                            groupId: cg.groupId,
                            groupName: cg.name,
                            day: cg.day,
                            dayName: cg.dayName,
                            startTime: cg.startTime,
                            endTime: cg.endTime,
                            room: cg.room,
                            weekType: cg.weekType,
                            platform: "Moodle"
                        )
                    }
                }
            }
        } catch {
            return nil
        }
        return nil
    }
}
