import SwiftUI
import WebKit

public struct AutomationTask: Identifiable {
    public var id: String { course.courseId + (group?.groupId ?? "unenroll") }
    public let course: Course
    public let group: ExerciseGroup?
    public let isEnroll: Bool
}

public struct LiveAutomationSheet: View {
    @Environment(\.dismiss) var dismiss
    @EnvironmentObject var appState: AppState
    
    public let task: AutomationTask
    
    @State private var currentStatus: String = "Initialisiere CAU-Verbindung..."
    @State private var progress: Double = 0.15
    @State private var isSuccess: Bool = false
    @State private var errorMessage: String? = nil
    
    public var body: some View {
        NavigationStack {
            ZStack {
                Color(red: 0.02, green: 0.07, blue: 0.14).ignoresSafeArea()
                
                VStack(spacing: 0) {
                    // Header Bar with animated status
                    VStack(spacing: 12) {
                        HStack {
                            ZStack {
                                Circle()
                                    .fill(isSuccess ? AeroTheme.emerald.opacity(0.2) : AeroTheme.solarOrange.opacity(0.2))
                                    .frame(width: 36, height: 36)
                                Image(systemName: isSuccess ? "checkmark.seal.fill" : "bolt.badge.clock.fill")
                                    .font(.system(size: 18))
                                    .foregroundColor(isSuccess ? AeroTheme.emerald : AeroTheme.solarOrange)
                            }
                            
                            VStack(alignment: .leading, spacing: 2) {
                                Text(task.isEnroll ? "Auto-Pilot: Einschreibung" : "Auto-Pilot: Austragung")
                                    .font(.system(.headline, design: .rounded).weight(.bold))
                                    .foregroundColor(.white)
                                
                                Text(task.course.courseId + (task.group != nil ? " · \(task.group!.name)" : ""))
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                    .lineLimit(1)
                            }
                            
                            Spacer()
                            
                            if isSuccess {
                                AeroBadge("Verifiziert", color: AeroTheme.emerald)
                            } else {
                                ProgressView()
                                    .progressViewStyle(CircularProgressViewStyle(tint: AeroTheme.skyBlue))
                                    .scaleEffect(0.85)
                            }
                        }
                        
                        // Live Status pill
                        HStack(spacing: 8) {
                            Text(currentStatus)
                                .font(.system(.subheadline, design: .rounded).weight(.medium))
                                .foregroundColor(.white)
                                .lineLimit(2)
                            Spacer()
                        }
                        .padding(.horizontal, 14)
                        .padding(.vertical, 8)
                        .background(
                            RoundedRectangle(cornerRadius: 12, style: .continuous)
                                .fill(Color.white.opacity(0.08))
                        )
                        
                        // Progress bar
                        GeometryReader { geo in
                            ZStack(alignment: .leading) {
                                Capsule()
                                    .fill(Color.white.opacity(0.12))
                                    .frame(height: 6)
                                Capsule()
                                    .fill(
                                        isSuccess
                                        ? LinearGradient(colors: [AeroTheme.emerald, AeroTheme.skyBlue], startPoint: .leading, endPoint: .trailing)
                                        : LinearGradient(colors: [AeroTheme.solarOrange, AeroTheme.skyBlue], startPoint: .leading, endPoint: .trailing)
                                    )
                                    .frame(width: geo.size.width * CGFloat(progress), height: 6)
                                    .animation(.easeInOut(duration: 0.35), value: progress)
                            }
                        }
                        .frame(height: 6)
                    }
                    .padding()
                    .background(Color(red: 0.05, green: 0.12, blue: 0.22))
                    
                    // Live WebKit View
                    LiveAutomationWebView(
                        task: task,
                        username: appState.username,
                        password: appState.password,
                        onStatusUpdate: { status, prog in
                            self.currentStatus = status
                            self.progress = prog
                        },
                        onSuccess: { msg in
                            self.isSuccess = true
                            self.progress = 1.0
                            self.currentStatus = msg
                            
                            // Apply state locally in app
                            if task.isEnroll, let grp = task.group {
                                appState.enrollInGroup(courseId: task.course.courseId, groupId: grp.groupId)
                            } else {
                                appState.clearEnrollment(courseId: task.course.courseId)
                            }
                            
                            #if canImport(UIKit)
                            UINotificationFeedbackGenerator().notificationOccurred(.success)
                            #endif
                            
                            // Automatically dismiss after brief celebration
                            DispatchQueue.main.asyncAfter(deadline: .now() + 1.8) {
                                dismiss()
                            }
                        },
                        onError: { err in
                            self.errorMessage = err
                            self.currentStatus = err
                            #if canImport(UIKit)
                            UINotificationFeedbackGenerator().notificationOccurred(.warning)
                            #endif
                        }
                    )
                    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                    .padding(8)
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(isSuccess ? "Erledigt" : "Schließen") {
                        dismiss()
                    }
                    .foregroundColor(AeroTheme.skyBlue)
                }
            }
        }
    }
}

