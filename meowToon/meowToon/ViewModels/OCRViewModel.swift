// ⚠️  Requires iOS 17.4+ (Vision + Translation APIs)

import Foundation
import Combine
import SwiftUI
@preconcurrency import Vision
import Translation
import NaturalLanguage

// MARK: - Model

struct RecognizedTextItem: Identifiable {
    let id           = UUID()
    let originalText: String
    var translatedText: String?
    let boundingBox:  CGRect
    var displayText: String { translatedText ?? originalText }
}

// MARK: - OCR

private class OCRService {
    func run(image: UIImage) async throws -> [VNRecognizedTextObservation] {
        guard let cg = image.cgImage else { throw CancellationError() }
        return try await withCheckedThrowingContinuation { cont in
            let req = VNRecognizeTextRequest { r, e in
                if let e { cont.resume(throwing: e); return }
                cont.resume(returning: r.results as? [VNRecognizedTextObservation] ?? [])
            }
            req.recognitionLevel = .accurate
            DispatchQueue.global(qos: .userInitiated).async {
                do    { try VNImageRequestHandler(cgImage: cg).perform([req]) }
                catch { cont.resume(throwing: error) }
            }
        }
    }
}

// MARK: - Google Translate (unofficial, free, no auth)

private enum GoogleTranslate {
    static func translateBatch(_ texts: [String], to target: String) async -> [String?] {
        await withTaskGroup(of: (Int, String?).self) { g in
            for (i, text) in texts.enumerated() {
                g.addTask { (i, await translate(text, to: target)) }
            }
            var out = [String?](repeating: nil, count: texts.count)
            for await (i, r) in g { out[i] = r }
            return out
        }
    }

    static func translate(_ text: String, to target: String) async -> String? {
        guard !text.trimmingCharacters(in: .whitespaces).isEmpty,
              let encoded = text.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed),
              let url = URL(string:
                "https://translate.googleapis.com/translate_a/single" +
                "?client=gtx&sl=auto&tl=\(target)&dt=t&q=\(encoded)")
        else { return nil }

        do {
            var req = URLRequest(url: url, timeoutInterval: 8)
            req.setValue("Mozilla/5.0", forHTTPHeaderField: "User-Agent")
            let (data, _) = try await URLSession.shared.data(for: req)
            // Response: [[[translated, original, ...], ...], ...]
            if let json    = try JSONSerialization.jsonObject(with: data) as? [[Any]],
               let segs    = json.first as? [[Any]] {
                let result = segs.compactMap { $0.first as? String }.joined()
                return result.isEmpty ? nil : result
            }
        } catch { }
        return nil
    }
}

// MARK: - MyMemory fallback

private enum MyMemory {
    static func translateBatch(_ texts: [String], to target: String) async -> [String?] {
        await withTaskGroup(of: (Int, String?).self) { g in
            for (i, t) in texts.enumerated() { g.addTask { (i, await translate(t, to: target)) } }
            var out = [String?](repeating: nil, count: texts.count)
            for await (i, r) in g { out[i] = r }
            return out
        }
    }

    /// Detects language with NLLanguageRecognizer; returns primary subtag (e.g. "ko", "en", "zh")
    static func detectLanguage(of text: String) -> String {
        let recognizer = NLLanguageRecognizer()
        recognizer.processString(text)
        let raw = recognizer.dominantLanguage?.rawValue ?? "en"
        return String(raw.split(separator: "-").first ?? "en")
    }

    static func translate(_ text: String, to target: String) async -> String? {
        let t = String(text.prefix(499))
        let sourceLang = detectLanguage(of: t)
        // Normalise target to primary subtag too (e.g. "zh-Hans" → "zh")
        let targetLang = String(target.split(separator: "-").first ?? Substring(target))
        // Skip if same language
        if sourceLang == targetLang { return nil }

        guard let enc = t.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed),
              let url = URL(string: "https://api.mymemory.translated.net/get?q=\(enc)&langpair=\(sourceLang)|\(targetLang)")
        else { return nil }
        do {
            let (data, _) = try await URLSession.shared.data(from: url)
            let j  = try JSONSerialization.jsonObject(with: data) as? [String: Any]
            // MyMemory returns responseStatus 200 on success, 400/429 on error
            if let status = j?["responseStatus"] as? Int, status != 200 { return nil }
            let rd = j?["responseData"] as? [String: Any]
            let r  = rd?["translatedText"] as? String
            // Guard against error messages being returned as "translated" text
            if let r, r.contains("INVALID SOURCE LANGUAGE") || r.contains("LANGPAIR") { return nil }
            return (r == nil || r == text) ? nil : r
        } catch { return nil }
    }
}

// MARK: - ViewModel

@MainActor
class OCRViewModel: ObservableObject {
    @Published var recognizedItems: [RecognizedTextItem] = []
    @Published var isProcessing    = false
    @Published var showOverlay     = false
    @Published var errorMessage:   String? = nil

    /// Only used when engine == .apple.
    /// Rule: nil → newConfig triggers the .translationTask; NEVER store the session.
    @Published var translationConfig: TranslationSession.Configuration? = nil

    private let ocrService   = OCRService()
    private var pendingItems: [RecognizedTextItem] = []
    private var targetCode:   String = "fr"
    private var pipelineTask: Task<Void, Never>?

