//
//  AriaKeychain.swift
//  AriaLite
//
//  Created by Giovanni Michele on 20/11/26.
//
//  I segreti della sessione nel Keychain, solo su questo telefono; quelli protetti si aprono con Face ID
//  (AriaBiometrics).
//

import Foundation
import LocalAuthentication
import Security

nonisolated enum AriaKeychain {
    private static let service = (Bundle.main.bundleIdentifier ?? "AriaLite") + ".aria"

    private static func baseQuery(_ account: String) -> [String: Any] {
        [kSecClass as String: kSecClassGenericPassword,
         kSecAttrService as String: service,
         kSecAttrAccount as String: account]
    }

    /// `protected`: per leggerlo serve Face ID (o il codice del telefono). Senza codice impostato
    /// la protezione non si può creare e il valore si salva come gli altri.
    static func set(_ value: String, for account: String, protected: Bool = false) {
        SecItemDelete(baseQuery(account) as CFDictionary)
        var item = baseQuery(account)
        item[kSecValueData as String] = Data(value.utf8)
        if protected, let access = SecAccessControlCreateWithFlags(
            nil, kSecAttrAccessibleWhenPasscodeSetThisDeviceOnly, .userPresence, nil) {
            item[kSecAttrAccessControl as String] = access
            if SecItemAdd(item as CFDictionary, nil) == errSecSuccess { return }
            item[kSecAttrAccessControl as String] = nil
        }
        item[kSecAttrAccessible as String] = kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly
        SecItemAdd(item as CFDictionary, nil)
    }

    /// Un valore protetto si legge solo con un `context` già autenticato (AriaBiometrics.authenticate),
    /// così il sistema non chiede Face ID una seconda volta. Senza `context` non chiede mai nulla:
    /// un valore protetto risulta assente.
    static func get(_ account: String, context: LAContext? = nil) -> String? {
        var query = baseQuery(account)
        query[kSecReturnData as String] = true
        query[kSecMatchLimit as String] = kSecMatchLimitOne
        query[kSecUseAuthenticationContext as String] = context ?? silentContext()
        var out: AnyObject?
        guard SecItemCopyMatching(query as CFDictionary, &out) == errSecSuccess, let data = out as? Data else { return nil }
        return String(data: data, encoding: .utf8)
    }

    /// C'è un valore, protetto o no, senza leggerlo e senza chiedere Face ID.
    static func exists(_ account: String) -> Bool {
        var query = baseQuery(account)
        query[kSecReturnAttributes as String] = true
        query[kSecMatchLimit as String] = kSecMatchLimitOne
        query[kSecUseAuthenticationContext as String] = silentContext()
        var out: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &out)
        return status == errSecSuccess || status == errSecInteractionNotAllowed
    }

    static func delete(_ account: String) {
        SecItemDelete(baseQuery(account) as CFDictionary)
    }

    private static func silentContext() -> LAContext {
        let context = LAContext()
        context.interactionNotAllowed = true
        return context
    }
}
