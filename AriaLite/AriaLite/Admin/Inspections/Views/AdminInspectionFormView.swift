//
//  AdminInspectionFormView.swift
//  AriaLite
//
//  Created by Giovanni Michele on 22/10/26.
//
//  Il foglio per creare o modificare un'ispezione, una sola scroll view di schede: dati generali,
//  dove (stabilimento, asset, area), scadenza e checklist con pulsanti per aggiungere, togliere e riordinare.
//  "Save" sta sempre in alto: va bene anche col telefono in orizzontale e la tastiera aperta.
//

import SwiftUI

struct AdminInspectionFormView: View {
    /// In `@State`: il foglio si ricostruisce col genitore, il form a metà non deve ripartire da capo.
    @State private var viewModel: AdminInspectionFormViewModel
    let onSaved: (AdminInspection) -> Void

    @Environment(\.dismiss) private var dismiss
    @FocusState private var focus: String?

    init(viewModel: AdminInspectionFormViewModel, onSaved: @escaping (AdminInspection) -> Void) {
        _viewModel = State(initialValue: viewModel)
        self.onSaved = onSaved
    }

    var body: some View {
        NavigationStack {
            ScrollViewReader { proxy in
                ScrollView {
                    VStack(alignment: .leading, spacing: 16) {
                        general
                        place
                        schedule
                        checklist
                        if let message = viewModel.validationMessage {
                            AdminSectionNotice(text: message, systemImage: "info.circle")
                        }
                        if let message = viewModel.errorMessage {
                            AdminSectionNotice(text: message, isError: true)
                        }
                    }
                    .padding(20)
                    .ariaReadableWidth()
                }
                .onChange(of: viewModel.lastAddedItemId) { _, id in
                    guard let id else { return }
                    focus = id
                    withAnimation(.snappy) { proxy.scrollTo(id, anchor: .center) }
                }
            }
            .scrollDismissesKeyboard(.interactively)
            .liteBackground()
            .navigationTitle(viewModel.screenTitle)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                        .disabled(viewModel.isSaving)
                }
                ToolbarItem(placement: .confirmationAction) {
                    if viewModel.isSaving {
                        ProgressView()
                    } else {
                        Button("Save", action: save).disabled(!viewModel.canSave)
                    }
                }
            }
            .interactiveDismissDisabled(viewModel.isSaving)
            .task { await viewModel.loadAssets() }
        }
        .presentationDragIndicator(.visible)
    }

    private func save() {
        focus = nil
        Task {
            if let saved = await viewModel.save() {
                onSaved(saved)
                dismiss()
            }
        }
    }

    // MARK: Schede

    private var general: some View {
        AdminCard(title: "Details", systemImage: "square.and.pencil") {
            VStack(alignment: .leading, spacing: 12) {
                field("Title") {
                    TextField("e.g. Weekly pump room round", text: $viewModel.title, axis: .vertical)
                        .lineLimit(1...3)
                }
                field("Notes") {
                    TextField("Instructions or context", text: $viewModel.notes, axis: .vertical)
                        .lineLimit(2...6)
                }
                field("Assigned to") {
                    TextField("Name or team", text: $viewModel.assignedTo)
                }
            }
            .disabled(viewModel.isSaving)
        }
    }

    private var place: some View {
        AdminCard(title: "Where", systemImage: "mappin.and.ellipse") {
            VStack(alignment: .leading, spacing: 12) {
                if !viewModel.plants.isEmpty {
                    Picker("Plant", selection: $viewModel.plantId) {
                        if viewModel.plantId == nil { Text("Select").tag(String?.none) }
                        ForEach(viewModel.plants) { Text($0.name).tag(Optional($0.id)) }
                    }
                    .pickerStyle(.menu)
                    .tint(Color.liteAccent)
                }
                field("Asset tag") {
                    TextField("e.g. M-101", text: $viewModel.assetTag)
                        .textInputAutocapitalization(.characters)
                        .autocorrectionDisabled()
                        .font(.subheadline.monospaced())
                }
                if !viewModel.assetChoices.isEmpty { assetMenu }
                field("Area") {
                    TextField("e.g. Pump room", text: $viewModel.zone)
                }
            }
            .disabled(viewModel.isSaving)
        }
    }

    private var assetMenu: some View {
        Menu {
            ForEach(viewModel.assetChoices) { asset in
                Button("\(asset.tag) · \(asset.name)") { viewModel.choose(asset) }
            }
        } label: {
            Label("Choose from assets", systemImage: "gearshape.2")
                .font(.subheadline.weight(.medium))
        }
        .tint(Color.liteAccent)
    }

    private var schedule: some View {
        AdminCard(title: "Due date", systemImage: "calendar") {
            VStack(alignment: .leading, spacing: 8) {
                Toggle("Set a due date", isOn: $viewModel.hasDueDate.animation(.snappy))
                    .tint(Color.liteAccent)
                if viewModel.hasDueDate {
                    DatePicker("Due", selection: $viewModel.dueDate, displayedComponents: [.date])
                        .datePickerStyle(.compact)
                        .tint(Color.liteAccent)
                }
            }
            .disabled(viewModel.isSaving)
        }
    }

    private var checklist: some View {
        AdminCard(title: "Checklist", systemImage: "checklist") {
            VStack(alignment: .leading, spacing: 14) {
                if viewModel.items.isEmpty {
                    AdminSectionNotice(text: String(localized: "No checks yet. Add the first one."), systemImage: "checklist")
                }
                ForEach($viewModel.items) { $item in
                    AdminInspectionFormItemRow(
                        number: (viewModel.items.firstIndex { $0.id == item.id } ?? 0) + 1, item: $item,
                        canMoveUp: viewModel.canMoveUp(item.id), canMoveDown: viewModel.canMoveDown(item.id),
                        isDisabled: viewModel.isSaving, focus: $focus,
                        onMoveUp: { withAnimation(.snappy) { viewModel.moveUp(item.id) } },
                        onMoveDown: { withAnimation(.snappy) { viewModel.moveDown(item.id) } },
                        onRemove: { withAnimation(.snappy) { viewModel.remove(item.id) } }
                    )
                    .id(item.id)
                    Divider()
                }
                Button {
                    withAnimation(.snappy) { viewModel.addItem() }
                } label: {
                    Label("Add check", systemImage: "plus.circle.fill")
                }
                .buttonStyle(.bordered)
                .tint(Color.liteAccent)
                .disabled(viewModel.isSaving)
            }
        }
    }

    /// Un campo con l'etichetta sopra e il testo in un riquadro.
    private func field<Content: View>(_ title: LocalizedStringKey, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title).font(.caption.weight(.semibold)).foregroundStyle(.secondary)
            content()
                .font(.subheadline)
                .padding(10)
                .background(Color.primary.opacity(0.06), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
        }
    }
}
