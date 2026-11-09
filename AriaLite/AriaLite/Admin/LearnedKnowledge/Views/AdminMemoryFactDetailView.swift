//
//  AdminMemoryFactDetailView.swift
//  AriaLite
//
//  Created by Giovanni Michele on 22/10/26.
//
//  Il dettaglio di un fatto imparato: testo, approva/rifiuta, chi l'ha proposto e quando, affidabilità,
//  uso nelle risposte e la conversazione da cui viene. Modifica ed elimina stanno nel menu in alto.
//  I dialoghi di conferma e gli errori li mostra AdminLearnedKnowledgeView (stesse azioni della lista).
//

import SwiftUI

struct AdminMemoryFactDetailView: View {
    @State private var viewModel: AdminMemoryFactDetailViewModel
    @State private var editForm: AdminMemoryFactFormViewModel?

    @Environment(\.dismiss) private var dismiss

    private let columns = [GridItem(.adaptive(minimum: 110), spacing: 10)]

    init(viewModel: AdminMemoryFactDetailViewModel) {
        _viewModel = State(initialValue: viewModel)
    }

    var body: some View {
        Group {
            if let fact = viewModel.fact {
                content(fact)
            } else {
                ContentUnavailableView("Fact deleted", systemImage: "trash",
                                       description: Text("This fact is no longer in the company memory."))
            }
        }
        .liteBackground()
        .navigationTitle("Fact")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            if let fact = viewModel.fact {
                ToolbarItem(placement: .topBarTrailing) {
                    Menu("Actions", systemImage: "ellipsis") {
                        Button("Edit", systemImage: "pencil") { editForm = viewModel.makeEditForm(for: fact) }
                        Button("Delete", systemImage: "trash", role: .destructive) { viewModel.askToDelete(fact) }
                    }
                    .disabled(viewModel.isBusy(fact))
                }
            }
        }
        .sheet(item: $editForm) { form in
            AdminMemoryFactFormView(viewModel: form) { viewModel.saved($0) }
        }
        // Eliminato (da qui o dal menu della lista): si torna alla lista.
        .onChange(of: viewModel.fact == nil) { _, deleted in
            if deleted { dismiss() }
        }
    }

    private func content(_ fact: AdminMemoryFact) -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                AdminMemoryFactHeaderCard(fact: fact, text: viewModel.text(of: fact),
                                          summary: viewModel.summaryLine(of: fact),
                                          isTranslated: viewModel.isTranslated(fact),
                                          showsOriginal: $viewModel.showsOriginal)
                if viewModel.canApprove(fact) || viewModel.canReject(fact) {
                    AdminMemoryFactModerationBar(
                        canApprove: viewModel.canApprove(fact), canReject: viewModel.canReject(fact),
                        isBusy: viewModel.isBusy(fact),
                        onApprove: { Task { await viewModel.approve(fact) } },
                        onReject: { viewModel.askToReject(fact) })
                }
                AdminMemoryFactFieldsCard(title: "Provenance", systemImage: "person.text.rectangle",
                                          fields: viewModel.provenance(of: fact))
                reliabilityCard(fact)
                usageCard(fact)
                if viewModel.hasConversation(fact) { conversationCard(fact) }
            }
            .padding(20)
            .ariaReadableWidth()
        }
    }

    // MARK: Schede

    private func reliabilityCard(_ fact: AdminMemoryFact) -> some View {
        AdminMemoryFactFieldsCard(title: "Reliability", systemImage: "checkmark.shield",
                                  fields: viewModel.reliability(of: fact)) {
            if viewModel.hasReliabilityNotes(fact) {
                VStack(alignment: .leading, spacing: 12) {
                    if let conflict = fact.conflictingEvidence {
                        AdminMemoryFactQuote(title: String(localized: "Conflicting evidence"), text: conflict, tint: .orange)
                    }
                    ForEach(fact.evidence, id: \.self) { item in
                        AdminMemoryFactQuote(title: String(localized: "Evidence"), text: item)
                    }
                }
                .padding(.top, 12)
            }
        }
    }

    private func usageCard(_ fact: AdminMemoryFact) -> some View {
        AdminCard(title: "Use in answers", systemImage: "chart.bar.xaxis") {
            VStack(alignment: .leading, spacing: 10) {
                LazyVGrid(columns: columns, alignment: .leading, spacing: 10) {
                    ForEach(viewModel.usage(of: fact)) { stat in
                        AdminStatTile(title: stat.title, value: stat.value, systemImage: stat.systemImage)
                    }
                }
                if let line = viewModel.lastUsedLine(of: fact) {
                    Text(line)
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
            }
        }
    }

    private func conversationCard(_ fact: AdminMemoryFact) -> some View {
        AdminCard(title: "From the conversation", systemImage: "bubble.left.and.text.bubble.right") {
            VStack(alignment: .leading, spacing: 12) {
                if let question = fact.sourceQuestion {
                    AdminMemoryFactQuote(title: String(localized: "Question"), text: question, tint: .secondary)
                }
                if let answer = viewModel.answer(of: fact) {
                    AdminMemoryFactQuote(title: String(localized: "Aria's answer"), text: answer)
                }
            }
        }
    }
}
