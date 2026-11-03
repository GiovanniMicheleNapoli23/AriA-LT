//
//  AriaExternalAction.swift
//  AriaLite
//
//  Created by Giovanni Michele on 30/10/26.
//
//  `aria.external_action`: un'azione fatta su un sistema esterno (Gmail, CMMS…). Il `summary` del server
//  può essere l'uscita grezza dello strumento (avviso "Untrusted content…" e JSON): in chat va una riga
//  breve, "Gmail · Send email". I dati veri stanno già nella card del risultato.
//

import Foundation

struct AriaExternalAction: Equatable {
    let system: String
    let detail: String
    let isOK: Bool

    /// Oltre questa lunghezza il riepilogo è un dump, non una frase.
    private static let maxSummary = 140

    init(_ data: AriaJSON) {
        system = data["system"]?.nonEmptyString ?? "CMMS"
        isOK = data["status"]?.stringValue == "ok"
        let summary = data["summary"]?.nonEmptyString
        let tool = data["tool"]?.nonEmptyString ?? summary.flatMap(Self.toolName(in:))
        if let summary, Self.isReadable(summary) {
            detail = summary
        } else if let tool, let name = Self.humanize(tool, system: system) {
            detail = name
        } else {
            detail = isOK ? String(localized: "Action completed") : String(localized: "Action failed")
        }
    }

    /// Una frase per le persone: niente avviso sui contenuti esterni, niente JSON, niente muri di testo.
    private static func isReadable(_ summary: String) -> Bool {
        summary.count <= maxSummary && !summary.hasPrefix("[") && !summary.contains("{")
    }

    /// "gmail-personal GMAIL_SEND_EMAIL returned id …" → "GMAIL_SEND_EMAIL".
    private static func toolName(in summary: String) -> String? {
        summary.split(whereSeparator: \.isWhitespace).lazy.map(String.init).first { word in
            word.count > 3 && word.contains("_") && word == word.uppercased() && word.allSatisfy { $0.isLetter || $0.isNumber || $0 == "_" }
        }
    }

    /// "GMAIL_SEND_EMAIL" con sistema "Gmail" → "Send email"; "mcp_gmail_personal_gmail_send_email" → "Send email".
    private static func humanize(_ tool: String, system: String) -> String? {
        var words = tool.lowercased().split(whereSeparator: { $0 == "_" || $0 == "-" || $0 == " " || $0 == "." }).map(String.init)
        // Il nome del server MCP e del sistema davanti all'azione: si tiene quello che viene dopo l'ultimo.
        let prefixes: Set<String> = ["mcp", "personal", system.lowercased()]
        if let last = words.lastIndex(where: prefixes.contains) { words.removeSubrange(...last) }
        guard !words.isEmpty else { return nil }
        let text = words.joined(separator: " ")
        return text.prefix(1).uppercased() + text.dropFirst()
    }
}
