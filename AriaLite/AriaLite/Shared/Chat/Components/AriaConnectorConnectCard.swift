//
//  AriaConnectorConnectCard.swift
//  AriaLite
//
//  Created by Giovanni Michele on 29/10/26.
//
//  La card `connector-connect` in chat: il connettore da collegare, il suo stato, i link
//  della guida e il pulsante che porta alla pagina della web. L'app non raccoglie mai chiavi o codici.
//

import SwiftUI

struct AriaConnectorConnectCard: View {
    let connector: AriaArtifactContent.ConnectorConnect
    var actions = AriaArtifactActions()
    @Environment(\.openURL) private var openURL

    /// Pagina della web dove si collegano i connettori.
    private static let webPath = "/marketplace"

    var body: some View {
        AriaCard {
            Label {
                Text(connector.title).font(.subheadline.weight(.semibold))
            } icon: {
                Image(systemName: "puzzlepiece.extension.fill").foregroundStyle(Color.liteAccent)
            }
            if let line = connector.stateLine {
                Text(line).font(.footnote).foregroundStyle(.secondary)
            }
            ForEach(connector.sources, id: \.self) { source in
                Button(source.label, systemImage: "arrow.up.right.square") { openURL(source.url) }
                    .font(.footnote.weight(.medium))
                    .buttonStyle(.borderless)
            }
            if connector.showsWebButton {
                Button("Connect on the web") { actions.open(Self.webPath) }
                    .font(.footnote.weight(.semibold))
                    .buttonStyle(.borderedProminent)
                    .tint(.liteAccent)
                    .foregroundStyle(Color.liteOnAccent)
            }
        }
    }
}
