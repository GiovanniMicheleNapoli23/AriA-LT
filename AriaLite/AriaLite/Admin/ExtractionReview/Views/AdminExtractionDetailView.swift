//
//  AdminExtractionDetailView.swift
//  AriaLite
//
//  Created by Giovanni Michele on 22/10/26.
//
//  Il dettaglio di un elemento estratto: intestazione, AI (proposta da applicare), campi principali da
//  correggere ("Save" in alto) e in fondo "Approve" / "Reject". Dopo la decisione torna alla lista.
//

import SwiftUI

struct AdminExtractionDetailView: View {
    @State private var viewModel: AdminExtractionDetailViewModel
    @State private var confirmsReject = false
    @FocusState private var focusedField: String?
    @Environment(\.dismiss) private var dismiss

    init(viewModel: AdminExtractionDetailViewModel) {
        _viewModel = State(initialValue: viewModel)
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                AdminExtractionHeader(item: viewModel.item)
                if let message = viewModel.refreshError {
                    AdminSectionNotice(text: message, isError: true)
                }
                if !viewModel.canEdit {
                    AdminSectionNotice(text: String(localized: "This item has no server id: it can be viewed but not changed."),
                                       systemImage: "lock")
                }
                AdminExtractionAICard(viewModel: viewModel)
                fieldsCard
                decisionButtons
            }
            .padding(20)
            .ariaReadableWidth()
        }
        .scrollDismissesKeyboard(.interactively)
        .liteBackground()
        .navigationTitle(viewModel.item.kind.title)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                if viewModel.isSaving {
                    ProgressView()
                } else {
                    Button("Save") {
                        focusedField = nil
                        Task { await viewModel.save() }
                    }
                    .fontWeight(.semibold)
                    .disabled(!viewModel.canSave)
                }
            }
            ToolbarItemGroup(placement: .keyboard) {
                Spacer()
                Button("Done") { focusedField = nil }
            }
        }
        .task { await viewModel.refresh() }
        .alert("Couldn't save", isPresented: $viewModel.showsActionError) {
            Button("OK") {}
        } message: {
            Text(viewModel.actionError ?? "")
        }
        .confirmationDialog("Reject this item?", isPresented: $confirmsReject, titleVisibility: .visible) {
            Button("Reject", role: .destructive) { decide(AdminExtractionStatus.rejected) }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("It won't be added to the plant's knowledge.")
        }
    }

    // MARK: Campi

    private var fieldsCard: some View {
        AdminCard(title: "Details", systemImage: "square.and.pencil") {
            if viewModel.isDirty {
                Button("Revert") { viewModel.resetDrafts() }
                    .font(.footnote.weight(.semibold))
                    .disabled(viewModel.isSaving)
            }
        } content: {
            VStack(alignment: .leading, spacing: 14) {
                ForEach(viewModel.fields) { field in
                    AdminExtractionFieldEditor(
                        field: field,
                        text: Binding(get: { viewModel.draft(field) }, set: { viewModel.setDraft($0, for: field) }),
                        isChanged: viewModel.isChanged(field),
                        isInvalid: viewModel.isInvalid(field),
                        isEnabled: viewModel.canEdit && !viewModel.isSaving
                    )
                    .focused($focusedField, equals: field.key)
                }
            }
        }
    }

    // MARK: Decisione

    private var decisionButtons: some View {
        ViewThatFits(in: .horizontal) {
            HStack(spacing: 12) { rejectButton; approveButton }
            VStack(spacing: 10) { approveButton; rejectButton }
        }
        .disabled(!viewModel.canDecide)
        .padding(.top, 4)
    }

    private var approveButton: some View {
        Button {
            decide(AdminExtractionStatus.approved)
        } label: {
            Group {
                if viewModel.isDeciding {
                    ProgressView()
                } else {
                    Label(viewModel.isDirty ? LocalizedStringKey("Save & approve") : LocalizedStringKey("Approve"),
                          systemImage: "checkmark.seal.fill")
                }
            }
            .font(.subheadline.weight(.semibold))
            .frame(maxWidth: .infinity)
        }
        .ariaProminentGlassButtonStyle(tint: .green)
    }

    private var rejectButton: some View {
        Button(role: .destructive) {
            confirmsReject = true
        } label: {
            Label("Reject", systemImage: "xmark.seal")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.red)
                .frame(maxWidth: .infinity)
        }
        .ariaGlassButtonStyle()
    }

    private func decide(_ status: String) {
        focusedField = nil
        Task {
            if await viewModel.decide(status) { dismiss() }
        }
    }
}
