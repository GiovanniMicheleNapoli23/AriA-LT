//
//  AdminRoleSectionRow.swift
//  AriaLite
//
//  Created by Giovanni Michele on 12/11/26.
//
//  La scheda Sezioni del dettaglio di un ruolo, già decisa dal view model: un gruppo per gruppo della sidebar,
//  una riga per sezione (interruttore) e, a sezione accesa, un chip per azione.
//

import Foundation

struct AdminRoleSectionGroup: Identifiable, Equatable {
    let group: AdminRoleGroup?
    let title: String
    let rows: [AdminRoleSectionRow]

    var id: String { group?.rawValue ?? "other" }
}

struct AdminRoleSectionRow: Identifiable, Equatable {
    let section: String
    let title: String
    let isOn: Bool
    /// Si può toccare: chi guarda cambia il ruolo, niente scritture in corso, e (per un ruolo alto) il suo ruolo ce
    /// l'ha o la sezione è accesa (toglierla si può sempre).
    let isEnabled: Bool
    /// Un ruolo alto che guarda una sezione che il suo ruolo non ha.
    let notInYourRole: Bool
    /// Solo a sezione accesa e con azioni nel catalogo.
    let chips: [AdminRoleActionChip]
    /// "Solo consultazione": una delle nove sezioni da guardare, accesa, con azioni, nessuna accesa.
    let showsLookOnlyHint: Bool
    /// Il catalogo ha azioni per la sezione (anche a sezione spenta, quando `chips` è vuoto): senza, è solo un interruttore.
    let hasActions: Bool
    /// Cosa dice la riga nell'elenco del ruolo: "Off", "View only", i nomi delle azioni accese, "2 of 5 actions", "All actions".
    let summary: String

    var id: String { section }
}

struct AdminRoleActionChip: Identifiable, Equatable {
    let action: String
    let title: String
    let isOn: Bool
    let isEnabled: Bool
    let notInYourRole: Bool

    var id: String { action }
}
