//
//  AriaError.swift
//  AriaLite
//
//  Created by Giovanni Michele on 20/11/26.
//
//  Gli errori del backend Aria con il loro testo per l'utente, i codici dei passi di un lavoro
//  (AriaServerCode) e i 409 dei turni della chat (AriaTurnConflict).
//

import Foundation

nonisolated enum AriaError: LocalizedError, Sendable {
    case signedOut
    /// La sessione è salvata ma protetta da Face ID e l'app non l'ha ancora aperta: non è un logout.
    case locked
    /// 401 `INVALID_OR_EXPIRED_LINK`: il link è già stato usato o è scaduto.
    case linkExpired
    /// L'host di accesso non ha le rotte del link (404): non è il server giusto.
    case linkSignInUnavailable
    /// L'host di accesso non risponde (502/503/504 del gateway). Non è un problema del link.
    case signInHostOffline
    /// 429 sull'invio o sulla verifica del link, con i secondi da aspettare se l'host li dice.
    case tooManyAttempts(retryAfter: Int?)
    /// Magic link della web: il captcha Turnstile manca o non è passato (400 MISSING_RESPONSE, 403 VERIFICATION_FAILED).
    case captchaRejected
    /// Iscrizione dall'app: il captcha Turnstile manca o non è passato (400 MISSING_RESPONSE, 403 VERIFICATION_FAILED).
    /// Senza, il link d'iscrizione non parte: non c'è un altro link a cui ripiegare.
    case signUpCheckFailed
    /// L'host di accesso non iscrive dall'app: rotta assente (404, una web precedente a questa release) o iscrizione
    /// spenta in quell'ambiente (403 `SIGN_UP_DISABLED`).
    case signUpUnavailable
    /// Il sistema non è raggiungibile (nessuna rete, server giù): non è un errore dell'operatore.
    case serverOffline
    /// 403 `not_a_mobile_user`: il login è valido ma non è quello di un utente mobile.
    case notMobileUser
    case http(status: Int, detail: String)
    /// Il server ha rifiutato un passo o un lavoro con un codice noto (`detail.code`).
    /// `missing`: gli id dei passi senza risultato (`steps_incomplete`).
    case workOrder(AriaServerCode, missing: [String] = [])
    /// 409 di un turno della chat (POST /v1/responses, Stop): vedi AriaTurnConflict.
    case turnConflict(AriaTurnConflict)
    case wafBlocked
    case bodyTooLarge(bytes: Int, limit: Int)
    case missingCompany
    case missingPlant
    /// Funzione non ancora aperta all'operatore: 403 `operation_forbidden` (backend senza la rotta).
    /// L'app nasconde la funzione invece di riprovare.
    case notOnPhone
    /// 403 `permission_denied`: il ruolo non ha la sezione o l'azione (o è in pausa, o non c'è). L'azienda resta
    /// scelta; i diritti si rileggono da GET /v1/me (AriaBackend) e ciò che non è più concesso sparisce.
    case permissionDenied(AriaPermissionDenial)
    /// Un rifiuto delle rotte di Roles & Rights con un codice noto (versione vecchia, nome già usato…).
    case accessRefused(AriaAccessRefusal)
    /// Un rifiuto delle rotte delle persone e dell'accesso all'app con un codice noto (`detail.code`); `detail` è il
    /// testo del server, per chi vuole mostrarlo.
    case peopleRefused(AriaPeopleRefusal, detail: String)
    /// Un rifiuto del tetto di spesa o degli avvisi d'uso con un codice noto (`detail.code`, più `minimum`, `user_ids`,
    /// `notice`, `expected`): vedi AriaUsageRefusal.
    case usageRefused(AriaUsageRefusal)
    /// 403 `session_ended`: un titolare ha chiuso questa sessione per l'azienda attiva. Le altre aziende funzionano
    /// ancora: si lascia questa (AriaBackend.leaveEndedWorkspace).
    case sessionEnded
    /// 422 con `detail.field` e `detail.valid` (closeout): il valore scelto non esiste, ecco quelli accettati.
    case invalidChoice(field: String, valid: [String], message: String)
    /// 402 `spend_cap_reached` di POST /v1/responses: il tetto di spesa dell'azienda è raggiunto (`overage.at_spend_cap`
    /// "stop"). Risponde prima dello stream; non si riprova. Il testo è quello del server, per i log.
    case spendCapReached(String)
    case decoding(String)
    case stream(String)

    var errorDescription: String? {
        switch self {
        case .signedOut: String(localized: "Your Aria session has expired. Sign in again.")
        case .locked: String(localized: "Unlock AriaPLT to continue.")
        case .linkExpired:
            String(localized: "This sign-in link has expired or has already been used. Request a new one.")
        case .linkSignInUnavailable:
            String(localized: "This server doesn't support signing in with an email link. Ask your company administrator.")
        case .signInHostOffline:
            String(localized: "The sign-in server is offline. Try again later.")
        case .tooManyAttempts(let seconds?) where seconds > 0:
            String(localized: "Too many attempts. Try again in \(seconds) seconds.")
        case .tooManyAttempts:
            String(localized: "Too many attempts. Wait a minute and try again.")
        case .captchaRejected, .signUpCheckFailed:
            String(localized: "The security check didn't pass. Complete it and try again.")
        case .signUpUnavailable:
            String(localized: "This server doesn't support creating an account from the app yet.")
        case .serverOffline:
            String(localized: "Aria is offline. Try again in a moment.")
        case .notMobileUser:
            String(localized: "This login is not a mobile user. Ask your company administrator for a mobile account.")
        case .http(let status, let detail): String(localized: "Error \(status): \(detail)")
        case .workOrder(let code, _): code.localized
        case .turnConflict(let conflict): conflict.localized
        case .wafBlocked: String(localized: "Request blocked by the firewall (body over 8 KB).")
        case .bodyTooLarge(let bytes, let limit): String(localized: "Message too long (\(bytes) bytes, limit \(limit)).")
        case .missingCompany: String(localized: "No company selected.")
        case .missingPlant: String(localized: "Select a site before using the chat.")
        case .notOnPhone: String(localized: "This isn't available on the phone yet.")
        case .permissionDenied(let denial):
            denial.pausesAccess
                ? String(localized: "Your access is paused. Ask your admin.")
                : String(localized: "Your role doesn't allow this.")
        case .accessRefused(let refusal): refusal.localized
        case .peopleRefused(let refusal, _): refusal.message
        case .usageRefused(let refusal): refusal.message
        case .sessionEnded: String(localized: "Your session for this workspace was ended. Sign in again.")
        case .invalidChoice(_, _, let message): message
        case .spendCapReached:
            String(localized: "Your company's spending limit is reached. An owner or admin can raise it.")
        case .decoding(let message): String(localized: "Invalid server response: \(message)")
        case .stream(let message): message
        }
    }
}