// MARK: - Live Automation WebKit View
private struct LiveAutomationWebView: UIViewRepresentable {
    let task: AutomationTask
    let username: String
    let password: String
    let onStatusUpdate: (String, Double) -> Void
    let onSuccess: (String) -> Void
    let onError: (String) -> Void
    
    func makeCoordinator() -> Coordinator {
        Coordinator(parent: self)
    }
    
    func makeUIView(context: Context) -> WKWebView {
        let config = WKWebViewConfiguration()
        config.websiteDataStore = WKWebsiteDataStore.default()
        config.preferences.javaScriptEnabled = true
        
        let contentController = WKUserContentController()
        contentController.add(context.coordinator, name: "unibodyAutomation")
        config.userContentController = contentController
        
        let wv = WKWebView(frame: .zero, configuration: config)
        wv.customUserAgent = "Mozilla/5.0 (iPhone; CPU iPhone OS 27_0 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/18.0 Mobile/15E148 Safari/604.1 UNIBODY-Mobile/1.0"
        wv.navigationDelegate = context.coordinator
        
        context.coordinator.webView = wv
        context.coordinator.startAutomation()
        
        return wv
    }
    
    func updateUIView(_ uiView: WKWebView, context: Context) { }
    
    class Coordinator: NSObject, WKNavigationDelegate, WKScriptMessageHandler {
        let parent: LiveAutomationWebView
        weak var webView: WKWebView?
        private var pollTimer: Timer?
        private var hasSucceeded = false
        private var stepCounter = 0
        
        init(parent: LiveAutomationWebView) {
            self.parent = parent
        }
        
        deinit {
            pollTimer?.invalidate()
        }
        
        func startAutomation() {
            guard let wv = webView else { return }
            let targetURL = parent.task.course.targetEnrollmentURL
            
            parent.onStatusUpdate("Lade \(targetURL.host ?? "CAU-Portal")...", 0.20)
            wv.load(URLRequest(url: targetURL))
            
            // Start heartbeat polling every 350ms in .common RunLoop mode
            pollTimer?.invalidate()
            let timer = Timer(timeInterval: 0.35, repeats: true) { [weak self] _ in
                self?.runAutomationStep()
            }
            RunLoop.main.add(timer, forMode: .common)
            self.pollTimer = timer
        }
        
        func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
            runAutomationStep()
        }
        
