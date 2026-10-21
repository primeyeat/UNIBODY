import SwiftUI

public struct CoursesView: View {
    @EnvironmentObject var appState: AppState
    
    public var body: some View {
        NavigationStack {
            ZStack {
                AeroBackgroundView()
                
                ScrollView {
                    LazyVStack(spacing: 16) {
                        // UNIBODY Deep-Sync Hero Card
                        Button {
                            Task {
                                await appState.performDeepSync()
                            }
                        } label: {
                            HStack(spacing: 14) {
                                ZStack {
                                    Circle()
                                        .fill(AeroTheme.oceanGradient)
                                        .frame(width: 44, height: 44)
                                    if appState.isDeepSyncing {
                                        ProgressView()
                                            .tint(.white)
                                    } else {
                                        Image(systemName: "arrow.triangle.2.circlepath")
                                            .font(.system(size: 20, weight: .bold))
                                            .foregroundColor(.white)
                                    }
                                }
                                
                                VStack(alignment: .leading, spacing: 3) {
                                    HStack {
                                        Text("UNIBODY Deep-Sync")
                                            .font(.system(.subheadline, design: .rounded).weight(.bold))
                                            .foregroundColor(.white)
                                        Spacer()
                                        AeroBadge("OpenOlat & Moodle", color: AeroTheme.emerald)
                                    }
                                    
                                    Text(appState.isDeepSyncing ? "Synchronisiere mit CAU-Portalen..." : "Gebuchte Gruppen live abfragen & im Stundenplan blockieren")
                                        .font(.caption2)
                                        .foregroundColor(.white.opacity(0.8))
                                        .lineLimit(1)
                                }
                            }
                            .padding(14)
                            .frutigerGlass(cornerRadius: 16)
                        }
                        .buttonStyle(.plain)
                        .disabled(appState.isDeepSyncing)
                        
                        if let msg = appState.deepSyncMessage {
                            HStack(spacing: 6) {
                                Image(systemName: "checkmark.seal.fill")
                                    .font(.caption2)
                                    .foregroundColor(AeroTheme.emerald)
                                Text(msg)
                                    .font(.caption2)
                                    .foregroundColor(.white.opacity(0.9))
                                    .lineLimit(1)
                                Spacer()
                            }
                            .padding(.horizontal, 12)
                            .padding(.vertical, 6)
                            .background(Color.white.opacity(0.06))
                            .clipShape(Capsule())
                        }
                        
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
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        Task {
                            await appState.performDeepSync()
                        }
                    } label: {
                        if appState.isDeepSyncing {
                            ProgressView()
                                .tint(AeroTheme.skyBlue)
                        } else {
                            Image(systemName: "arrow.triangle.2.circlepath")
                                .foregroundColor(AeroTheme.skyBlue)
                        }
                    }
                }
            }
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
