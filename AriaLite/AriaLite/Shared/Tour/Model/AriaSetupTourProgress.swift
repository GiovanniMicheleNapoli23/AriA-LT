//
//  AriaSetupTourProgress.swift
//  AriaLite
//
//  Created by Giovanni Michele on 13/11/26.
//
//  Il ricordo del giro guidato: fatto, per account (lo stesso telefono con un'altra email lo rivede), il passo
//  a cui è arrivata la prima esecuzione (si riprende da lì) e se è nascosto. Si nasconde con
//  `-AriaTourHidden YES`.
//

import Foundation

struct AriaSetupTourProgress {
    private static let doneKeyPrefix = "AriaSetupTourDone."
    private static let stepKeyPrefix = "AriaSetupTourStep."
    /// `-AriaTourHidden YES` (UI test): il giro non parte.
    static let hiddenKey = "AriaTourHidden"

    private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    /// La chiave dell'account: l'email in minuscolo, così "A@x.it" e "a@x.it" sono lo stesso account.
    static func doneKey(account: String) -> String {
        doneKeyPrefix + account.lowercased()
    }

    static func stepKey(account: String) -> String {
        stepKeyPrefix + account.lowercased()
    }

    func isDone(account: String) -> Bool {
        defaults.bool(forKey: Self.doneKey(account: account))
    }

    func markDone(account: String) {
        defaults.set(true, forKey: Self.doneKey(account: account))
    }

    /// La chiave (`rawValue`) del passo a cui era arrivata la prima esecuzione; `nil` = nessuna da riprendere.
    func savedStep(account: String) -> String? {
        defaults.string(forKey: Self.stepKey(account: account))
    }

    func saveStep(_ key: String, account: String) {
        defaults.set(key, forKey: Self.stepKey(account: account))
    }

    func clearStep(account: String) {
        defaults.removeObject(forKey: Self.stepKey(account: account))
    }

    var isHidden: Bool { defaults.bool(forKey: Self.hiddenKey) }
}
