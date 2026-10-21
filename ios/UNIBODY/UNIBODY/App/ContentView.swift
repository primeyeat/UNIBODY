import SwiftUI

public struct ContentView: View {
    @StateObject private var appState = AppState()
    
    public init() {}
    
    public var body: some View {
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
        .environmentObject(appState)
        .tint(AeroTheme.skyBlue)
        .preferredColorScheme(appState.isDarkMode ? .dark : .light)
        .sheet(isPresented: $appState.showClaireEasterEgg) {
            ClaireEasterEggModalView()
                .presentationDetents([.fraction(0.68), .large])
        }
        .sheet(isPresented: $appState.showLiveDeepSyncSheet) {
            LiveDeepSyncSheet()
                .environmentObject(appState)
                .presentationDetents([.fraction(0.88), .large])
        }
    }
}