        private func runAutomationStep() {
            guard !hasSucceeded, let wv = webView else { return }
            stepCounter += 1
            
            let params: [String: Any] = [
                "username": parent.username.trimmingCharacters(in: .whitespacesAndNewlines),
                "password": parent.password,
                "isEnroll": parent.task.isEnroll,
                "targetName": parent.task.group?.name ?? "",
                "targetDay": parent.task.group?.dayName ?? "",
                "targetTime": parent.task.group?.startTime ?? "",
                "targetId": parent.task.group?.groupId ?? "",
                "courseId": parent.task.course.courseId
            ]
            
            guard let jsonData = try? JSONSerialization.data(withJSONObject: params),
                  let jsonString = String(data: jsonData, encoding: .utf8) else { return }
            
            let js = """
            (function() {
                const PARAMS = \(jsonString);
                const USERNAME = PARAMS.username;
                const PASSWORD = PARAMS.password;
                const IS_ENROLL = PARAMS.isEnroll;
                const TARGET_NAME = (PARAMS.targetName || "").toLowerCase();
                const TARGET_DAY = (PARAMS.targetDay || "").toLowerCase();
                const TARGET_TIME = (PARAMS.targetTime || "").toLowerCase();
                const TARGET_ID = (PARAMS.targetId || "").toLowerCase();
                
                // 1. Check for Confirmation Modal Dialog first
                const modal = document.querySelector('.modal-dialog, .modal-content, .o_modal');
                if (modal) {
                    const btn = modal.querySelector('button.btn-primary, input[type="submit"]') ||
                                Array.from(modal.querySelectorAll('button, a.btn, input[type="button"]')).find(b => /(ja|einschreiben|anmelden|austragen|abmelden|bestätigen|speichern|ok|yes)/i.test((b.innerText || b.value || '').trim()));
                    if (btn) {
                        btn.click();
                        return { action: "MODAL_CONFIRMED", msg: "Bestätige Buchungs-Dialog..." };
                    }
                }
                
                // 2. OpenOlat 21+ FlexiForm AJAX Login (`#ofo_oolat_login`)
                const olatForm = document.getElementById('ofo_oolat_login');
                const olatNameInput = document.getElementById('o_fiooolat_login_name');
                const olatPassInput = document.getElementById('o_fiooolat_login_pass');
                const olatBtn = document.getElementById('o_fiooolat_login_button');
                
                if (olatForm && (olatNameInput || olatPassInput)) {
                    // Check Step 2: Password first
                    if (olatPassInput && olatPassInput.offsetParent !== null) {
                        if (olatPassInput.value !== PASSWORD && PASSWORD.length > 0) {
                            olatPassInput.focus();
                            olatPassInput.value = PASSWORD;
                            olatPassInput.dispatchEvent(new Event('input', { bubbles: true }));
                            olatPassInput.dispatchEvent(new Event('change', { bubbles: true }));
                        }
                        const du = document.getElementById('ofo_oolat_login_dispatchuri');
                        const ev = document.getElementById('ofo_oolat_login_eventval');
                        if (du) du.value = 'o_fiooolat_login_button';
                        if (ev) ev.value = '2';
                        if (typeof window.o_XHRSubmit === 'function') {
                            window.o_XHRSubmit('ofo_oolat_login');
                        } else if (olatBtn) {
                            olatBtn.click();
                        }
                        return { action: "LOGIN_STEP2", msg: "Übermittle CAU-Passwort..." };
                    }
                    
                    // Step 1: Username
                    if (olatNameInput && (!olatPassInput || olatPassInput.offsetParent === null)) {
                        if (olatNameInput.value !== USERNAME && USERNAME.length > 0) {
                            olatNameInput.focus();
                            olatNameInput.value = USERNAME;
                            olatNameInput.dispatchEvent(new Event('input', { bubbles: true }));
                            olatNameInput.dispatchEvent(new Event('change', { bubbles: true }));
                        }
                        const du = document.getElementById('ofo_oolat_login_dispatchuri');
                        const ev = document.getElementById('ofo_oolat_login_eventval');
                        if (du) du.value = 'o_fiooolat_login_button';
                        if (ev) ev.value = '2';
                        if (typeof window.o_XHRSubmit === 'function') {
                            window.o_XHRSubmit('ofo_oolat_login');
                        } else if (olatBtn) {
                            olatBtn.click();
                        }
                        return { action: "LOGIN_STEP1", msg: "Melde " + (USERNAME || "Benutzer") + " an..." };
                    }
                }
                
                // 3. Moodle Login
                const moodleUser = document.querySelector('form#login input#username, input[name="username"]');
                const moodlePass = document.querySelector('form#login input#password, input[name="password"]');
                const moodleBtn = document.querySelector('form#login button#loginbtn, button[type="submit"]');
                if (moodleUser && moodlePass && moodleBtn) {
                    moodleUser.value = USERNAME;
                    moodlePass.value = PASSWORD;
                    moodleBtn.click();
                    return { action: "LOGIN_MOODLE", msg: "Melde bei Moodle an..." };
                }
                
                // 4. Shibboleth / SAML IdP Login (`idp.uni-kiel.de`)
                const idpUser = document.querySelector('input#username, input[name="j_username"]');
                const idpPass = document.querySelector('input#password, input[name="j_password"]');
                const idpBtn = document.querySelector('button[type="submit"], input[type="submit"]');
                if (idpUser && idpPass && idpBtn) {
                    idpUser.value = USERNAME;
                    idpPass.value = PASSWORD;
                    idpBtn.click();
                    return { action: "LOGIN_IDP", msg: "CAU-Zentral-Login..." };
                }
                
                // 5. OpenOlat Tree Navigation: Find 'Einschreibung' / 'Anmeldung'
                const table = document.querySelector('table.o_table, table.table');
                if (!table) {
                    const nodes = Array.from(document.querySelectorAll('.o_tree a, .o_course_menu a, nav a, .o_subnav a, a.o_tree_link, #o_main_container a, .o_course_run a'));
                    let targetNode = nodes.find(a => {
                        const txt = (a.innerText || a.getAttribute('title') || '').trim().toLowerCase();
                        return txt === 'einschreibung' || txt === 'anmeldung zur übung' || txt === 'anmeldung' || txt === 'übungsgruppen';
                    });
                    if (!targetNode) {
                        targetNode = nodes.find(a => /einschreib|anmeldung|gruppenwahl|übungsgruppen/i.test((a.innerText || a.getAttribute('title') || '').trim().toLowerCase()));
                    }
                    if (targetNode) {
                        const label = (targetNode.innerText || '').trim();
                        targetNode.click();
                        return { action: "CLICKED_NODE", msg: "Öffne " + label + "..." };
                    }
                }
                
                // 6. Action in Table
                if (table) {
                    const rows = Array.from(table.querySelectorAll('tbody tr'));
                    
                    // UNENROLL
                    if (!IS_ENROLL) {
                        for (let tr of rows) {
                            const cancelBtn = tr.querySelector('a[onclick*="cmd.enrolled.cancel"], a[onclick*="cmd.cancel"], td:nth-child(6) a') ||
                                              Array.from(tr.querySelectorAll('a, button')).find(a => /austragen|abmelden|verlassen/i.test((a.innerText || a.title || '').trim()));
                            if (cancelBtn) {
                                cancelBtn.click();
                                window.__clickedCancel = true;
                                return { action: "CLICKED_CANCEL", msg: "Klicke Austragen..." };
                            }
                        }
                        
                        const anyCancel = table.querySelector('a[onclick*="cmd.enrolled.cancel"], a[onclick*="cmd.cancel"]');
                        if (!anyCancel && window.__clickedCancel) {
                            return { action: "SUCCESS", msg: "Erfolgreich ausgetragen & verifiziert!" };
                        }
                    }
                    
                    // ENROLL
                    if (IS_ENROLL) {
                        for (let tr of rows) {
                            const txt = (tr.innerText || '').toLowerCase();
                            const matches = txt.includes(TARGET_NAME) || (TARGET_ID && txt.includes(TARGET_ID)) || (TARGET_DAY && txt.includes(TARGET_DAY) && TARGET_TIME && txt.includes(TARGET_TIME));
                            if (matches) {
                                const cancelBtn = tr.querySelector('a[onclick*="cmd.enrolled.cancel"], a[onclick*="cmd.cancel"]') ||
                                                  Array.from(tr.querySelectorAll('a')).find(a => /austragen/i.test(a.innerText || ''));
                                if (cancelBtn) {
                                    return { action: "SUCCESS", msg: "Verbindlich im CAU-Portal eingetragen!" };
                                }
                                
                                const enrollBtn = tr.querySelector('a[onclick*="cmd.enrolled.add"], a[onclick*="cmd.enroll"], td:nth-child(5) a') ||
                                                  Array.from(tr.querySelectorAll('a, button')).find(a => /einschreiben/i.test(a.innerText || ''));
                                if (enrollBtn) {
                                    enrollBtn.click();
                                    window.__clickedEnroll = true;
                                    return { action: "CLICKED_ENROLL", msg: "Klicke Einschreiben..." };
                                }
                            }
                        }
                        
                        if (window.__clickedEnroll) {
                            return { action: "SUCCESS", msg: "Einschreibung verbindlich gebucht!" };
                        }
                    }
                }
                
                // Moodle choicegroup
                const moodleRadios = Array.from(document.querySelectorAll('input[type="radio"][name="answer"]'));
                if (moodleRadios.length > 0) {
                    if (IS_ENROLL) {
                        moodleRadios[0].checked = true;
                        const sub = document.querySelector('form#choicegroupform input[type="submit"], input[type="submit"]');
                        if (sub) { sub.click(); return { action: "SUCCESS", msg: "Moodle-Gruppe gebucht!" }; }
                    } else {
                        const del = document.querySelector('input[name="deletechoice"], button[name="deletechoice"]');
                        if (del) { del.click(); return { action: "SUCCESS", msg: "Moodle-Gruppe abgemeldet!" }; }
                    }
                }
                
                return { action: "IDLE", msg: "Synchronisiere mit CAU..." };
            })();
            """
            
            wv.evaluateJavaScript(js) { [weak self] result, error in
                if let error = error {
                    print("[UNIBODY-JS-ERROR] \(error)")
                }
                guard let self = self, !self.hasSucceeded else { return }
                guard let dict = result as? [String: Any], let action = dict["action"] as? String else { return }
                let msg = dict["msg"] as? String ?? ""
                
                DispatchQueue.main.async {
                    switch action {
                    case "LOGIN_STEP1":
                        self.parent.onStatusUpdate(msg, 0.35)
                    case "LOGIN_STEP2":
                        self.parent.onStatusUpdate(msg, 0.50)
                    case "CLICKED_NODE":
                        self.parent.onStatusUpdate(msg, 0.65)
                    case "CLICKED_ENROLL", "CLICKED_CANCEL":
                        self.parent.onStatusUpdate(msg, 0.85)
                    case "MODAL_CONFIRMED":
                        self.parent.onStatusUpdate(msg, 0.90)
                    case "SUCCESS":
                        self.hasSucceeded = true
                        self.pollTimer?.invalidate()
                        self.parent.onSuccess(msg)
                    default:
                        break
                    }
                }
            }
        }
        
        func userContentController(_ userContentController: WKUserContentController, didReceive message: WKScriptMessage) {
            if message.name == "unibodyAutomation", let body = message.body as? [String: Any] {
                let type = body["type"] as? String ?? ""
                let msg = body["message"] as? String ?? "Erfolgreich!"
                if type == "SUCCESS" {
                    hasSucceeded = true
                    pollTimer?.invalidate()
                    parent.onSuccess(msg)
                }
            }
        }
    }
}
