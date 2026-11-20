//
//  AriaContext.swift
//  AriaLite
//
//  Created by Giovanni Michele on 20/11/26.
//
//  Azienda, sito e lingua attivi (finiscono negli header e nei body) e il segnale che i diritti tenuti
//  dall'app vanno riletti da GET /v1/me.
//

import Foundation

/// Azienda, stabilimento e lingua attivi: finiscono negli header e nei body.
actor AriaContext {
    nonisolated struct Snapshot: Sendable {
        let companyId: String?
        let plantId: String?
        let locale: String
    }

    private(set) var companyId: String? = UserDefaults.standard.string(forKey: "aria.company_id")
    private(set) var plantId: String? = UserDefaults.standard.string(forKey: "aria.plant_id")

    /// Lingua dell'app: il backend la usa per fissare la lingua della sessione al primo turno.
    nonisolated var locale: String { Self.appLocale }

    /// `it` o `en`: serve anche fuori dal contesto (la lingua dell'email del link d'iscrizione).
    nonisolated static var appLocale: String {
        Locale.current.language.languageCode?.identifier == "it" ? "it" : "en"
    }

    func setCompany(_ id: String?) {
        companyId = id
        UserDefaults.standard.set(id, forKey: "aria.company_id")
    }

    func setPlant(_ id: String?) {
        plantId = id
        UserDefaults.standard.set(id, forKey: "aria.plant_id")
    }

    func snapshot() -> Snapshot { Snapshot(companyId: companyId, plantId: plantId, locale: locale) }

    // MARK: Diritti

    /// I diritti tenuti dall'app sono forse vecchi: AriaBackend rilegge GET /v1/me. Ne resta in attesa al più uno.
    nonisolated let accessSignals: AsyncStream<Void>
    private nonisolated let accessSignal: AsyncStream<Void>.Continuation
    /// `access.version` dell'ultima GET /v1/me letta per l'azienda attiva.
    private var accessVersion: String?
    /// L'ultima versione diversa già segnalata: ogni versione nuova fa rileggere una volta sola.
    private var signaledVersion: String?
    /// La sessione segue il ruolo: un `operation_forbidden` può voler dire che il server ha spento l'interruttore.
    private var followsRole = false

    init() {
        (accessSignals, accessSignal) = AsyncStream.makeStream(bufferingPolicy: .bufferingNewest(1))
    }

    /// Dopo ogni GET /v1/me (o all'uscita, con `nil`).
    func setAccess(version: String?, followsRole: Bool) {
        accessVersion = version
        signaledVersion = nil
        self.followsRole = followsRole
    }

    /// Ogni risposta dell'host dei dati: `X-Access-Version` diverso da quello tenuto, un 403 `permission_denied`, o
    /// un `operation_forbidden` mentre la sessione segue il ruolo, fanno rileggere i diritti.
    func observe(status: Int, version: String?, code: String?) {
        if let version, !version.isEmpty, version != accessVersion, version != signaledVersion {
            signaledVersion = version
            accessSignal.yield()
        } else if status == 403, code == "permission_denied" || (code == "operation_forbidden" && followsRole) {
            accessSignal.yield()
        }
    }

    /// Dall'esterno (un evento `permission_denied` di uno stream, un errore della chat che lo cita).
    nonisolated func accessMayHaveChanged() {
        accessSignal.yield()
    }
}
