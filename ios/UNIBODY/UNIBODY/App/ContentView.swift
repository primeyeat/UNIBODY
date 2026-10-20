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
        .preferredColorScheme(.dark)
    }
}
