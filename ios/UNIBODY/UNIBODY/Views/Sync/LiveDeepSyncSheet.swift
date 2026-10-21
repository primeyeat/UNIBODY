import SwiftUI
import WebKit

public struct LiveDetectedGroup: Identifiable, Equatable {
    public var id: String { courseId + "-" + groupId }
    public let courseId: String
    public let courseTitle: String
    public let groupId: String
    public let groupName: String
    public let day: Int
    public let dayName: String
    public let startTime: String
    public let endTime: String
    public let time: String
    public let room: String
    public let weekType: String
    public let platform: String
    
    public init(
        courseId: String,
        courseTitle: String,
        groupId: String,
        groupName: String,
        day: Int,
        dayName: String,
        startTime: String,
        endTime: String,
        time: String,
        room: String = "CAU Campus",
        weekType: String = "all",
        platform: String = "OpenOlat"
    ) {
        self.courseId = courseId
        self.courseTitle = courseTitle
        self.groupId = groupId
        self.groupName = groupName
        self.day = day
        self.dayName = dayName
        self.startTime = startTime
        self.endTime = endTime
        self.time = time
        self.room = room
        self.weekType = weekType
        self.platform = platform
    }
}

public struct LiveDeepSyncSheet: View {
    @Environment(\.dismiss) var dismiss
    @EnvironmentObject var appState: AppState
    
    @State private var currentStatus: String = "Starte UNIBODY Deep-Sync..."
    @State private var progress: Double = 0.10
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
                                
