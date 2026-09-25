//
//  AriaLanguageModel.swift
//  AriaLite
//
//  On-device generation via Apple Intelligence (FoundationModels).
//  Gestisce le richieste in linguaggio naturale che non corrispondono alla
//  knowledge base delle procedure. Se Apple Intelligence non è disponibile
//  (device non idoneo / simulatore), reply(...) restituisce nil e il chiamante
//  ricade sulla risposta predefinita.
//

import Foundation
#if canImport(FoundationModels)
import FoundationModels
#endif

@MainActor
final class AriaLanguageModel {

    // `Any?` invece del tipo diretto: una proprietà archiviata non può essere marcata @available,
    // ma il tipo reale esiste solo da iOS 26 in poi.
    #if canImport(FoundationModels)
    private var session: Any?
    #endif

    // Persona / system instructions del modello.
    private let instructions = """
    You are AriA, a helpful assistant for industrial maintenance technicians.
    Give clear, practical, technically accurate answers in English, using short paragraphs or numbered steps.
    Keep it concise and professional.
    """

    /// True se il modello on-device (Apple Intelligence) è pronto all'uso.
    static var isAvailable: Bool {
        #if canImport(FoundationModels)
        if #available(iOS 26.0, *), case .available = SystemLanguageModel.default.availability { return true }
        #endif
        return false
    }

    var isAvailable: Bool { AriaLanguageModel.isAvailable }

    /// Genera una risposta. Restituisce nil se il modello non è disponibile o in caso di errore.
    func reply(to userMessage: String, context: String?) async -> String? {
        #if canImport(FoundationModels)
        guard #available(iOS 26.0, *), case .available = SystemLanguageModel.default.availability else { return nil }
        do {
            let session = ensureSession()
            let prompt: String
            if let context, !context.isEmpty {
                prompt = "The technician is working on: \(context)\n\n\(userMessage)"
            } else {
                prompt = userMessage
            }
            let response = try await session.respond(to: prompt)
            let content = response.content.trimmingCharacters(in: .whitespacesAndNewlines)
            // Se il modello rifiuta (guardrail/over-refusal), trattiamo come "nessuna risposta"
            // così il chiamante ripiega sulla risposta locale invece di mostrare il rifiuto.
            if content.isEmpty || Self.looksLikeRefusal(content) { return nil }
            return content
        } catch {
            return nil
        }
        #else
        return nil
        #endif
    }

    // Riconosce risposte di rifiuto tipiche dei guardrail.
    private static func looksLikeRefusal(_ text: String) -> Bool {
        let t = text.lowercased()
        let markers = [
            "cannot assist", "can't assist", "cannot help", "can't help",
            "unable to assist", "unable to help", "i can't provide", "i cannot provide",
            "i'm not able to", "i am not able to", "i can't help with", "not able to help"
        ]
        return markers.contains { t.contains($0) }
    }

    #if canImport(FoundationModels)
    @available(iOS 26.0, *)
    private func ensureSession() -> LanguageModelSession {
        if let existing = session as? LanguageModelSession { return existing }
        let created = LanguageModelSession(instructions: instructions)
        session = created
        return created
    }
    #endif
}
