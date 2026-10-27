//
//  AdminAgentStudioRunLogCard.swift
//  AriaLite
//
//  Created by Giovanni Michele on 27/10/26.
//
//  Il registro tecnico del run, chiuso di default: gli ultimi 50 eventi, con la possibilità di mostrarli tutti.
//

import SwiftUI

struct AdminAgentStudioRunLogCard: View {
    let events: [AdminAgentStudioRunEvent]

    private static let tailCount = 50

    @State private var showsAll = false

    var body: some View {
        AdminAgentStudioDisclosureCard(title: "Technical log", systemImage: "list.bullet.rectangle", startsExpanded: false) {
            VStack(alignment: .leading, spacing: 8) {
                if events.isEmpty {
                    AdminSectionNotice(text: String(localized: "No events recorded."))
                } else {
                    let shown = showsAll ? events : Array(events.suffix(Self.tailCount))
                    VStack(spacing: 0) {
                        ForEach(shown) { event in
                            AdminAgentStudioEventRow(event: event, showsDivider: event.id != shown.last?.id)
                        }
                    }
                    if events.count > Self.tailCount {
                        Button {
                            showsAll.toggle()
                        } label: {
                            showsAll ? Text("Show only the latest") : Text("Show all (\(events.count))")
                        }
                        .font(.subheadline.weight(.semibold))
                        .tint(Color.liteAccent)
                    }
                }
            }
        }
    }
}
