import SwiftUI

public struct ScheduleView: View {
    @EnvironmentObject var appState: AppState
    @State private var selectedDay: Int = 0
    @State private var showAddEventSheet = false
    @State private var showICSImportSheet = false
    
    private let dayNames = ["Montag", "Dienstag", "Mittwoch", "Donnerstag", "Freitag"]
    private let dayShort = ["Mo", "Di", "Mi", "Do", "Fr"]
    
    public var body: some View {
        NavigationStack {
            ZStack {
                // Background ambient Frutiger Aero backdrop (hardware rasterized)
                ZStack {
                    LinearGradient(
                        colors: [
                            Color(red: 0.02, green: 0.08, blue: 0.16),
                            Color(red: 0.01, green: 0.04, blue: 0.1)
                        ],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                    
                    // Ambient lighting orbs
                    Circle()
                        .fill(AeroTheme.skyBlue.opacity(0.18))
                        .frame(width: 320, height: 320)
                        .blur(radius: 80)
                        .offset(x: -120, y: -200)
                    
                    Circle()
                        .fill(AeroTheme.auroraGreen.opacity(0.15))
                        .frame(width: 280, height: 280)
                        .blur(radius: 70)
                        .offset(x: 140, y: 150)
                }
                .drawingGroup()
                .ignoresSafeArea()
                
                VStack(spacing: 0) {
                    // Day Selector Tabs
                    HStack(spacing: 8) {
                        ForEach(0..<5) { idx in
                            Button {
                                withAnimation(.spring(response: 0.35, dampingFraction: 0.75)) {
                                    selectedDay = idx
                                }
                            } label: {
                                VStack(spacing: 4) {
                                    Text(dayShort[idx])
                                        .font(.system(.subheadline, design: .rounded).weight(.bold))
                                    
                                    let count = appState.schedule.filter { $0.day == idx && $0.enabled }.count
                                    Circle()
                                        .fill(selectedDay == idx ? Color.white : (count > 0 ? AeroTheme.skyBlue : Color.clear))
                                        .frame(width: 5, height: 5)
                                }
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 10)
                                .background(
                                    ZStack {
                                        if selectedDay == idx {
                                            RoundedRectangle(cornerRadius: 12, style: .continuous)
                                                .fill(AeroTheme.oceanGradient)
                                                .shadow(color: AeroTheme.skyBlue.opacity(0.4), radius: 6, x: 0, y: 3)
                                        } else {
                                            RoundedRectangle(cornerRadius: 12, style: .continuous)
                                                .fill(Color.white.opacity(0.06))
                                        }
                                    }
                                )
                                .foregroundColor(selectedDay == idx ? .white : .secondary)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.horizontal)
                    .padding(.vertical, 10)
                    
                    // Swipeable Page TabView between Days
                    TabView(selection: $selectedDay) {
                        ForEach(0..<5, id: \.self) { day in
                            DaySchedulePageView(day: day, showICSImportSheet: $showICSImportSheet)
                                .tag(day)
                        }
                    }
                    .tabViewStyle(.page(indexDisplayMode: .never))
                    .animation(.spring(response: 0.35, dampingFraction: 0.75), value: selectedDay)
                    .onChange(of: selectedDay) { _ in
                        #if canImport(UIKit)
                        UIImpactFeedbackGenerator(style: .light).impactOccurred()
                        #endif
                    }
                }
            }
            .navigationTitle("Wochenplan")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button {
                        Task { await appState.syncWithLocalServer() }
                    } label: {
                        if appState.isSyncing {
                            ProgressView()
                                .tint(AeroTheme.skyBlue)
                        } else {
                            Image(systemName: "arrow.triangle.2.circlepath")
                                .foregroundColor(AeroTheme.skyBlue)
                        }
                    }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    HStack(spacing: 12) {
                        Button {
                            withAnimation {
                                appState.toggleDarkMode()
                            }
                        } label: {
                            Image(systemName: appState.isDarkMode ? "sun.max.fill" : "moon.stars.fill")
                                .font(.title3)
                                .foregroundColor(AeroTheme.skyBlue)
                        }
                        
                        Button {
                            showAddEventSheet = true
                        } label: {
                            Image(systemName: "plus.circle.fill")
                                .font(.title3)
                                .foregroundColor(AeroTheme.skyBlue)
                        }
                    }
                }
            }
            .sheet(isPresented: $showICSImportSheet) {
                UnivISImportView()
            }
            .sheet(isPresented: $showAddEventSheet) {
                AddEventSheet(selectedDay: selectedDay)
            }
        }
    }
}

// MARK: - Day Page View for Swipe Navigation
private struct DaySchedulePageView: View {
    let day: Int
    @Binding var showICSImportSheet: Bool
    @EnvironmentObject var appState: AppState
    
    private let dayNames = ["Montag", "Dienstag", "Mittwoch", "Donnerstag", "Freitag"]
    
    private var eventsForDay: [ScheduleEvent] {
        appState.schedule
            .filter { $0.day == day }
            .sorted { $0.startMinutes < $1.startMinutes }
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // Selected Day Title & Event Count
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(dayNames[day])
                        .font(.system(.title2, design: .rounded).weight(.bold))
                        .foregroundColor(.white)
                    Text("\(eventsForDay.count) Termine eingetragen")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                Spacer()
                
                Button {
                    showICSImportSheet = true
                } label: {
                    Label("UnivIS ICS", systemImage: "calendar.badge.plus")
                        .font(.caption.weight(.semibold))
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .background(Capsule().fill(AeroTheme.skyBlue.opacity(0.2)))
                        .foregroundColor(AeroTheme.skyBlue)
                }
            }
            .padding(.horizontal)
            .padding(.top, 6)
            .padding(.bottom, 12)
            
            // Events List
            if eventsForDay.isEmpty {
                Spacer()
                VStack(spacing: 12) {
                    Image(systemName: "calendar.badge.clock")
                        .font(.system(size: 48))
                        .foregroundColor(AeroTheme.skyBlue.opacity(0.6))
                    Text("Keine Termine am \(dayNames[day])")
                        .font(.headline)
                        .foregroundColor(.white)
                    Text("Importiere deinen UnivIS-Plan oder wähle Übungsgruppen aus dem Katalog.")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 32)
                }
                Spacer()
            } else {
                ScrollView {
                    LazyVStack(spacing: 12) {
                        ForEach(eventsForDay) { ev in
                            ScheduleEventCard(
                                event: ev,
                                onToggle: {
                                    appState.toggleEvent(id: ev.id)
                                },
                                onDelete: {
                                    appState.deleteEvent(id: ev.id)
                                }
                            )
                        }
                    }
                    .padding(.horizontal)
                    .padding(.bottom, 24)
                }
                .refreshable {
                    await appState.syncWithLocalServer()
                }
            }
        }
    }
}
