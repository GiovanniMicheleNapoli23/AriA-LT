//
//  AdminAgentStudioRunModeSection.swift
//  AriaLite
//
//  Created by Giovanni Michele on 27/10/26.
//
//  "Run it": le tre modalità come righe selezionabili in un solo blocco di vetro e, sotto, un solo
//  pulsante Start la cui etichetta e il cui colore seguono la modalità scelta.
//

import SwiftUI

struct AdminAgentStudioRunModeSection: View {
    let selection: AdminAgentStudioRunMode
    let startLabel: String
    let isRealRun: Bool
    let canStart: Bool
    let onSelect: (AdminAgentStudioRunMode) -> Void
    let onStart: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            AdminAgentStudioSectionHeader(title: "Run it")
            AdminAgentStudioGlassGroup {
                ForEach(AdminAgentStudioRunMode.allCases) { mode in
                    AdminAgentStudioModeRow(mode: mode, isSelected: mode == selection) { onSelect(mode) }
                    if mode != AdminAgentStudioRunMode.allCases.last { Divider().padding(.leading, 14) }
                }
            }
            Button(action: onStart) {
                Text(startLabel)
                    .font(.headline)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
            .tint(isRealRun ? Color.orange : Color.liteAccent)
            .foregroundStyle(isRealRun ? Color.white : Color.liteOnAccent)
            .disabled(!canStart)
        }
    }
}
