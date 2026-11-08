import SwiftUI

public struct ContentView: View {
    @StateObject private var appState = AppState()
    @ObservedObject private var mailService = CAUMailService.shared
    
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
            
            MaterialsFinderView()
                .tabItem {
                    Label("Materialien", systemImage: "folder.fill")
                }
            
            CAUMailView()
                .tabItem {
                    Label("Uni-Mail", systemImage: "envelope.fill")
                }
                .badge(mailService.unreadCount)
            
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
