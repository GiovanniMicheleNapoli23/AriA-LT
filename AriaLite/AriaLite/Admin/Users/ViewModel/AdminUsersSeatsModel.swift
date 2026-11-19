//
//  AdminUsersSeatsModel.swift
//  AriaLite
//
//  Created by Giovanni Michele on 18/11/26.
//
//  Come il pannello dei titolari legge il tetto di utenti: quale impaginazione ha il piano e i conti derivati.
//  Porta `lib/members/seat-model.ts` della web. Niente testi e niente rete: tutti i numeri sono del server.
//

import Foundation

nonisolated struct AdminUsersSeatsModel: Equatable, Sendable {
    /// - `perUser`: tetto morbido, ogni utente in più si paga (Basic).
    /// - `capped`: tetto fisso (Basic Plus, Professional).
    /// - `override`: tetto fisso scritto nel contratto, su qualunque piano.
    /// - `trial`: il tetto fisso della prova gratuita.
    /// - `contract`: il piano non dice un tetto (Enterprise senza deroga).
    enum Layout: Equatable, Sendable {
        case perUser
        case capped
        case override
        case trial
        case contract
    }

    let layout: Layout
    /// Nessun piano assegnato: l'azienda usa il piano di riserva, niente importi.
    let fallback: Bool
    let users: Int
    let pending: Int
    /// Utenti più inviti aperti: i posti presi.
    let used: Int
    /// Il tetto in vigore; `nil` senza tetto.
    let cap: Int?
    /// C'è un tetto fisso.
    let hard: Bool
    let state: AdminUsersRules.CapState
    /// Posti liberi sotto un tetto fisso.
    let left: Int
    /// Utenti oltre quelli inclusi, su un piano a utente.
    let extra: Int

    init(_ info: AdminUserSeatsInfo) {
        users = info.users
        pending = info.pendingInvites
        used = info.taken
        cap = info.userCap
        hard = info.mode == "hard" && info.userCap != nil
        if hard && info.trial {
            layout = .trial
        } else if hard && info.overrideActive {
            layout = .override
        } else if hard {
            layout = .capped
        } else if info.mode == "soft" {
            layout = .perUser
        } else {
            layout = .contract
        }
        fallback = info.tierSource != "assignment"
        state = AdminUsersRules.capState(info)
        left = hard ? max(0, (info.userCap ?? 0) - info.taken) : 0
        extra = layout == .perUser ? max(0, info.users - (info.includedUsers ?? 0)) : 0
    }

    var limit: Int { cap ?? 0 }

    /// Quanto del tetto è preso (0...1), per la barra; `nil` senza tetto fisso.
    var fraction: Double? {
        guard hard, let cap, cap > 0 else { return nil }
        return min(1, Double(used) / Double(cap))
    }
}
