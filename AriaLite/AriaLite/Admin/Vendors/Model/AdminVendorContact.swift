//
//  AdminVendorContact.swift
//  AriaLite
//
//  Created by Giovanni Michele on 22/10/26.
//
//  Controlli leggeri e link dei contatti di un fornitore (email, telefono, sito): servono al modulo per
//  non mandare un testo palesemente sbagliato e al dettaglio per rendere le righe toccabili.
//

import Foundation

nonisolated enum AdminVendorContact {
    /// Una sola @, qualcosa prima, un dominio con un punto in mezzo, niente spazi.
    static func isPlausibleEmail(_ text: String) -> Bool {
        guard !text.contains(where: \.isWhitespace) else { return false }
        let parts = text.split(separator: "@", omittingEmptySubsequences: false)
        guard parts.count == 2, !parts[0].isEmpty else { return false }
        let domain = parts[1]
        guard let dot = domain.lastIndex(of: "."), dot != domain.startIndex else { return false }
        return domain.index(after: dot) != domain.endIndex
    }

    /// "acme.com" → https://acme.com. Solo http/https, con un host.
    static func websiteURL(_ text: String) -> URL? {
        let lower = text.lowercased()
        let hasScheme = lower.hasPrefix("http://") || lower.hasPrefix("https://")
        guard !text.contains(where: \.isWhitespace), let url = URL(string: hasScheme ? text : "https://\(text)"),
              let host = url.host(percentEncoded: false), host.contains(".") else { return nil }
        return AriaURLPolicy.external(url)
    }

    /// `mailto:` solo per un indirizzo plausibile.
    static func mailURL(_ email: String) -> URL? {
        guard isPlausibleEmail(email) else { return nil }
        var components = URLComponents()
        components.scheme = "mailto"
        components.path = email
        return components.url
    }

    /// `tel:` con le sole cifre e il "+": mai il testo del server tal quale.
    static func phoneURL(_ phone: String) -> URL? {
        let dialable = phone.filter { $0.isASCII && ($0.isNumber || $0 == "+") }
        guard dialable.contains(where: \.isNumber) else { return nil }
        return URL(string: "tel:\(dialable)")
    }
}
