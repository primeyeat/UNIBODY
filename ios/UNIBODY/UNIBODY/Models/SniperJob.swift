import Foundation

public struct SniperJob: Identifiable, Codable, Hashable {
    public let id: String
    public let courseId: String
    public let title: String
    public let platformHost: String
    public let mode: String // "sniper" or "priority"
    public var status: String // "idle", "armed", "running", "completed", "failed"
    public var targetTime: String // ISO 8601 string
    public var priorities: [ExerciseGroup]
    public var enrolledGroup: ExerciseGroup?
    public var rankWon: Int?
    public var resultMessage: String?
    public var completedAt: String?
    
    public enum CodingKeys: String, CodingKey {
        case id = "job_id"
        case courseId = "course_id"
        case title
        case platformHost = "platform_host"
        case mode
        case status
        case targetTime = "target_time"
        case priorities
        case enrolledGroup = "enrolled_group"
        case rankWon = "rank_won"
        case resultMessage = "result_message"
        case completedAt = "completed_at"
    }
    
    public init(
        id: String = UUID().uuidString,
        courseId: String,
        title: String,
        platformHost: String = "lms.uni-kiel.de",
        mode: String = "sniper",
        status: String = "armed",
        targetTime: String = "2026-10-21T12:00:00",
        priorities: [ExerciseGroup] = [],
        enrolledGroup: ExerciseGroup? = nil,
        rankWon: Int? = nil,
        resultMessage: String? = nil,
        completedAt: String? = nil
    ) {
        self.id = id
        self.courseId = courseId
        self.title = title
        self.platformHost = platformHost
        self.mode = mode
        self.status = status
        self.targetTime = targetTime
        self.priorities = priorities
        self.enrolledGroup = enrolledGroup
        self.rankWon = rankWon
        self.resultMessage = resultMessage
        self.completedAt = completedAt
    }
}
