//
//  AdminReasoningPhase.swift
//  AriaLite
//
//  Created by Giovanni Michele on 22/10/26.
//
//  Una fase della trace (scope, perception, retrieval, memory, prompt, generation, gates, machineState,
//  learning) pronta da mostrare: valori brevi in righe, il resto in blocchi JSON da aprire.
//

import Foundation

nonisolated struct AdminReasoningPhase: Identifiable, Sendable {
    let key: String
    let title: String
    let systemImage: String
    let fields: [AdminAssetField]
    let blocks: [AdminReasoningJSONBlock]

    var id: String { key }
    var isEmpty: Bool { fields.isEmpty && blocks.isEmpty }

    /// "3 values · 2 blocks", accanto al titolo quando la sezione è chiusa.
    var summary: String {
        isEmpty ? String(localized: "Empty") : String(localized: "\(fields.count) values · \(blocks.count) blocks")
    }

    init(key: String, value: AriaJSON) {
        self.key = key
        let known = Self.catalog[key]
        title = known?.title ?? AdminReasoningFormat.humanize(key)
        systemImage = known?.systemImage ?? "curlybraces"
        if let object = value.objectValue {
            (fields, blocks) = AdminReasoningFormat.split(object)
        } else if let text = AdminReasoningFormat.inline(value, key: key) {
            fields = [AdminAssetField(title: title, value: text)]
            blocks = []
        } else {
            fields = []
            blocks = [AdminReasoningJSONBlock(key: key, value: value)]
        }
    }

    /// Le fasi note, nell'ordine del turno; quelle nuove del server vanno in fondo, in ordine alfabetico.
    static let order = ["scope", "perception", "retrieval", "memory", "prompt", "generation", "gates",
                        "machineState", "learning"]

    private static let catalog: [String: (title: String, systemImage: String)] = [
        "scope": (String(localized: "Scope"), "scope"),
        "perception": (String(localized: "Perception"), "eye"),
        "retrieval": (String(localized: "Retrieval"), "doc.text.magnifyingglass"),
        "memory": (String(localized: "Memory"), "brain"),
        "prompt": (String(localized: "Prompt"), "text.bubble"),
        "generation": (String(localized: "Generation"), "sparkles"),
        "gates": (String(localized: "Gates"), "checkmark.shield"),
        "machineState": (String(localized: "Machine state"), "gauge.with.dots.needle.33percent"),
        "learning": (String(localized: "Learning"), "graduationcap"),
    ]

    /// Tutte le fasi di una trace, nell'ordine `order`.
    static func phases(of trace: AdminReasoningTrace) -> [AdminReasoningPhase] {
        let keys = trace.phases.keys.sorted { lhs, rhs in
            switch (order.firstIndex(of: lhs), order.firstIndex(of: rhs)) {
            case let (l?, r?): l < r
            case (.some, nil): true
            case (nil, .some): false
            case (nil, nil): lhs < rhs
            }
        }
        return keys.compactMap { key in trace.phases[key].map { AdminReasoningPhase(key: key, value: $0) } }
    }
}
