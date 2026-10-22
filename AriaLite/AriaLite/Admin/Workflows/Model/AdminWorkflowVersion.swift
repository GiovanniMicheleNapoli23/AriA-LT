//
//  AdminWorkflowVersion.swift
//  AriaLite
//
//  Created by Giovanni Michele on 22/10/26.
//
//  Una versione pubblicata di un flusso (FlowDefinitionVersion): numero, quando e da chi, e il grafo
//  com'era. Ripristinarla riporta il flusso a quel grafo.
//

import Foundation

nonisolated struct AdminWorkflowVersion: Decodable, Sendable, Identifiable, Hashable {
    /// Il numero di versione, unico dentro il flusso.
    let version: Int
    let name: String
    let description: String?
    let graph: AdminWorkflowGraph
    let publishedAt: Date?
    let publishedBy: String?

    var id: Int { version }

    private enum CodingKeys: String, CodingKey { case version, name, description, graph, publishedAt, publishedBy }

    init(from decoder: any Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        version = try c.decode(Int.self, forKey: .version)
        name = (try? c.decodeIfPresent(String.self, forKey: .name)) ?? ""
        description = (try? c.decodeIfPresent(String.self, forKey: .description)).flatMap { $0.isEmpty ? nil : $0 }
        graph = (try? c.decodeIfPresent(AdminWorkflowGraph.self, forKey: .graph)) ?? AdminWorkflowGraph()
        publishedAt = (try? c.decodeIfPresent(AriaWireDate.self, forKey: .publishedAt))?.value
        publishedBy = (try? c.decodeIfPresent(String.self, forKey: .publishedBy)).flatMap { $0.isEmpty ? nil : $0 }
    }
}
