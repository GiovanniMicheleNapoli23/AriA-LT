//
//  AriaCompanyWebsite.swift
//  AriaLite
//
//  Created by Giovanni Michele on 18/11/26.
//
//  Il sito dell'azienda chiesto all'iscrizione, con le regole esatte della web (company-website.ts): il dominio
//  pubblico dell'indirizzo scritto, i provider di posta personale rifiutati, il dominio suggerito dall'email e la
//  verifica DNS tramite un resolver iniettabile. Niente rete qui: solo il nome si risolve, mai si scarica la pagina.
//

import Foundation

/// Perché un sito non può rappresentare l'azienda.
nonisolated enum AriaWebsiteProblem: String, CaseIterable, Sendable, Equatable {
    case invalid, personal, notFound, unverified

    /// Testi della web (onboarding.setup.website.problem.*).
    var message: LocalizedStringResource {
        switch self {
        case .invalid: "That isn't a web address."
        case .personal: "That's an email provider. Enter your company's own website."
        case .notFound: "This domain doesn't exist. Check how it's spelled."
        case .unverified: "We couldn't check this website."
        }
    }

    /// `unverified` non blocca il pulsante (il salvataggio ricontrolla); gli altri sì.
    var blocksSaving: Bool { self != .unverified }
}

/// L'esito del controllo: il dominio accettato, oppure il problema.
nonisolated enum AriaWebsiteCheck: Sendable, Equatable {
    case ok(host: String)
    case problem(AriaWebsiteProblem)
}

