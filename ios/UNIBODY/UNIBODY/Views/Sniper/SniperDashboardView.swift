import SwiftUI

public struct SniperDashboardView: View {
    @EnvironmentObject var appState: AppState
    
    public var body: some View {
        NavigationStack {
            ZStack {
                AeroBackgroundView()
                
                ScrollView {
                    VStack(alignment: .leading, spacing: 18) {
                        // Hero Status Card
                        VStack(alignment: .leading, spacing: 10) {
                            HStack {
                                Image(systemName: "cross.circle.fill")
                                    .font(.title2)
                                    .foregroundColor(AeroTheme.emerald)
                                Text("UNIBODY-Sniper")
                                    .font(.system(.title3, design: .rounded).weight(.bold))
                                    .foregroundColor(.primary)
                                Spacer()
                                AeroBadge("\(appState.jobs.count) Aktiv", color: AeroTheme.emerald)
                            }
                            
                            Text("Überwacht die Freischaltung der Übungsgruppen auf OpenOlat (lms.uni-kiel.de) und Moodle (elearn.informatik.uni-kiel.de) und snipet deine Wunschübung sekundengenau.")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        .padding(18)
                        .frutigerGlass(cornerRadius: 18)
                        
                        // Active Jobs List
                        if appState.jobs.isEmpty {
                            VStack(spacing: 12) {
                                Image(systemName: "scope")
                                    .font(.system(size: 44))
                                    .foregroundColor(AeroTheme.skyBlue.opacity(0.6))
                                Text("Keine Sniper-Jobs scharfgestellt")
                                    .font(.headline)
                                    .foregroundColor(.white)
                                Text("Wähle in der Modul-Übersicht ein Fach aus und klicke auf 'Sniper scharfstellen'.")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                    .multilineTextAlignment(.center)
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 40)
                        } else {
                            Text("Scharfgestellte Jobs")
                                .font(.system(.headline, design: .rounded).weight(.bold))
                                .foregroundColor(.white)
                                .padding(.horizontal, 4)
                            
                            LazyVStack(spacing: 14) {
                                ForEach(appState.jobs) { job in
                                    SniperJobCard(job: job)
                                }
                            }
                        }
                    }
                    .padding()
                }
            }
            .navigationTitle("Sniper")
        }
    }
}

private struct SniperJobCard: View {
    let job: SniperJob
    
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    HStack(spacing: 6) {
                        AeroBadge(job.platformHost)
                        AeroBadge(job.status.uppercased(), color: job.status == "completed" ? AeroTheme.emerald : AeroTheme.solarOrange)
                    }
                    Text(job.title)
                        .font(.system(.subheadline, design: .rounded).weight(.bold))
                        .foregroundColor(.white)
                        .padding(.top, 2)
                }
                Spacer()
            }
            
            Divider()
                .background(Color.white.opacity(0.1))
            
            HStack {
                Label("Startet: \(job.targetTime.replacingOccurrences(of: "T", with: " um "))", systemImage: "clock")
                    .font(.caption)
                    .foregroundColor(.secondary)
                Spacer()
                Text("\(job.priorities.count) Prioritäten")
                    .font(.caption.weight(.semibold))
                    .foregroundColor(AeroTheme.skyBlue)
            }
            
            if let won = job.enrolledGroup {
                HStack(spacing: 6) {
                    Image(systemName: "checkmark.seal.fill")
                        .foregroundColor(AeroTheme.emerald)
                    Text("Erfolgreich erhalten: \(won.name)")
                        .font(.caption.weight(.bold))
                        .foregroundColor(AeroTheme.emerald)
                }
                .padding(8)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(RoundedRectangle(cornerRadius: 10).fill(AeroTheme.emerald.opacity(0.12)))
            }
        }
        .padding(14)
        .frutigerGlass(cornerRadius: 16)
    }
}
