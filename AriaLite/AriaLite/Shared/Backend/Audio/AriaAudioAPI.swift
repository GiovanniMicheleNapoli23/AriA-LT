//
//  AriaAudioAPI.swift
//  AriaLite
//
//  Created by Giovanni Michele on 21/10/26.
//
//  Le rotte della dettatura, aperte anche all'operatore dal 20/10/2026 (guida "operator member parity", §4):
//
//      GET  /v1/audio/transcriptions/capabilities   se mostrare la dettatura sul server (JWT, niente Company-Id)
//      GET  /v1/audio/vocabulary                    codici allarme, tag e termini dell'azienda: aiuti al riconoscitore
//      POST /v1/audio/transcriptions                la registrazione → testo (AriaAPIClient.transcribe, multipart)
//      POST /v1/audio/polish                        un testo dettato → testo scritto
//
//  In produzione (ottobre 2026) CloudFront ferma i body da 8 KB in su con un 403 prima del backend: ogni
//  registrazione è più grande, quindi la trascrizione sul server fallisce finché il limite non si alza.
//  Quello che resta sempre: il riconoscimento sul telefono più `polish` (testi brevi).
//

import Foundation

/// GET /v1/audio/transcriptions/capabilities.
nonisolated struct AriaDictationCapabilities: Decodable, Sendable, Equatable {
    /// `false` = niente dettatura sul server (resta il riconoscimento sul telefono).
    let available: Bool
    /// Oltre questa dimensione la registrazione non si manda (413).
    let maxAudioMb: Double?
    /// `true` se POST /v1/audio/polish fa qualcosa su questo server (indipendente da `available`).
    let polish: Bool?

    static let unavailable = AriaDictationCapabilities(available: false, maxAudioMb: nil, polish: false)
}

/// GET /v1/audio/vocabulary.
nonisolated struct AriaDictationVocabulary: Decodable, Sendable {
    nonisolated struct Term: Decodable, Sendable, Equatable {
        let token: String
        /// "alarm" | "asset" | "term".
        let kind: String?
        let label: String?
    }

    let terms: [Term]
}

nonisolated struct AriaPolishRequest: Encodable, Sendable {
    /// Il server accetta al massimo 20.000 caratteri.
    static let maxLength = 20_000
    let text: String
    let language: String?
}

nonisolated struct AriaPolishResponse: Decodable, Sendable {
    let text: String
    let changed: Bool?
}

nonisolated struct AriaAudioAPI: Sendable {
    let api: AriaAPIClient

    /// Si chiede una volta, quando il composer si apre. Ha bisogno del JWT ma non dell'azienda.
    func capabilities() async throws -> AriaDictationCapabilities {
        try await api.call(AriaEndpoint(method: "GET", path: "v1/audio/transcriptions/capabilities", companyScoped: false))
    }

    /// I termini dell'azienda come aiuti per il riconoscitore (`contextualStrings`), senza doppioni.
    func vocabulary() async throws -> [String] {
        let response: AriaDictationVocabulary = try await api.call(.get("v1/audio/vocabulary"))
        var seen = Set<String>()
        return response.terms.compactMap { term in
            let token = term.token.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !token.isEmpty, seen.insert(token).inserted else { return nil }
            return token
        }
    }

    /// Da testo dettato a testo scritto. Se la pulizia fallisce il server restituisce il testo com'era
    /// (`changed: false`): la risposta si usa sempre. `language`: la lingua di dettatura (nil = automatica).
    func polish(_ text: String, language: String?) async throws -> String {
        let text = String(text.prefix(AriaPolishRequest.maxLength))
        let response: AriaPolishResponse = try await api.call(.post("v1/audio/polish",
                                                                    body: AriaPolishRequest(text: text, language: language)))
        let polished = response.text.trimmingCharacters(in: .whitespacesAndNewlines)
        return polished.isEmpty ? text : polished
    }
}
