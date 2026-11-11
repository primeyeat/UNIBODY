import Foundation
import WebKit

/// Crawls an OpenOlat course on-device (hidden WKWebView) and collects the PDF files it offers.
/// Walks every node of the course menu plus up to three levels of sub-folders.
/// Navigation and credential injection are restricted to trusted university hosts (NET-02).
@MainActor
public final class OpenOlatMaterialsCrawler: NSObject, WKNavigationDelegate {
    public static let shared = OpenOlatMaterialsCrawler()

    public struct FoundFile: Hashable {
        public let name: String
        public let href: String
        public let path: String
    }

    private var webView: WKWebView?
    private var navigationContinuation: CheckedContinuation<Bool, Never>?
    private var navigationTimeout: DispatchWorkItem?

    override private init() {
        super.init()
        let config = WKWebViewConfiguration()
        // Shares the university session cookies with the other in-app web views
        config.websiteDataStore = WKWebsiteDataStore.default()
        let wv = WKWebView(frame: CGRect(x: 0, y: 0, width: 1024, height: 900), configuration: config)
        wv.customUserAgent = "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/18.0 Safari/605.1.15 UNIBODY-Mobile/1.0"
        wv.navigationDelegate = self
        webView = wv
    }

    // MARK: - WKNavigationDelegate

    public func webView(_ webView: WKWebView, decidePolicyFor navigationAction: WKNavigationAction, decisionHandler: @escaping (WKNavigationActionPolicy) -> Void) {
        decisionHandler(KeychainHelper.isTrustedCAUURL(navigationAction.request.url) ? .allow : .cancel)
    }

