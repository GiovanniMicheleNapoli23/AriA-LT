//
//  AriaWorkOrderContext.swift
//  AriaLite
//
//  Created by Giovanni Michele on 15/10/26.
//
//  Il contesto che viaggia col primo messaggio della chat di un passo: ordine, passo corrente
//  e avvertenze. Il body di /v1/responses ha un limite (AriaConfig.maxBodyBytes): i testi lunghi si tagliano.
//

import Foundation

extension AriaWorkOrder {
    /// Testo per la chat contestuale di `step`.
    func chatContext(step: AriaProcedureStep?) -> String {
        var lines = ["Work order: \(title)"]
        let facts = [("Asset", assetTag), ("Zone", zone), ("Priority", priorityLevel.map { "\($0)" }),
                     ("Category", category), ("Type", type)]
        let line = facts.compactMap { name, value in value.flatMap { $0.isEmpty ? nil : "\(name): \($0)" } }
        if !line.isEmpty { lines.append(line.joined(separator: " | ")) }
        if let description, !description.isEmpty { lines.append("Description: \(description.truncated(to: 1200))") }

        if let procedure, let step {
            lines.append("Procedure step \(step.number) of \(procedure.steps.count): \(step.text.truncated(to: 600))")
            if let report = step.report {
                lines.append("Step result so far: \(report.isDone ? "done" : "not done")"
                             + (report.note.map { " (note: \($0.truncated(to: 400)))" } ?? ""))
            }
            if !procedure.safetyWarnings.isEmpty {
                lines.append("Safety warnings: " + procedure.safetyWarnings.joined(separator: "; ").truncated(to: 600))
            }
        }
        return lines.joined(separator: "\n")
    }
}

private extension String {
    func truncated(to count: Int) -> String {
        self.count <= count ? self : String(prefix(count)) + "…"
    }
}
