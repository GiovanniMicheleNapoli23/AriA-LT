//
//  AdminUserDetailViewModel+Switches.swift
//  AriaLite
//
//  Created by Giovanni Michele on 18/11/26.
//
//  I due interruttori della persona (§5.3): accenderli parte subito, spegnerli chiede conferma. L'interruttore
//  legge sempre la riga dell'elenco: se la conferma si annulla, torna da solo com'era.
//

import Foundation

extension AdminUserDetailViewModel {
    var appAccessIsOn: Bool { row?.appAccess ?? false }

    var fieldWorkerIsOn: Bool { row?.fieldWorker ?? false }

    /// "You can't turn off your own app access." al posto del testo di aiuto.
    var appSwitchFooter: String {
        controls.appSwitchLockedOnSelf
            ? String(localized: "You can't turn off your own app access.")
            : String(localized: "Can use the AriaPLT mobile app.")
    }

    func setAppAccess(_ on: Bool) {
        guard !isWorking, !controls.appSwitchLockedOnSelf else { return }
        if on { Task { await sendAppAccess(true) } } else { confirmation = .appOff }
    }

    func setFieldWorker(_ on: Bool) {
        guard !isWorking else { return }
        if on { Task { await sendFieldWorker(true) } } else { confirmation = .fieldOff }
    }

    func sendAppAccess(_ on: Bool) async {
        guard let api = owner.api, let name = row?.displayName else { return }
        await write {
            try await api.setAppAccess(userId: userId, on: on)
            return on ? String(localized: "\(name) can use the app.") : String(localized: "\(name) can no longer use the app.")
        }
    }

    func sendFieldWorker(_ on: Bool) async {
        guard let api = owner.api, let name = row?.displayName else { return }
        await write {
            try await api.setFieldWorker(userId: userId, on: on)
            return on ? String(localized: "\(name) is a field worker.") : String(localized: "\(name) is no longer a field worker.")
        }
    }
}
