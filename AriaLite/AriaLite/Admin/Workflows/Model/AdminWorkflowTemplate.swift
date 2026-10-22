//
//  AdminWorkflowTemplate.swift
//  AriaLite
//
//  Created by Giovanni Michele on 22/10/26.
//
//  I modelli di flusso (GET /v1/topologies) e il grafo di uno (GET /v1/topologies/{name}/graph).
//  Le due rotte non hanno uno schema: la lista può essere un array o un oggetto nome → scheda, il grafo
//  può stare alla radice o sotto `graph`. Si leggono tutte le forme plausibili; quello che non si
//  capisce si scarta, e un modello senza nodi non si può usare.
//

import Foundation

nonisolated struct AdminWorkflowTemplate: Sendable, Identifiable, Hashable {
    /// Il nome con cui si chiede il grafo.
    let name: String
    let description: String?

    var id: String { name }
}

nonisolated struct AdminWorkflowTemplateList: Decodable, Sendable {
    let templates: [AdminWorkflowTemplate]

    init(from decoder: any Decoder) throws {
        let json = try AriaJSON(from: decoder)
        var source = json
        if let object = json.objectValue,
           let key = ["topologies", "templates", "items", "data"].first(where: { object[$0] != nil }),
           let inner = object[key] {
            source = inner
        }
        var found: [AdminWorkflowTemplate] = []
        switch source {
        case .array(let items):
            found = items.compactMap(Self.template(from:))
        case .object(let object):
            found = object.compactMap { key, value in
                switch value {
                case .object(let fields): Self.template(named: key, fields: fields)
                case .string(let text): AdminWorkflowTemplate(name: key, description: text.nonEmpty)
                default: nil
                }
            }
        default:
            break
        }
        var seen = Set<String>()
        templates = found.filter { seen.insert($0.name).inserted }
            .sorted { $0.name.localizedStandardCompare($1.name) == .orderedAscending }
    }

    private static func template(from json: AriaJSON) -> AdminWorkflowTemplate? {
        if let name = json.nonEmptyString { return AdminWorkflowTemplate(name: name, description: nil) }
        guard let fields = json.objectValue,
              let name = ["name", "id", "key"].lazy.compactMap({ fields[$0]?.nonEmptyString }).first else { return nil }
        return template(named: name, fields: fields)
    }

    private static func template(named name: String, fields: [String: AriaJSON]) -> AdminWorkflowTemplate {
        let description = ["description", "summary"].lazy.compactMap { fields[$0]?.nonEmptyString }.first
        return AdminWorkflowTemplate(name: name, description: description)
    }
}

nonisolated struct AdminWorkflowTemplateGraph: Decodable, Sendable {
    let graph: AdminWorkflowGraph

    init(from decoder: any Decoder) throws {
        let json = try AriaJSON(from: decoder)
        let root = json["graph"]?.objectValue != nil ? json["graph"] : json
        graph = (try? root?.decoded(as: AdminWorkflowGraph.self)) ?? AdminWorkflowGraph()
    }
}

private extension String {
    nonisolated var nonEmpty: String? {
        let trimmed = trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }
}
