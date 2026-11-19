//
//  AdminUsageTone.swift
//  AriaLite
//
//  Created by Giovanni Michele on 18/11/26.
//
//  I toni e i pezzi comuni dei modelli di visualizzazione della pagina Usage. Nessun colore: le viste scelgono
//  (normale = accento, avviso = ambra, "over" e critico = grigio, mai rosso).
//

import Foundation

/// Il tono di una barra o di un contatore: normale, ambra, oltre il previsto.
nonisolated enum AdminUsageTone: Sendable, Equatable {
    case normal, warning, over
}

/// Il tono dell'avviso in testa alla pagina.
nonisolated enum AdminUsageAlertTone: Sendable, Equatable {
    case info, warning, critical
}

/// Un'azione che apre una mail alle vendite (`config.ui.sales_contact_email`): "Upgrade to {plan}", "Choose a plan".
nonisolated struct AdminUsageMailAction: Sendable, Equatable {
    var label: String
    var url: URL
}

/// La mail alle vendite: `mailto:` con l'oggetto codificato come `encodeURIComponent` della web.
nonisolated enum AdminUsageMail {
    static func url(email: String, subject: String) -> URL? {
        var allowed = CharacterSet.alphanumerics
        allowed.insert(charactersIn: "-_.!~*'()")
        guard let encoded = subject.addingPercentEncoding(withAllowedCharacters: allowed) else { return nil }
        return URL(string: "mailto:\(email)?subject=\(encoded)")
    }

    /// L'azione con l'etichetta data e un oggetto; `nil` senza indirizzo o con un indirizzo che non fa un URL.
    static func action(label: String, subject: String, email: String?) -> AdminUsageMailAction? {
        guard let email, !email.isEmpty, let url = url(email: email, subject: subject) else { return nil }
        return AdminUsageMailAction(label: label, url: url)
    }
}

/// Lo stato di una chiamata, per riquadro.
nonisolated enum AdminUsagePhase: Sendable, Equatable {
    case idle, loading, loaded, failed
}
