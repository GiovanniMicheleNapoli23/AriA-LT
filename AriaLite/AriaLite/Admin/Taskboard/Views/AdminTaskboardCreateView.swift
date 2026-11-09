//
//  AdminTaskboardCreateView.swift
//  AriaLite
//
//  Created by Giovanni Michele on 22/10/26.
//
//  Il foglio di creazione rapida, una sola scroll view di schede: il task (titolo, colonna, priorità e
//  "Draft with AI") e, sotto, i modelli di ordine da cui crearne uno in un tocco nella colonna scelta.
//

import SwiftUI

struct AdminTaskboardCreateView: View {
    /// In `@State`: il foglio si ricostruisce col genitore, quello che si è scritto non deve sparire.
    @State private var viewModel: AdminTaskboardCreateViewModel
    @FocusState private var focused: Field?
    @ScaledMetric(relativeTo: .body) private var orbSide: CGFloat = 20
    @Environment(\.dismiss) private var dismiss

    private enum Field { case title, details }

    init(viewModel: AdminTaskboardCreateViewModel) {
        _viewModel = State(initialValue: viewModel)
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    taskCard
                    templatesCard
                    if let message = viewModel.errorMessage {
                        AdminSectionNotice(text: message, isError: true)
                    }
                }
                .padding(20)
                .ariaReadableWidth()
            }
            .scrollDismissesKeyboard(.interactively)
            .liteBackground()
            .navigationTitle("New task")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }.disabled(viewModel.isSaving)
                }
                ToolbarItem(placement: .confirmationAction) {
                    if viewModel.isSaving {
                        ProgressView()
                    } else {
                        Button("Create") { Task { await viewModel.create() } }.disabled(!viewModel.canCreate)
                    }
                }
            }
            .interactiveDismissDisabled(viewModel.isBusy)
            .task { await viewModel.loadTemplates() }
            .onChange(of: viewModel.didFinish) { _, finished in if finished { dismiss() } }
        }
    }

    // MARK: Task

    private var taskCard: some View {
        AdminCard(title: "Task", systemImage: "checklist") {
            VStack(alignment: .leading, spacing: 12) {
                TextField("Title", text: $viewModel.title, axis: .vertical)
                    .font(.body)
                    .lineLimit(1...3)
                    .focused($focused, equals: .title)
                    .submitLabel(.next)
                    .onSubmit { focused = .details }
                TextField("Description (optional)", text: $viewModel.details, axis: .vertical)
                    .font(.subheadline)
                    .lineLimit(2...8)
                    .focused($focused, equals: .details)
                Divider()
                LabeledContent("Column") {
                    Picker("Column", selection: $viewModel.status) {
                        ForEach(columns, id: \.self) { Text($0.localized).tag($0) }
                    }
                    .labelsHidden()
                }
                LabeledContent("Priority") {
                    Picker("Priority", selection: $viewModel.priority) {
                        ForEach(AdminWorkOrderPriority.known, id: \.self) { Text($0.localized).tag($0) }
                    }
                    .labelsHidden()
                }
                aiButton
                if let note = viewModel.aiNote {
                    Text(note).font(.footnote).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
                }
            }
            .disabled(viewModel.isSaving)
        }
    }

    /// La colonna scelta resta nell'elenco anche se non è fra quelle di partenza.
    private var columns: [AdminWorkOrderStatus] {
        let base = AdminTaskboardCreateViewModel.startColumns
        return base.contains(viewModel.status) ? base : base + [viewModel.status]
    }

    private var aiButton: some View {
        Button {
            focused = nil
            Task { await viewModel.draftWithAI() }
        } label: {
            if viewModel.isDrafting {
                HStack(spacing: 8) { ProgressView(); Text("Drafting…") }
            } else {
                Label {
                    Text("Draft with AI")
                } icon: {
                    AriaOrb(isAnimating: false).frame(width: orbSide, height: orbSide)
                        // La sfera è uno shader: il pulsante disabilitato non la spegne da solo.
                        .opacity(viewModel.canDraft ? 1 : 0.4)
                }
            }
        }
        .buttonStyle(.bordered)
        .tint(Color.liteAccent)
        .disabled(!viewModel.canDraft)
    }

    // MARK: Modelli

    private var templatesCard: some View {
        AdminCard(title: "From a template", systemImage: "doc.on.doc") {
            VStack(alignment: .leading, spacing: 4) {
                if viewModel.isLoadingTemplates {
                    ProgressView().frame(maxWidth: .infinity)
                } else if let message = viewModel.templatesMessage {
                    AdminSectionNotice(text: message, isError: true)
                } else if viewModel.templates.isEmpty {
                    AdminSectionNotice(text: String(localized: "No templates yet."))
                } else {
                    Text("Creates a task in the chosen column with the template's fields.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                        .padding(.bottom, 6)
                    ForEach(viewModel.templates) { template in
                        Button {
                            Task { await viewModel.create(from: template) }
                        } label: {
                            AdminWorkOrderTemplateRow(
                                title: template.title,
                                subtitle: AdminWorkOrderFormat.joined([template.type.localized, template.assetTag, template.category]),
                                priority: template.priority,
                                steps: String(localized: "\(template.steps.count) steps"),
                                parts: template.parts.isEmpty ? nil : String(localized: "\(template.parts.count) parts"),
                                isBusy: viewModel.applyingTemplateId == template.id)
                        }
                        .buttonStyle(.plain)
                        .disabled(viewModel.isBusy)
                        if template.id != viewModel.templates.last?.id { Divider() }
                    }
                }
            }
        }
    }
}