/// Codici di `detail.code` delle chiamate sui passi, sulle foto e sul completamento.
nonisolated enum AriaServerCode: String, Sendable, CaseIterable {
    case stepNotFound = "step_not_found"
    case photoNotFound = "photo_not_found"
    case workOrderClosed = "work_order_closed"
    case stepNotReported = "step_not_reported"
    case photoLimitReached = "photo_limit_reached"
    case photoNotUploaded = "photo_not_uploaded"
    case stepsIncomplete = "steps_incomplete"
    case noteRequired = "note_required"
    case noteTooLong = "note_too_long"
    case unsupportedMediaType = "unsupported_media_type"
    case photoTooLarge = "photo_too_large"
    case resolutionNotesRequired = "resolution_notes_required"
    case storageUnavailable = "storage_unavailable"

    var localized: String {
        switch self {
        case .stepNotFound: String(localized: "This step was removed. The task has been refreshed.")
        case .photoNotFound: String(localized: "This photo no longer exists.")
        case .workOrderClosed: String(localized: "This task is closed and can no longer be changed.")
        case .stepNotReported: String(localized: "Mark the step as done or not done before adding photos.")
        case .photoLimitReached: String(localized: "A step can have at most 3 photos.")
        case .photoNotUploaded: String(localized: "The photo was not uploaded. Try again.")
        case .stepsIncomplete: String(localized: "Every step needs a result before the task can be completed.")
        case .noteRequired: String(localized: "Add a note to explain why the step was not done.")
        case .noteTooLong: String(localized: "The note is too long (2000 characters at most).")
        case .unsupportedMediaType: String(localized: "This photo format is not supported.")
        case .photoTooLarge: String(localized: "The photo is too large (10 MB at most).")
        case .resolutionNotesRequired: String(localized: "Describe what was done before completing the task.")
        case .storageUnavailable: String(localized: "Photo storage is not available on the server.")
        }
    }
}

/// 409 sui turni della chat (`detail.code`, con `detail.response_id` / `detail.status`).
nonisolated struct AriaTurnConflict: Sendable, Equatable {
    enum Code: String, Sendable {
        /// Il messaggio è già stato accettato: ci si riaggancia al suo turno, non lo si rimanda.
        case turnAlreadyStarted = "turn_already_started"
        /// Nella sessione risponde ancora un altro messaggio: si aspetta che finisca, poi si manda.
        case turnInProgress = "turn_in_progress"
        /// L'id della risposta è già usato: si manda con una chiave nuova.
        case responseIdTaken = "response_id_taken"
        /// La stessa `Idempotency-Key` con un body o una sessione diversi: è un invio nuovo, con una chiave nuova.
        case idempotencyConflict = "idempotency_conflict"
        /// Stop su un turno già finito.
        case turnNotRunning = "turn_not_running"
    }

    let code: Code
    let responseId: String?
    /// Con `turn_not_running`: come era finito il turno.
    let status: String?

    init(code: Code, responseId: String? = nil, status: String? = nil) {
        self.code = code
        self.responseId = responseId
        self.status = status
    }

    init?(_ data: Data) {
        guard let detail = (try? JSONDecoder().decode(AriaJSON.self, from: data))?["detail"],
              let code = detail["code"]?.stringValue.flatMap(Code.init(rawValue:)) else { return nil }
        self.init(code: code, responseId: detail["response_id"]?.stringValue, status: detail["status"]?.stringValue)
    }

    var localized: String {
        switch code {
        case .turnAlreadyStarted, .turnInProgress: String(localized: "Aria is still answering. Wait for the answer, then try again.")
        case .responseIdTaken, .idempotencyConflict: String(localized: "The message could not be sent. Try again.")
        case .turnNotRunning: String(localized: "The answer had already finished.")
        }
    }
}
