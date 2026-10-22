//
//  AdminConnectorTile.swift
//  AriaLite
//
//  Created by Giovanni Michele on 22/10/26.
//
//  La scheda di un connettore nella griglia: icona, nome, stato e una riga di contesto
//  (tool esposti, connessione personale o condivisa).
//

import SwiftUI

struct AdminConnectorTile: View {
    let connector: AdminConnector

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .top) {
                AdminConnectorIcon(provider: connector.provider, name: connector.name)
                Spacer(minLength: 8)
                AdminConnectorStatusBadge(status: connector.status)
            }
            Text(connector.name)
                .font(.headline)
                .foregroundStyle(.primary)
                .multilineTextAlignment(.leading)
                .lineLimit(2)
            if !connector.summaryLine.isEmpty {
                Text(connector.summaryLine)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .contentShape(Rectangle())
        .ariaGlass(in: RoundedRectangle(cornerRadius: 16))
        .accessibilityElement(children: .combine)
    }
}
