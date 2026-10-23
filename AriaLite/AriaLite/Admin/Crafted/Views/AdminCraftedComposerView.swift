//
//  AdminCraftedComposerView.swift
//  AriaLite
//
//  Created by Giovanni Michele on 23/10/26.
//
//  Il composer di Crafted, in un foglio: "Cosa vuoi che Aria crei?", un campo e gli esempi per tipo che lo
//  riempiono. Crea chiede l'artifact ad Aria e apre subito la sua riga.
//

import SwiftUI

struct AdminCraftedComposerView: View {
    @Bindable var viewModel: AdminCraftedComposerViewModel

    @Environment(\.dismiss) private var dismiss
    @FocusState private var isFocused: Bool

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    Text("What do you want Aria to make?")
                        .font(.title2.weight(.semibold))
                    TextField("Describe the chart, table or plan you need…", text: $viewModel.text, axis: .vertical)
                        .lineLimit(2...8)
                        .focused($isFocused)
                        .submitLabel(.send)
                        .onSubmit { viewModel.create() }
                        .padding(14)
                        .ariaGlass(in: RoundedRectangle(cornerRadius: 16))
                    if let reason = viewModel.blockedReason {
                        Text(reason)
                            .font(.footnote)
                            .foregroundStyle(.red)
                    }
                    examples
                }
                .padding(20)
                .ariaReadableWidth()
            }
            .scrollDismissesKeyboard(.interactively)
            .liteBackground()
            .navigationTitle("New artifact")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Create") { viewModel.create() }
                        .disabled(!viewModel.canCreate)
                }
            }
        }
        .task { isFocused = true }
    }

    private var examples: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("Or start from an example")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
                .textCase(.uppercase)
                .accessibilityAddTraits(.isHeader)
            ForEach(viewModel.examples) { example in
                AdminCraftedExampleRow(example: example) {
                    viewModel.fill(with: example)
                    isFocused = true
                }
            }
        }
    }
}
