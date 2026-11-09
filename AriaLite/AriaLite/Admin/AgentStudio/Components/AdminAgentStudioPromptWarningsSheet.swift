//
//  AdminAgentStudioPromptWarningsSheet.swift
//  AriaLite
//
//  Created by Giovanni Michele on 27/10/26.
//
//  Gli avvisi del server sul prompt appena salvato, per esteso, in un foglio.
//

import SwiftUI

struct AdminAgentStudioPromptWarningsSheet: View {
    let warnings: [String]

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 12) {
                    ForEach(warnings, id: \.self) { warning in
                        AdminSectionNotice(text: warning, isError: true)
                    }
                }
                .padding(20)
                .ariaReadableWidth()
            }
            .liteBackground()
            .navigationTitle("Warnings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }
}
