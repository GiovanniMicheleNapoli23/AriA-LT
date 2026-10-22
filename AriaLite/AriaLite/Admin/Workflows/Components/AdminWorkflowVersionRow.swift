//
//  AdminWorkflowVersionRow.swift
//  AriaLite
//
//  Created by Giovanni Michele on 22/10/26.
//
//  Una versione pubblicata nel foglio delle versioni: numero, quando e (se è un indirizzo) da chi,
//  quanti passi aveva. Il ripristino lo fa il menu di chi la usa.
//

import SwiftUI

struct AdminWorkflowVersionRow: View {
    let version: AdminWorkflowVersion
    let isCurrent: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 8) {
                Text("Version \(version.version)")
                    .font(.headline)
                if isCurrent {
                    Text("Current")
                        .font(.caption2.weight(.bold))
                        .foregroundStyle(.green)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 3)
                        .background(Color.green.opacity(0.14), in: Capsule())
                }
            }
            if !version.name.isEmpty {
                Text(version.name)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            Text(metaLine)
                .font(.caption)
                .foregroundStyle(.tertiary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .contentShape(Rectangle())
    }

    /// "3 days ago · by marco@… · 5 steps". L'autore si mostra solo se è un indirizzo, non un id interno.
    private var metaLine: String {
        var parts: [String] = []
        if let date = version.publishedAt { parts.append(date.formatted(.relative(presentation: .named))) }
        if let author = version.publishedBy, author.contains("@") { parts.append(String(localized: "by \(author)")) }
        parts.append(String(localized: "\(version.graph.nodes.count) steps"))
        return parts.joined(separator: " · ")
    }
}
