//
//  AdminExtractionDetailView.swift
//  AriaLite
//
//  Created by Giovanni Michele on 22/10/26.
//
//  Il dettaglio di un elemento estratto: intestazione, i campi da correggere come un modulo delle
//  Impostazioni ("Save" in alto), l'AI che propone modifiche e, nella barra in basso, "Approve" / "Reject".
//  Dopo la decisione torna alla lista.
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
                fieldsCard
                AdminExtractionAICard(viewModel: viewModel)
            }
            .padding(20)
            .ariaReadableWidth()
        }
        .scrollDismissesKeyboard(.interactively)
        .ariaBottomBar { decisionBar }
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
        .alert("Reject this item?", isPresented: $confirmsReject) {
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
            VStack(alignment: .leading, spacing: 0) {
                ForEach(viewModel.fields) { field in
                    if field != viewModel.fields.first { Divider() }
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

    /// Fissa in basso: la decisione resta a portata mentre si scorrono i campi.
    private var decisionBar: some View {
        ViewThatFits(in: .horizontal) {
            HStack(spacing: 10) { rejectButton; approveButton }
            VStack(spacing: 8) { approveButton; rejectButton }
        }
        .disabled(!viewModel.canDecide)
        .padding(10)
        .ariaGlass(in: RoundedRectangle(cornerRadius: 24, style: .continuous))
        .padding(.horizontal, 20)
        .padding(.bottom, 8)
        .ariaReadableWidth()
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
                          systemImage: "checkmark")
                }
            }
            .font(.subheadline.weight(.semibold))
            .frame(maxWidth: .infinity)
        }
        .ariaAccentGlassButtonStyle()
    }

    private var rejectButton: some View {
        Button(role: .destructive) {
            confirmsReject = true
        } label: {
            Label("Reject", systemImage: "xmark")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(Color.liteDanger)
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
