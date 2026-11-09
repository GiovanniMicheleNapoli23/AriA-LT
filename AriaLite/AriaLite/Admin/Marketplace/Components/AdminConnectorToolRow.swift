//
//  AdminConnectorToolRow.swift
//  AriaLite
//
//  Created by Giovanni Michele on 22/10/26.
//
//  Un tool esposto dal connettore: nome tecnico, descrizione e un segno se modifica dati.
//

import SwiftUI

struct AdminConnectorToolRow: View {
    let tool: AdminConnectorTool

    var body: some View {
        VStack(alignment: .leading, spacing: 3) {
            HStack(alignment: .firstTextBaseline, spacing: 6) {
                Text(tool.name)
                    .font(.footnote.weight(.semibold).monospaced())
                    .foregroundStyle(.primary)
                    .textSelection(.enabled)
                if tool.destructive {
                    Label("Changes data", systemImage: "pencil.and.outline")
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(.orange)
                }
            }
            if let description = tool.description {
                Text(description)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(3)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.vertical, 6)
    }
}
