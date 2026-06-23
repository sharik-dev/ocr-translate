import SwiftUI
import WebKit

struct WebViewContainer: UIViewRepresentable {
    @ObservedObject var viewModel: WebViewModel
    var isAdBlockEnabled: Bool = true

    func makeCoordinator() -> Coordinator { Coordinator(self) }

    func makeUIView(context: Context) -> WKWebView {
        let prefs = WKWebpagePreferences()
        prefs.allowsContentJavaScript = true

        let config = WKWebViewConfiguration()
        config.defaultWebpagePreferences = prefs
        config.allowsInlineMediaPlayback = true
        // CRITICAL: block JS-initiated popups that aren't from a real user tap
        config.preferences.javaScriptCanOpenWindowsAutomatically = false

        // Inject aggressive popup/redirect killer at document start
        let killer = WKUserScript(
            source: Self.popupKillerJS,
            injectionTime: .atDocumentStart,
            forMainFrameOnly: false
        )
        config.userContentController.addUserScript(killer)

        let webView = WKWebView(frame: .zero, configuration: config)
        webView.navigationDelegate = context.coordinator
        webView.uiDelegate         = context.coordinator
        webView.allowsBackForwardNavigationGestures = true

        viewModel.webView = webView
        viewModel.loadPendingIfNeeded()

        // Apply adblock on creation if enabled
        if isAdBlockEnabled {
            Task { @MainActor in
                AdBlockManager.shared.apply(to: config.userContentController)
            }
        }

        return webView
    }

    func updateUIView(_ webView: WKWebView, context: Context) {
        context.coordinator.syncAdBlock(enabled: isAdBlockEnabled, webView: webView)
    }

    // MARK: - Coordinator

    class Coordinator: NSObject, WKNavigationDelegate, WKUIDelegate {
        var parent: WebViewContainer
        private var adBlockApplied = false

        init(_ parent: WebViewContainer) {
            self.parent = parent
        }

        @MainActor
        func syncAdBlock(enabled: Bool, webView: WKWebView) {
            let ucc = webView.configuration.userContentController
            if enabled && !adBlockApplied {
                AdBlockManager.shared.apply(to: ucc)
                adBlockApplied = true
            } else if !enabled && adBlockApplied {
                AdBlockManager.shared.remove(from: ucc)
                adBlockApplied = false
            }
        }

        // MARK: WKNavigationDelegate

        func webView(_ webView: WKWebView,
                     decidePolicyFor navigationAction: WKNavigationAction,
                     decisionHandler: @escaping (WKNavigationActionPolicy) -> Void) {

            let req = navigationAction.request
            let targetURL = req.url
            let targetHost = targetURL?.host?.lowercased() ?? ""

            // 1. Always block known adult / gambling / cam / popunder destinations,
            //    regardless of how the navigation was initiated.
            if Self.isForbiddenHost(targetHost) {
                decisionHandler(.cancel)
                return
            }

            // 2. Block popups (no target frame). Real user-clicked links get loaded in current tab.
            if navigationAction.targetFrame == nil {
                if navigationAction.navigationType == .linkActivated, let url = targetURL {
                    webView.load(URLRequest(url: url))
                }
                decisionHandler(.cancel)
                return
            }

            // 3. Block JS-initiated (".other") cross-host main-frame redirects.
            //    Only when BOTH source AND target are the main frame — cross-site
            //    iframe loads (video players: vidsrc, 2embed, streamwish…) must pass through.
            if navigationAction.navigationType == .other,
               navigationAction.sourceFrame.isMainFrame,
               navigationAction.targetFrame?.isMainFrame == true,
               let current = webView.url, let _ = targetURL,
               let currentHost = current.host?.lowercased(),
               !currentHost.isEmpty, !targetHost.isEmpty,
               !Self.sameSite(currentHost, targetHost) {
                decisionHandler(.cancel)
                return
            }

            decisionHandler(.allow)
        }

