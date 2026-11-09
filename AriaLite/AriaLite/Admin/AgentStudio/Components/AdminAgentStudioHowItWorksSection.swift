//
//  AdminAgentStudioHowItWorksSection.swift
//  AriaLite
//
//  Created by Giovanni Michele on 27/10/26.
//
//  "How it works": i passi del workflow come flusso verticale in un blocco di vetro, dal trigger in giù.
//

import SwiftUI

struct AdminAgentStudioHowItWorksSection: View {
    let steps: [AdminAgentStudioWorkflowStep]

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            AdminAgentStudioSectionHeader(title: "How it works")
            AdminAgentStudioGlassGroup {
                if steps.isEmpty {
                    AdminSectionNotice(text: String(localized: "This workflow has no steps yet."))
                        .padding(14)
                } else {
                    VStack(alignment: .leading, spacing: 0) {
                        ForEach(Array(steps.enumerated()), id: \.element.id) { index, step in
                            AdminAgentStudioFlowStepRow(step: step, isLast: index == steps.count - 1)
                        }
                    }
                    .padding(14)
                }
            }
        }
    }
}
