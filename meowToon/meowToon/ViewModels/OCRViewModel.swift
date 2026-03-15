// ⚠️  Requires iOS 18.0+ (Vision + Translation APIs)

import Foundation
import Combine
import SwiftUI
@preconcurrency import Vision
import Translation

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

// MARK: - ViewModel

@MainActor
class OCRViewModel: ObservableObject {
    @Published var recognizedItems: [RecognizedTextItem] = []
    @Published var isProcessing    = false
    @Published var showOverlay     = false
    @Published var errorMessage:   String? = nil

    /// Config passée au .translationTask — on la garde vivante entre les appuis.
    /// Chaque appui appelle invalidate() qui incrémente version → la config devient
    /// ≠ à la précédente → .translationTask se re-déclenche à coup sûr.
    @Published var translationConfig: TranslationSession.Configuration? = nil

    private let ocrService   = OCRService()
    private var pendingItems: [RecognizedTextItem] = []
    private var targetCode:   String = "fr"
    private var pipelineTask: Task<Void, Never>?

    // MARK: - Public

    func startPipeline(
        image:              UIImage,
        viewSize:           CGSize,
        targetLanguageCode: String,
        enableFallback:     Bool
    ) {
        cancel()
        errorMessage = nil
        targetCode   = targetLanguageCode

        pipelineTask = Task { [weak self] in
            guard let self else { return }
            await self.run(image: image, viewSize: viewSize)
        }
    }

    func cancel() {
        pipelineTask?.cancel()
        pipelineTask    = nil
        isProcessing    = false
        showOverlay     = false
        pendingItems    = []
        recognizedItems = []
        // translationConfig intentionnellement laissé intact :
        // run() appellera invalidate() dessus au prochain appui.
    }

    func dismissOverlay() {
        showOverlay     = false
        recognizedItems = []
        pendingItems    = []
    }

    /// Appelé quand la langue cible change → force une nouvelle config au prochain appui.
    func invalidateSession() { translationConfig = nil }

    // MARK: - Pipeline

    private func run(image: UIImage, viewSize: CGSize) async {
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

        // ── 3. Déclencher la traduction ────────────────────────────────
        guard !Task.isCancelled else { isProcessing = false; return }
        let targetLanguage = Locale.Language(identifier: targetCode)

        if var existing = translationConfig {
            // La config existe → invalidate() incrémente version → la rend ≠ à l'ancienne
            // → SwiftUI détecte le changement et appelle .translationTask avec une session fraîche
            existing.invalidate()
            translationConfig = existing          // publication de la config modifiée
        } else {
            // Premier appui (ou après changement de langue) → créer la config
            translationConfig = TranslationSession.Configuration(
                source: nil,                     // auto-detect
                target: targetLanguage
            )
        }
    }

    // MARK: - Exécution — appelée par .translationTask dans ContentView

    func performTranslation(session: TranslationSession) async {
        defer { isProcessing = false }
        guard !pendingItems.isEmpty, !Task.isCancelled else { return }

        let requests = pendingItems.enumerated().map { (i, item) in
            TranslationSession.Request(sourceText: item.originalText, clientIdentifier: "\(i)")
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
            // Même langue ou erreur réseau → afficher le texte original
            recognizedItems = pendingItems
            showOverlay = true
        }
    }
}