                                Text("Liest gebuchte Übungen live aus den echten Kursen aus")
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
                            HStack {
                                Text("✅ Im Wochenplan gebuchte Übungen:")
                                    .font(.caption.weight(.bold))
                                    .foregroundColor(AeroTheme.emerald)
                                Spacer()
                                Text("\(detectedGroups.count) verifiziert")
                                    .font(.caption2)
                                    .foregroundColor(.white.opacity(0.7))
                            }
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
                                                if dg.weekType != "all" {
                                                    AeroBadge("Woche \(dg.weekType)", color: AeroTheme.solarOrange)
                                                }
                                                AeroBadge(dg.platform, color: AeroTheme.emerald)
                                            }
                                            Text(dg.groupName)
                                                .font(.caption2)
                                                .foregroundColor(.white.opacity(0.85))
                                                .lineLimit(1)
                                            Text("🗓️ \(dg.dayName), \(dg.time) · \(dg.room)")
                                                .font(.system(size: 10, weight: .medium))
                                                .foregroundColor(AeroTheme.skyBlue)
                                                .lineLimit(1)
                                        }
                                        .padding(10)
                                        .frame(width: 240)
                                        .background(Color.white.opacity(0.08))
                                        .clipShape(RoundedRectangle(cornerRadius: 12))
                                    }
                                }
                                .padding(.horizontal, 16)
                            }
                        }
                    }
                    
                    // Live WebKit View with Frutiger Aero Glass Window Frame
                    ZStack {
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
                                
                                // 1. Wipe old enrolled exercise events to prevent bogus duplicates
                                appState.schedule.removeAll { $0.type == "enrolled_exercise" }
                                appState.enrolledGroups.removeAll()
                                for i in 0..<appState.courses.count {
                                    appState.courses[i].enrolledGroupId = nil
                                }
                                
                                // 2. Apply verified matches into AppState
                                for m in matches {
                                    appState.enrollInGroup(
                                        courseId: m.courseId,
                                        groupId: m.groupId,
                                        customName: m.groupName,
                                        day: m.day,
                                        dayName: m.dayName,
                                        startTime: m.startTime,
                                        endTime: m.endTime,
                                        room: m.room,
                                        weekType: m.weekType
                                    )
                                }
                                
                                let count = matches.count
                                let summary = count > 0
                                    ? "✅ Deep-Sync: \(count) Übung\(count == 1 ? "" : "en") mit echten Live-Terminen synchronisiert!"
                                    : "🔍 Keine aktiven Übungs-Einschreibungen auf CAU LMS gefunden."
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
                        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                        
                        // Glass Border Overlay
                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .strokeBorder(
                                LinearGradient(
                                    colors: [Color.white.opacity(0.35), Color.white.opacity(0.08)],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                ),
                                lineWidth: 1
                            )
                            .allowsHitTesting(false)
                    }
                    .padding(.horizontal, 12)
                    .padding(.top, 8)
                    .padding(.bottom, 6)
                    
                    // Bottom Done / Close Button
                    Button {
                        dismiss()
                    } label: {
                        HStack(spacing: 8) {
                            Image(systemName: isSuccess ? "checkmark.circle.fill" : "xmark.circle")
                                .font(.system(size: 16, weight: .bold))
                            Text(isSuccess ? "Fertig (\(detectedGroups.count) synchronisiert)" : "Schließen")
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
        let webpagePrefs = WKWebpagePreferences()
        webpagePrefs.allowsContentJavaScript = true
        config.defaultWebpagePreferences = webpagePrefs
        
        let wv = WKWebView(frame: .zero, configuration: config)
        wv.customUserAgent = "Mozilla/5.0 (iPhone; CPU iPhone OS 27_0 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/18.0 Mobile/15E148 Safari/604.1 UNIBODY-iOS"
        wv.isOpaque = false
        wv.backgroundColor = .clear
        wv.navigationDelegate = context.coordinator
        
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
        
        // Multi-course queue for live ground-truth scraping
        private var coursesToScan: [Course] = []
        private var currentCourseIndex: Int = 0
        private var currentCourseTicks: Int = 0
        private var detectedMatches: [LiveDetectedGroup] = []
        
        init(parent: LiveDeepSyncWebView) {
            self.parent = parent
        }
        
        deinit {
            pollTimer?.invalidate()
        }
        
        func startDeepSync() {
            guard let wv = webView else { return }
            
            // Prioritize courses that have exercise groups
            coursesToScan = parent.courses.filter { !$0.isLectureOnly }
            currentCourseIndex = 0
            currentCourseTicks = 0
            detectedMatches.removeAll()
            
            guard !coursesToScan.isEmpty else {
                parent.onStatusUpdate("Keine Übungskurse zum Abfragen gefunden.", 1.0)
                finishSuccess()
                return
            }
            
            loadCurrentCourse()
            
            pollTimer?.invalidate()
            let timer = Timer(timeInterval: 0.40, repeats: true) { [weak self] _ in
                self?.runDeepSyncStep()
            }
            RunLoop.main.add(timer, forMode: .common)
            self.pollTimer = timer
        }
        
        private func loadCurrentCourse() {
            guard let wv = webView, currentCourseIndex < coursesToScan.count else {
                finishSuccess()
                return
            }
            
            currentCourseTicks = 0
            let course = coursesToScan[currentCourseIndex]
            let fraction = Double(currentCourseIndex) / Double(max(1, coursesToScan.count))
            let prog = 0.20 + fraction * 0.70
            
            parent.onStatusUpdate("Öffne \(course.title)... (\(currentCourseIndex + 1)/\(coursesToScan.count))", prog)
            wv.load(URLRequest(url: course.targetEnrollmentURL))
        }
        
        private func advanceToNextCourse() {
            currentCourseIndex += 1
            if currentCourseIndex < coursesToScan.count {
                loadCurrentCourse()
            } else {
                finishSuccess()
            }
        }
        
        func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
            runDeepSyncStep()
        }
        
        private func runDeepSyncStep() {
            guard !hasSucceeded, let wv = webView else { return }
            guard currentCourseIndex < coursesToScan.count else {
                finishSuccess()
                return
            }
            
            currentCourseTicks += 1
            stepCounter += 1
            
            let effectiveUser = parent.username.trimmingCharacters(in: .whitespacesAndNewlines)
            let effectivePass = parent.password
            
            guard !effectiveUser.isEmpty, !effectivePass.isEmpty else {
                parent.onError("⚠️ Keine Zugangsdaten hinterlegt. Bitte trage deine stu-Kennung & Passwort im Tab 'Login & Tresor' ein.")
                return
            }
            
            let course = coursesToScan[currentCourseIndex]
            
            // Timeout per course: If after ~20 ticks (8.0s) nothing found, move to next course
            if currentCourseTicks > 20 {
                advanceToNextCourse()
                return
            }
            
            var groupList: [[String: Any]] = []
            for g in course.groups {
                groupList.append([
                    "groupId": g.groupId,
                    "name": g.name,
                    "day": g.day,
                    "dayName": g.dayName,
                    "startTime": g.startTime,
                    "endTime": g.endTime,
                    "room": g.room
                ])
            }
            
            let courseMeta: [String: Any] = [
                "courseId": course.courseId,
                "title": course.title,
                "platformId": course.platformId,
                "groups": groupList
            ]
            
            let params: [String: Any] = [
                "username": effectiveUser,
                "password": effectivePass,
                "currentCourse": courseMeta
            ]
            
            guard let jsonData = try? JSONSerialization.data(withJSONObject: params),
                  let jsonString = String(data: jsonData, encoding: .utf8) else { return }
            
            let js = """
            (function() {
                const PARAMS = \(jsonString);
                const USERNAME = PARAMS.username;
                const PASSWORD = PARAMS.password;
                const COURSE = PARAMS.currentCourse;
                
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
                
                function parseGermanTimeslot(text) {
                    if (!text) return null;
                    const lower = text.toLowerCase();
                    let day = -1;
                    let dayName = "Montag";
                    if (lower.includes("montag") || /\\bmo\\b/.test(lower)) { day = 0; dayName = "Montag"; }
                    else if (lower.includes("dienstag") || /\\bdi\\b/.test(lower)) { day = 1; dayName = "Dienstag"; }
                    else if (lower.includes("mittwoch") || /\\bmi\\b/.test(lower)) { day = 2; dayName = "Mittwoch"; }
                    else if (lower.includes("donnerstag") || /\\bdo\\b/.test(lower)) { day = 3; dayName = "Donnerstag"; }
                    else if (lower.includes("freitag") || /\\bfr\\b/.test(lower)) { day = 4; dayName = "Freitag"; }
                    
                    let startTime = "10:15";
                    let endTime = "11:45";
                    const tm = lower.match(/(\\d{1,2})[:.](\\d{2})\\s*(?:-|–|bis)\\s*(\\d{1,2})[:.](\\d{2})/);
                    if (tm) {
                        startTime = tm[1].padStart(2, '0') + ":" + tm[2];
                        endTime = tm[3].padStart(2, '0') + ":" + tm[4];
                    } else {
                        const sm = lower.match(/\\b(\\d{1,2})\\s*(?:-|–|bis)\\s*(\\d{1,2})\\b/);
                        if (sm) {
                            startTime = sm[1].padStart(2, '0') + ":15";
                            endTime = sm[2].padStart(2, '0') + ":45";
                        }
                    }
                    if (day !== -1) {
                        return { day, dayName, startTime, endTime, time: startTime + "–" + endTime };
                    }
                    return null;
                }
                
                // 1. OPENOLAT LOGIN DETECTION
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
                    return { action: "LOGIN_STEP2", msg: "Übermittle CAU-Passwort an OpenOlat..." };
                }
                if (olatNameInput && olatNameInput.offsetParent !== null) {
                    setVal(olatNameInput, USERNAME);
                    const now = Date.now();
                    if (!window.__lastStep1Ts || (now - window.__lastStep1Ts > 2500)) {
                        window.__lastStep1Ts = now;
                        setTimeout(triggerOlatSubmit, 100);
                    }
                    return { action: "LOGIN_STEP1", msg: "Melde " + USERNAME + " bei OpenOlat an..." };
                }
                
                // 2. MOODLE LOGIN DETECTION
                const moodleUser = document.querySelector('form#login input#username, input[name="username"]');
                const moodlePass = document.querySelector('form#login input#password, input[name="password"]');
                const moodleBtn = document.querySelector('form#login button#loginbtn, button[type="submit"], input[type="submit"]');
                if (moodleUser && moodlePass && moodleBtn && moodleUser.offsetParent !== null) {
                    setVal(moodleUser, USERNAME);
                    setVal(moodlePass, PASSWORD);
                    setTimeout(() => { moodleBtn.click(); }, 120);
                    return { action: "LOGIN_GENERIC", msg: "Melde bei Informatik-Moodle an..." };
                }
                
                // 3. TREE NAVIGATION: Find & Click "Übung" / "Anmeldung zur Übung"
                function openExerciseSection() {
                    const closeBtn = document.querySelector('.modal-header .close, button.close, .o_modal_close');
                    if (closeBtn) closeBtn.click();
                    
                    const allLinks = Array.from(document.querySelectorAll('#o_main_left a, .o_tree a, .o_course_menu a, nav a, .o_subnav a, a.o_tree_link, a.o_tree_opener, #o_main_container a'));
                    
                    // 1. Expand tree folder if closed: e.g. "Unterelemente von Übung"
                    const ubOpener = allLinks.find(el => {
                        const title = (el.getAttribute('title') || '').toLowerCase();
                        const txt = (el.innerText || '').toLowerCase();
                        return title.includes('unterelemente von übung') || title.includes('unterelemente von uebung') || (el.classList.contains('o_tree_opener') && (title.includes('übung') || txt.includes('übung')));
                    });
                    if (ubOpener) {
                        let code = (ubOpener.getAttribute('onclick') || '').replace(/return\\s+false\\s*;?/g, '');
                        if (code) {
                            try { (new Function(code)).call(ubOpener); } catch(e) {}
                        }
                        ubOpener.click();
                    }
                    
                    // 2. Click specific registration node
                    let target = allLinks.find(el => {
                        const txt = (el.innerText || '').trim().toLowerCase();
                        return txt === 'anmeldung zur übung' || txt === 'anmeldung zur uebung' ||
                               txt === 'anmeldung' || txt === 'einschreibung' || 
                               txt === 'übungsgruppen' || txt === 'uebungsgruppen' || 
                               txt === 'gruppenwahl';
                    });
                    
                    if (!target) {
                        target = allLinks.find(el => {
                            const txt = (el.innerText || '').trim().toLowerCase();
                            return /(?:anmeldung|einschreib|gruppenwahl|übungsgruppe|uebungsgruppe)/i.test(txt);
                        });
                    }
                    
                    if (!target) {
                        target = allLinks.find(el => {
                            const txt = (el.innerText || '').trim().toLowerCase();
                            return txt === 'übung' || txt === 'uebung' || txt === 'übungen' || txt === 'uebungen';
                        });
                    }
                    
                    if (target) {
                        const now = Date.now();
                        if (!window.__lastTreeClick || (now - window.__lastTreeClick > 2500)) {
                            window.__lastTreeClick = now;
                            let code = (target.getAttribute('onclick') || '').replace(/return\\s+false\\s*;?/g, '');
                            if (code) {
                                try { (new Function(code)).call(target); } catch(e) {}
                            }
                            target.click();
                            target.dispatchEvent(new MouseEvent('click', { bubbles: true, cancelable: true, view: window }));
                            return (target.innerText || 'Übung').trim();
                        }
                    }
                    return null;
                }
                
                // 4. FIND EXERCISE TABLE (Must have capacity or enrollment actions)
                function findExerciseTable() {
                    const tables = Array.from(document.querySelectorAll('table.o_table, table.table'));
                    for (const t of tables) {
                        const html = t.innerHTML.toLowerCase();
                        const text = t.innerText.toLowerCase();
                        const hasCapacity = /\\d+\\s*\\/\\s*\\d+/.test(text);
                        const hasEnrollAction = /cmd\\.enrolled\\.cancel|cmd\\.cancel|einschreiben|austragen|abmelden/i.test(html);
                        const hasGroupRows = /gruppe|gr\\.|übung|uebung/i.test(text);
                        
                        // Exclude overview tables that only show the course container "EBWL 26/27"
                        if ((hasCapacity || hasEnrollAction) && hasGroupRows) {
                            return t;
                        }
                    }
                    if (tables.length === 1) {
                        const text = tables[0].innerText.toLowerCase();
                        if (/\\d+\\s*\\/\\s*\\d+/.test(text) || /cmd\\.enrolled\\.cancel|einschreiben|austragen/i.test(tables[0].innerHTML)) {
                            return tables[0];
                        }
                    }
                    return null;
                }
                
                // 5. EXECUTE NAVIGATION & SCRAPING
                if (location.hostname.includes('lms.uni-kiel.de')) {
                    const table = findExerciseTable();
                    
                    if (table) {
                        const rows = Array.from(table.querySelectorAll('tbody tr'));
                        let enrolledRowFound = null;
                        
                        for (const tr of rows) {
                            const text = (tr.innerText || '').toLowerCase();
                            const isEnrolled = text.includes('eingeschrieben') || 
                                               text.includes('angemeldet') || 
                                               tr.querySelector('a[onclick*="cmd.enrolled.cancel"], a[onclick*="cmd.cancel"], a[onclick*="cancel"]') !== null ||
                                               Array.from(tr.querySelectorAll('a, button')).some(b => /austragen|abmelden/i.test(b.innerText || b.value || ''));
                            
                            // Exclude "nicht eingeschrieben"
                            if (isEnrolled && !text.includes('nicht eingeschrieben')) {
                                const tds = Array.from(tr.querySelectorAll('td, th')).map(td => (td.innerText || '').trim());
                                const rawName = tds[0] || (tr.querySelector('td') ? tr.querySelector('td').innerText : '');
                                const rawDesc = tds[1] || '';
                                const combined = `${rawName} ${rawDesc}`;
                                const slot = parseGermanTimeslot(combined);
                                
                                // Extract exact room if present
                                let room = "CAU Campus";
                                const roomMatch = combined.match(/([a-z0-9]+\\s*-\\s*r\\.[a-z0-9./]+|[a-z0-9]+\\s*-\\s*hörsaal\\s*\\d+|cap\\d+\\s*-\\s*[^\\n,]+)/i);
                                if (roomMatch) {
                                    room = roomMatch[1].trim();
                                }
                                
                                // Extract weekType if present
                                let weekType = "all";
                                if (/(?:woche\\s*a|\\bw1\\b)/i.test(combined)) {
                                    weekType = "A";
                                } else if (/(?:woche\\s*b|\\bw2\\b)/i.test(combined)) {
                                    weekType = "B";
                                }
                                
                                enrolledRowFound = {
                                    groupName: rawName.replace(/\\s+/g, ' ').trim(),
                                    day: slot ? slot.day : 0,
                                    dayName: slot ? slot.dayName : "Montag",
                                    startTime: slot ? slot.startTime : "10:15",
                                    endTime: slot ? slot.endTime : "11:45",
                                    time: slot ? slot.time : "10:15–11:45",
                                    room: room,
                                    weekType: weekType,
                                    hasSlot: slot !== null
                                };
                                break;
                            }
                        }
                        
                        return {
                            action: "SCANNED_COURSE_TABLE",
                            enrolled: enrolledRowFound,
                            rowCount: rows.length
                        };
                    }
                    
                    // Table not present yet -> try clicking left menu!
                    const clickedNode = openExerciseSection();
                    if (clickedNode) {
                        return { action: "CLICKED_NODE", msg: "Öffne " + clickedNode + " für " + COURSE.courseId + "..." };
                    }
                }
                
                // 6. MOODLE CHOICEGROUP LIVE SCRAPE
                if (location.hostname.includes('elearn.informatik')) {
                    const checkedRadio = document.querySelector('input[type="radio"]:checked');
                    if (checkedRadio) {
                        const tr = checkedRadio.closest('tr, label, div') || document.body;
                        const text = (tr.innerText || '').trim();
                        const slot = parseGermanTimeslot(text);
                        return {
                            action: "SCANNED_COURSE_TABLE",
                            enrolled: {
                                groupName: text.split('\\n')[0] || "Moodle Übung",
                                day: slot ? slot.day : 0,
                                dayName: slot ? slot.dayName : "Montag",
                                startTime: slot ? slot.startTime : "10:15",
                                endTime: slot ? slot.endTime : "11:45",
                                time: slot ? slot.time : "10:15–11:45",
                                room: "Informatik-Zentrum",
                                weekType: "all",
                                hasSlot: slot !== null
                            }
                        };
                    }
                }
                
                return { action: "WAITING", msg: "Lade Kursdaten..." };
            })()
            """
            
            wv.evaluateJavaScript(js) { [weak self] result, error in
                guard let self = self, let dict = result as? [String: Any] else { return }
                let action = dict["action"] as? String ?? ""
                let msg = dict["msg"] as? String ?? ""
                
                switch action {
                case "LOGIN_STEP1", "LOGIN_STEP2", "LOGIN_GENERIC", "CLICKED_NODE":
                    self.parent.onStatusUpdate(msg, 0.40)
                case "SCANNED_COURSE_TABLE":
                    let course = self.coursesToScan[self.currentCourseIndex]
                    if let rawEnrolled = dict["enrolled"] as? [String: Any] {
                        let gName = (rawEnrolled["groupName"] as? String) ?? "Übungsgruppe"
                        let day = (rawEnrolled["day"] as? Int) ?? 0
                        let dayName = (rawEnrolled["dayName"] as? String) ?? "Montag"
                        let startTime = (rawEnrolled["startTime"] as? String) ?? "10:15"
                        let endTime = (rawEnrolled["endTime"] as? String) ?? "11:45"
                        let time = (rawEnrolled["time"] as? String) ?? "\(startTime)–\(endTime)"
                        let room = (rawEnrolled["room"] as? String) ?? "CAU Campus"
                        let weekType = (rawEnrolled["weekType"] as? String) ?? "all"
                        let hasSlot = (rawEnrolled["hasSlot"] as? Bool) ?? false
                        
                        // Check if a catalog group matches this real slot
                        var matchedGroupId = course.courseId + "-live"
                        for cg in course.groups {
                            if cg.day == day && cg.startTime == startTime {
                                matchedGroupId = cg.groupId
                                break
                            }
                        }
                        
                        // Only add if genuine slot or real enrolled group verified
                        if hasSlot || !gName.isEmpty {
                            let match = LiveDetectedGroup(
                                courseId: course.courseId,
                                courseTitle: course.title,
                                groupId: matchedGroupId,
                                groupName: gName,
                                day: day,
                                dayName: dayName,
                                startTime: startTime,
                                endTime: endTime,
                                time: time,
                                room: room,
                                weekType: weekType,
                                platform: course.platformId.contains("moodle") ? "Moodle" : "OpenOlat"
                            )
                            if !self.detectedMatches.contains(where: { $0.courseId == course.courseId }) {
                                self.detectedMatches.append(match)
                            }
                        }
                    }
                    
                    // Course scanned! Move directly to the next course in the queue
                    self.advanceToNextCourse()
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
