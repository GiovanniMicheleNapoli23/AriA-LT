//
//  AdminCategoryIcon.swift
//  AriaLite
//
//  Created by Giovanni Michele on 22/10/26.
//
//  L'icona di una categoria: il nome SF Symbols se esiste davvero sul sistema, altrimenti un'icona generica.
//

import UIKit

@MainActor
enum AdminCategoryIcon {
    /// Icona di ripiego quando il nome non è un simbolo valido.
    static let fallback = "tag"

    /// Il nome da mostrare: quello del server se è un simbolo valido, altrimenti `tag`.
    static func symbolName(for icon: String?) -> String {
        guard let name = icon?.trimmingCharacters(in: .whitespacesAndNewlines), !name.isEmpty,
              UIImage(systemName: name) != nil else { return fallback }
        return name
    }

    /// `true` se il testo è un simbolo SF Symbols valido (o vuoto, che vuol dire "nessuna icona").
    static func isValid(_ text: String) -> Bool {
        let name = text.trimmingCharacters(in: .whitespacesAndNewlines)
        return name.isEmpty || UIImage(systemName: name) != nil
    }
}
