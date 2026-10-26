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
                    .padding(.horizontal, 10)
                    .padding(.top, 8)
                    .padding(.bottom, 6)
                    
                    // Fixed Bottom Done / Close Button (elevated above home bar, perfectly tappable)
                    Button {
                        dismiss()
                    } label: {
                        HStack(spacing: 8) {
                            Image(systemName: isSuccess ? "checkmark.circle.fill" : "xmark.circle")
                                .font(.system(size: 16, weight: .bold))
                            Text(isSuccess ? "Erledigt" : "Abbrechen")
                                .font(.system(.body, design: .rounded).weight(.bold))
                        }
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .frame(height: 50)
                        .background(
                            ZStack {
                                RoundedRectangle(cornerRadius: 14, style: .continuous)
                                    .fill(isSuccess ? AeroTheme.auroraGradient : AeroTheme.oceanGradient)
                                
                                RoundedRectangle(cornerRadius: 14, style: .continuous)
                                    .strokeBorder(Color.white.opacity(0.35), lineWidth: 1)
                            }
                        )
                        .shadow(color: isSuccess ? AeroTheme.emerald.opacity(0.3) : Color.clear, radius: 8, x: 0, y: 3)
                    }
                    .buttonStyle(.plain)
                    .padding(.horizontal, 16)
                    .padding(.top, 4)
                    .padding(.bottom, 16)
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
            
            let effectiveUser = parent.username.trimmingCharacters(in: .whitespacesAndNewlines)
            let effectivePass = parent.password
            
            guard !effectiveUser.isEmpty, !effectivePass.isEmpty else {
                parent.onError("⚠️ Keine Zugangsdaten hinterlegt. Bitte trage deine stu-Kennung & Passwort im Tab 'Login & Tresor' ein.")
                return
            }
            
            let params: [String: Any] = [
                "username": effectiveUser,
                "password": effectivePass,
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
                
                // Helper: Robustly set input value with native descriptor + jQuery + full DOM events
                function setVal(el, val) {
                    if (!el || val === undefined || val === null) return false;
                    try {
                        el.focus();
                        const proto = Object.getOwnPropertyDescriptor(window.HTMLInputElement.prototype, 'value');
                        if (proto && proto.set) {
                            proto.set.call(el, val);
                        } else {
                            el.value = val;
                        }
                        if (window.jQuery) {
                            try { window.jQuery(el).val(val).trigger('input').trigger('change'); } catch(e) {}
                        }
                        el.dispatchEvent(new Event('input', { bubbles: true }));
                        el.dispatchEvent(new Event('change', { bubbles: true }));
                        el.dispatchEvent(new KeyboardEvent('keydown', { bubbles: true }));
                        el.dispatchEvent(new KeyboardEvent('keyup', { bubbles: true }));
                        return true;
                    } catch (e) {
                        el.value = val;
                        return true;
                    }
                }
                
                // Helper: Trigger OpenOlat FlexiForm submit
                function triggerOlatSubmit() {
                    const du = document.getElementById('ofo_oolat_login_dispatchuri');
                    const ev = document.getElementById('ofo_oolat_login_eventval');
                    if (du) du.value = 'o_fiooolat_login_button';
                    if (ev) ev.value = '2';
                    if (window.o_info) window.o_info.preventOnchange = true;
                    
                    const btn = document.getElementById('o_fiooolat_login_button');
                    if (btn) {
                        try {
                            if (typeof btn.onclick === 'function') {
                                btn.onclick.call(btn, new MouseEvent('click', { bubbles: true, cancelable: true }));
                            }
                        } catch(e) {}
                        btn.click();
                        btn.dispatchEvent(new MouseEvent('click', { bubbles: true, cancelable: true, view: window }));
                    }
                    if (typeof window.o_XHRSubmit === 'function') {
                        try { window.o_XHRSubmit('ofo_oolat_login'); } catch(e) {}
                    }
                }
                
                // ==========================================
                // 1. OPENOLAT FLEXIFORM LOGIN (lms.uni-kiel.de/dmz/)
                // ==========================================
                const olatForm = document.getElementById('ofo_oolat_login');
                const olatNameInput = document.getElementById('o_fiooolat_login_name');
                const olatPassInput = document.getElementById('o_fiooolat_login_pass');
                
                if (olatForm && (olatNameInput || olatPassInput)) {
                    // Step 2: Password input is visible
                    if (olatPassInput && olatPassInput.offsetParent !== null) {
                        if (olatNameInput && olatNameInput.offsetParent !== null && olatNameInput.value !== USERNAME) {
                            setVal(olatNameInput, USERNAME);
                        }
                        setVal(olatPassInput, PASSWORD);
                        
                        const now = Date.now();
                        if (!window.__lastStep2Ts || (now - window.__lastStep2Ts > 2500)) {
                            window.__lastStep2Ts = now;
                            setTimeout(triggerOlatSubmit, 100);
                        }
                        return { action: "LOGIN_STEP2", msg: "Übermittle CAU-Passwort..." };
                    }
                    
                    // Step 1: Username input is visible
                    if (olatNameInput && olatNameInput.offsetParent !== null) {
                        setVal(olatNameInput, USERNAME);
                        
                        const now = Date.now();
                        if (!window.__lastStep1Ts || (now - window.__lastStep1Ts > 2500)) {
                            window.__lastStep1Ts = now;
                            setTimeout(triggerOlatSubmit, 100);
                        }
                        return { action: "LOGIN_STEP1", msg: "Melde " + USERNAME + " an..." };
                    }
                }
                
                // ==========================================
                // 2. MOODLE / SHIBBOLETH / CAU-IDP LOGIN
                // ==========================================
                const moodleUser = document.querySelector('form#login input#username, input[name="username"], input[name="j_username"]');
                const moodlePass = document.querySelector('form#login input#password, input[name="password"], input[name="j_password"]');
                const moodleBtn = document.querySelector('form#login button#loginbtn, button[type="submit"], input[type="submit"], button[name="_eventId_proceed"]');
                if (moodleUser && moodlePass && moodleBtn && moodleUser.offsetParent !== null && moodlePass.offsetParent !== null) {
                    setVal(moodleUser, USERNAME);
                    setVal(moodlePass, PASSWORD);
                    const now = Date.now();
                    if (!window.__lastMoodleTs || (now - window.__lastMoodleTs > 3000)) {
                        window.__lastMoodleTs = now;
                        setTimeout(() => { moodleBtn.click(); }, 120);
                    }
                    return { action: "LOGIN_GENERIC", msg: "CAU-Zentral-Login für " + USERNAME + "..." };
                }
                
                // ==========================================
                // 3. CONFIRMATION MODAL (Strictly excluding #o_form_dirty_message)
                // ==========================================
                function findConfirmationModalButton() {
                    const modals = Array.from(document.querySelectorAll('.modal.in, .modal.show, div.modal-dialog, div.o_modal, div.modal-content'));
                    for (const m of modals) {
                        if (m.id === 'o_form_dirty_message' || m.closest('#o_form_dirty_message')) continue;
                        if (m.offsetParent === null) continue;
                        const style = window.getComputedStyle(m);
                        if (style.display === 'none' || style.visibility === 'hidden' || style.opacity === '0') continue;
                        
                        const buttons = Array.from(m.querySelectorAll('button, a.btn, input[type="submit"], input[type="button"]'));
                        for (const b of buttons) {
                            if (b.offsetParent === null) continue;
                            if (b.classList.contains('o_form_dirty_back') || b.classList.contains('o_form_dirty_ignore')) continue;
                            const txt = (b.innerText || b.value || '').trim().toLowerCase();
                            if (txt === 'abbrechen' || txt === 'nein' || txt === 'cancel' || txt === 'zurück' || txt === 'close') continue;
                            if (b.classList.contains('btn-primary') || /(ja|einschreiben|anmelden|austragen|abmelden|bestätigen|speichern|ok|yes)/i.test(txt)) {
                                return b;
                            }
                        }
                    }
                    return null;
                }
                
                const modalBtn = findConfirmationModalButton();
                if (modalBtn) {
                    const now = Date.now();
                    if (!window.__lastModalClick || (now - window.__lastModalClick > 1500)) {
                        window.__lastModalClick = now;
                        modalBtn.click();
                    }
                    return { action: "MODAL_CONFIRMED", msg: "Bestätige Buchungs-Dialog..." };
                }
                
                // ==========================================
                // 4. OPENOLAT TREE NAVIGATION (Find 'Einschreibung' if no table)
                // ==========================================
                const table = document.querySelector('table.o_table, table.table');
                if (!table) {
                    const links = Array.from(document.querySelectorAll('.o_tree a, .o_course_menu a, nav a, .o_subnav a, a.o_tree_link, #o_main_container a, .o_course_run a'));
                    let targetLink = links.find(a => {
                        const txt = (a.innerText || a.getAttribute('title') || '').trim().toLowerCase();
                        return txt === 'einschreibung' || txt === 'anmeldung zur übung' || txt === 'anmeldung' || txt === 'übungsgruppen';
                    });
                    if (!targetLink) {
                        targetLink = links.find(a => /einschreib|anmeldung|gruppenwahl|übungsgruppen/i.test((a.innerText || a.getAttribute('title') || '').trim().toLowerCase()));
                    }
                    if (targetLink) {
                        const now = Date.now();
                        if (!window.__lastNodeClick || (now - window.__lastNodeClick > 3500)) {
                            window.__lastNodeClick = now;
                            const label = (targetLink.innerText || 'Einschreibung').trim();
                            targetLink.click();
                            return { action: "CLICKED_NODE", msg: "Öffne " + label + "..." };
                        }
                    }
                }
                
                // ==========================================
                // 5. TABLE ACTIONS (ENROLL & UNENROLL)
                // ==========================================
                if (table) {
                    const rows = Array.from(table.querySelectorAll('tbody tr'));
                    
                    // UNENROLL (!IS_ENROLL)
                    if (!IS_ENROLL) {
                        const anyCancel = table.querySelector('a[onclick*="cmd.enrolled.cancel"], a[onclick*="cmd.cancel"]');
                        if (window.__clickedCancel && !anyCancel) {
                            return { action: "SUCCESS", msg: "Erfolgreich ausgetragen & verifiziert!" };
                        }
                        
                        for (let tr of rows) {
                            const cancelBtn = tr.querySelector('a[onclick*="cmd.enrolled.cancel"], a[onclick*="cmd.cancel"], td:nth-child(6) a') ||
                                              Array.from(tr.querySelectorAll('a, button, input[type="button"]')).find(a => /austragen|abmelden|verlassen/i.test((a.innerText || a.value || a.title || '').trim()));
                            if (cancelBtn && cancelBtn.offsetParent !== null) {
                                const now = Date.now();
                                if (!window.__lastCancelClick || (now - window.__lastCancelClick > 2500)) {
                                    window.__lastCancelClick = now;
                                    window.__clickedCancel = true;
                                    try { if (typeof cancelBtn.onclick === 'function') cancelBtn.onclick.call(cancelBtn); } catch(e) {}
                                    cancelBtn.focus();
                                    cancelBtn.click();
                                    cancelBtn.dispatchEvent(new MouseEvent('click', { bubbles: true, cancelable: true, view: window }));
                                    return { action: "CLICKED_CANCEL", msg: "Klicke Austragen..." };
                                }
                            }
                        }
                        
                        if (!anyCancel && !window.__clickedCancel) {
                            const anyEnroll = table.querySelector('a[onclick*="cmd.enrolled.add"], a[onclick*="cmd.enroll"]');
                            if (anyEnroll) {
                                return { action: "SUCCESS", msg: "Bereits ausgetragen (nicht belegt)!" };
                            }
                        }
                    }
                    
                    // ENROLL (IS_ENROLL)
                    if (IS_ENROLL) {
                        // Check if an alert banner indicates success
                        const successAlert = document.querySelector('.alert.alert-success, .o_info, .alert-info');
                        if (successAlert && /eingeschrieben|erfolgreich|angemeldet/i.test(successAlert.innerText || '')) {
                            return { action: "SUCCESS", msg: "Verbindlich im CAU-Portal eingetragen!" };
                        }
                        
                        // Extract target group number from TARGET_NAME, TARGET_ID, etc.
                        let targetNum = null;
                        const numMatch = (TARGET_NAME + " " + TARGET_ID).match(/(?:gruppe|gr\\.?|übung|tutorium|group)\\s*0*(\\d+)/i);
                        if (numMatch) {
                            targetNum = parseInt(numMatch[1], 10);
                        } else {
                            const anyNum = TARGET_NAME.match(/\\b0*(\\d+)\\b/);
                            if (anyNum) targetNum = parseInt(anyNum[1], 10);
                        }
                        
                        // Find best matching row
                        let bestRow = null;
                        let bestScore = -1;
                        
                        for (let idx = 0; idx < rows.length; idx++) {
                            const tr = rows[idx];
                            const tds = Array.from(tr.querySelectorAll('td')).map(td => (td.innerText || '').toLowerCase().trim());
                            const combined = tds.join(' ');
                            let score = 0;
                            
                            if (targetNum !== null) {
                                const rowNumMatch = combined.match(/(?:gruppe|gr\\.?|übung|tutorium|group)\\s*0*(\\d+)/i);
                                if (rowNumMatch && parseInt(rowNumMatch[1], 10) === targetNum) {
                                    score += 70;
                                } else if (idx === targetNum - 1) {
                                    score += 35;
                                }
                            }
                            
                            if (TARGET_TIME && TARGET_TIME.length >= 3 && combined.includes(TARGET_TIME)) {
                                score += 45;
                            }
                            
                            if (TARGET_DAY && TARGET_DAY.length >= 2) {
                                const shortDay = TARGET_DAY.slice(0, 2);
                                if (combined.includes(TARGET_DAY) || combined.includes(shortDay)) {
                                    score += 25;
                                }
                            }
                            
                            if (TARGET_NAME && combined.includes(TARGET_NAME)) score += 50;
                            if (TARGET_ID && combined.includes(TARGET_ID)) score += 50;
                            if (rows.length === 1) score += 30;
                            
                            if (score > bestScore) {
                                bestScore = score;
                                bestRow = tr;
                            }
                        }
                        
                        // Fallback row if score didn't reach threshold
                        if (!bestRow || bestScore < 20) {
                            if (targetNum !== null && (targetNum - 1) >= 0 && (targetNum - 1) < rows.length) {
                                bestRow = rows[targetNum - 1];
                            } else {
                                bestRow = rows.find(r => {
                                    const btn = r.querySelector('td:nth-child(5) a, a[onclick*="cmd.enrolled.add"], a[onclick*="cmd.enroll"]');
                                    return btn && btn.offsetParent !== null;
                                }) || rows[0];
                            }
                        }
                        
                        if (bestRow) {
                            // Check if already enrolled in this row
                            const cancelBtn = bestRow.querySelector('td:nth-child(6) a, a[onclick*="cmd.enrolled.cancel"], a[onclick*="cmd.cancel"]') ||
                                              Array.from(bestRow.querySelectorAll('a, button')).find(a => /austragen|abmelden/i.test(a.innerText || ''));
                            const statusCell = bestRow.querySelector('td:nth-child(4)');
                            const isEnrolledStatus = statusCell && /eingeschrieben/i.test(statusCell.innerText) && !/nicht|kein/i.test(statusCell.innerText);
                            
                            if (cancelBtn || isEnrolledStatus) {
                                return { action: "SUCCESS", msg: "Verbindlich im CAU-Portal eingetragen!" };
                            }
                            
                            // Check if already clicked enroll and any cancel button is now visible
                            if (window.__clickedEnroll) {
                                const anyCancel = table.querySelector('a[onclick*="cmd.enrolled.cancel"], a[onclick*="cmd.cancel"]');
                                if (anyCancel) {
                                    return { action: "SUCCESS", msg: "Einschreibung verbindlich gebucht!" };
                                }
                            }
                            
                            // Look for enroll button
                            const enrollBtn = bestRow.querySelector('td:nth-child(5) a, a[onclick*="cmd.enrolled.add"], a[onclick*="cmd.enroll"]') ||
                                              Array.from(bestRow.querySelectorAll('a, button, input[type="button"]')).find(a => /einschreiben|anmelden|buchen/i.test((a.innerText || a.value || a.title || '').trim()));
                            
                            if (enrollBtn && enrollBtn.offsetParent !== null) {
                                const now = Date.now();
                                if (!window.__lastEnrollClick || (now - window.__lastEnrollClick > 2500)) {
                                    window.__lastEnrollClick = now;
                                    window.__clickedEnroll = true;
                                    try { if (typeof enrollBtn.onclick === 'function') enrollBtn.onclick.call(enrollBtn); } catch(e) {}
                                    enrollBtn.focus();
                                    enrollBtn.click();
                                    enrollBtn.dispatchEvent(new MouseEvent('click', { bubbles: true, cancelable: true, view: window }));
                                    return { action: "CLICKED_ENROLL", msg: "Klicke Einschreiben..." };
                                }
                            }
                        }
                        
                        if (window.__clickedEnroll) {
                            const anyCancel = table.querySelector('a[onclick*="cmd.enrolled.cancel"], a[onclick*="cmd.cancel"]');
                            if (anyCancel) {
                                return { action: "SUCCESS", msg: "Einschreibung verbindlich gebucht!" };
                            }
                        }
                    }
                }
                
                // ==========================================
                // 6. MOODLE CHOICEGROUP FORM
                // ==========================================
                const moodleRadios = Array.from(document.querySelectorAll('input[type="radio"][name="answer"]'));
                if (moodleRadios.length > 0) {
                    if (IS_ENROLL) {
                        let targetRadio = moodleRadios[0];
                        const numM = (TARGET_NAME + " " + TARGET_ID).match(/(?:übungsgruppe|gruppe|gr\\.?|übung|tutorium|group)\\s*0*(\\d+)/i);
                        const wantNum = numM ? parseInt(numM[1], 10) : null;
                        for (let i = 0; i < moodleRadios.length; i++) {
                            const r = moodleRadios[i];
                            const tr = r.closest('tr, div') || document.body;
                            const lblTxt = (tr.innerText || '').toLowerCase();
                            if (wantNum !== null) {
                                const rm = lblTxt.match(/(?:übungsgruppe|gruppe|gr\\.?|übung|tutorium|group)\\s*0*(\\d+)/i);
                                if (rm && parseInt(rm[1], 10) === wantNum) {
                                    targetRadio = r;
                                    break;
                                }
                            } else if (TARGET_NAME && lblTxt.includes(TARGET_NAME)) {
                                targetRadio = r;
                                break;
                            }
                        }
                        if (targetRadio.checked) {
                            return { action: "SUCCESS", msg: "Bereits in dieser Moodle-Gruppe eingetragen!" };
                        }
                        targetRadio.checked = true;
                        targetRadio.dispatchEvent(new Event('change', { bubbles: true }));
                        const form = targetRadio.closest('form') || document.querySelector('form.tableform, form#choicegroupform');
                        const sub = form ? form.querySelector('button[type="submit"], input[type="submit"]') : document.querySelector('input[type="submit"], button[type="submit"]');
                        if (sub) { sub.click(); return { action: "SUCCESS", msg: "Moodle-Gruppe verbindlich gebucht!" }; }
                        if (form) { form.submit(); return { action: "SUCCESS", msg: "Moodle-Gruppe verbindlich gebucht!" }; }
                    } else {
                        const del = document.querySelector('a[href*="action=delchoicegroup"], input[name="deletechoice"], button[name="deletechoice"]') ||
                                    Array.from(document.querySelectorAll('a, button, input[type="submit"]')).find(b => /remove my choice|auswahl entfernen|austragen/i.test(b.innerText || b.value || ''));
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
                    case "LOGIN_GENERIC":
                        self.parent.onStatusUpdate(msg, 0.45)
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