        private static let forbiddenSubstrings: [String] = [
            // Cam / adult ad networks
            "exoclick","juicyads","trafficjunky","trafficstars","eroadvertising",
            "ero-advertising","plugrush","adxpansion","twinred","adspyglass",
            "trafficfactory","tsyndicate","realsrv","exosrv","exdynsrv",
            "dynsrvtbg","dynsrvazh","clickaine","adk2","mellowads",
            // Cam sites commonly used as popunder destinations
            "bongacams","chaturbate","livejasmin","stripchat","cam4","camsoda",
            "adultfriendfinder","stripcash","jerkmate",
            // Popunder networks
            "popads","popcash","popmyads","propellerads","adsterra","hilltopads",
            "clickadu","onclickperformance","onclickads","admaven","ad-maven",
            "monetag","propu.sh","popunder",
            // Gambling
            "casino","bet365","betway","bwin","unibet","1xbet","pokerstars",
            "winamax","parionssport","slots-","-slots","poker-"
        ]

        private static func isForbiddenHost(_ host: String) -> Bool {
            guard !host.isEmpty else { return false }
            return forbiddenSubstrings.contains { host.contains($0) }
        }

        /// True when two hosts share their registrable domain (rough heuristic).
        private static func sameSite(_ a: String, _ b: String) -> Bool {
            if a == b { return true }
            let ap = a.split(separator: ".")
            let bp = b.split(separator: ".")
            guard ap.count >= 2, bp.count >= 2 else { return a == b }
            return ap.suffix(2) == bp.suffix(2)
        }

        func webView(_ webView: WKWebView, didStartProvisionalNavigation _: WKNavigation!) {
            DispatchQueue.main.async {
                self.parent.viewModel.isLoading = true
                self.parent.viewModel.urlString = webView.url?.absoluteString ?? ""
                self.parent.updateState(webView)
            }
        }

        func webView(_ webView: WKWebView, didFinish _: WKNavigation!) {
            DispatchQueue.main.async {
                self.parent.viewModel.isLoading = false
                self.parent.viewModel.title = webView.title ?? ""
                self.parent.viewModel.urlString = webView.url?.absoluteString ?? ""
                self.parent.updateState(webView)
            }
        }

        func webView(_ webView: WKWebView, didFail _: WKNavigation!, withError _: Error) {
            DispatchQueue.main.async {
                self.parent.viewModel.isLoading = false
                self.parent.updateState(webView)
            }
        }

        // MARK: WKUIDelegate — kill all popups

        func webView(_ webView: WKWebView,
                     createWebViewWith configuration: WKWebViewConfiguration,
                     for navigationAction: WKNavigationAction,
                     windowFeatures: WKWindowFeatures) -> WKWebView? {
            // Return nil so the popup is blocked. If it's a real user link, load it in the current view.
            if navigationAction.navigationType == .linkActivated,
               let url = navigationAction.request.url {
                webView.load(URLRequest(url: url))
            }
            return nil
        }

        // Suppress JS alert/confirm/prompt spam — auto-dismiss
        func webView(_ webView: WKWebView, runJavaScriptAlertPanelWithMessage message: String,
                     initiatedByFrame frame: WKFrameInfo, completionHandler: @escaping () -> Void) {
            completionHandler()
        }

        func webView(_ webView: WKWebView, runJavaScriptConfirmPanelWithMessage message: String,
                     initiatedByFrame frame: WKFrameInfo, completionHandler: @escaping (Bool) -> Void) {
            completionHandler(false)
        }

        func webView(_ webView: WKWebView, runJavaScriptTextInputPanelWithPrompt prompt: String,
                     defaultText: String?, initiatedByFrame frame: WKFrameInfo,
                     completionHandler: @escaping (String?) -> Void) {
            completionHandler(nil)
        }
    }

    func updateState(_ webView: WKWebView) {
        viewModel.canGoBack    = webView.canGoBack
        viewModel.canGoForward = webView.canGoForward
    }

    // MARK: - Injected JS (popup/redirect killer)

