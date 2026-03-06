// ⚠️  Requires minimum deployment target iOS 17.4+
// Set in Xcode: Target → General → Minimum Deployments → iOS 17.4

import Foundation
import Combine
import SwiftUI
@preconcurrency import Vision
import Translation

// MARK: - Data model for a single recognized + translated text region

struct RecognizedTextItem: Identifiable {
    let id = UUID()
    /// Original text detected by Vision
    let originalText: String
    /// Translated text (filled after Translation completes)
    var translatedText: String?
    /// Bounding box in the web-view's coordinate space (points, top-left origin)
    let boundingBox: CGRect

    var displayText: String { translatedText ?? originalText }
}

class OCRService {
    func recognizeText(in image: UIImage) async throws -> [VNRecognizedTextObservation] {
        guard let cgImage = image.cgImage else {
            struct ImageError: Error {}
            throw ImageError()
        }
        
        return try await withCheckedThrowingContinuation { continuation in
            let request = VNRecognizeTextRequest { request, error in
                if let error = error {
                    continuation.resume(throwing: error)
                    return
                }
                
                let observations = request.results as? [VNRecognizedTextObservation] ?? []
                continuation.resume(returning: observations)
            }
            
            request.recognitionLevel = .accurate
            
            let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])
            
            DispatchQueue.global(qos: .userInitiated).async {
                do {
                    try handler.perform([request])
                } catch {
                    continuation.resume(throwing: error)
                }
            }
        }
    }
}

// MARK: - ViewModel

@MainActor
class OCRViewModel: ObservableObject {
    @Published var recognizedItems: [RecognizedTextItem] = []
    @Published var isProcessing: Bool = false
    @Published var showOverlay: Bool = false
    /// Driving property for the `.translationTask` SwiftUI modifier in BrowserView
    @Published var translationConfig: TranslationSession.Configuration? = nil

    private let ocrService = OCRService()
    /// Items waiting for translation (set before triggering translationConfig)
    private var pendingItems: [RecognizedTextItem] = []

    // MARK: - Public interface

    /// Call this to kick off the full OCR → Translation pipeline.
    /// `viewSize` must match the rendered size of the WKWebView on screen.
    func startPipeline(image: UIImage, viewSize: CGSize, targetLanguageCode: String) async {
        guard !isProcessing else { return }
        isProcessing = true
        showOverlay  = false
        recognizedItems = []
        pendingItems    = []

        // 1. Run Vision OCR
        let observations: [VNRecognizedTextObservation]
        do {
            observations = try await ocrService.recognizeText(in: image)
        } catch {
            print("OCR error: \(error)")
            isProcessing = false
            return
        }

        // 2. Map observations to items with view-space bounding boxes
        var items: [RecognizedTextItem] = []
        for obs in observations {
            guard let candidate = obs.topCandidates(1).first,
                  !candidate.string.trimmingCharacters(in: .whitespaces).isEmpty
            else { continue }

            // Vision uses a bottom-left origin with values 0…1; convert to top-left view coords
            let box = obs.boundingBox
            let viewBox = CGRect(
                x:      box.minX * viewSize.width,
                y:      (1.0 - box.maxY) * viewSize.height,
                width:  box.width  * viewSize.width,
                height: box.height * viewSize.height
            )
            items.append(RecognizedTextItem(originalText: candidate.string, boundingBox: viewBox))
        }

        guard !items.isEmpty else {
            isProcessing = false
            return
        }

        pendingItems = items

        // 3. Trigger Apple Translation via the `.translationTask` modifier in BrowserView
        let target = Locale.Language(identifier: targetLanguageCode)
        
        // Force a state change so the SwiftUI modifier registers it as a new task even if the language is the same
        translationConfig = nil
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            self.translationConfig = TranslationSession.Configuration(source: nil, target: target)
        }
    }

    // MARK: - Called by BrowserView's .translationTask closure

    func performTranslation(session: TranslationSession) async {
        let requests = pendingItems.enumerated().map { idx, item in
            TranslationSession.Request(sourceText: item.originalText,
                                       clientIdentifier: String(idx))
        }
        do {
            let responses = try await session.translations(from: requests)
            var updated = pendingItems
            for response in responses {
                if let idStr = response.clientIdentifier,
                   let idx  = Int(idStr), idx < updated.count {
                    updated[idx].translatedText = response.targetText
                }
            }
            recognizedItems = updated
        } catch {
            print("Translation error: \(error)")
            // Fall back to showing original text
            recognizedItems = pendingItems
        }
        
        // Finalize state
        showOverlay  = true
        isProcessing = false
        translationConfig = nil
    }

    func dismissOverlay() {
        showOverlay     = false
        recognizedItems = []
        pendingItems    = []
        translationConfig = nil
    }
}