nonisolated enum AriaCompanyWebsite {
    /// La web taglia l'input a 300 caratteri prima di leggerlo.
    static let maxInputLength = 300

    /// Host che non sono il sito di un'azienda: provider di posta gratuita. Un'azienda "su" gmail.com non è un'azienda,
    /// anche se il dominio si risolve.
    static let personalEmailDomains: Set<String> = [
        "gmail.com", "googlemail.com", "google.com",
        "outlook.com", "outlook.it",
        "hotmail.com", "hotmail.it",
        "live.com", "live.it",
        "msn.com",
        "yahoo.com", "yahoo.it", "ymail.com",
        "icloud.com", "me.com", "mac.com",
        "aol.com",
        "proton.me", "protonmail.com", "pm.me",
        "gmx.com", "gmx.net", "gmx.de", "web.de",
        "mail.com",
        "zoho.com",
        "yandex.com", "yandex.ru", "mail.ru",
        "tutanota.com", "fastmail.com",
        "libero.it", "virgilio.it", "alice.it", "tim.it", "tin.it", "tiscali.it", "email.it", "fastwebnet.it",
        "inwind.it", "iol.it", "pec.it", "legalmail.it", "aruba.it",
        "orange.fr", "free.fr", "laposte.net", "wanadoo.fr",
        "t-online.de",
        "qq.com", "163.com",
    ]

    // MARK: - Indirizzo

    /// L'host di ciò che è stato scritto ("https://www.acme.it/chi-siamo", "acme.it", "WWW.Acme.IT."), minuscolo, senza
    /// "www." né punto finale; nil se non è un nome di dominio pubblico (niente punto, un IP, una porta, credenziali,
    /// localhost).
    static func host(_ input: String) -> String? {
        let raw = String(input.prefix(maxInputLength)).trimmingCharacters(in: .whitespacesAndNewlines)
        // Come la web: vuoto o con spazi dentro non è un indirizzo ("acme .it").
        guard !raw.isEmpty, !raw.unicodeScalars.contains(where: { $0.properties.isWhitespace }) else { return nil }

        // Schema esplicito (solo http/https); senza, si legge come https.
        var scheme = "https"
        var rest = Substring(raw)
        if let range = raw.range(of: "^[A-Za-z][A-Za-z0-9+.-]*://", options: .regularExpression) {
            scheme = raw[range].dropLast(3).lowercased()
            rest = raw[range.upperBound...]
        }
        guard scheme == "http" || scheme == "https" else { return nil }

        // L'autorità arriva fino al primo "/", "?", "#" (o "\", che l'URL web tratta come "/").
        var authority = rest.prefix { !"/?#\\".contains($0) }

        // Credenziali: tutto prima dell'ultima "@"; vuote (solo "@") la web le accetta.
        if let at = authority.lastIndex(of: "@") {
            guard authority[..<at].isEmpty else { return nil }
            authority = authority[authority.index(after: at)...]
        }

        // Porta: se c'è deve essere numerica; quella di default dello schema sparisce, le altre fanno rifiutare.
        var hostText = authority
        if let colon = authority.lastIndex(of: ":") {
            let port = authority[authority.index(after: colon)...]
            guard port.allSatisfy({ $0.isASCII && $0.isNumber }) else { return nil }
            if !port.isEmpty {
                guard let number = Int(port), number <= 65535 else { return nil }
                guard number == (scheme == "https" ? 443 : 80) else { return nil }
            }
            hostText = authority[..<colon]
        }

        // Nomi non ASCII (IDN): la conversione in punycode la fa Foundation, come `new URL` sulla web.
        var host: String
        if hostText.allSatisfy(\.isASCII) {
            host = hostText.lowercased()
        } else {
            guard let ascii = URL(string: "https://\(hostText)")?.host else { return nil }
            host = ascii.lowercased()
        }

        if host.hasSuffix(".") { host.removeLast() }
        if host.hasPrefix("www.") { host.removeFirst(4) }
        guard host.utf8.count <= 253 else { return nil }

        let labels = host.split(separator: ".", omittingEmptySubsequences: false)
        guard labels.count >= 2 else { return nil }
        guard labels.allSatisfy(isLabel), let tld = labels.last, isTopLevelDomain(tld) else { return nil }
        return host
    }

    /// L'host stesso, o il dominio sotto cui sta, è un provider di posta gratuita.
    static func isPersonalEmailHost(_ host: String) -> Bool {
        let labels = host.split(separator: ".", omittingEmptySubsequences: false)
        guard labels.count > 1 else { return false }
        for index in 0..<(labels.count - 1) where personalEmailDomains.contains(labels[index...].joined(separator: ".")) {
            return true
        }
        return false
    }

    /// Ciò che si può dire senza rete: l'indirizzo è un dominio, e non di un provider di posta.
    static func checkFormat(_ input: String) -> AriaWebsiteCheck {
        guard let found = AriaCompanyWebsite.host(input) else { return .problem(.invalid) }
        if isPersonalEmailHost(found) { return .problem(.personal) }
        return .ok(host: found)
    }

    /// Il dominio dell'email quando può essere il sito dell'azienda, con cui si apre il campo; "" per un provider.
    static func suggested(email: String?) -> String {
        // Come la web: `email.split("@")[1]`, cioè il secondo pezzo.
        guard let email else { return "" }
        let parts = email.split(separator: "@", omittingEmptySubsequences: false)
        guard parts.count > 1, !parts[1].isEmpty else { return "" }
        if case .ok(let host) = checkFormat(String(parts[1])) { return host }
        return ""
    }

    /// Ciò che il campo tiene quando si incolla "https://…": la web toglie un `^\s*https?://` iniziale (senza badare alle
    /// maiuscole).
    static func fieldText(_ typed: String) -> String {
        guard let range = typed.range(of: #"^\s*https?://"#, options: [.regularExpression, .caseInsensitive]) else {
            return typed
        }
        return String(typed[range.upperBound...])
    }

    // MARK: - Verifica

    /// Il formato, poi la ricerca DNS tramite `resolver`. Un host che finisce in ".local" è `.notFound` senza cercarlo
    /// (su iOS andrebbe a mDNS e potrebbe far comparire l'avviso del Local Network). Un problema di formato non chiama
    /// mai il resolver.
    static func verify(_ input: String, resolver: any AriaDomainResolving) async -> AriaWebsiteCheck {
        let format = checkFormat(input)
        guard case .ok(let host) = format else { return format }
        if host.hasSuffix(".local") { return .problem(.notFound) }
        switch await resolver.lookup(host) {
        case .found: return .ok(host: host)
        case .notFound: return .problem(.notFound)
        case .failed: return .problem(.unverified)
        }
    }

    // MARK: - Regole delle etichette

    /// Un'etichetta: lettere, cifre e trattini interni, da 1 a 63 caratteri.
    private static func isLabel(_ label: Substring) -> Bool {
        let bytes = label.utf8
        guard (1...63).contains(bytes.count), bytes.first != UInt8(ascii: "-"), bytes.last != UInt8(ascii: "-") else {
            return false
        }
        return bytes.allSatisfy { isLowercaseLetter($0) || isDigit($0) || $0 == UInt8(ascii: "-") }
    }

    /// L'ultima etichetta: solo lettere da 2 a 63 (oppure la forma `xn--…` di un IDN).
    private static func isTopLevelDomain(_ label: Substring) -> Bool {
        let bytes = label.utf8
        if (2...63).contains(bytes.count), bytes.allSatisfy(isLowercaseLetter) { return true }
        guard label.hasPrefix("xn--") else { return false }
        let tail = bytes.dropFirst(4)
        return (1...59).contains(tail.count) && tail.allSatisfy { isLowercaseLetter($0) || isDigit($0) || $0 == UInt8(ascii: "-") }
    }

    private static func isLowercaseLetter(_ byte: UInt8) -> Bool { (UInt8(ascii: "a")...UInt8(ascii: "z")).contains(byte) }
    private static func isDigit(_ byte: UInt8) -> Bool { (UInt8(ascii: "0")...UInt8(ascii: "9")).contains(byte) }
}
