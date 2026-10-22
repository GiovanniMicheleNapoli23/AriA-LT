//
//  AdminCraftedWidget.swift
//  AriaLite
//
//  Created by Giovanni Michele on 22/10/26.
//
//  Un widget salvato (SavedWidgetResponse): non una fotografia dei dati ma la "ricetta" di una card di
//  Aria — che tipo di card, quale tool e con quali argomenti — da rieseguire per avere i numeri di oggi.
//

import Foundation

nonisolated struct AdminCraftedWidget: Codable, Sendable, Hashable, Identifiable {
    /// Lo schema lo dà opzionale: senza id il widget si mostra ma non si apre né si elimina.
    let serverId: String?
    let title: String
    let description: String?
    let kind: String
    let toolName: String
    let toolArgs: [String: AriaJSON]?
    let position: Int?

    var id: String { serverId ?? "\(toolName)|\(title)|\(position ?? 0)" }

    enum CodingKeys: String, CodingKey {
        case title, description, kind, position
        case serverId = "id"
        case toolName = "tool_name"
        case toolArgs = "tool_args"
    }

    init(from decoder: any Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        serverId = try? c.decodeIfPresent(String.self, forKey: .serverId)
        title = (try? c.decodeIfPresent(String.self, forKey: .title)) ?? ""
        description = Self.nonBlank(try? c.decodeIfPresent(String.self, forKey: .description))
        kind = (try? c.decodeIfPresent(String.self, forKey: .kind)) ?? ""
        toolName = (try? c.decodeIfPresent(String.self, forKey: .toolName)) ?? ""
        toolArgs = try? c.decodeIfPresent([String: AriaJSON].self, forKey: .toolArgs)
        position = try? c.decodeIfPresent(Int.self, forKey: .position)
    }

    /// Il titolo da mostrare: se il server non ne ha uno, il tipo di card.
    var displayTitle: String { Self.nonBlank(title) ?? AdminCraftedKind.label(kind) }

    /// Gli argomenti del tool, in ordine, come righe "chiave: valore".
    var argumentFields: [AdminAssetField] {
        (toolArgs ?? [:]).sorted { $0.key < $1.key }.map { key, value in
            AdminAssetField(title: key.replacingOccurrences(of: "_", with: " "), value: value.stringValue ?? value.compactDescription)
        }
    }

    /// `nil` se vuota o fatta solo di spazi.
    private static func nonBlank(_ text: String?) -> String? {
        let trimmed = text?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        return trimmed.isEmpty ? nil : trimmed
    }

    var searchableFields: [String] {
        [title, description ?? "", toolName, kind, AdminCraftedKind.label(kind)]
    }
}

/// Body di POST /v1/saved-widgets.
nonisolated struct AdminCraftedWidgetCreate: Encodable, Sendable {
    let title: String
    let description: String?
    let kind: String
    let toolName: String
    let toolArgs: [String: AriaJSON]
    let position: Int

    enum CodingKeys: String, CodingKey {
        case title, description, kind, position
        case toolName = "tool_name"
        case toolArgs = "tool_args"
    }
}
