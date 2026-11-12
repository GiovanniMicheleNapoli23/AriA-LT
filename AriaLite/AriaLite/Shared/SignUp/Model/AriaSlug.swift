//
//  AriaSlug.swift
//  AriaLite
//
//  Created by Giovanni Michele on 11/11/26.
//
//  Lo slug dell'azienda (il suo nome breve negli indirizzi) con la regola della web, `normalizeSlug`:
//  minuscole; ogni gruppo di caratteri che non sono a–z o 0–9 diventa un solo `-`; via i `-` in testa e in coda;
//  i primi 32 caratteri. "Acme Srl" → "acme-srl", "Ölwerk & Co." → "lwerk-co" (solo ASCII: Ö non è una lettera
//  ammessa). Il backend confronta lo slug così com'è: si manda sempre normalizzato.
//

import Foundation

nonisolated enum AriaSlug {
    static let maxLength = 32
    /// Sotto questa lunghezza non si chiede se è libero.
    static let minCheckLength = 2

    static func normalize(_ text: String) -> String {
        var slug = ""
        var separator = false
        for scalar in text.lowercased().unicodeScalars {
            if isAllowed(scalar) {
                if separator, !slug.isEmpty { slug.append("-") }
                separator = false
                slug.unicodeScalars.append(scalar)
            } else {
                separator = true
            }
        }
        return String(slug.prefix(maxLength))
    }

    /// Come `normalize`, ma mentre la persona scrive: il `-` in coda resta, altrimenti sparirebbe a ogni tasto e
    /// non si potrebbero separare due parole. Si controlla e si manda sempre `normalize`.
    static func editing(_ text: String) -> String {
        let slug = normalize(text)
        guard !slug.isEmpty, slug.count < maxLength,
              let last = text.lowercased().unicodeScalars.last, !isAllowed(last) else { return slug }
        return slug + "-"
    }

    private static func isAllowed(_ scalar: Unicode.Scalar) -> Bool {
        ("a"..."z").contains(scalar) || ("0"..."9").contains(scalar)
    }
}
