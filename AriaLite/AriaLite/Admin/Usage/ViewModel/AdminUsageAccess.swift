//
//  AdminUsageAccess.swift
//  AriaLite
//
//  Created by Giovanni Michele on 18/11/26.
//
//  Chi vede la voce "Usage" (contratto 2): i clienti possono vedere i consumi (`billing.customer_visibility` della
//  config) E la persona può aprirla (un titolare, o un membro con i ruoli accesi, la sessione che segue il ruolo e la
//  sezione `llm_usage` concessa). Funzione pura: la chiama la barra laterale.
//

import Foundation

nonisolated enum AdminUsageAccess {
    nonisolated enum Entry: Sendable, Equatable {
        /// Niente voce: i clienti non vedono i consumi, il ruolo non la concede o il backend non ha le rotte.
        case hidden
        /// La config non ha ancora risposto: uno stato di caricamento, mai "nessun accesso".
        case loading
        case shown
    }

    /// La persona può aprire la pagina secondo `GET /v1/me` → `access`:
    /// - un titolare (`access.admin`);
    /// - un membro con `model` "rbac", `appFollowsRole` e la sezione `llm_usage` concessa (le rotte non sono nell'elenco
    ///   di una sessione ristretta: senza `appFollowsRole` rispondono 403 `operation_forbidden`);
    /// - nessun blocco `access` (backend precedente): come un titolare, tutto concesso come prima;
    /// - un'azienda "legacy": solo i titolari.
    static func mayOpen(_ rights: AriaRights) -> Bool {
        guard let access = rights.access else { return true }
        if access.admin { return true }
        return rights.followsRole && rights.has(.llmUsage)
    }

    /// La voce del menù: nascosta se la persona non può aprirla, se il backend non ha le rotte (`isUnavailable`) o quando
    /// la config dice che i consumi non sono visibili; di caricamento finché la config non ha risposto; mostrata se è
    /// visibile o se la lettura è fallita (la pagina offre "Riprova").
    static func entry(config: AriaUsageConfig?, configPhase: AriaUsageStore.Phase, isUnavailable: Bool,
                      rights: AriaRights) -> Entry {
        if isUnavailable || !mayOpen(rights) { return .hidden }
        if let config { return config.customerVisibility ? .shown : .hidden }
        switch configPhase {
        case .idle, .loading: return .loading
        case .failed: return .shown
        // Letta ma senza config non succede: si nasconde per prudenza.
        case .loaded: return .hidden
        }
    }
}
