//
//  AdminAgentStudioEventRow.swift
//  AriaLite
//
//  Created by Giovanni Michele on 22/10/26.
//
//  Una riga del registro di un run (o dell'esito di un avvio): titolo, esito e dettaglio.
//

import SwiftUI

struct AdminAgentStudioEventRow: View {
    let event: AdminAgentStudioRunEvent
    var showsDivider = true

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            VStack(alignment: .leading, spacing: 3) {
                HStack(alignment: .firstTextBaseline, spacing: 8) {
                    Text(event.title)
                        .font(.footnote.weight(.semibold))
                        .lineLimit(2)
                    Spacer(minLength: 8)
                    if let status = event.status { AdminAgentStudioBadge(status: status) }
                }
                if let detail = event.detail {
                    Text(detail)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(6)
                        .textSelection(.enabled)
                }
            }
            .padding(.vertical, 8)
            if showsDivider { Divider() }
        }
    }
}
