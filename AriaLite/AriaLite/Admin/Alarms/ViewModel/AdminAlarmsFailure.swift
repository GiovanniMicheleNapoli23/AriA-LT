//
//  AdminAlarmsFailure.swift
//  AriaLite
//
//  Created by Giovanni Michele on 22/10/26.
//
//  Cosa dire quando una chiamata degli allarmi fallisce. Un 403 vuol dire che il ruolo non lo consente:
//  si spiega, senza uscire dall'account. Solo una sessione scaduta passa da `backend.handle`.
//  Per le azioni dell'AI c'è anche AdminAlarmAssistFailure: un 400/422 di solito è un `action` non valido.
//

import Foundation

struct AdminAlarmsFailure: Equatable {
    enum Action { case read, write, workOrder }

    let message: String
    /// Il ruolo dell'account non ha accesso: riprovare non serve.
    let isForbidden: Bool
    /// L'allarme non esiste (più): un altro utente l'ha eliminato.
    let isNotFound: Bool

    /// `nil` per una chiamata annullata (cambio di filtro, schermata chiusa): non è un errore da mostrare.
    static func from(_ error: any Error, action: Action, backend: AriaBackend) -> Self? {
        if error is CancellationError { return nil }
        if let urlError = error as? URLError, urlError.code == .cancelled { return nil }
        switch error as? AriaError {
        case .signedOut?:
            backend.handle(error)
        case .notOnPhone?, .http(403, _)?:
            let message = switch action {
            case .read:
                String(localized: "Your role doesn't have access to alarms. Ask an owner or admin of your company.")
            case .write:
                String(localized: "Your role can't change alarms. Ask an owner or admin of your company.")
            case .workOrder:
                String(localized: "Your role can't create work orders. Ask an owner or admin of your company.")
            }
            return Self(message: message, isForbidden: true, isNotFound: false)
        case .http(404, _)?:
            let message = String(localized: "This alarm no longer exists.")
            return Self(message: message, isForbidden: false, isNotFound: true)
        default:
            break
        }
        return Self(message: error.localizedDescription, isForbidden: false, isNotFound: false)
    }
}

/// Un'azione dell'AI (ai-improve, diagnosi) fallita: il messaggio e, se il server li ha detti, i valori
/// di `action` validi.
struct AdminAlarmAssistFailure: Equatable {
    let message: String
    let validActions: [String]

    /// `nil` se non c'è niente da dire (richiesta annullata).
    static func from(_ error: any Error, action: String?, backend: AriaBackend) -> Self? {
        if let action {
            switch error as? AriaError {
            case .invalidChoice(_, let valid, let message)?:
                let text = String(localized: "The server didn't accept the action “\(action)”: \(message)")
                return Self(message: text, validActions: valid)
            case .http(let status, let detail)? where status == 400 || status == 422:
                let text = String(localized: "The server didn't accept the action “\(action)”: \(detail)")
                return Self(message: text, validActions: validActions(in: detail))
            default:
                break
            }
        }
        guard let failure = AdminAlarmsFailure.from(error, action: .write, backend: backend) else { return nil }
        return Self(message: failure.message, validActions: [])
    }

    /// Le azioni elencate in un dettaglio testuale come "Must be one of: a, b, c" o, alla pydantic,
    /// "Input should be 'a', 'b' or 'c'".
    static func validActions(in detail: String) -> [String] {
        let lower = detail.lowercased()
        let markers = ["one of", "valid actions", "allowed actions", "supported actions", "should be", "expected"]
        guard let marker = markers.lazy.compactMap({ lower.range(of: $0) }).first else { return [] }
        let tail = lower[marker.upperBound...].prefix { $0 != "." && !$0.isNewline }
        let filler: Set<String> = ["or", "and", "be", "of", "the", "are", "is", "one", "actions", "action",
                                   "valid", "got", "input"]
        var seen = Set<String>()
        return tail.split(whereSeparator: { " ,;:[]()|/'\"`".contains($0) })
            .map(String.init)
            .filter { $0.wholeMatch(of: /[a-z][a-z0-9_]*/) != nil && !filler.contains($0) }
            .filter { seen.insert($0).inserted }
    }
}
