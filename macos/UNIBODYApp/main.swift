import Cocoa
import WebKit

// UNIBODY for macOS (unofficial student tool).
// A native window around the local web UI. The app starts the
// Python server on 127.0.0.1:8765, shows it in a WKWebView and stops the server
// again when the app quits. Nothing leaves the machine: only the loopback
// address is loaded inside the window, every other link opens in the browser.

private let serverPort: UInt16 = 8765
private let serverURL = URL(string: "http://127.0.0.1:8765/")!

private let launchTime = Date()
private let timingEnabled = ProcessInfo.processInfo.environment["UNIBODY_DEBUG_TIMING"] != nil

/// Prints startup timings when UNIBODY_DEBUG_TIMING is set (run the binary from a terminal).
private func mark(_ label: String) {
    guard timingEnabled else { return }
    FileHandle.standardError.write(String(format: "[timing] %6.0f ms  %@\n", Date().timeIntervalSince(launchTime) * 1000, label).data(using: .utf8)!)
}

final class AppDelegate: NSObject, NSApplicationDelegate, WKNavigationDelegate, WKUIDelegate, WKDownloadDelegate {
    private var window: NSWindow!
    private var webView: WKWebView!
    private var statusLabel: NSTextField!
    private var splashView: NSView!
    private var spinner: NSProgressIndicator!
    private var splashDismissed = false
    private var pendingStatus: String?
    private var serverProcess: Process?
    private var startAttempts = 0

    // MARK: - Lifecycle

