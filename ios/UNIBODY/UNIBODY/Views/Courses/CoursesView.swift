import SwiftUI

public struct CoursesView: View {
    @EnvironmentObject var appState: AppState
    
    public var body: some View {
        NavigationStack {
            ZStack {
                AeroBackgroundView()
                
                ScrollView {
                    LazyVStack(spacing: 16) {
                        ForEach(appState.courses) { course in
                            NavigationLink {
                                CourseDetailView(course: course)
                            } label: {
                                CourseCard(course: course)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding()
                }
            }
            .navigationTitle("Module & Übungen")
        }
    }
}

private struct CourseCard: View {
    @EnvironmentObject var appState: AppState
    let course: Course
    
    private var enrolledGroup: ExerciseGroup? {
        if let gid = appState.enrolledGroups[course.courseId] {
            return course.groups.first(where: { $0.groupId == gid })
        }
        return nil
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 6) {
                        AeroBadge(course.platformHost, icon: course.platformId == "openolat" ? "building.columns.fill" : "bolt.fill")
                        
                        if course.isLectureOnly {
                            AeroBadge("Reine Vorlesung", color: AeroTheme.skyBlue)
                        } else if course.enrollmentMode == "sniper" {
                            AeroBadge("Sniper FCFS", color: AeroTheme.solarOrange)
                        } else {
                            AeroBadge("Prioritäten", color: Color.purple)
                        }
                    }
                    
                    Text(course.title)
                        .font(.system(.headline, design: .rounded).weight(.bold))
                        .foregroundColor(.primary)
                        .lineLimit(2)
                        .padding(.top, 2)
                    
                    if !course.lecturer.isEmpty {
                        Text(course.lecturer)
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                
                Spacer()
                
                Image(systemName: "chevron.right")
                    .foregroundColor(AeroTheme.skyBlue.opacity(0.8))
                    .font(.footnote.weight(.bold))
                    .padding(.top, 4)
            }
            
            Divider()
                .background(Color.white.opacity(0.1))
            
            HStack {
                if course.isLectureOnly {
                    HStack(spacing: 5) {
                        Image(systemName: "books.vertical.fill")
                            .font(.caption2)
                        Text("Reine Vorlesung (Keine Übungsgruppen)")
                            .font(.caption.weight(.medium))
                    }
                    .foregroundColor(.secondary)
                    
                    Spacer()
                    
                    Text("Freie Belegung")
                        .font(.caption.weight(.bold))
                        .foregroundColor(AeroTheme.skyBlue)
                } else {
                    HStack(spacing: 4) {
                        Image(systemName: "person.2")
                            .font(.caption2)
                        Text("\(course.groups.count) Übungsgruppen")
                            .font(.caption.weight(.medium))
                    }
                    .foregroundColor(.secondary)
                    
                    Spacer()
                    
                    if let enrolled = enrolledGroup {
                        HStack(spacing: 4) {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundColor(AeroTheme.emerald)
                            Text(enrolled.name)
                                .font(.caption.weight(.bold))
                                .foregroundColor(AeroTheme.emerald)
                                .lineLimit(1)
                        }
                    } else {
                        Text("Noch nicht belegt")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
            }
        }
        .padding(16)
        .frutigerGlass(cornerRadius: 18)
    }
}
