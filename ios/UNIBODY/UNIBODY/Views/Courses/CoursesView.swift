import SwiftUI

public struct CoursesView: View {
    @EnvironmentObject var appState: AppState
    
    public var body: some View {
        NavigationStack {
            ZStack {
                // Background
                LinearGradient(
                    colors: [
                        Color(red: 0.02, green: 0.08, blue: 0.16),
                        Color(red: 0.01, green: 0.04, blue: 0.1)
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )
                .ignoresSafeArea()
                
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
                        
                        if course.enrollmentMode == "sniper" {
                            AeroBadge("Sniper FCFS", color: AeroTheme.solarOrange)
                        } else {
                            AeroBadge("Prioritäten", color: Color.purple)
                        }
                    }
                    
                    Text(course.title)
                        .font(.system(.headline, design: .rounded).weight(.bold))
                        .foregroundColor(.white)
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
        .padding(16)
        .frutigerGlass(cornerRadius: 18)
    }
}