    func applicationDidFinishLaunching(_ notification: Notification) {
        mark("didFinishLaunching")
        buildMenu()
        buildWindow()
        mark("window visible")
        if let problem = pendingStatus { showStatus(problem); pendingStatus = nil; return }
        waitForServerThenLoad()
        NSApp.activate(ignoringOtherApps: true)
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        // Keep running without a window so reminders keep working.
        false
    }

    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        showWindow(nil)
        return true
    }

    func applicationWillTerminate(_ notification: Notification) {
        stopServer()
    }

    // MARK: - Server

    /// Where server.py lives and where user data goes.
    /// - Linked build (macos/build_app.sh): the project folder, data in its data/ folder.
    /// - Standalone build (macos/build_dmg.sh): code inside the app bundle,
    ///   data in ~/Library/Application Support/UNIBODY.
    private var serverLocation: (code: URL, data: URL, standalone: Bool)? {
        let fm = FileManager.default
        if let path = Bundle.main.object(forInfoDictionaryKey: "UNIBODYProjectDir") as? String, !path.isEmpty {
            let url = URL(fileURLWithPath: path, isDirectory: true)
            if fm.fileExists(atPath: url.appendingPathComponent("server.py").path) {
                return (url, url.appendingPathComponent("data", isDirectory: true), false)
            }
        }
        if let bundled = Bundle.main.resourceURL?.appendingPathComponent("server", isDirectory: true),
           fm.fileExists(atPath: bundled.appendingPathComponent("server.py").path),
           let support = fm.urls(for: .applicationSupportDirectory, in: .userDomainMask).first {
            return (bundled, support.appendingPathComponent("UNIBODY", isDirectory: true), true)
        }
        return nil
    }

    private var pythonExecutable: URL? {
        let fm = FileManager.default
        let candidates = [
            "/opt/homebrew/bin/python3",
            "/usr/local/bin/python3",
            "/Library/Frameworks/Python.framework/Versions/Current/bin/python3",
            "/Library/Developer/CommandLineTools/usr/bin/python3",
            "/Applications/Xcode.app/Contents/Developer/usr/bin/python3",
        ]
        for candidate in candidates where fm.isExecutableFile(atPath: candidate) {
            return URL(fileURLWithPath: candidate)
        }
        return nil
    }

    /// True when something already listens on the loopback port.
    private func serverIsUp() -> Bool {
        let fd = socket(AF_INET, SOCK_STREAM, 0)
        guard fd >= 0 else { return false }
        defer { close(fd) }
        var addr = sockaddr_in()
        addr.sin_family = sa_family_t(AF_INET)
        addr.sin_port = serverPort.bigEndian
        addr.sin_addr.s_addr = inet_addr("127.0.0.1")
        let result = withUnsafePointer(to: &addr) {
            $0.withMemoryRebound(to: sockaddr.self, capacity: 1) {
                connect(fd, $0, socklen_t(MemoryLayout<sockaddr_in>.size))
            }
        }
        return result == 0
    }

    /// Called before the UI exists so Python boots while the window is being built.
    func startServerIfNeeded() {
        guard !serverIsUp() else { return } // Reuse a server that is already running.
        guard let location = serverLocation else {
            showStatus("Die UNIBODY-Programmdateien wurden nicht gefunden.\nBitte die App neu installieren.")
            return
        }
        guard let python = pythonExecutable else {
            showStatus("Python 3 wurde nicht gefunden.\n\nUNIBODY braucht Python 3.9 oder neuer. Installiere es von python.org oder im Terminal mit\nxcode-select --install\nund öffne UNIBODY danach erneut.")
            return
        }

        let dataDir = location.data
        try? FileManager.default.createDirectory(
            at: dataDir, withIntermediateDirectories: true,
            attributes: [.posixPermissions: 0o700])
        let logURL = dataDir.appendingPathComponent("server.log")
        if !FileManager.default.fileExists(atPath: logURL.path) {
            FileManager.default.createFile(atPath: logURL.path, contents: nil)
        }

        let process = Process()
        process.executableURL = python
        process.arguments = ["server.py"]
        process.currentDirectoryURL = location.code
        var environment = ProcessInfo.processInfo.environment
        environment["PYTHONUNBUFFERED"] = "1"
        if location.standalone {
            environment["UNIBODY_DATA_DIR"] = dataDir.path
            // Cache compiled bytecode outside the signed app bundle: faster starts
            // without ever writing into the bundle.
            environment["PYTHONPYCACHEPREFIX"] = dataDir.appendingPathComponent("pycache").path
            environment.removeValue(forKey: "PYTHONDONTWRITEBYTECODE")
        }
        process.environment = environment
        if let log = try? FileHandle(forWritingTo: logURL) {
            log.seekToEndOfFile()
            process.standardOutput = log
            process.standardError = log
        }
        do {
            try process.run()
            serverProcess = process
        } catch {
            showStatus("Der Server konnte nicht gestartet werden:\n\(error.localizedDescription)")
        }
    }

    private func stopServer() {
        guard let process = serverProcess, process.isRunning else { return }
        process.terminate()
        let deadline = Date().addingTimeInterval(2)
        while process.isRunning && Date() < deadline { usleep(50_000) }
        if process.isRunning { kill(process.processIdentifier, SIGKILL) }
        serverProcess = nil
    }

    private func waitForServerThenLoad() {
        if serverIsUp() {
            // The splash stays on top until the page has actually rendered.
            mark("server up, loading page")
            webView.load(URLRequest(url: serverURL))
            return
        }
        if let process = serverProcess, !process.isRunning {
            showStatus("Der Server wurde unerwartet beendet.\nDetails stehen in der Datei server.log im UNIBODY-Datenordner.")
            return
        }
        startAttempts += 1
        if startAttempts > 1000 { // about 20 seconds
            showStatus("Der Server antwortet nicht.\nDetails stehen in der Datei server.log im UNIBODY-Datenordner.")
            return
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.02) { [weak self] in
            self?.waitForServerThenLoad()
        }
    }

    /// Shows a problem on the splash screen instead of the web UI.
    private func showStatus(_ text: String) {
        guard statusLabel != nil else { pendingStatus = text; return }
        statusLabel.stringValue = text
        statusLabel.isHidden = false
        spinner.stopAnimation(nil)
        splashDismissed = false
        splashView.alphaValue = 1
        splashView.isHidden = false
    }

    private func showSplashLoading() {
        statusLabel.isHidden = true
        spinner.startAnimation(nil)
        splashDismissed = false
        splashView.alphaValue = 1
        splashView.isHidden = false
    }

    /// Fades the splash out once the web UI is painted and remembers the
    /// page background so the next launch starts in the same colour.
    private func revealWebView() {
        guard !splashDismissed else { return }
        splashDismissed = true
        webView.evaluateJavaScript(
            "(() => { for (const el of [document.body, document.documentElement]) { const c = getComputedStyle(el).backgroundColor.match(/[\\d.]+/g); if (c && c.length >= 3 && (c.length < 4 || parseFloat(c[3]) > 0.5)) return c.slice(0, 3).join(','); } return ''; })()"
        ) { [weak self] value, _ in
            if let rgb = value as? String, !rgb.isEmpty {
                UserDefaults.standard.set(rgb, forKey: "UNIBODYSplashBackground")
            }
            // Give WebKit a moment to paint the first frame behind the splash.
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
                guard let self = self, self.splashDismissed else { return }
                self.spinner.stopAnimation(nil)
                NSAnimationContext.runAnimationGroup({ context in
                    context.duration = 0.18
                    self.splashView.animator().alphaValue = 0
                }, completionHandler: {
                    mark("splash gone")
                    if self.splashDismissed { self.splashView.isHidden = true }
                })
            }
        }
    }

    /// Background of the splash: the page colour from the last launch,
    /// or the light default theme on first launch.
    private var splashBackground: NSColor {
        let parts = (UserDefaults.standard.string(forKey: "UNIBODYSplashBackground") ?? "241,247,252")
            .split(separator: ",").compactMap { Double($0) }
        guard parts.count == 3 else { return NSColor(srgbRed: 241 / 255, green: 247 / 255, blue: 252 / 255, alpha: 1) }
        return NSColor(srgbRed: parts[0] / 255, green: parts[1] / 255, blue: parts[2] / 255, alpha: 1)
    }

    // MARK: - Window

    private func buildWindow() {
        let configuration = WKWebViewConfiguration()
        configuration.websiteDataStore = .default()
        webView = WKWebView(frame: .zero, configuration: configuration)
        webView.navigationDelegate = self
        webView.uiDelegate = self
        webView.allowsBackForwardNavigationGestures = false
        webView.allowsMagnification = true
        // Warm up the web content process while the Python server is still booting.
        webView.loadHTMLString("", baseURL: nil)
        webView.translatesAutoresizingMaskIntoConstraints = false

        // Splash: logo, name and a small spinner on the app's own background colour.
        let background = splashBackground
        let rgb = background.usingColorSpace(.sRGB) ?? background
        let isDark = (0.299 * rgb.redComponent + 0.587 * rgb.greenComponent + 0.114 * rgb.blueComponent) < 0.5
        let primaryText = isDark ? NSColor.white : NSColor(srgbRed: 0.05, green: 0.16, blue: 0.27, alpha: 1)

        splashView = NSView()
        splashView.wantsLayer = true
        splashView.layer?.backgroundColor = background.cgColor
        splashView.translatesAutoresizingMaskIntoConstraints = false

        let logo = NSImageView(image: NSApp.applicationIconImage)
        logo.imageScaling = .scaleProportionallyUpOrDown
        logo.translatesAutoresizingMaskIntoConstraints = false

        let title = NSTextField(labelWithString: "UNIBODY")
        title.font = .systemFont(ofSize: 30, weight: .semibold)
        title.textColor = primaryText

        spinner = NSProgressIndicator()
        spinner.style = .spinning
        spinner.controlSize = .small
        spinner.isDisplayedWhenStopped = false
        spinner.appearance = NSAppearance(named: isDark ? .darkAqua : .aqua)
        spinner.startAnimation(nil)

        statusLabel = NSTextField(wrappingLabelWithString: "")
        statusLabel.alignment = .center
        statusLabel.font = .systemFont(ofSize: 13)
        statusLabel.textColor = primaryText.withAlphaComponent(0.7)
        statusLabel.isHidden = true

        let stack = NSStackView(views: [logo, title, spinner, statusLabel])
        stack.orientation = .vertical
        stack.alignment = .centerX
        stack.spacing = 14
        stack.setCustomSpacing(22, after: title)
        stack.translatesAutoresizingMaskIntoConstraints = false
        splashView.addSubview(stack)

        let content = NSView()
        content.wantsLayer = true
        content.layer?.backgroundColor = background.cgColor
        content.addSubview(webView)
        content.addSubview(splashView)
        NSLayoutConstraint.activate([
            webView.leadingAnchor.constraint(equalTo: content.leadingAnchor),
            webView.trailingAnchor.constraint(equalTo: content.trailingAnchor),
            webView.topAnchor.constraint(equalTo: content.topAnchor),
            webView.bottomAnchor.constraint(equalTo: content.bottomAnchor),
            splashView.leadingAnchor.constraint(equalTo: content.leadingAnchor),
            splashView.trailingAnchor.constraint(equalTo: content.trailingAnchor),
            splashView.topAnchor.constraint(equalTo: content.topAnchor),
            splashView.bottomAnchor.constraint(equalTo: content.bottomAnchor),
            logo.widthAnchor.constraint(equalToConstant: 112),
            logo.heightAnchor.constraint(equalToConstant: 112),
            stack.centerXAnchor.constraint(equalTo: splashView.centerXAnchor),
            stack.centerYAnchor.constraint(equalTo: splashView.centerYAnchor, constant: -20),
            statusLabel.widthAnchor.constraint(lessThanOrEqualToConstant: 460),
        ])

        window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 1440, height: 900),
            styleMask: [.titled, .closable, .miniaturizable, .resizable],
            backing: .buffered,
            defer: false
        )
        window.title = "UNIBODY"
        window.backgroundColor = background
        window.isReleasedWhenClosed = false
        window.minSize = NSSize(width: 720, height: 520)
        window.contentView = content
        window.center()
        window.setFrameAutosaveName("UNIBODYMainWindow")
        window.makeKeyAndOrderFront(nil)
    }

    @objc private func showWindow(_ sender: Any?) {
        window.makeKeyAndOrderFront(sender)
        NSApp.activate(ignoringOtherApps: true)
    }

    @objc private func reloadPage(_ sender: Any?) {
        if webView.url == nil {
            startAttempts = 0
            showSplashLoading()
            startServerIfNeeded()
            waitForServerThenLoad()
        } else {
            webView.reload()
        }
    }

    @objc private func openInBrowser(_ sender: Any?) {
        NSWorkspace.shared.open(serverURL)
    }

    @objc private func revealDataFolder(_ sender: Any?) {
        guard let data = serverLocation?.data else { return }
        NSWorkspace.shared.open(data)
    }

    @objc private func zoomIn(_ sender: Any?) { webView.pageZoom = min(webView.pageZoom + 0.1, 2.0) }
    @objc private func zoomOut(_ sender: Any?) { webView.pageZoom = max(webView.pageZoom - 0.1, 0.5) }
    @objc private func zoomReset(_ sender: Any?) { webView.pageZoom = 1.0 }

    // MARK: - Menu

    private func buildMenu() {
        let main = NSMenu()

        let appItem = NSMenuItem()
        let appMenu = NSMenu()
        appMenu.addItem(withTitle: "Über UNIBODY", action: #selector(NSApplication.orderFrontStandardAboutPanel(_:)), keyEquivalent: "")
        appMenu.addItem(.separator())
        appMenu.addItem(withTitle: "UNIBODY ausblenden", action: #selector(NSApplication.hide(_:)), keyEquivalent: "h")
        let hideOthers = appMenu.addItem(withTitle: "Andere ausblenden", action: #selector(NSApplication.hideOtherApplications(_:)), keyEquivalent: "h")
        hideOthers.keyEquivalentModifierMask = [.command, .option]
        appMenu.addItem(withTitle: "Alle einblenden", action: #selector(NSApplication.unhideAllApplications(_:)), keyEquivalent: "")
        appMenu.addItem(.separator())
        appMenu.addItem(withTitle: "UNIBODY beenden", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")
        appItem.submenu = appMenu
        main.addItem(appItem)

        let editItem = NSMenuItem()
        let editMenu = NSMenu(title: "Bearbeiten")
        editMenu.addItem(withTitle: "Widerrufen", action: Selector(("undo:")), keyEquivalent: "z")
        let redo = editMenu.addItem(withTitle: "Wiederholen", action: Selector(("redo:")), keyEquivalent: "z")
        redo.keyEquivalentModifierMask = [.command, .shift]
        editMenu.addItem(.separator())
        editMenu.addItem(withTitle: "Ausschneiden", action: #selector(NSText.cut(_:)), keyEquivalent: "x")
        editMenu.addItem(withTitle: "Kopieren", action: #selector(NSText.copy(_:)), keyEquivalent: "c")
        editMenu.addItem(withTitle: "Einsetzen", action: #selector(NSText.paste(_:)), keyEquivalent: "v")
        editMenu.addItem(withTitle: "Alles auswählen", action: #selector(NSText.selectAll(_:)), keyEquivalent: "a")
        editItem.submenu = editMenu
        main.addItem(editItem)

        let viewItem = NSMenuItem()
        let viewMenu = NSMenu(title: "Darstellung")
        viewMenu.addItem(withTitle: "Neu laden", action: #selector(reloadPage(_:)), keyEquivalent: "r")
        viewMenu.addItem(.separator())
        viewMenu.addItem(withTitle: "Originalgröße", action: #selector(zoomReset(_:)), keyEquivalent: "0")
        viewMenu.addItem(withTitle: "Vergrößern", action: #selector(zoomIn(_:)), keyEquivalent: "+")
        viewMenu.addItem(withTitle: "Verkleinern", action: #selector(zoomOut(_:)), keyEquivalent: "-")
        viewMenu.addItem(.separator())
        viewMenu.addItem(withTitle: "Im Browser öffnen", action: #selector(openInBrowser(_:)), keyEquivalent: "")
        viewMenu.addItem(withTitle: "Datenordner im Finder zeigen", action: #selector(revealDataFolder(_:)), keyEquivalent: "")
        viewItem.submenu = viewMenu
        main.addItem(viewItem)

        let windowItem = NSMenuItem()
        let windowMenu = NSMenu(title: "Fenster")
        windowMenu.addItem(withTitle: "Schließen", action: #selector(NSWindow.performClose(_:)), keyEquivalent: "w")
        windowMenu.addItem(withTitle: "Im Dock ablegen", action: #selector(NSWindow.performMiniaturize(_:)), keyEquivalent: "m")
        windowMenu.addItem(.separator())
        windowMenu.addItem(withTitle: "UNIBODY", action: #selector(showWindow(_:)), keyEquivalent: "1")
        windowItem.submenu = windowMenu
        main.addItem(windowItem)
        NSApp.windowsMenu = windowMenu

        NSApp.mainMenu = main
    }

    // MARK: - Navigation guard

    /// Only the local UNIBODY server may be shown inside the window.
    private func isLocalAppURL(_ url: URL?) -> Bool {
        guard let url = url else { return false }
        if url.absoluteString == "about:blank" { return true }
        guard url.scheme?.lowercased() == "http",
              let host = url.host?.lowercased(),
              host == "127.0.0.1" || host == "localhost" else { return false }
        return (url.port ?? 80) == Int(serverPort)
    }

    private func openExternally(_ url: URL) {
        guard let scheme = url.scheme?.lowercased(),
              ["http", "https", "mailto"].contains(scheme) else { return }
        NSWorkspace.shared.open(url)
    }

    func webView(_ webView: WKWebView, decidePolicyFor navigationAction: WKNavigationAction,
                 decisionHandler: @escaping (WKNavigationActionPolicy) -> Void) {
        guard let url = navigationAction.request.url else { decisionHandler(.cancel); return }
        if isLocalAppURL(url) {
            decisionHandler(navigationAction.shouldPerformDownload ? .download : .allow)
        } else {
            if navigationAction.targetFrame?.isMainFrame ?? true { openExternally(url) }
            decisionHandler(.cancel)
        }
    }

    func webView(_ webView: WKWebView, decidePolicyFor navigationResponse: WKNavigationResponse,
                 decisionHandler: @escaping (WKNavigationResponsePolicy) -> Void) {
        let disposition = (navigationResponse.response as? HTTPURLResponse)?
            .value(forHTTPHeaderField: "Content-Disposition")?.lowercased() ?? ""
        if disposition.hasPrefix("attachment") || !navigationResponse.canShowMIMEType {
            decisionHandler(.download)
        } else {
            decisionHandler(.allow)
        }
    }

    func webView(_ webView: WKWebView, navigationAction: WKNavigationAction, didBecome download: WKDownload) {
        download.delegate = self
    }

    func webView(_ webView: WKWebView, navigationResponse: WKNavigationResponse, didBecome download: WKDownload) {
        download.delegate = self
    }

    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        guard isLocalAppURL(webView.url), webView.url?.absoluteString != "about:blank" else { return } // warm-up page
        mark("page didFinish")
        revealWebView()
    }

    func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!, withError error: Error) {
        let code = (error as NSError).code
        if code == NSURLErrorCancelled || code == 102 { return } // cancelled or turned into a download
        showStatus("Die Oberfläche konnte nicht geladen werden.\n\(error.localizedDescription)\n\nMit ⌘R erneut versuchen.")
    }

    // MARK: - Links that ask for a new window

    func webView(_ webView: WKWebView, createWebViewWith configuration: WKWebViewConfiguration,
                 for navigationAction: WKNavigationAction, windowFeatures: WKWindowFeatures) -> WKWebView? {
        guard let url = navigationAction.request.url else { return nil }
        if isLocalAppURL(url) {
            // Local files (PDFs, attachments): load here so they display or download.
            webView.load(navigationAction.request)
        } else {
            openExternally(url)
        }
        return nil
    }

    // MARK: - JavaScript dialogs and file picker

    func webView(_ webView: WKWebView, runJavaScriptAlertPanelWithMessage message: String,
                 initiatedByFrame frame: WKFrameInfo, completionHandler: @escaping () -> Void) {
        let alert = NSAlert()
        alert.messageText = "UNIBODY"
        alert.informativeText = message
        alert.addButton(withTitle: "OK")
        alert.beginSheetModal(for: window) { _ in completionHandler() }
    }

    func webView(_ webView: WKWebView, runJavaScriptConfirmPanelWithMessage message: String,
                 initiatedByFrame frame: WKFrameInfo, completionHandler: @escaping (Bool) -> Void) {
        let alert = NSAlert()
        alert.messageText = "UNIBODY"
        alert.informativeText = message
        alert.addButton(withTitle: "OK")
        alert.addButton(withTitle: "Abbrechen")
        alert.beginSheetModal(for: window) { completionHandler($0 == .alertFirstButtonReturn) }
    }

    func webView(_ webView: WKWebView, runOpenPanelWith parameters: WKOpenPanelParameters,
                 initiatedByFrame frame: WKFrameInfo, completionHandler: @escaping ([URL]?) -> Void) {
        let panel = NSOpenPanel()
        panel.allowsMultipleSelection = parameters.allowsMultipleSelection
        panel.canChooseDirectories = false
        panel.beginSheetModal(for: window) { completionHandler($0 == .OK ? panel.urls : nil) }
    }

    // MARK: - Downloads

    func download(_ download: WKDownload, decideDestinationUsing response: URLResponse,
                  suggestedFilename: String, completionHandler: @escaping (URL?) -> Void) {
        let downloads = FileManager.default.urls(for: .downloadsDirectory, in: .userDomainMask).first
            ?? URL(fileURLWithPath: NSTemporaryDirectory())
        // lastPathComponent strips any path parts from the suggested name.
        var name = URL(fileURLWithPath: suggestedFilename).lastPathComponent
        if name.isEmpty || name == "/" || name.hasPrefix(".") { name = "UNIBODY-Download" }
        var target = downloads.appendingPathComponent(name)
        let base = target.deletingPathExtension().lastPathComponent
        let ext = target.pathExtension
        var counter = 2
        while FileManager.default.fileExists(atPath: target.path) {
            let candidate = ext.isEmpty ? "\(base) \(counter)" : "\(base) \(counter).\(ext)"
            target = downloads.appendingPathComponent(candidate)
            counter += 1
        }
        downloadTargets[ObjectIdentifier(download)] = target
        completionHandler(target)
    }

    private var downloadTargets: [ObjectIdentifier: URL] = [:]

    func downloadDidFinish(_ download: WKDownload) {
        if let target = downloadTargets.removeValue(forKey: ObjectIdentifier(download)) {
            NSWorkspace.shared.activateFileViewerSelecting([target])
        }
    }

    func download(_ download: WKDownload, didFailWithError error: Error, resumeData: Data?) {
        downloadTargets.removeValue(forKey: ObjectIdentifier(download))
        let alert = NSAlert()
        alert.messageText = "Download fehlgeschlagen"
        alert.informativeText = error.localizedDescription
        alert.beginSheetModal(for: window, completionHandler: nil)
    }
}

let app = NSApplication.shared
let delegate = AppDelegate()
app.delegate = delegate
delegate.startServerIfNeeded()
mark("server spawned")
app.setActivationPolicy(.regular)
app.run()
