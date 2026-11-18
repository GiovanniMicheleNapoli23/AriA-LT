//
//  AriaEffortSheet.swift
//  AriaLite
//
//  Created by Giovanni Michele on 18/11/26.
//
//  Il foglio "Effort" aperto dal "+" della chat: i livelli con cosa costa una risposta, e la scelta per la
//  conversazione. Se i livelli non si leggono, spiega che le risposte usano Base e offre "Try again".
//  La logica sta in AriaEffortPickerViewModel.
//

import SwiftUI

struct AriaEffortSheet: View {
    @Environment(\.dismiss) private var dismiss
    @State private var model: AriaEffortPickerViewModel

    init(chat: AriaAgentChat, backend: AriaBackend) {
        _model = State(initialValue: AriaEffortPickerViewModel(chat: chat, backend: backend))
    }

    var body: some View {
        NavigationStack {
            ZStack {
                Color.liteBackground.ignoresSafeArea()
                ScrollView {
                    content
                        .padding(.horizontal, 20)
                        .padding(.vertical, 12)
                        .ariaReadableWidth()
                }
                .scrollBounceBehavior(.basedOnSize)
            }
            .navigationTitle("Effort")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
            // Le stime si chiedono quando l'elenco compare (anche dopo un "Try again" riuscito).
            .task { await model.refreshConfig() }
            .task(id: model.screen) { await model.loadEstimates() }
        }
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
    }

    @ViewBuilder
    private var content: some View {
        switch model.screen {
        case .loading:
            ProgressView()
                .frame(maxWidth: .infinity, minHeight: 120)
                .accessibilityLabel("Loading effort levels")
        case .error:
            AriaUsageErrorView(
                title: "Effort levels aren’t available right now",
                message: "Replies keep using Base and chat works as usual.",
                isBusy: model.isRetrying
            ) { model.retry() }
        case .list:
            list
        }
    }

    private var list: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Higher effort lets AriA think longer before it replies, which helps with harder questions. Each reply uses more credits, so fewer fit in a day.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)

            let rows = model.rows
            VStack(spacing: 0) {
                ForEach(rows) { row in
                    if row.id != rows.first?.id { Divider().padding(.leading, 46) }
                    AriaEffortLevelRow(row: row, lockedHint: model.lockedHint) {
                        if model.select(row) { dismiss() }
                    }
                }
            }
            .background(Color.liteSurface, in: RoundedRectangle(cornerRadius: 16))
            // Una risposta in corso: i livelli non si cambiano (contratto 2.2).
            .opacity(model.isSelectionDisabled ? 0.5 : 1)
            .sensoryFeedback(.selection, trigger: model.chat.effortLevel)

            footer
        }
    }

    private var footer: some View {
        VStack(alignment: .leading, spacing: 4) {
            if let persist = model.persistFooter { Text(verbatim: persist) }
            if model.showsEstimateNote {
                Text("Replies per day are estimates for a full day’s allowance.")
            }
        }
        .font(.footnote)
        .foregroundStyle(.secondary)
        .fixedSize(horizontal: false, vertical: true)
        .padding(.horizontal, 4)
    }
}
