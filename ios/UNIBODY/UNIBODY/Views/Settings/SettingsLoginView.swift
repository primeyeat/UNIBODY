import SwiftUI

public struct SettingsLoginView: View {
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
                    VStack(alignment: .leading, spacing: 20) {
                        // Header Status Card
                        VStack(alignment: .leading, spacing: 8) {
                            HStack {
                                Image(systemName: appState.isVaultSaved ? "lock.shield.fill" : "lock.open.trianglebadge.exclamationmark.fill")
                                    .font(.title2)
                                    .foregroundColor(appState.isVaultSaved ? AeroTheme.emerald : AeroTheme.solarOrange)
                                Text("CAU Login & Auto-Fill Tresor")
                                    .font(.system(.title3, design: .rounded).weight(.bold))
                                    .foregroundColor(.white)
                                Spacer()
                                AeroBadge(
                                    appState.isVaultSaved ? "Aktiv" : "Nicht konfiguriert",
                                    color: appState.isVaultSaved ? AeroTheme.emerald : AeroTheme.solarOrange
                                )
                            }
                            
                            Text("Hinterlege deine CAU-Kennung (stu-Nummer) einmalig. UNIBODY füllt deine Daten bei lms.uni-kiel.de (OpenOlat) und elearn.informatik.uni-kiel.de (Moodle) automatisch aus.")
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
                                .foregroundColor(.white)
                            
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
                                        .foregroundColor(.white)
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
                                            .foregroundColor(.white)
                                    } else {
                                        SecureField("Passwort", text: $inputPassword)
                                            .textContentType(.password)
                                            .foregroundColor(.white)
                                    }
                                    Button {
                                        isPasswordVisible.toggle()
                                    } label: {
                                        Image(systemName: isPasswordVisible ? "eye.slash.fill" : "eye.fill")
                                            .foregroundColor(.secondary)
                                    }
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
                                    Text("⚡ UNIBODY Dual-Platform (Beide)").tag("unibody")
                                    Text("🏛️ lms.uni-kiel.de (OpenOlat)").tag("openolat")
                                    Text("💻 elearn.informatik.uni-kiel.de").tag("moodle")
                                }
                                .pickerStyle(.segmented)
                            }
                            
                            // Auto-Fill Toggles
                            Toggle(isOn: $autoFill) {
                                VStack(alignment: .leading, spacing: 2) {
                                    Text("Automatisches Ausfüllen (Auto-Fill)")
                                        .font(.subheadline.weight(.semibold))
                                        .foregroundColor(.white)
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
                                        .foregroundColor(.white)
                                    Text("Meldet dich ohne manuellen Klick direkt an")
                                        .font(.caption2)
                                        .foregroundColor(.secondary)
                                }
                            }
                            .tint(AeroTheme.skyBlue)
                            
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
                                    Text("Zugangsdaten speichern & aktivieren")
                                }
                                .frame(maxWidth: .infinity)
                                .glossyButton(gradient: AeroTheme.auroraGradient, cornerRadius: 14)
                            }
                            .buttonStyle(.plain)
                            .disabled(inputUsername.trimmingCharacters(in: .whitespaces).isEmpty)
                            .padding(.top, 6)
                            
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
                        
                        // Backend Sync Section
                        VStack(alignment: .leading, spacing: 10) {
                            Text("UNIBODY Core-Server Sync")
                                .font(.system(.headline, design: .rounded).weight(.bold))
                                .foregroundColor(.white)
                            
                            HStack {
                                TextField("http://127.0.0.1:8765", text: $appState.serverURL)
                                    .font(.system(.caption, design: .monospaced))
                                    .foregroundColor(.white)
                                    .padding(10)
                                    .background(RoundedRectangle(cornerRadius: 10).fill(Color.white.opacity(0.08)))
                                
                                Button {
                                    Task {
                                        await appState.syncWithLocalServer()
                                    }
                                } label: {
                                    if appState.isSyncing {
                                        ProgressView()
                                            .tint(.white)
                                    } else {
                                        Text("Sync")
                                            .font(.caption.weight(.bold))
                                            .padding(.horizontal, 14)
                                            .padding(.vertical, 10)
                                            .background(Capsule().fill(AeroTheme.skyBlue))
                                            .foregroundColor(.white)
                                    }
                                }
                            }
                            
                            if let msg = appState.syncMessage {
                                Text(msg)
                                    .font(.caption2)
                                    .foregroundColor(.secondary)
                            }
                        }
                        .padding(18)
                        .frutigerGlass(cornerRadius: 18)
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
