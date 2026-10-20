import Foundation

public struct Course: Identifiable, Codable, Hashable {
    public var id: String { courseId }
    public let courseId: String
    public let univisId: String
    public let olatRepoId: String
    public let title: String
    public let lecturer: String
    public let platformId: String
    public let platformHost: String
    public let platformBadge: String
    public let url: String
    public let enrollmentMode: String // "sniper" or "priority"
    public let enrollmentOpensAt: String
    public var groups: [ExerciseGroup]
    public var enrolledGroupId: String?
    
    public enum CodingKeys: String, CodingKey {
        case courseId = "course_id"
        case univisId = "univis_id"
        case olatRepoId = "olat_repo_id"
        case title
        case lecturer
        case platformId = "platform_id"
        case platformHost = "platform_host"
        case platformBadge = "platform_badge"
        case url
        case enrollmentMode = "enrollment_mode"
        case enrollmentOpensAt = "enrollment_opens_at"
        case groups
        case enrolledGroupId = "enrolled_group_id"
    }
    
    public init(
        courseId: String,
        univisId: String = "",
        olatRepoId: String = "",
        title: String,
        lecturer: String = "",
        platformId: String = "openolat",
        platformHost: String = "lms.uni-kiel.de",
        platformBadge: String = "🏛️ lms.uni-kiel.de",
        url: String = "https://lms.uni-kiel.de",
        enrollmentMode: String = "sniper",
        enrollmentOpensAt: String = "2026-10-21T12:00:00",
        groups: [ExerciseGroup] = [],
        enrolledGroupId: String? = nil
    ) {
        self.courseId = courseId
        self.univisId = univisId
        self.olatRepoId = olatRepoId
        self.title = title
        self.lecturer = lecturer
        self.platformId = platformId
        self.platformHost = platformHost
        self.platformBadge = platformBadge
        self.url = url
        self.enrollmentMode = enrollmentMode
        self.enrollmentOpensAt = enrollmentOpensAt
        self.groups = groups
        self.enrolledGroupId = enrolledGroupId
    }
}
