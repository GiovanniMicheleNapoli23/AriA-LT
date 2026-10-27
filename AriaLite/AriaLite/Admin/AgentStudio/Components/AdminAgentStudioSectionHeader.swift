//
//  AdminAgentStudioSectionHeader.swift
//  AriaLite
//
//  Created by Giovanni Michele on 27/10/26.
//
//  Il titolo di un gruppo della schermata principale di Agent Studio, con una riga di dettaglio facoltativa sotto.
//

import SwiftUI

struct AdminAgentStudioSectionHeader: View {
    let title: LocalizedStringKey
    var detail: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title)
                .font(.headline)
                .accessibilityAddTraits(.isHeader)
            if let detail {
                Text(detail)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}
