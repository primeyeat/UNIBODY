import SwiftUI

public struct SettingsLoginView: View {
    @ObservedObject private var reminderService = ReminderService.shared
    @EnvironmentObject var appState: AppState
    
    @State private var inputUsername: String = ""
    @State private var inputPassword: String = ""
    @State private var isPasswordVisible: Bool = false
    @State private var selectedPlatform: String = "unibody"
    @State private var autoFill: Bool = true
    @State private var autoSubmit: Bool = true
    @State private var showSaveSuccessBanner: Bool = false
    
    public init() {}
    
    public var body: some View {
        NavigationStack {
            ZStack {
                AeroBackgroundView()
                
                ScrollView {
                    VStack(alignment: .leading, spacing: 20) {
                        // Header Status Card
                        VStack(alignment: .leading, spacing: 8) {
                            HStack {
                                Image(systemName: appState.isVaultSaved ? "lock.shield.fill" : "lock.open.trianglebadge.exclamationmark.fill")
                                    .font(.title2)
                                    .foregroundColor(appState.isVaultSaved ? AeroTheme.emerald : AeroTheme.solarOrange)
                                Text("Uni-Login & Auto-Fill Tresor")
                                    .font(.system(.title3, design: .rounded).weight(.bold))
                                    .foregroundColor(.primary)
                                Spacer()
                                AeroBadge(
                                    appState.isVaultSaved ? "Aktiv" : "Nicht konfiguriert",
                                    color: appState.isVaultSaved ? AeroTheme.emerald : AeroTheme.solarOrange
                                )
                            }
                            
                            Text("Inoffizielles Studierenden-Tool (keine offizielle App der CAU Kiel). Hinterlege deine Studierenden-Kennung (stu-Nummer) lokal im Gerätetresor für lms.uni-kiel.de (OpenOlat) und elearn.informatik.uni-kiel.de (Moodle).")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        .padding(18)
                        .frutigerGlass(cornerRadius: 18)
                        
                        if showSaveSuccessBanner {
                            HStack(spacing: 8) {
                                Image(systemName: "checkmark.circle.fill")
                                    .foregroundColor(AeroTheme.emerald)
                                Text("Zugangsdaten sicher gespeichert & aktiv!")
                                    .font(.subheadline.weight(.semibold))
                                    .foregroundColor(AeroTheme.emerald)
                            }
                            .padding(12)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(RoundedRectangle(cornerRadius: 12).fill(AeroTheme.emerald.opacity(0.15)))
                            .transition(.move(edge: .top).combined(with: .opacity))
                        }
                        
                        // Credentials Form
                        VStack(alignment: .leading, spacing: 14) {
                            Text("Zugangsdaten")
                                .font(.system(.headline, design: .rounded).weight(.bold))
                                .foregroundColor(.primary)
                            
                            VStack(alignment: .leading, spacing: 6) {
                                Text("CAU-Kennung (z. B. stu123456)")
                                    .font(.caption.weight(.semibold))
                                    .foregroundColor(.secondary)
                                
                                HStack {
                                    Image(systemName: "person.fill")
                                        .foregroundColor(AeroTheme.skyBlue)
                                        .frame(width: 24)
                                    TextField("stu123456", text: $inputUsername)
                                        .textContentType(.username)
                                        .textInputAutocapitalization(.never)
                                        .autocorrectionDisabled()
                                        .foregroundColor(.primary)
                                }
                                .padding(12)
                                .background(RoundedRectangle(cornerRadius: 12).fill(Color.white.opacity(0.08)))
                                .overlay(RoundedRectangle(cornerRadius: 12).strokeBorder(Color.white.opacity(0.2), lineWidth: 1))
                            }
                            
                            VStack(alignment: .leading, spacing: 6) {
                                Text("Passwort")
                                    .font(.caption.weight(.semibold))
                                    .foregroundColor(.secondary)
                                
                                HStack {
                                    Image(systemName: "key.fill")
                                        .foregroundColor(AeroTheme.skyBlue)
                                        .frame(width: 24)
                                    if isPasswordVisible {
                                        TextField("Passwort", text: $inputPassword)
                                            .foregroundColor(.primary)
                                    } else {
                                        SecureField("Passwort", text: $inputPassword)
                                            .textContentType(.password)
                                            .foregroundColor(.primary)
                                    }
                                    Button {
                                        isPasswordVisible.toggle()
                                    } label: {
                                        Image(systemName: isPasswordVisible ? "eye.slash.fill" : "eye.fill")
                                            .foregroundColor(.secondary)
                                    }
                                    .accessibilityLabel(isPasswordVisible ? "Passwort verbergen" : "Passwort anzeigen")
                                }
                                .padding(12)
                                .background(RoundedRectangle(cornerRadius: 12).fill(Color.white.opacity(0.08)))
                                .overlay(RoundedRectangle(cornerRadius: 12).strokeBorder(Color.white.opacity(0.2), lineWidth: 1))
                            }
                            
                            // Platform selector
                            VStack(alignment: .leading, spacing: 6) {
                                Text("Standard-Plattform")
                                    .font(.caption.weight(.semibold))
                                    .foregroundColor(.secondary)
                                
                                Picker("Plattform", selection: $selectedPlatform) {
                                    Text("⚡ UNIBODY (Beide)").tag("unibody")
                                    Text("🏛️ lms.uni-kiel.de (OpenOlat)").tag("openolat")
                                    Text("💻 elearn.informatik.uni-kiel.de").tag("moodle")
                                }
                                .pickerStyle(.segmented)
                            }
                            
                            // Auto-Fill Toggles
                            Toggle(isOn: Binding(
                                get: { reminderService.isEnabled },
                                set: { newValue in Task { await reminderService.setEnabled(newValue) } }
                            )) {
                                VStack(alignment: .leading, spacing: 2) {
                                    Text("Erinnerungen")
                                        .font(.subheadline.weight(.semibold))
                                    Text(reminderService.statusText ?? "Mitteilung 24 und 2 Stunden vor Abgabefristen sowie zum Einschreibungsstart")
                                        .font(.caption2)
                                        .foregroundColor(.secondary)
                                }
                            }
                            .tint(AeroTheme.emerald)
                            
                            Toggle(isOn: $autoFill) {
                                VStack(alignment: .leading, spacing: 2) {
                                    Text("Automatisches Ausfüllen (Auto-Fill)")
                                        .font(.subheadline.weight(.semibold))
                                        .foregroundColor(.primary)
                                    Text("Trägt stu-Kennung & Passwort beim Aufruf automatisch ein")
                                        .font(.caption2)
                                        .foregroundColor(.secondary)
                                }
                            }
                            .tint(AeroTheme.skyBlue)
                            
                            Toggle(isOn: $autoSubmit) {
                                VStack(alignment: .leading, spacing: 2) {
                                    Text("1-Klick Auto-Submit")
                                        .font(.subheadline.weight(.semibold))
                                        .foregroundColor(.primary)
                                    Text("Meldet dich ohne manuellen Klick direkt an")
                                        .font(.caption2)
                                        .foregroundColor(.secondary)
                                }
                            }
                            .tint(AeroTheme.skyBlue)
                            
                            // Primary UNIBODY Deep-Sync Button
                            Button {
                                appState.saveCredentials(
                                    username: inputUsername,
                                    password: inputPassword,
                                    defaultPlatform: selectedPlatform,
                                    autoFill: autoFill,
                                    autoSubmit: autoSubmit
                                )
                                Task {
                                    await appState.performDeepSync()
                                }
                            } label: {
                                HStack {
                                    if appState.isDeepSyncing || appState.isSyncing {
                                        ProgressView()
                                            .tint(.white)
                                    } else {
                                        Image(systemName: "arrow.triangle.2.circlepath")
                                    }
                                    Text(appState.isDeepSyncing ? "UNIBODY Deep-Sync läuft..." : "UNIBODY Deep-Sync (OpenOlat & Moodle)")
                                }
                                .frame(maxWidth: .infinity)
                                .glossyButton(gradient: AeroTheme.oceanGradient, cornerRadius: 14)
                            }
                            .buttonStyle(.plain)
                            .disabled(inputUsername.trimmingCharacters(in: .whitespaces).isEmpty || appState.isDeepSyncing)
                            .padding(.top, 4)
                            
                            if let d = appState.lastSyncDate {
                                HStack(spacing: 4) {
                                    Image(systemName: "checkmark.circle.fill")
                                        .foregroundColor(AeroTheme.emerald)
                                    Text("Letzter Deep-Sync: \(d.formatted(date: .omitted, time: .shortened)) Uhr")
                                        .foregroundColor(.primary.opacity(0.85))
                                }
                                .font(.caption2)
                                .frame(maxWidth: .infinity, alignment: .center)
                                .padding(.top, 2)
                            }
                            
                            // Save Button
                            Button {
                                withAnimation {
                                    appState.saveCredentials(
                                        username: inputUsername,
                                        password: inputPassword,
                                        defaultPlatform: selectedPlatform,
                                        autoFill: autoFill,
                                        autoSubmit: autoSubmit
                                    )
                                    showSaveSuccessBanner = true
                                }
                                DispatchQueue.main.asyncAfter(deadline: .now() + 3.0) {
                                    withAnimation {
                                        showSaveSuccessBanner = false
                                    }
                                }
                            } label: {
                                HStack {
                                    Image(systemName: "checkmark.shield.fill")
                                    Text("Nur Zugangsdaten im Tresor sichern")
                                }
                                .font(.caption.weight(.semibold))
                                .foregroundColor(AeroTheme.skyBlue)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 4)
                            }
                            .buttonStyle(.plain)
                            .disabled(inputUsername.trimmingCharacters(in: .whitespaces).isEmpty)
                            
                            if appState.isVaultSaved {
                                Button(role: .destructive) {
                                    withAnimation {
                                        appState.clearCredentials()
                                        inputUsername = ""
                                        inputPassword = ""
                                    }
                                } label: {
                                    HStack {
                                        Image(systemName: "trash")
                                        Text("Gespeicherte Daten entfernen")
                                    }
                                    .font(.caption.weight(.semibold))
                                    .foregroundColor(AeroTheme.rubyRed)
                                    .frame(maxWidth: .infinity)
                                    .padding(.top, 4)
                                }
                            }
                        }
                        .padding(18)
                        .frutigerGlass(cornerRadius: 18)
                        
                        OptimizerPreferencesCard()
                        
                        // Appearance & Theme Mode Section
                        VStack(alignment: .leading, spacing: 12) {
                            HStack {
                                Image(systemName: appState.isDarkMode ? "moon.stars.fill" : "sun.max.fill")
                                    .font(.title3)
                                    .foregroundColor(appState.isDarkMode ? AeroTheme.skyBlue : AeroTheme.solarOrange)
                                Text("Erscheinungsbild")
                                    .font(.system(.headline, design: .rounded).weight(.bold))
                                    .foregroundColor(.primary)
                                Spacer()
                                AeroBadge(
                                    appState.isDarkMode ? "🌙 Dark Mode" : "☀️ Daylight Mode",
                                    color: appState.isDarkMode ? AeroTheme.skyBlue : AeroTheme.solarOrange
                                )
                            }
                            
                            Text("Wähle deinen Design-Stil (z. B. komplett matt & minimalistisch) sowie Daylight- oder Dark-Mode.")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            
                            VStack(alignment: .leading, spacing: 6) {
                                Text("Design-Stil")
                                    .font(.caption.weight(.semibold))
                                    .foregroundColor(.secondary)
                                
                                Picker("Design-Stil", selection: $appState.designTheme) {
                                    Text("🫧 Frutiger Aero (Aqua Glass)").tag("aero")
                                    Text("🪨 Matte Minimal (Flat & Puristisch)").tag("matte")
                                    Text("🍏 Cupertino Minimal").tag("cupertino")
                                    Text("🌿 Botanischer Garten").tag("botanical")
                                    Text("🌴 Vaporwave Sunset").tag("vaporwave")
                                }
                                .pickerStyle(.menu)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .padding(10)
                                .background(RoundedRectangle(cornerRadius: 10).fill(Color.primary.opacity(0.06)))
                            }
                            
                            Button {
                                withAnimation {
                                    appState.toggleDarkMode()
                                }
                            } label: {
                                HStack {
                                    Image(systemName: appState.isDarkMode ? "sun.max.fill" : "moon.stars.fill")
                                    Text(appState.isDarkMode ? "Zu Daylight Mode wechseln" : "Zu Dark Mode wechseln")
                                }
                                .font(.subheadline.weight(.semibold))
                                .foregroundColor(.primary)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 12)
                                .frutigerGlass(cornerRadius: 12)
                            }
                            .buttonStyle(.plain)
                        }
                        .padding(18)
                        .frutigerGlass(cornerRadius: 18)
                        
                        // Unofficial Student Project Disclaimer Footer
                        VStack(alignment: .leading, spacing: 6) {
                            HStack(spacing: 6) {
                                Image(systemName: "info.circle.fill")
                                    .foregroundColor(AeroTheme.skyBlue)
                                Text("Rechtlicher Hinweis (Inoffizielles Projekt)")
                                    .font(.caption.weight(.bold))
                                    .foregroundColor(.primary)
                            }
                            Text("UNIBODY ist ein unabhängiges, inoffizielles Programm für Studierende an der CAU Kiel und steht in keiner offiziellen Verbindung zur Christian-Albrechts-Universität zu Kiel, OpenOlat oder Moodle.")
                                .font(.caption2)
                                .foregroundColor(.secondary)
                        }
                        .padding(14)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .frutigerGlass(cornerRadius: 14)

                    }
                    .padding()
                }
            }
            .navigationTitle("Login & Tresor")
            .onAppear {
                inputUsername = appState.username
                inputPassword = appState.password
                selectedPlatform = appState.defaultPlatform
                autoFill = appState.isAutoFillActive
                autoSubmit = appState.isAutoSubmitActive
            }
        }
    }
}
