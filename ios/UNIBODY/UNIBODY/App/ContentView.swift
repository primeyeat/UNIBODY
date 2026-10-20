import SwiftUI

public struct ContentView: View {
    @StateObject private var appState = AppState()
    
    public init() {}
    
    public var body: some View {
        ZStack(alignment: .top) {
            TabView {
                ScheduleView()
                    .tabItem {
                        Label("Wochenplan", systemImage: "calendar")
                    }
                
                CoursesView()
                    .tabItem {
                        Label("Module", systemImage: "books.vertical.fill")
                    }
                
                SniperDashboardView()
                    .tabItem {
                        Label("Sniper", systemImage: "cross.circle.fill")
                    }
                
                SettingsLoginView()
                    .tabItem {
                        Label("Login & Tresor", systemImage: "key.fill")
                    }
            }
            
            // Floating Dynamic Island Campus Map & Room Navigator
            if let event = appState.activeNavEvent ?? (appState.isDynamicIslandActive ? appState.nextUpcomingEvent : nil) {
                DynamicCampusIslandView(event: event) {
                    appState.closeCampusNavigation()
                }
                .zIndex(999)
                .transition(.asymmetric(
                    insertion: .move(edge: .top).combined(with: .opacity),
                    removal: .move(edge: .top).combined(with: .opacity)
                ))
            }
        }
        .environmentObject(appState)
        .tint(AeroTheme.skyBlue)
        .preferredColorScheme(appState.isDarkMode ? .dark : .light)
        .sheet(isPresented: $appState.showClaireEasterEgg) {
            ClaireEasterEggModalView()
                .presentationDetents([.fraction(0.68), .large])
        }
    }
}
