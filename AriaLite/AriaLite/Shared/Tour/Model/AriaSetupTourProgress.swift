//
//  AriaSetupTourProgress.swift
//  AriaLite
//
//  Created by Giovanni Michele on 13/11/26.
//
//  Il ricordo del giro guidato: fatto, per account (lo stesso telefono con un'altra email lo rivede), il passo
//  a cui è arrivata la prima esecuzione (si riprende da lì) e se è nascosto. Si nasconde con
//  `-AriaTourHidden YES`. Nelle chiavi l'account è un'impronta dell'email, non l'email: UserDefaults è un
//  file in chiaro che finisce nei backup, e gli indirizzi di chi ha usato il dispositivo non ci restano.
//

import CryptoKit
import Foundation

struct AriaSetupTourProgress {
    private static let doneKeyPrefix = "AriaSetupTourDone."
    private static let stepKeyPrefix = "AriaSetupTourStep."
    /// Le chiavi con l'email in chiaro delle versioni precedenti sono già state convertite.
    private static let migratedKey = "AriaSetupTourKeysMigrated"
    /// `-AriaTourHidden YES` (UI test): il giro non parte.
    static let hiddenKey = "AriaTourHidden"

    private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    /// La chiave dell'account: l'impronta dell'email in minuscolo, così "A@x.it" e "a@x.it" sono lo stesso account.
    static func doneKey(account: String) -> String {
        doneKeyPrefix + fingerprint(account)
    }

    static func stepKey(account: String) -> String {
        stepKeyPrefix + fingerprint(account)
    }

    /// I primi 16 byte di SHA-256 dell'email in minuscolo, in esadecimale.
    private static func fingerprint(_ account: String) -> String {
        SHA256.hash(data: Data(account.lowercased().utf8)).prefix(16).map { String(format: "%02x", $0) }.joined()
    }

    func isDone(account: String) -> Bool {
        migrateLegacyKeys()
        return defaults.bool(forKey: Self.doneKey(account: account))
    }

    func markDone(account: String) {
        defaults.set(true, forKey: Self.doneKey(account: account))
    }

    /// La chiave (`rawValue`) del passo a cui era arrivata la prima esecuzione; `nil` = nessuna da riprendere.
    func savedStep(account: String) -> String? {
        migrateLegacyKeys()
        return defaults.string(forKey: Self.stepKey(account: account))
    }

    /// Le chiavi delle versioni precedenti avevano l'email in chiaro: una volta sola, il valore di ognuna
    /// (di tutti gli account passati dal dispositivo, non solo di chi è entrato) passa alla chiave con
    /// l'impronta, così il giro non si ripete, e quella vecchia si toglie.
    private func migrateLegacyKeys() {
        guard !defaults.bool(forKey: Self.migratedKey) else { return }
        for (key, value) in defaults.dictionaryRepresentation() {
            for prefix in [Self.doneKeyPrefix, Self.stepKeyPrefix] where key.hasPrefix(prefix) {
                let account = String(key.dropFirst(prefix.count))
                guard !Self.isFingerprint(account) else { continue }
                let new = prefix + Self.fingerprint(account)
                if defaults.object(forKey: new) == nil { defaults.set(value, forKey: new) }
                defaults.removeObject(forKey: key)
            }
        }
        defaults.set(true, forKey: Self.migratedKey)
    }

    private static func isFingerprint(_ text: String) -> Bool {
        text.count == 32 && text.allSatisfy(\.isHexDigit)
    }

    func saveStep(_ key: String, account: String) {
        defaults.set(key, forKey: Self.stepKey(account: account))
    }

    func clearStep(account: String) {
        defaults.removeObject(forKey: Self.stepKey(account: account))
    }

    var isHidden: Bool { defaults.bool(forKey: Self.hiddenKey) }
}
