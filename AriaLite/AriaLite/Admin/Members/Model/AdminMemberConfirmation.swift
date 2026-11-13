//
//  AdminMemberConfirmation.swift
//  AriaLite
//
//  Created by Giovanni Michele on 12/11/26.
//
//  Le azioni della scheda che chiedono conferma e cosa dicono: ogni frase promette solo quel che il server fa
//  davvero (ordini rilasciati, licenza liberata). I casi portano i fatti letti al momento della domanda.
//

import Foundation

nonisolated enum AdminMemberConfirmation: Sendable, Hashable {
    /// Sospendere in tutta l'azienda. `appWasActive`: l'app era attiva (licenza liberata, ordini rilasciati).
    case suspendInCompany(appWasActive: Bool)
    /// Rimuovere dall'azienda: gli ordini aperti si rilasciano sempre. `hadApp`: perde anche l'app.
    case removeFromCompany(hadApp: Bool)
    /// Sospendere solo l'app: libera la licenza e rilascia gli ordini.
    case suspendApp
    /// Togliere l'accesso all'app. `freesSeat`: occupava una licenza; `appWasActive`: gli ordini si rilasciano.
    case revokeAccess(freesSeat: Bool, appWasActive: Bool)
    case logoutAll
    case logoutDevice(AdminMobileUserSession)

    var title: String {
        switch self {
        case .suspendInCompany: String(localized: "Suspend in the company?")
        case .removeFromCompany: String(localized: "Remove from the company?")
        case .suspendApp: String(localized: "Suspend app access?")
        case .revokeAccess: String(localized: "Remove app access?")
        case .logoutAll: String(localized: "Log out all devices?")
        case .logoutDevice: String(localized: "Log out this device?")
        }
    }

    /// Le frasi, una dopo l'altra: il test controlla che ci siano o no.
    var message: String {
        sentences.joined(separator: " ")
    }

    var actionTitle: String {
        switch self {
        case .suspendInCompany: String(localized: "Suspend")
        case .removeFromCompany: String(localized: "Remove")
        case .suspendApp: String(localized: "Suspend app")
        case .revokeAccess: String(localized: "Remove access")
        case .logoutAll, .logoutDevice: String(localized: "Log out")
        }
    }

    // MARK: - Frasi

    /// Gli ordini rilasciati: quelli assegnati tornano pianificati, gli altri restano senza assegnatario.
    static var ordersReleased: String {
        String(localized: "Their open work orders are released: assigned ones go back to planned, the others stay without an assignee.")
    }

    static var seatFreed: String { String(localized: "Their seat is freed.") }

    private var sentences: [String] {
        switch self {
        case .suspendInCompany(let appWasActive):
            var parts = [String(localized: "They won't be able to use this company, on the web or in the app.")]
            if appWasActive { parts += [Self.seatFreed, Self.ordersReleased] }
            return parts
        case .removeFromCompany(let hadApp):
            var parts = [String(localized: "They leave the company and its teams, and lose their future shifts and their connector links.")]
            parts.append(Self.ordersReleased)
            if hadApp { parts.append(String(localized: "They also lose their app access.")) }
            return parts
        case .suspendApp:
            return [String(localized: "They won't be able to use the app; the web stays available."),
                    Self.seatFreed, Self.ordersReleased]
        case .revokeAccess(let freesSeat, let appWasActive):
            var parts = [String(localized: "They lose their access to the app.")]
            if freesSeat { parts.append(Self.seatFreed) }
            if appWasActive { parts.append(Self.ordersReleased) }
            parts.append(String(localized: "Their devices are signed out only if no other company lets them in."))
            return parts
        case .logoutAll:
            return [String(localized: "They will be signed out everywhere and will need a new sign-in link.")]
        case .logoutDevice(let session):
            let device = session.device.isEmpty ? String(localized: "Unknown device") : session.device
            return [String(localized: "The app on \(device) will be signed out.")]
        }
    }
}