    public func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        finishNavigation(true)
    }

    public func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
        finishNavigation(false)
    }

    public func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!, withError error: Error) {
        finishNavigation(false)
    }

    private func finishNavigation(_ success: Bool) {
        navigationTimeout?.cancel()
        if let continuation = navigationContinuation {
            navigationContinuation = nil
            continuation.resume(returning: success)
        }
    }

    private func load(_ url: URL, timeout: TimeInterval = 12.0) async -> Bool {
        guard let wv = webView, KeychainHelper.isTrustedCAUURL(url) else { return false }
        finishNavigation(false)
        return await withCheckedContinuation { continuation in
            self.navigationContinuation = continuation
            let workItem = DispatchWorkItem { [weak self] in self?.finishNavigation(false) }
            self.navigationTimeout = workItem
            DispatchQueue.main.asyncAfter(deadline: .now() + timeout, execute: workItem)
            wv.load(URLRequest(url: url))
        }
    }

    private func pause(_ seconds: Double) async {
        try? await Task.sleep(nanoseconds: UInt64(seconds * 1_000_000_000))
    }

    // MARK: - Page state & login

    private static let stateJS = """
    (function() {
        const onLMS = location.hostname === 'lms.uni-kiel.de';
        if (document.querySelector('input[type="password"]')) return 'LOGIN_NEEDED';
        if (onLMS && document.querySelector('.o_tree a')) return 'COURSE_READY';
        if (onLMS && document.readyState === 'complete' && document.querySelector('#o_main_center_content_inner, #o_main')) return 'PAGE_READY';
        return '';
    })()
    """

    private func waitForState(timeout: Double) async -> String {
        guard let wv = webView else { return "" }
        let deadline = Date().addingTimeInterval(timeout)
        while Date() < deadline {
            if let state = try? await wv.evaluateJavaScript(Self.stateJS) as? String, !state.isEmpty {
                return state
            }
            await pause(0.25)
        }
        return ""
    }

    private func attemptLogin(username: String, password: String) async {
        guard let wv = webView, let current = wv.url, KeychainHelper.isTrustedCAUURL(current) else { return }
        // Credentials are passed as JSON string literals, never concatenated raw (NET-03)
        let userJS = KeychainHelper.jsStringLiteral(username)
        let passJS = KeychainHelper.jsStringLiteral(password)
        let loginJS = """
        (function() {
            const host = (window.location.hostname || '').toLowerCase();
            const trusted = host === 'uni-kiel.de' || host.endsWith('.uni-kiel.de') || host === 'dfn.de' || host.endsWith('.dfn.de');
            if (!trusted || window.location.protocol !== 'https:') return 'UNTRUSTED_HOST';
            const userField = document.querySelector('#o_fiooolat_login_name, input[name="o_fiooolat_login_name"], input[name="username"], input[name="login"], input#username, input#login_input, input#j_username');
            const passField = document.querySelector('#o_fiooolat_login_pass, input[name="o_fiooolat_login_pass"], input[name="password"], input#password, input#pass, input#j_password');
            if (!userField || !passField) return 'NO_LOGIN_FORM';
            userField.value = \(userJS);
            userField.dispatchEvent(new Event('input', { bubbles: true }));
            userField.dispatchEvent(new Event('change', { bubbles: true }));
            passField.value = \(passJS);
            passField.dispatchEvent(new Event('input', { bubbles: true }));
            passField.dispatchEvent(new Event('change', { bubbles: true }));
            const submit = document.querySelector('#o_fiooolat_login_button, button[type="submit"], input[type="submit"], button.btn-primary');
            if (!submit) return 'NO_SUBMIT';
            submit.click();
            return 'SUBMITTED';
        })()
        """
        _ = try? await wv.evaluateJavaScript(loginJS)
    }

    // MARK: - Crawl

    /// Same in-page crawler as the desktop version (`OPENOLAT_CRAWL_JS` in lms_bot.py).
    private static let crawlBody = #"""
    const sleep = (ms) => new Promise((r) => setTimeout(r, ms));
    const text = (el) => (el.textContent || '').replace(/\s+/g, ' ').trim();
    const content = () =>
      document.querySelector('#o_main_center_content_inner') ||
      document.querySelector('#o_main_center_content') ||
      document.body;
    const settle = async () => {
      await sleep(350);
      for (let i = 0; i < 40; i++) {
        if (!(window.o_info && window.o_info.linkbusy)) break;
        await sleep(150);
      }
      await sleep(150);
    };
    const found = new Map();
    const harvest = (trail) => {
      for (const a of content().querySelectorAll('a[href]')) {
        let name = '';
        try {
          name = decodeURIComponent(new URL(a.href).pathname.split('/').pop() || '');
        } catch (e) {
          continue;
        }
        if (!/\.pdf$/i.test(name) || found.has(name)) continue;
        found.set(name, { name: name, href: a.href, path: trail.join(' / ') });
      }
    };
    const treeLinks = () =>
      Array.from(document.querySelectorAll('.o_tree a')).filter(
        (a) => text(a) && a.target !== '_blank' && !/o_tree_oc/.test(a.className)
      );
    const folderLinks = () =>
      Array.from(content().querySelectorAll('a')).filter(
        (a) => text(a) && (a.querySelector('.o_filetype_folder') || /o_filetype_folder/.test(a.className))
      );

    let clicks = 0;
    const MAX_CLICKS = 90;
    const openTrail = async (trail) => {
      const node = treeLinks().find((a) => text(a) === trail[0]);
      if (!node) return false;
      node.click(); clicks++;
      await settle();
      for (const folderName of trail.slice(1)) {
        const folder = folderLinks().find((a) => text(a) === folderName);
        if (!folder) return false;
        folder.click(); clicks++;
        await settle();
      }
      return true;
    };
    const crawlFolders = async (trail, depth) => {
      if (depth >= 3) return;
      const names = Array.from(new Set(folderLinks().map(text)));
      for (const name of names) {
        if (clicks >= MAX_CLICKS) return;
        const next = trail.concat([name]);
        if (!(await openTrail(next))) continue;
        harvest(next);
        await crawlFolders(next, depth + 1);
      }
    };

    harvest([]);
    const visited = new Set();
    for (let guard = 0; guard < 60 && clicks < MAX_CLICKS; guard++) {
      const node = treeLinks().find((a) => !visited.has(text(a)));
      if (!node) break;
      const title = text(node);
      visited.add(title);
      node.click(); clicks++;
      await settle();
      harvest([title]);
      await crawlFolders([title], 0);
    }
    return JSON.stringify(Array.from(found.values()));
    """#

    private static let fetchBody = #"""
    try {
      const res = await fetch(href, { credentials: 'include' });
      if (!res.ok) return '';
      const buf = new Uint8Array(await res.arrayBuffer());
      if (buf.length < 5 || buf.length > 25 * 1024 * 1024) return '';
      if (String.fromCharCode(buf[0], buf[1], buf[2], buf[3], buf[4]) !== '%PDF-') return '';
      let bin = '';
      for (let i = 0; i < buf.length; i += 0x8000) {
        bin += String.fromCharCode.apply(null, buf.subarray(i, i + 0x8000));
      }
      return btoa(bin);
    } catch (e) {
      return '';
    }
    """#

    /// Opens the course (logging in if needed) and returns all PDF files found in it.
    /// Returns nil if the course room could not be reached.
    public func crawl(courseURL: URL, username: String, password: String) async -> [FoundFile]? {
        guard let wv = webView, courseURL.host?.lowercased() == "lms.uni-kiel.de" else { return nil }

        _ = await load(courseURL)
        var state = await waitForState(timeout: 8)
        if state == "LOGIN_NEEDED", !username.isEmpty, !password.isEmpty {
            for _ in 0..<2 {
                await attemptLogin(username: username, password: password)
                await pause(1.5)
                state = await waitForState(timeout: 8)
                if state != "LOGIN_NEEDED" { break }
            }
            _ = await load(courseURL)
            state = await waitForState(timeout: 8)
        }
        guard state == "COURSE_READY" || state == "PAGE_READY" else { return nil }

        guard let raw = try? await wv.callAsyncJavaScript(Self.crawlBody, arguments: [:], in: nil, contentWorld: .page) as? String,
              let data = raw.data(using: .utf8),
              let list = try? JSONSerialization.jsonObject(with: data) as? [[String: Any]] else {
            return []
        }
        return list.compactMap { entry in
            guard let name = entry["name"] as? String, let href = entry["href"] as? String,
                  let url = URL(string: href), url.scheme == "https", url.host?.lowercased() == "lms.uni-kiel.de" else {
                return nil
            }
            return FoundFile(name: name, href: href, path: (entry["path"] as? String) ?? "")
        }
    }

    /// Downloads one crawled file inside the logged-in page. Returns nil unless it is a real PDF.
    public func download(_ file: FoundFile) async -> Data? {
        guard let wv = webView,
              let b64 = try? await wv.callAsyncJavaScript(Self.fetchBody, arguments: ["href": file.href], in: nil, contentWorld: .page) as? String,
              !b64.isEmpty,
              let data = Data(base64Encoded: b64),
              String(data: data.prefix(5), encoding: .ascii) == "%PDF-" else {
            return nil
        }
        return data
    }
}