    // MARK: - Public

    func startPipeline(
        image:             UIImage,
        viewSize:          CGSize,
        targetLanguageCode: String,
        engine:             TranslationEngine,
        enableFallback:     Bool
    ) {
        cancel()   // stop any in-flight pipeline
        errorMessage = nil
        targetCode   = targetLanguageCode

        pipelineTask = Task { [weak self] in
            guard let self else { return }
            await self.run(image: image, viewSize: viewSize,
                           engine: engine, fallback: enableFallback)
        }
    }

    func cancel() {
        pipelineTask?.cancel()
        pipelineTask    = nil
        isProcessing    = false
        showOverlay     = false
        translationConfig = nil
        pendingItems    = []
        recognizedItems = []
    }

    func dismissOverlay() {
        showOverlay     = false
        recognizedItems = []
        pendingItems    = []
        translationConfig = nil
    }

    func invalidateSession() { translationConfig = nil }

    // MARK: - Pipeline

    private func run(image: UIImage, viewSize: CGSize,
                     engine: TranslationEngine, fallback: Bool) async {
        guard !Task.isCancelled else { return }
        isProcessing = true
        showOverlay  = false
        pendingItems = []

        // ── 1. OCR ──────────────────────────────────────────────────────
        let obs: [VNRecognizedTextObservation]
        do { obs = try await ocrService.run(image: image) }
        catch {
            isProcessing = false
            if !Task.isCancelled { errorMessage = "Échec OCR : \(error.localizedDescription)" }
            return
        }
        guard !Task.isCancelled else { isProcessing = false; return }

        // ── 2. Bounding boxes ──────────────────────────────────────────
        let items: [RecognizedTextItem] = obs.compactMap { o in
            guard let c = o.topCandidates(1).first,
                  !c.string.trimmingCharacters(in: .whitespaces).isEmpty else { return nil }
            let b = o.boundingBox
            return RecognizedTextItem(
                originalText: c.string,
                boundingBox: CGRect(
                    x:      b.minX  * viewSize.width,
                    y:     (1 - b.maxY) * viewSize.height,
                    width:  b.width  * viewSize.width,
                    height: b.height * viewSize.height
                )
            )
        }
        guard !items.isEmpty else { isProcessing = false; return }
        pendingItems = items

        // ── 3. Translate ───────────────────────────────────────────────
        switch engine {
        case .google:
            await translateHTTP(using: GoogleTranslate.translateBatch, fallback: fallback)

        case .myMemory:
            await translateHTTP(using: MyMemory.translateBatch, fallback: false)

        case .apple:
            // Create a fresh TranslationSession every time (no reuse)
            guard !Task.isCancelled else { isProcessing = false; return }
            let config = TranslationSession.Configuration(
                source: nil,
                target: Locale.Language(identifier: targetCode)
            )
            do {
                let session = try await TranslationSession(configuration: config)
                await performTranslation(session: session, fallback: fallback)
            } catch {
                // On failure, optionally fallback to HTTP engine
                if fallback {
                    await translateHTTP(using: GoogleTranslate.translateBatch, fallback: false)
                } else {
                    // Show original items if Apple session could not be created
                    recognizedItems = pendingItems
                    showOverlay = true
                    isProcessing = false
                }
            }
        }
    }

    private func translateHTTP(
        using batch: ([String], String) async -> [String?],
        fallback: Bool
    ) async {
        guard !Task.isCancelled else { isProcessing = false; return }
        let texts   = pendingItems.map(\.originalText)
        var results = await batch(texts, targetCode)

        // If nothing translated and fallback enabled, try MyMemory
        if fallback && results.allSatisfy({ $0 == nil }) {
            results = await MyMemory.translateBatch(texts, to: targetCode)
        }

        guard !Task.isCancelled else { isProcessing = false; return }
        var updated = pendingItems
        for (i, r) in results.enumerated() where i < updated.count {
            updated[i].translatedText = r
        }
        recognizedItems = updated
        showOverlay  = true
        isProcessing = false
    }

    // MARK: - Apple translation execution
    // ⚠️  Do NOT store `session` — create a fresh one each time and use it here only.

    func performTranslation(session: TranslationSession, fallback: Bool) async {
        defer {
            translationConfig = nil
            isProcessing      = false
        }
        guard !pendingItems.isEmpty, !Task.isCancelled else { return }

        let requests = pendingItems.enumerated().map {
            TranslationSession.Request(sourceText: $1.originalText, clientIdentifier: "\($0)")
        }

        do {
            let responses = try await session.translations(from: requests)
            var updated = pendingItems
            for r in responses {
                if let s = r.clientIdentifier, let i = Int(s), i < updated.count {
                    updated[i].translatedText = r.targetText
                }
            }
            recognizedItems = updated
            showOverlay = true
        } catch {
            // Same-language pair → no translation needed, show original
            let desc = String(describing: error)
            if desc.contains("unsupportedLanguagePairing") || desc.contains("same") {
                recognizedItems = pendingItems
                showOverlay = true
            } else if fallback {
                // Cascade to Google
                await translateHTTP(using: GoogleTranslate.translateBatch, fallback: false)
            } else {
                recognizedItems = pendingItems
                showOverlay = true
            }
        }
    }
}

