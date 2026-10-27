//
//  AdminAgentStudioPromptBaseSheet.swift
//  AriaLite
//
//  Created by Giovanni Michele on 27/10/26.
//
//  Il prompt di base di un agente, in sola lettura e selezionabile, in un foglio con il suo scroll.
//

import SwiftUI

struct AdminAgentStudioPromptBaseSheet: View {
    let text: String

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                Text(text)
                    .font(.callout.monospaced())
                    .textSelection(.enabled)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(20)
                    .ariaReadableWidth()
            }
            .liteBackground()
            .navigationTitle("Base prompt")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }
}
