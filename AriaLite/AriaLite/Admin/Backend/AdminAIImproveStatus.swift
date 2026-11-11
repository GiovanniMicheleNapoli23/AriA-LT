//
//  AdminAIImproveStatus.swift
//  AriaLite
//
//  Created by Giovanni Michele on 10/11/26.
//
//  Le risposte di …/ai-improve (allarmi, piani di manutenzione) hanno la forma
//  {"status": "...", "action": "...", "result": {...}}. Il server può rispondere 200 con
//  {"status": "error", "result": {"error": "Unknown action: …"}}: è un errore, non una proposta.
//

import Foundation

nonisolated enum AdminAIImproveStatus {
    /// Il messaggio da mostrare se la risposta è un errore; `nil` se è una proposta.
    static func errorMessage(in json: AriaJSON) -> String? {
        let status = json["status"]?.stringValue?.lowercased()
        let detail = json["result"]?["error"]?.nonEmptyString ?? json["error"]?.nonEmptyString
        guard status == "error" || detail != nil else { return nil }
        if let detail, detail.lowercased().hasPrefix("unknown action") {
            return String(localized: "The assistant doesn't support this request.")
        }
        return detail ?? String(localized: "The assistant couldn't complete the request.")
    }

    /// Le lingue in cui si può tradurre (come la web); il nome è quello di sistema, nella lingua dell'app.
    static let translationLanguages = ["it", "en", "fr", "de", "es"]

    static func languageName(_ code: String) -> String {
        Locale.current.localizedString(forLanguageCode: code)?.localizedCapitalized ?? code
    }

    /// La lingua proposta per tradurre: quella dell'app, se c'è fra le possibili.
    static var defaultTranslationLanguage: String {
        let current = Locale.current.language.languageCode?.identifier ?? "en"
        return translationLanguages.contains(current) ? current : "en"
    }
}