    private static let popupKillerJS: String = #"""
    (function () {
        try {
            // ============================================================
            // 0. Whitelist trusted media platforms — their players break
            //    if our cosmetic CSS / popup killer touches them.
            // ============================================================
            try {
                const h = (location.hostname || '').toLowerCase();
                if (/(^|\.)(youtube\.com|youtube-nocookie\.com|youtu\.be|googlevideo\.com|ytimg\.com|vimeo\.com|player\.vimeo\.com|dailymotion\.com|twitch\.tv|player\.twitch\.tv|soundcloud\.com|spotify\.com|tiktok\.com)$/.test(h)) {
                    return;
                }
            } catch (e) {}
            // ============================================================
            // 1. AGGRESSIVE COSMETIC FILTERING (Brave / uBO-style)
            //    Inject a <style> at document_start that hides ad containers
            //    BEFORE they paint. Pure CSS = zero layout flicker.
            // ============================================================
            const COSMETIC_CSS = `
                .adsbygoogle, ins.adsbygoogle, .adsbox, .ad-banner, .ad-slot,
                .ad-wrapper, .ad-container, .ad-box, .ads, .ads-wrapper,
                .ads-container, .ads-banner, .ads-block, .ads-area, .ads-zone,
                .advertisement, .advertising, .advert, .advert-wrapper,
                .sponsored, .sponsor, .sponsored-link, .sponsored-content,
                .promo-banner, .promoted, .partner-content,
                #ad, #ads, #adunit, #ad-banner, #ad-container, #ad-wrapper,
                #ad-top, #ad-bottom, #ad-side, #ad-header, #ad-footer,
                #banner-ad, #top-ad, #bottom-ad, #side-ad, #header-ad,
                #footer-ad, #sticky-ad, #floating-ad, #popup-ad, #video-ad,
                div[id^="ad-"], div[id^="ads-"], div[id^="advert"],
                div[id*="-ad-"], div[id*="-ads-"], div[id*="_ad_"], div[id*="_ads_"],
                div[id^="google_ads"], div[id^="div-gpt-ad"],
                div[class^="ad-"], div[class^="ads-"], div[class^="advert"],
                div[class*=" ad-"], div[class*=" ads-"],
                div[class*="-ad-"], div[class*="-ads-"], div[class*="_ad_"], div[class*="_ads_"],
                div[class*="adbanner" i], div[class*="ad-banner" i],
                div[class*="sponsor" i], div[class*="promoted" i],
                iframe[src*="doubleclick"], iframe[src*="googlesyndication"],
                iframe[src*="googleadservices"], iframe[src*="adservice"],
                iframe[src*="adnxs"], iframe[src*="adsystem"],
                iframe[src*="adskeeper"], iframe[src*="adsterra"],
                iframe[src*="propeller"], iframe[src*="popads"],
                iframe[src*="popcash"], iframe[src*="trafficjunky"],
                iframe[src*="exoclick"], iframe[src*="juicyads"],
                iframe[src*="hilltopads"], iframe[src*="taboola"],
                iframe[src*="outbrain"], iframe[src*="mgid"],
                iframe[src*="revcontent"], iframe[src*="criteo"],
                iframe[src*="/ads/"], iframe[src*="/ad?"], iframe[src*="/ad/"],
                iframe[src*="/advert/"], iframe[src*="/banner/"], iframe[src*="adservice"],
                iframe[id^="google_ads"], iframe[id^="ad_iframe"],
                iframe[name^="google_ads"], iframe[width="300"][height="250"],
                iframe[width="728"][height="90"], iframe[width="160"][height="600"],
                iframe[width="970"][height="250"], iframe[width="320"][height="50"],
                iframe[width="468"][height="60"],
                ins.adsbygoogle, ins[class*="adsbygoogle"],
                .gpt-ad, .gpt-slot, .leaderboard-ad, .sidebar-ad,
                .article-ad, .inline-ad, .between-ad, .footer-ads,
                .reader-ad, .top-banner-ad, .manga-ads, .chapter-ad,
                aside[class*="ad" i]:not([class*="add" i]):not([class*="read" i]):not([class*="head" i]),
                section[class*="ad" i]:not([class*="add" i]):not([class*="read" i]):not([class*="head" i]),
                .popup-overlay, .modal-overlay, .interstitial, #interstitial,
                .newsletter-popup, .subscribe-popup, .notification-prompt,
                .push-notification, .floating-ad, .sticky-ad,
                .cookie-banner, .cookie-notice, .cookie-consent, #cookie-banner,
                .gdpr-banner, .gdpr-notice, #gdpr,
                .video-ad, .preroll-ad, .vast-ad,
                .anti-adblock, .adblock-message, .adblock-notice, #adblock-detected
                { display: none !important; visibility: hidden !important;
                  opacity: 0 !important; height: 0 !important; width: 0 !important;
                  min-height: 0 !important; min-width: 0 !important;
                  max-height: 0 !important; max-width: 0 !important;
                  position: absolute !important; left: -99999px !important;
                  pointer-events: none !important; }
                /* Unfreeze scroll if an overlay/popup blocked it */
                html, body { overflow: auto !important; }
                body { position: static !important; }
            `;
            const injectCSS = () => {
                if (document.getElementById('__meowtoon_adblock_css')) return;
                const target = document.head || document.documentElement;
                if (!target) return;
                const style = document.createElement('style');
                style.id = '__meowtoon_adblock_css';
                style.textContent = COSMETIC_CSS;
                target.appendChild(style);
            };
            injectCSS();
            // Re-inject in case the page wipes <head>
            new MutationObserver(injectCSS).observe(document.documentElement || document, {
                childList: true, subtree: false
            });

            // ============================================================
            // 2. NUKE window.open + popups
            // ============================================================
            try {
                Object.defineProperty(window, 'open', {
                    value: function () { return null; },
                    writable: false, configurable: false
                });
            } catch (e) { window.open = function () { return null; }; }

            // ============================================================
            // 3. Strip target="_blank" -> _self on every anchor
            // ============================================================
            const fixAnchors = (root) => {
                try {
                    const anchors = (root && root.querySelectorAll)
                        ? root.querySelectorAll('a[target="_blank"], a[target="_new"]')
                        : [];
                    anchors.forEach(a => { a.target = '_self'; a.rel = 'noopener noreferrer'; });
                } catch (e) {}
            };
            fixAnchors(document);

            // ============================================================
            // 4. Sweep ad/iframe nodes from DOM (belt-and-suspenders w/ CSS)
            // ============================================================
            const AD_IFRAME_HOSTS = [
                'doubleclick','googlesyndication','googleadservices','adservice',
                'adnxs','adsystem','adskeeper','adsterra','propeller','popads',
                'popcash','trafficjunky','exoclick','juicyads','hilltopads',
                'taboola','outbrain','mgid','revcontent','criteo','adcash',
                'monetag','clickadu','onclickperformance','onclickads'
                // Removed 'onclick' (too broad — was matching player URLs containing onclick handlers)
            ];
            const looksLikeAdId = (s) => {
                if (!s) return false;
                s = s.toLowerCase();
                // Skip false positives (banner = often legit movie/show hero banners on streaming sites)
                if (/add|read|head|load|pad|adapt|admin|adobe|address|ready|player|video|stream|embed|iframe|movie|show|episode|poster|hero|featured|banner/.test(s)) return false;
                return /(^|[-_])ads?($|[-_0-9])|advert|popunder|adsense|adslot|adunit/.test(s);
            };
            const nukeAdNodes = (root) => {
                if (!root || !root.querySelectorAll) return;
                // Ad-network iframes — match ONLY known ad-network hosts and very specific ad paths.
                // Do NOT match the bare word "popup" — many video players have it in query params.
                root.querySelectorAll('iframe[src]').forEach(f => {
                    const src = (f.src || '').toLowerCase();
                    if (AD_IFRAME_HOSTS.some(h => src.includes(h)) ||
                        /\/(ads|advert|banner|popunder)\//.test(src)) {
                        f.remove();
                    }
                });
                // Heuristic by id/class — never touch iframes or <video>/<source> elements
                root.querySelectorAll('div,aside,section,ins').forEach(n => {
                    if (n.querySelector && n.querySelector('iframe, video, source')) return;
                    if (looksLikeAdId(n.id) || looksLikeAdId(n.className)) {
                        n.remove();
                    }
                });
            };
            const sweepAll = () => nukeAdNodes(document);

            const mo = new MutationObserver(muts => {
                muts.forEach(m => {
                    m.addedNodes && m.addedNodes.forEach(n => {
                        if (n.nodeType !== 1) return;
                        // Anchor fix
                        if (n.tagName === 'A' && (n.target === '_blank' || n.target === '_new')) {
                            n.target = '_self';
                            n.rel = 'noopener noreferrer';
                        }
                        fixAnchors(n);
                        // Ad-iframe / ad-div fix
                        if (n.tagName === 'IFRAME') {
                            const src = (n.src || '').toLowerCase();
                            if (AD_IFRAME_HOSTS.some(h => src.includes(h)) ||
                                /\/(ads|advert|banner|popunder)\//.test(src)) {
                                n.remove();
                                return;
                            }
                        }
                        // Never wipe nodes that wrap a real video / iframe / player
                        if (n.querySelector && n.querySelector('iframe, video, source')) {
                            // fall through to recursive ad sweep but don't auto-remove the wrapper
                        } else if (looksLikeAdId(n.id) || looksLikeAdId(n.className)) {
                            n.remove();
                            return;
                        }
                        nukeAdNodes(n);
                    });
                });
            });
            if (document.documentElement) {
                mo.observe(document.documentElement, { childList: true, subtree: true });
            }
            document.addEventListener('DOMContentLoaded', sweepAll);
            setTimeout(sweepAll, 500);
            setTimeout(sweepAll, 2000);

            // ============================================================
            // 5. Block beforeunload / scroll-freeze tricks
            // ============================================================
            window.onbeforeunload = null;
            window.addEventListener('beforeunload', e => { e.stopImmediatePropagation(); }, true);

            // ============================================================
            // 6. Block sneaky setTimeout redirects (<100ms location.*)
            // ============================================================
            const _setTimeout = window.setTimeout;
            window.setTimeout = function (fn, t) {
                try {
                    const src = (typeof fn === 'function') ? fn.toString() : String(fn);
                    if (/location\s*(\.href|\.replace|\.assign|=)/.test(src) && (t || 0) < 100) {
                        return 0;
                    }
                } catch (e) {}
                return _setTimeout.apply(window, arguments);
            };

            // ============================================================
            // 7. Strip <meta http-equiv="refresh">
            // ============================================================
            const killMetaRefresh = () => {
                document.querySelectorAll('meta[http-equiv="refresh" i]').forEach(m => m.remove());
            };
            killMetaRefresh();
            document.addEventListener('DOMContentLoaded', killMetaRefresh);

            // ============================================================
            // 8. Stub common ad/tracker globals so anti-adblock checks pass
            //    silently instead of nagging the user.
            // ============================================================
            const noop = function () {};
            const stubObj = new Proxy(function(){}, {
                get: () => stubObj,
                apply: () => stubObj,
                construct: () => ({})
            });
            try {
                window.adsbygoogle = window.adsbygoogle || [];
                window.adsbygoogle.push = noop;
                window.googletag = window.googletag || { cmd: { push: noop } };
                window.googletag.cmd = window.googletag.cmd || { push: noop };
                window.googletag.cmd.push = noop;
                window.googletag.pubads = function(){ return stubObj; };
                window.googletag.display = noop;
                window.googletag.defineSlot = function(){ return stubObj; };
                window._gaq = window._gaq || []; window._gaq.push = noop;
                window.ga = window.ga || noop;
                window.gtag = window.gtag || noop;
                window.fbq = window.fbq || noop;
                window.dataLayer = window.dataLayer || []; window.dataLayer.push = noop;
                window.yaCounter = stubObj;
                window.popMagic = stubObj;
                window.popns = stubObj;
            } catch (e) {}

            // ============================================================
            // 9. KILL CENTERED INTERSTITIAL POPUPS (VPN ads, fake alerts,
            //    "your device is infected", crypto promos, etc.)
            //    Heuristic: fixed/sticky element with high z-index that
            //    covers the viewport center → almost always an ad popup.
            // ============================================================
            const AD_TEXT = /\b(nordvpn|expressvpn|surfshark|ipvanish|cyberghost|protonvpn|atlasvpn|hola\s*vpn|free\s*vpn|best\s*vpn|recommended\s*vpn|vpn\s*offer|vpn\s*deal|vpn\s*app|install\s+(?:the\s+|our\s+)?vpn|use\s+vpn\s+to|to\s+continue\s+watching\s+(?:in|on|with)|continue\s+in\s+safe\s+mode|watch\s+in\s+safe\s+mode|up\s+to\s+\d+\s*%\s+(?:cheaper|off|discount)|buy\s+games\s+up\s+to|optimized\s+servers\s+for\s+live|zero\s+buffering(?:\s+during\s+(?:games|streams))?|crystal\s+clear\s+hd|real[\s\-]?time,?\s*no\s+delays|brave\s*browser|browse\s+without\s+popups|ad\s*blocker\s+built[\s\-]?in|screen[\s\-]?covering\s+banners|browse\s+privately|try\s+brave|download\s+brave|votre\s+(appareil|téléphone|iphone|ordinateur)\s+(est|a\s+été)|your\s+(device|iphone|phone|pc)\s+is\s+infected|virus\s+detected|claim\s+your\s+(prize|reward|gift)|félicitations,?\s+vous|congratulations,?\s+you|you\s+(have\s+)?won|allow\s+notifications|enable\s+notifications|push\s+notifications|crypto\s+(bonus|reward|airdrop)|bitcoin\s+(generator|miner)|forex\s+signals)\b/i;

            // ============================================================
            //  HEURISTIC: "close button + CTA button = ad popup"
            //  Looks for a modal-like container that has a small × close
            //  button AND a prominent call-to-action button. Bails out if
            //  it looks like a login form, a video player, or an image lightbox.
            // ============================================================
            const looksLikeAdPopup = (el) => {
                try {
                    if (!el || el.nodeType !== 1 || !el.isConnected) return false;
                    const r = el.getBoundingClientRect();
                    const vw = window.innerWidth || 1, vh = window.innerHeight || 1;
                    if (r.width < 240 || r.height < 140) return false;
                    if (r.width >= vw * 0.98 && r.height >= vh * 0.98) return false;

                    // — Safety: don't touch login / signup forms
                    if (el.querySelector('input[type="password"], input[type="email"], input[name*="email" i], input[name*="login" i], input[name*="user" i]')) return false;
                    if (el.querySelector('form[action*="login" i], form[action*="signin" i], form[action*="register" i], form[action*="auth" i]')) return false;

                    // — Safety: don't touch a video / iframe-player wrapper
                    const v = el.querySelector('video, iframe');
                    if (v) {
                        const vr = v.getBoundingClientRect();
                        if (vr.width * vr.height > r.width * r.height * 0.4) return false;
                    }

                    // — Safety: don't touch image lightboxes (single dominant img)
                    const imgs = el.querySelectorAll('img');
                    if (imgs.length === 1) {
                        const ir = imgs[0].getBoundingClientRect();
                        if (ir.width * ir.height > r.width * r.height * 0.55) return false;
                    }

                    // 1) Has a close-X-like element?
                    const closeSel = '[class*="close" i],[id*="close" i],[aria-label*="close" i],[aria-label*="dismiss" i],[aria-label*="fermer" i],button[title*="close" i],button[title*="fermer" i]';
                    let hasClose = !!el.querySelector(closeSel);
                    if (!hasClose) {
                        // also accept literal × / ✕ / ✖ glyphs in small clickable elements
                        const candidates = el.querySelectorAll('button, a, span, div, i, svg');
                        for (let i = 0; i < candidates.length && !hasClose; i++) {
                            const c = candidates[i];
                            const cr = c.getBoundingClientRect();
                            if (cr.width > 50 || cr.height > 50) continue;
                            const tx = (c.textContent || '').trim();
                            if (tx === '×' || tx === '✕' || tx === '✖' || tx === 'x' || tx === 'X' || tx === '╳') {
                                hasClose = true; break;
                            }
                            if (c.tagName === 'SVG' || c.querySelector && c.querySelector('svg')) {
                                const parentText = (c.parentElement && c.parentElement.getAttribute('aria-label') || '').toLowerCase();
                                if (/close|dismiss|fermer/.test(parentText)) { hasClose = true; break; }
                            }
                        }
                    }
                    if (!hasClose) return false;

                    // 2) Has a prominent CTA button?
                    const ctaText = /(^|\s)(continue|install|download|allow|claim|get\s+(it|now|started)|try\s+(it|now)|sign\s+up|join\s+now|subscribe|enable|activate|accept\s+offer|see\s+offer|view\s+offer|buy\s+now|order\s+now|learn\s+more|start\s+(?:free|now)|en\s+savoir|j'accepte|continuer|installer|télécharger|accepter)($|\s)/i;
                    let hasCTA = false;
                    const buttons = el.querySelectorAll('button, a[role="button"], a[href], [class*="btn" i], [class*="button" i], [role="button"]');
                    for (let i = 0; i < buttons.length; i++) {
                        const b = buttons[i];
                        const br = b.getBoundingClientRect();
                        if (br.width < 80 || br.height < 28) continue;
                        const bt = (b.textContent || '').trim();
                        if (bt.length === 0 || bt.length > 60) continue;
                        if (ctaText.test(bt)) { hasCTA = true; break; }
                    }
                    if (!hasCTA) return false;

                    // 3) Must be roughly centered or at least floating prominently
                    const s = window.getComputedStyle(el);
                    const isOverlay = (s.position === 'fixed' || s.position === 'absolute' || s.position === 'sticky');
                    if (!isOverlay) return false;
                    const z = parseInt(s.zIndex, 10) || 0;
                    if (z < 50) return false;

                    return true;
                } catch (e) { return false; }
            };

            // Fake App Store / iOS notification prompts — Install paired with another button
            const looksLikeFakeStorePrompt = (el) => {
                try {
                    const txt = (el.textContent || '').toLowerCase();
                    if (txt.length > 400) return false; // ad prompts are short
                    const hasInstall = /(^|[\s>])install([\s<.!]|$)/.test(txt);
                    if (!hasInstall) return false;
                    const hasDetails = /(^|[\s>])details([\s<.!]|$)/.test(txt);
                    const hasOpen    = /(^|[\s>])open([\s<.!]|$)/.test(txt);
                    const hasCancel  = /(^|[\s>])cancel([\s<.!]|$)/.test(txt);
                    const hasLater   = /(^|[\s>])(later|not\s+now|maybe\s+later|no\s+thanks)([\s<.!]|$)/.test(txt);
                    if (hasDetails || hasOpen || hasCancel || hasLater) {
                        const r = el.getBoundingClientRect();
                        const vw = window.innerWidth || 1, vh = window.innerHeight || 1;
                        if (r.width > 200 && r.width < vw * 0.98 &&
                            r.height > 80  && r.height < vh * 0.75) return true;
                    }
                } catch (e) {}
                return false;
            };

            const isBackdrop = (el) => {
                try {
                    const s = window.getComputedStyle(el);
                    if (s.position !== 'fixed') return false;
                    const r = el.getBoundingClientRect();
                    const vw = window.innerWidth || 1, vh = window.innerHeight || 1;
                    // Must cover essentially the whole viewport
                    if (r.width < vw * 0.95 || r.height < vh * 0.95) return false;
                    // Must NOT contain interactive UI of its own (real backdrops are bare divs)
                    if (el.children && el.children.length > 0) return false;
                    const bg = s.backgroundColor || '';
                    const z  = parseInt(s.zIndex, 10) || 0;
                    // Translucent black backdrop, classic ad-modal pattern
                    const isTranslucent = /rgba\(\s*0\s*,\s*0\s*,\s*0\s*,\s*0?\.[0-9]+\s*\)/.test(bg);
                    return z >= 1000 && isTranslucent;
                } catch (e) { return false; }
            };

            const killCenteredPopups = (root) => {
                if (!root || !root.querySelectorAll) return;
                const vw = window.innerWidth || 1, vh = window.innerHeight || 1;
                // ONLY remove elements with explicit ad signals (text keywords or
                // fake-prompt button pattern). NO pure geometric detection — that
                // was killing legit lazy-loaded content carousels.
                root.querySelectorAll('div,section,aside,dialog,article').forEach(n => {
                    try {
                        if (!n.isConnected) return;
                        const r = n.getBoundingClientRect();
                        if (r.width < 200 || r.height < 80) return;
                        // Never remove the page wrapper itself
                        if (r.width >= vw * 0.98 && r.height >= vh * 0.98) return;
                        const text = (n.textContent || '').slice(0, 1500);
                        if (AD_TEXT.test(text) || looksLikeFakeStorePrompt(n) || looksLikeAdPopup(n)) {
                            n.remove();
                        }
                    } catch (e) {}
                });
                // Translucent dimming backdrops that block interaction with the page
                root.querySelectorAll('div').forEach(n => {
                    if (isBackdrop(n)) n.remove();
                });
            };

            const sweepPopups = () => killCenteredPopups(document);
            // Run on DOMContentLoaded + a few times after to catch late-injected popups
            document.addEventListener('DOMContentLoaded', sweepPopups);
            setTimeout(sweepPopups, 400);
            setTimeout(sweepPopups, 1200);
            setTimeout(sweepPopups, 3000);
            setTimeout(sweepPopups, 6000);

            // Watch for late-injected popups (most VPN ads are added after page load)
            const popupMO = new MutationObserver(muts => {
                let touched = false;
                muts.forEach(m => {
                    m.addedNodes && m.addedNodes.forEach(n => {
                        if (n.nodeType === 1) touched = true;
                    });
                });
                if (touched) {
                    // Debounce — let lazy content settle before scanning
                    clearTimeout(window.__meowtoon_popup_debounce);
                    window.__meowtoon_popup_debounce = setTimeout(sweepPopups, 250);
                }
            });
            if (document.documentElement) {
                popupMO.observe(document.documentElement, { childList: true, subtree: true });
            }

            // ============================================================
            // 9b. CATCH POPUPS AT REVEAL TIME
            //     Most ad popups are pre-rendered hidden in the DOM and shown
            //     via class toggle / opacity transition / animation. We hook
            //     those events so we kill them the instant they try to appear.
            // ============================================================
            const checkReveal = (el) => {
                try {
                    if (!el || el.nodeType !== 1 || !el.isConnected) return;
                    const r = el.getBoundingClientRect();
                    if (r.width < 150 || r.height < 60) return;
                    const vw = window.innerWidth || 1, vh = window.innerHeight || 1;
                    if (r.width >= vw * 0.98 && r.height >= vh * 0.98) return;
                    const text = (el.textContent || '').slice(0, 1500);
                    if (AD_TEXT.test(text) || looksLikeFakeStorePrompt(el) || looksLikeAdPopup(el)) {
                        el.remove();
                        return;
                    }
                    // Walk up to a reasonable popup wrapper and re-check
                    let parent = el.parentElement;
                    let depth = 0;
                    while (parent && depth < 4) {
                        const ptext = (parent.textContent || '').slice(0, 1500);
                        if (AD_TEXT.test(ptext) || looksLikeFakeStorePrompt(parent) || looksLikeAdPopup(parent)) {
                            parent.remove();
                            return;
                        }
                        parent = parent.parentElement;
                        depth++;
                    }
                } catch (e) {}
            };

            // Hook CSS animation/transition events — popups almost always
            // use one of these to slide/fade in.
            ['animationstart','animationend','transitionend','transitionstart'].forEach(evt => {
                document.addEventListener(evt, e => checkReveal(e.target), true);
            });

            // Watch class/style changes — popups often go from .hidden -> .visible
            // or from display:none -> display:block via inline style.
            const revealMO = new MutationObserver(muts => {
                muts.forEach(m => {
                    if (m.type !== 'attributes') return;
                    const t = m.target;
                    if (!t || t.nodeType !== 1) return;
                    try {
                        const s = window.getComputedStyle(t);
                        if (s.display === 'none' || s.visibility === 'hidden') return;
                        if (parseFloat(s.opacity || '1') < 0.3) return;
                        checkReveal(t);
                    } catch (e) {}
                });
            });
            try {
                if (document.documentElement) {
                    revealMO.observe(document.documentElement, {
                        attributes: true,
                        attributeFilter: ['class','style','hidden','aria-hidden','data-state','data-show','data-visible','open'],
                        subtree: true
                    });
                }
            } catch (e) {}

            // ============================================================
            // 10. Restore scroll if a popup locked the body
            // ============================================================
            const unlockScroll = () => {
                try {
                    document.documentElement.style.overflow = '';
                    document.body.style.overflow = '';
                    document.body.style.position = '';
                    document.documentElement.classList.forEach(c => {
                        if (/no-scroll|modal-open|overflow-hidden|noscroll|locked/i.test(c)) {
                            document.documentElement.classList.remove(c);
                        }
                    });
                    document.body.classList.forEach(c => {
                        if (/no-scroll|modal-open|overflow-hidden|noscroll|locked/i.test(c)) {
                            document.body.classList.remove(c);
                        }
                    });
                } catch (e) {}
            };
            setInterval(unlockScroll, 2000);
        } catch (e) { /* swallow */ }
    })();
    """#
}
