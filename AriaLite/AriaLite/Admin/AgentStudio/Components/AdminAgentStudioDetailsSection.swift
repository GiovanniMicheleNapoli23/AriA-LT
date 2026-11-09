//
//  AdminAgentStudioDetailsSection.swift
//  AriaLite
//
//  Created by Giovanni Michele on 27/10/26.
//
//  "Details": poche righe titolo/valore in un blocco di vetro, sempre aperte. Il valore può andare
//  a capo; niente testo selezionabile.
//

import SwiftUI

struct AdminAgentStudioDetailsSection: View {
    let fields: [AdminAssetField]

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            AdminAgentStudioSectionHeader(title: "Details")
            AdminAgentStudioGlassGroup {
                ForEach(fields) { field in
                    HStack(alignment: .firstTextBaseline, spacing: 12) {
                        Text(field.title)
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.leading)
                        Spacer(minLength: 12)
                        Text(field.value)
                            .multilineTextAlignment(.trailing)
                    }
                    .font(.subheadline)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 10)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .accessibilityElement(children: .combine)
                    if field != fields.last { Divider().padding(.leading, 14) }
                }
            }
        }
    }
}
