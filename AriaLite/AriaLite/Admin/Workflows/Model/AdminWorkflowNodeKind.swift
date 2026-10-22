//
//  AdminWorkflowNodeKind.swift
//  AriaLite
//
//  Created by Giovanni Michele on 22/10/26.
//
//  I tipi di nodo di un flusso: nome e icona per mostrarli (il server manda solo l'id del tipo), e
//  la scheda di GET /v1/topologies/node-kinds che dice se il tipo è disponibile su questo server.
//

import Foundation

nonisolated enum AdminWorkflowNodeKind: String, Sendable, CaseIterable {
    case start
    case bindSpecialty = "bind_specialty"
    case retrieve
    case safetyGate = "safety_gate"
    case safety
    case agent
    case tools
    case groundingCheck = "grounding_check"
    case group

    var label: String {
        switch self {
        case .start: String(localized: "Start")
        case .bindSpecialty: String(localized: "Bind specialty")
        case .retrieve: String(localized: "Retrieve")
        case .safetyGate: String(localized: "Safety gate")
        case .safety: String(localized: "Safety")
        case .agent: String(localized: "Agent")
        case .tools: String(localized: "Tools")
        case .groundingCheck: String(localized: "Grounding check")
        case .group: String(localized: "Group")
        }
    }

    var systemImage: String {
        switch self {
        case .start: "play.circle"
        case .bindSpecialty: "link"
        case .retrieve: "magnifyingglass"
        case .safetyGate: "shield.lefthalf.filled"
        case .safety: "exclamationmark.shield"
        case .agent: "sparkles"
        case .tools: "wrench.and.screwdriver"
        case .groundingCheck: "checkmark.seal"
        case .group: "square.on.square.dashed"
        }
    }

    /// Un tipo nuovo che l'app non conosce si mostra col suo id leggibile ("my_kind" → "My kind").
    static func label(for raw: String) -> String {
        if let kind = AdminWorkflowNodeKind(rawValue: raw) { return kind.label }
        let words = raw.replacingOccurrences(of: "_", with: " ").trimmingCharacters(in: .whitespaces)
        return words.isEmpty ? String(localized: "Step") : words.prefix(1).uppercased() + words.dropFirst()
    }

    static func systemImage(for raw: String) -> String {
        AdminWorkflowNodeKind(rawValue: raw)?.systemImage ?? "circle.dashed"
    }
}

/// Una voce di GET /v1/topologies/node-kinds (i gestori e le dipendenze non servono sul telefono).
nonisolated struct AdminWorkflowNodeKindInfo: Decodable, Sendable, Hashable {
    let kind: String
    /// `false`: il server non ha i servizi che il tipo richiede, un flusso che lo usa non parte.
    let available: Bool
    let singleton: Bool

    private enum CodingKeys: String, CodingKey { case kind, available, singleton }

    init(from decoder: any Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        kind = try c.decode(String.self, forKey: .kind)
        available = (try? c.decodeIfPresent(Bool.self, forKey: .available)) ?? true
        singleton = (try? c.decodeIfPresent(Bool.self, forKey: .singleton)) ?? false
    }
}
