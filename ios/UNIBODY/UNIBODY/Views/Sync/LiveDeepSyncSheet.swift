import SwiftUI
import WebKit

public struct LiveDetectedGroup: Identifiable, Equatable {
    public var id: String { courseId + "-" + groupId }
    public let courseId: String
    public let courseTitle: String
    public let groupId: String
    public let groupName: String
    public let dayName: String
    public let time: String
    public let platform: String
}

public struct LiveDeepSyncSheet: View {
    @Environment(\.dismiss) var dismiss
    @EnvironmentObject var appState: AppState
    
    @State private var currentStatus: String = "Starte UNIBODY Deep-Sync..."
    @State private var progress: Double = 0.15
    @State private var isSuccess: Bool = false
    @State private var detectedGroups: [LiveDetectedGroup] = []
    @State private var errorMessage: String? = nil
    
    public init() {}
    
    public var body: some View {
        NavigationStack {
            ZStack {
                Color(red: 0.02, green: 0.07, blue: 0.14).ignoresSafeArea()
                
                VStack(spacing: 0) {
                    // Header Card
                    VStack(spacing: 12) {
                        HStack {
                            ZStack {
                                if isSuccess {
                                    Circle()
                                        .fill(AeroTheme.emerald.opacity(0.2))
                                        .frame(width: 40, height: 40)
                                } else {
                                    Circle()
                                        .fill(AeroTheme.oceanGradient)
                                        .frame(width: 40, height: 40)
                                }
                                Image(systemName: isSuccess ? "checkmark.circle.fill" : "arrow.triangle.2.circlepath")
                                    .font(.system(size: 20, weight: .bold))
                                    .foregroundColor(isSuccess ? AeroTheme.emerald : .white)
                            }
                            
                            VStack(alignment: .leading, spacing: 2) {
                                Text("UNIBODY Deep-Sync")
                                    .font(.system(.headline, design: .rounded).weight(.bold))
                                    .foregroundColor(.white)
                                
                                Text("Liest gebuchte Übungen aus OpenOlat & Moodle aus")
                                    .font(.caption2)
                                    .foregroundColor(.white.opacity(0.75))
                            }
                            
                            Spacer()
                            
                            if isSuccess {
                                AeroBadge("\(detectedGroups.count) Gefunden", color: AeroTheme.emerald)
                            } else {
                                ProgressView()
                                    .progressViewStyle(CircularProgressViewStyle(tint: AeroTheme.skyBlue))
                                    .scaleEffect(0.85)
                            }
                        }
                        
                        // Live Status Banner
                        HStack(spacing: 8) {
                            Image(systemName: "sparkles")
                                .foregroundColor(AeroTheme.skyBlue)
                                .font(.caption)
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
                                        : LinearGradient(colors: [AeroTheme.skyBlue, Color.cyan], startPoint: .leading, endPoint: .trailing)
                                    )
                                    .frame(width: geo.size.width * CGFloat(progress), height: 6)
                                    .animation(.easeInOut(duration: 0.35), value: progress)
                            }
                        }
                        .frame(height: 6)
                    }
                    .padding()
                    .background(Color(red: 0.05, green: 0.12, blue: 0.22))
                    
                    // Detected Groups List if any found
                    if !detectedGroups.isEmpty {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("✅ Im Wochenplan gebuchte Übungen:")
                                .font(.caption.weight(.bold))
                                .foregroundColor(AeroTheme.emerald)
                                .padding(.horizontal, 16)
                                .padding(.top, 10)
                            
                            ScrollView(.horizontal, showsIndicators: false) {
                                HStack(spacing: 10) {
                                    ForEach(detectedGroups) { dg in
                                        VStack(alignment: .leading, spacing: 3) {
                                            HStack {
                                                Text(dg.courseId)
                                                    .font(.caption.weight(.bold))
                                                    .foregroundColor(.white)
                                                Spacer()
                                                AeroBadge(dg.platform, color: AeroTheme.emerald)
                                            }
                                            Text(dg.groupName)
                                                .font(.caption2)
                                                .foregroundColor(.white.opacity(0.85))
                                                .lineLimit(1)
                                            Text("🗓️ \(dg.dayName), \(dg.time)")
                                                .font(.system(size: 10, weight: .medium))
                                                .foregroundColor(AeroTheme.skyBlue)
                                        }
                                        .padding(10)
                                        .frame(width: 220)
                                        .background(Color.white.opacity(0.08))
                                        .clipShape(RoundedRectangle(cornerRadius: 12))
                                    }
                                }
                                .padding(.horizontal, 16)
                            }
                        }
                    }
                    
                    // Live WebKit View
                    LiveDeepSyncWebView(
                        username: appState.username,
                        password: appState.password,
                        courses: appState.courses,
                        onStatusUpdate: { status, prog in
                            self.currentStatus = status
                            self.progress = prog
                        },
                        onSuccess: { matches in
                            self.isSuccess = true
                            self.progress = 1.0
                            self.detectedGroups = matches
                            
                            // Automatically apply each detected match into app state
                            for m in matches {
                                appState.enrollInGroup(courseId: m.courseId, groupId: m.groupId)
                            }
                            
                            let count = matches.count
                            let summary = count > 0
                                ? "✅ Deep-Sync erfolgreich: \(count) belegte Übung\(count == 1 ? "" : "en") synchronisiert!"
                                : "🔍 Keine aktiven Übungs-Buchungen auf OpenOlat oder Moodle gefunden."
                            self.currentStatus = summary
                            appState.syncMessage = summary
                            appState.deepSyncMessage = summary
                            appState.lastSyncDate = Date()
                            
                            #if canImport(UIKit)
                            UINotificationFeedbackGenerator().notificationOccurred(.success)
                            #endif
                            
                            DispatchQueue.main.asyncAfter(deadline: .now() + 2.5) {
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
                    
                    // Bottom Done Button
                    Button {
                        dismiss()
                    } label: {
                        HStack(spacing: 8) {
                            Image(systemName: isSuccess ? "checkmark.circle.fill" : "xmark.circle")
                                .font(.system(size: 16, weight: .bold))
                            Text(isSuccess ? "Fertig" : "Schließen")
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
        }
    }
}

private struct LiveDeepSyncWebView: UIViewRepresentable {
    let username: String
    let password: String
    let courses: [Course]
    let onStatusUpdate: (String, Double) -> Void
    let onSuccess: ([LiveDetectedGroup]) -> Void
    let onError: (String) -> Void
    
    func makeCoordinator() -> Coordinator {
        Coordinator(parent: self)
    }
    
    func makeUIView(context: Context) -> WKWebView {
        let config = WKWebViewConfiguration()
        config.websiteDataStore = WKWebsiteDataStore.default()
        
        let wv = WKWebView(frame: .zero, configuration: config)
        wv.navigationDelegate = context.coordinator
        wv.customUserAgent = "Mozilla/5.0 (iPhone; CPU iPhone OS 27_0 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/18.0 Mobile/15E148 Safari/604.1 UNIBODY-iOS"
        wv.isOpaque = false
        wv.backgroundColor = .clear
        
        context.coordinator.webView = wv
        context.coordinator.startDeepSync()
        return wv
    }
    
    func updateUIView(_ uiView: WKWebView, context: Context) {}
    
    class Coordinator: NSObject, WKNavigationDelegate {
        let parent: LiveDeepSyncWebView
        weak var webView: WKWebView?
        private var pollTimer: Timer?
        private var hasSucceeded = false
        private var stepCounter = 0
        private var scannedOpenOlat = false
        private var scannedMoodle = false
        private var detectedMatches: [LiveDetectedGroup] = []
        
        init(parent: LiveDeepSyncWebView) {
            self.parent = parent
        }
        
        deinit {
            pollTimer?.invalidate()
        }
        
        func startDeepSync() {
            guard let wv = webView else { return }
            parent.onStatusUpdate("Lade OpenOlat Meine Gruppen...", 0.20)
            
            let url = URL(string: "https://lms.uni-kiel.de/url/GroupsSite/0")!
            wv.load(URLRequest(url: url))
            
            pollTimer?.invalidate()
            let timer = Timer(timeInterval: 0.45, repeats: true) { [weak self] _ in
                self?.runDeepSyncStep()
            }
            RunLoop.main.add(timer, forMode: .common)
            self.pollTimer = timer
        }
        
        func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
            runDeepSyncStep()
        }
        
        private func runDeepSyncStep() {
            guard !hasSucceeded, let wv = webView else { return }
            stepCounter += 1
            
            let effectiveUser = parent.username.trimmingCharacters(in: .whitespacesAndNewlines)
            let effectivePass = parent.password
            
            guard !effectiveUser.isEmpty, !effectivePass.isEmpty else {
                parent.onError("⚠️ Keine Zugangsdaten hinterlegt. Bitte trage deine stu-Kennung & Passwort im Tab 'Login & Tresor' ein.")
                return
            }
            
            // Build courses catalog metadata for JavaScript group matching
            var catalogList: [[String: Any]] = []
            for c in parent.courses {
                var groupList: [[String: Any]] = []
                for g in c.groups {
                    groupList.append([
                        "groupId": g.groupId,
                        "name": g.name,
                        "day": g.day,
                        "dayName": g.dayName,
                        "startTime": g.startTime,
                        "endTime": g.endTime,
                        "room": g.room,
                        "tutor": g.tutor
                    ])
                }
                catalogList.append([
                    "courseId": c.courseId,
                    "title": c.title,
                    "univisId": c.univisId,
                    "olatRepoId": c.olatRepoId,
                    "platformId": c.platformId,
                    "platformHost": c.platformHost,
                    "groups": groupList
                ])
            }
            
            let params: [String: Any] = [
                "username": effectiveUser,
                "password": effectivePass,
                "catalog": catalogList
            ]
            
            guard let jsonData = try? JSONSerialization.data(withJSONObject: params),
                  let jsonString = String(data: jsonData, encoding: .utf8) else { return }
            
            let js = """
            (function() {
                const PARAMS = \(jsonString);
                const USERNAME = PARAMS.username;
                const PASSWORD = PARAMS.password;
                const CATALOG = PARAMS.catalog;
                
                function setVal(el, val) {
                    if (!el || val === undefined || val === null) return false;
                    try {
                        el.focus();
                        const proto = Object.getOwnPropertyDescriptor(window.HTMLInputElement.prototype, 'value');
                        if (proto && proto.set) { proto.set.call(el, val); } else { el.value = val; }
                        if (window.jQuery) { try { window.jQuery(el).val(val).trigger('input').trigger('change'); } catch(e) {} }
                        el.dispatchEvent(new Event('input', { bubbles: true }));
                        el.dispatchEvent(new Event('change', { bubbles: true }));
                        return true;
                    } catch (e) { el.value = val; return true; }
                }
                
                function triggerOlatSubmit() {
                    const du = document.getElementById('ofo_oolat_login_dispatchuri');
                    const ev = document.getElementById('ofo_oolat_login_eventval');
                    if (du) du.value = 'o_fiooolat_login_button';
                    if (ev) ev.value = '2';
                    if (window.o_info) window.o_info.preventOnchange = true;
                    const btn = document.getElementById('o_fiooolat_login_button');
                    if (btn) {
                        try { if (typeof btn.onclick === 'function') btn.onclick.call(btn, new MouseEvent('click', { bubbles: true, cancelable: true })); } catch(e) {}
                        btn.click();
                        btn.dispatchEvent(new MouseEvent('click', { bubbles: true, cancelable: true, view: window }));
                    }
                    if (typeof window.o_XHRSubmit === 'function') {
                        try { window.o_XHRSubmit('ofo_oolat_login'); } catch(e) {}
                    }
                }
                
                // 1. OPENOLAT LOGIN
                const olatNameInput = document.getElementById('o_fiooolat_login_name');
                const olatPassInput = document.getElementById('o_fiooolat_login_pass');
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
                if (olatNameInput && olatNameInput.offsetParent !== null) {
                    setVal(olatNameInput, USERNAME);
                    const now = Date.now();
                    if (!window.__lastStep1Ts || (now - window.__lastStep1Ts > 2500)) {
                        window.__lastStep1Ts = now;
                        setTimeout(triggerOlatSubmit, 100);
                    }
                    return { action: "LOGIN_STEP1", msg: "Melde " + USERNAME + " an..." };
                }
                
                // 2. MOODLE LOGIN
                const moodleUser = document.querySelector('form#login input#username, input[name="username"]');
                const moodlePass = document.querySelector('form#login input#password, input[name="password"]');
                const moodleBtn = document.querySelector('form#login button#loginbtn, button[type="submit"]');
                if (moodleUser && moodlePass && moodleBtn && moodleUser.offsetParent !== null) {
                    setVal(moodleUser, USERNAME);
                    setVal(moodlePass, PASSWORD);
                    setTimeout(() => { moodleBtn.click(); }, 120);
                    return { action: "LOGIN_GENERIC", msg: "CAU-Zentral-Login..." };
                }
                
                // 3. SCAN OPENOLAT 'MEINE GRUPPEN' (url/GroupsSite/0)
                if (location.href.includes('GroupsSite') || location.href.includes('groups')) {
                    const table = document.querySelector('table.o_table, table.table');
                    if (table) {
                        const rows = Array.from(table.querySelectorAll('tbody tr'));
                        const matches = [];
                        
                        for (const tr of rows) {
                            const rowText = (tr.innerText || '').toLowerCase();
                            for (const c of CATALOG) {
                                const cid = c.courseId.toLowerCase();
                                const cUniv = (c.univisId || '').toLowerCase();
                                const cOlat = (c.olatRepoId || '').toLowerCase();
                                const cTitle = (c.title || '').toLowerCase();
                                
                                const matchCourse = (cUniv && rowText.includes(cUniv)) ||
                                                    (cOlat && rowText.includes(cOlat)) ||
                                                    rowText.includes(cid) ||
                                                    (cTitle.length > 5 && rowText.includes(cTitle.slice(0, 15)));
                                
                                if (matchCourse) {
                                    // Match specific group
                                    let matchedGroup = null;
                                    for (const g of c.groups) {
                                        const gName = (g.name || '').toLowerCase();
                                        const gDay = (g.dayName || '').toLowerCase();
                                        const gTime = (g.startTime || '').toLowerCase();
                                        const gId = (g.groupId || '').toLowerCase();
                                        
                                        if (rowText.includes(gId) || (rowText.includes(gDay) && rowText.includes(gTime)) || (gName.length > 4 && rowText.includes(gName))) {
                                            matchedGroup = g;
                                            break;
                                        }
                                    }
                                    if (!matchedGroup && c.groups.length > 0) {
                                        matchedGroup = c.groups[0];
                                    }
                                    if (matchedGroup) {
                                        matches.push({
                                            courseId: c.courseId,
                                            courseTitle: c.title,
                                            groupId: matchedGroup.groupId,
                                            groupName: matchedGroup.name,
                                            dayName: matchedGroup.dayName,
                                            time: matchedGroup.startTime + "–" + matchedGroup.endTime,
                                            platform: "OpenOlat"
                                        });
                                    }
                                }
                            }
                        }
                        return { action: "SCANNED_OPENOLAT", matches: matches, rowCount: rows.length };
                    }
                }
                
                // 4. SCAN MOODLE DASHBOARD / CHOICEGROUPS
                if (location.href.includes('elearn.informatik')) {
                    const checkedRadios = Array.from(document.querySelectorAll('input[type="radio"]:checked'));
                    const choiceRows = Array.from(document.querySelectorAll('.results tr, .choicegroup tr, .table tr'));
                    const matches = [];
                    
                    for (const c of CATALOG) {
                        if (c.platformId === 'moodle_info' || c.platformHost.includes('elearn.informatik')) {
                            for (const g of c.groups) {
                                const gName = (g.name || '').toLowerCase();
                                for (const r of checkedRadios) {
                                    const parentText = (r.closest('tr, label, div') || document.body).innerText.toLowerCase();
                                    if (parentText.includes(gName) || parentText.includes(g.groupId.toLowerCase())) {
                                        matches.push({
                                            courseId: c.courseId,
                                            courseTitle: c.title,
                                            groupId: g.groupId,
                                            groupName: g.name,
                                            dayName: g.dayName,
                                            time: g.startTime + "–" + g.endTime,
                                            platform: "Moodle"
                                        });
                                    }
                                }
                            }
                        }
                    }
                    return { action: "SCANNED_MOODLE", matches: matches };
                }
                
                return { action: "WAITING", msg: "Lade Daten..." };
            })()
            """
            
            wv.evaluateJavaScript(js) { [weak self] result, error in
                guard let self = self, let dict = result as? [String: Any] else { return }
                let action = dict["action"] as? String ?? ""
                let msg = dict["msg"] as? String ?? ""
                
                switch action {
                case "LOGIN_STEP1":
                    self.parent.onStatusUpdate(msg, 0.35)
                case "LOGIN_STEP2":
                    self.parent.onStatusUpdate(msg, 0.50)
                case "LOGIN_GENERIC":
                    self.parent.onStatusUpdate(msg, 0.45)
                case "SCANNED_OPENOLAT":
                    if !self.scannedOpenOlat {
                        self.scannedOpenOlat = true
                        self.parent.onStatusUpdate("OpenOlat Gruppen analysiert...", 0.75)
                        
                        var newMatches: [LiveDetectedGroup] = []
                        if let rawMatches = dict["matches"] as? [[String: Any]] {
                            for rm in rawMatches {
                                let cId = (rm["courseId"] as? String) ?? ""
                                let cTitle = (rm["courseTitle"] as? String) ?? ""
                                let gId = (rm["groupId"] as? String) ?? ""
                                let gName = (rm["groupName"] as? String) ?? ""
                                let day = (rm["dayName"] as? String) ?? ""
                                let time = (rm["time"] as? String) ?? ""
                                let platform = (rm["platform"] as? String) ?? "OpenOlat"
                                
                                if !cId.isEmpty && !gId.isEmpty {
                                    newMatches.append(LiveDetectedGroup(
                                        courseId: cId,
                                        courseTitle: cTitle,
                                        groupId: gId,
                                        groupName: gName,
                                        dayName: day,
                                        time: time,
                                        platform: platform
                                    ))
                                }
                            }
                        }
                        self.detectedMatches.append(contentsOf: newMatches)
                        
                        // Check if we need to scan Moodle next
                        let hasMoodleCourses = self.parent.courses.contains { $0.platformId.contains("moodle") || $0.platformHost.contains("elearn") }
                        if hasMoodleCourses && !self.scannedMoodle {
                            self.parent.onStatusUpdate("Öffne Informatik-Moodle...", 0.85)
                            wv.load(URLRequest(url: URL(string: "https://elearn.informatik.uni-kiel.de/my/")!))
                        } else {
                            self.finishSuccess()
                        }
                    }
                case "SCANNED_MOODLE":
                    if !self.scannedMoodle {
                        self.scannedMoodle = true
                        self.parent.onStatusUpdate("Moodle Gruppen synchronisiert...", 0.95)
                        if let rawMatches = dict["matches"] as? [[String: Any]] {
                            for rm in rawMatches {
                                let cId = (rm["courseId"] as? String) ?? ""
                                let cTitle = (rm["courseTitle"] as? String) ?? ""
                                let gId = (rm["groupId"] as? String) ?? ""
                                let gName = (rm["groupName"] as? String) ?? ""
                                let day = (rm["dayName"] as? String) ?? ""
                                let time = (rm["time"] as? String) ?? ""
                                let platform = (rm["platform"] as? String) ?? "Moodle"
                                
                                if !cId.isEmpty && !gId.isEmpty && !self.detectedMatches.contains(where: { $0.courseId.lowercased() == cId.lowercased() }) {
                                    self.detectedMatches.append(LiveDetectedGroup(
                                        courseId: cId,
                                        courseTitle: cTitle,
                                        groupId: gId,
                                        groupName: gName,
                                        dayName: day,
                                        time: time,
                                        platform: platform
                                    ))
                                }
                            }
                        }
                        self.finishSuccess()
                    }
                default:
                    break
                }
            }
        }
        
        private func finishSuccess() {
            guard !hasSucceeded else { return }
            hasSucceeded = true
            pollTimer?.invalidate()
            pollTimer = nil
            
            DispatchQueue.main.async { [weak self] in
                guard let self = self else { return }
                self.parent.onSuccess(self.detectedMatches)
            }
        }
    }
}
