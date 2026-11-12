//
//  AdminDocumentPipelineToggle.swift
//  AriaLite
//
//  Created by Giovanni Michele on 12/11/26.
//
//  Una pipeline da avviare dopo il caricamento: icona, nome e cosa fa, con lo switch a destra.
//

import SwiftUI

struct AdminDocumentPipelineToggle: View {
    let title: LocalizedStringKey
    let detail: LocalizedStringKey
    let systemImage: String
    @Binding var isOn: Bool

    @ScaledMetric(relativeTo: .body) private var iconWidth: CGFloat = 24

    var body: some View {
        Toggle(isOn: $isOn) {
            HStack(alignment: .firstTextBaseline, spacing: 12) {
                Image(systemName: systemImage)
                    .font(.body.weight(.medium))
                    .foregroundStyle(Color.liteAccent)
                    .frame(width: iconWidth)
                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.body)
                    Text(detail)
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
        }
        .padding(.vertical, 4)
    }
}
