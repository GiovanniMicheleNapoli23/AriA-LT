//
//  AdminWorkOrderResponses.swift
//  AriaLite
//
//  Created by Giovanni Michele on 22/10/26.
//
//  Le risposte delle azioni sull'ordine: l'esito dell'assegnazione automatica (AutoAssignResponse) e la
//  traduzione dei testi (forma libera nell'OpenAPI: si leggono i campi noti, il resto si mostra com'è).
//

import Foundation

/// POST /v1/work-orders/{id}/auto-assign.
nonisolated struct AdminWorkOrderAutoAssignResult: Decodable, Sendable, Hashable {
    var assigned: Bool
    var assigneeId: String?
    var assigneeName: String?
    var note: String?

    private enum CodingKeys: String, CodingKey { case assigned, assignee, note }

    init(assigned: Bool, assigneeId: String? = nil, assigneeName: String? = nil, note: String? = nil) {
        self.assigned = assigned
        self.assigneeId = assigneeId
        self.assigneeName = assigneeName
        self.note = note
    }

    init(from decoder: any Decoder) throws {
        let f = try AdminWorkOrderFields(decoder, keyedBy: CodingKeys.self)
        assigned = f.value(Bool.self, .assigned) ?? false
        note = f.text(.note)
        let assignee = f.value(AriaJSON.self, .assignee)
        assigneeId = assignee?["id"]?.nonEmptyString
        assigneeName = assignee?["name"]?.nonEmptyString
    }
}

/// GET /v1/work-orders/{id}/translation?locale=: i testi dell'ordine in un'altra lingua, da leggere.
nonisolated struct AdminWorkOrderTranslation: Sendable, Hashable {
    /// La lingua chiesta ("it", "en", …).
    let locale: String
    var title: String?
    /// Descrizione, note e gli altri testi tradotti, nell'ordine in cui si mostrano.
    var blocks: [AdminWorkOrderTextBlock]

    var isEmpty: Bool { title == nil && blocks.isEmpty }

    /// Chiavi che non sono testo dell'ordine.
    private static let ignored: Set<String> = [
        "id", "locale", "language", "sourceLocale", "targetLocale", "workOrderId", "translated", "cached",
    ]

    /// La risposta, già in camelCase. I testi possono stare al primo livello o dentro `translation`/`fields`.
    init(json: AriaJSON, locale: String) {
        self.locale = json["locale"]?.nonEmptyString ?? locale
        let source = json["translation"]?.objectValue.map(AriaJSON.object)
            ?? json["fields"]?.objectValue.map(AriaJSON.object)
            ?? json["workOrder"]?.objectValue.map(AriaJSON.object)
            ?? json
        title = source["title"]?.nonEmptyString
        let known: [(key: String, title: String, icon: String)] = [
            ("description", String(localized: "Description"), "text.alignleft"),
            ("notes", String(localized: "Notes"), "note.text"),
            ("resolutionNotes", String(localized: "Resolution notes"), "checkmark.seal"),
            ("feedback", String(localized: "Feedback"), "bubble.left"),
        ]
        var blocks = known.compactMap { item in
            source[item.key]?.nonEmptyString.map { AdminWorkOrderTextBlock(title: item.title, icon: item.icon, text: $0) }
        }
        // Altri testi che il server traduce e l'app non conosce ancora: si mostrano col loro nome.
        let used = Set(known.map(\.key) + ["title"]).union(Self.ignored)
        let extra = (source.objectValue ?? [:])
            .filter { !used.contains($0.key) }
            .compactMap { key, value in
                if case .string = value, let text = value.nonEmptyString {
                    return AdminWorkOrderTextBlock(title: key, icon: "text.quote", text: text)
                }
                return nil
            }
            .sorted { $0.title < $1.title }
        blocks += extra
        self.blocks = blocks
    }
}
