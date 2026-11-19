//
//  AdminUsageBillingViewModel+Support.swift
//  AriaLite
//
//  Created by Giovanni Michele on 18/11/26.
//
//  Quello che serve a ogni scheda dei controlli di fatturazione per scrivere in sicurezza: il timbro di una risposta (epoca e
//  azienda), il client e la gestione degli errori delle chiamate da titolare (contratto 7).
//

import Foundation

extension AdminUsageBillingViewModel {
    /// Epoca, azienda: una risposta vale ancora se non sono cambiate.
    struct Stamp: Sendable {
        let epoch: Int
        let pageEpoch: Int
        let company: String
    }

    func currentStamp() -> Stamp {
        Stamp(epoch: epoch, pageEpoch: page.epoch, company: page.loadKey)
    }

    func isCurrent(_ stamp: Stamp) -> Bool {
        stamp.epoch == epoch && page.isCurrent(epoch: stamp.pageEpoch, company: stamp.company)
    }

    var api: AriaUsageAPI { AriaUsageAPI(api: backend.api) }


    // MARK: Errori

    /// Agisce su un errore di una chiamata da titolare e dice se è da mostrare (`true`) o solo annullata (`false`):
    /// - annullata: niente;
    /// - 403 da titolare ("Insufficient role", `permission_denied`): si nascondono le parti da titolare (`ownerRefused`) e si
    ///   rilegge la config (la pagina non lo fa da sola: `react` tralascia questo caso);
    /// - sessione scaduta, sessione chiusa, `operation_forbidden`: come la pagina (`react`).
    @discardableResult
    func handle(_ error: any Error) -> Bool {
        switch AdminUsageFailure.classify(error, ownerCall: true) {
        case .cancelled:
            return false
        case .ownerRefused:
            page.ownerRefused = true
            Task { [backend] in await backend.usage.loadConfig(force: true) }
            return true
        default:
            return page.react(to: error, ownerCall: true)
        }
    }

    /// Il codice di un rifiuto del tetto o degli avvisi, se è uno dei sei noti.
    static func refusal(_ error: any Error) -> AriaUsageRefusal? {
        if case .usageRefused(let refusal)? = error as? AriaError { return refusal }
        return nil
    }
}
