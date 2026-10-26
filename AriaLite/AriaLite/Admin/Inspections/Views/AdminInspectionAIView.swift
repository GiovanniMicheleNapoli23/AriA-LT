//
//  AdminInspectionAIView.swift
//  AriaLite
//
//  Created by Giovanni Michele on 22/10/26.
//
//  "Improve with AI": scegli cosa chiedere, guarda la proposta (testo per le note e controlli nuovi) e
//  applicala o scartala. Una sola scroll view di schede; niente si scrive finché non premi "Apply".
//

import SwiftUI

struct AdminInspectionAIView: View {
    @State private var viewModel: AdminInspectionAIViewModel
    @Environment(\.dismiss) private var dismiss

    init(viewModel: AdminInspectionAIViewModel) {
        _viewModel = State(initialValue: viewModel)
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    if let answer = viewModel.proposal {
                        proposal(answer)
                    } else {
                        request
                    }
                    if let message = viewModel.errorMessage {
                        AdminSectionNotice(text: message, isError: true)
                    }
                }
                .padding(20)
                .ariaReadableWidth()
            }
            .scrollDismissesKeyboard(.interactively)
            .liteBackground()
            .navigationTitle("Improve with AI")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") { dismiss() }
                        .disabled(viewModel.isApplying)
                }
            }
            .interactiveDismissDisabled(viewModel.isApplying || viewModel.isRunning)
            .onChange(of: viewModel.didFinish) { _, finished in
                if finished { dismiss() }
            }
        }
        .presentationDragIndicator(.visible)
    }

    // MARK: Richiesta

    private var request: some View {
        VStack(alignment: .leading, spacing: 16) {
            AdminCard(ariaTitle: "What should Aria do?") {
                VStack(spacing: 8) {
                    ForEach(AdminInspectionAIAction.allCases) { action in
                        actionRow(action)
                    }
                }
                if viewModel.action == .custom {
                    TextField("e.g. Add checks for lockout and tagout", text: $viewModel.customPrompt, axis: .vertical)
                        .lineLimit(2...6)
                        .font(.subheadline)
                        .padding(10)
                        .background(Color.primary.opacity(0.06), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
                }
            }
            .disabled(viewModel.isRunning)
            Button {
                Task { await viewModel.run() }
            } label: {
                if viewModel.isRunning {
                    HStack(spacing: 8) {
                        ProgressView()
                        Text("Asking Aria…")
                    }
                    .frame(maxWidth: .infinity)
                } else {
                    Label("Generate proposal", systemImage: "wand.and.stars").frame(maxWidth: .infinity)
                }
            }
            .ariaProminentGlassButtonStyle(tint: .liteAccent, foreground: .liteOnAccent)
            .disabled(!viewModel.canRun)
        }
    }

    private func actionRow(_ action: AdminInspectionAIAction) -> some View {
        Button {
            withAnimation(.snappy) { viewModel.action = action }
        } label: {
            HStack(spacing: 12) {
                Image(systemName: action.systemImage)
                    .foregroundStyle(Color.liteAccent)
                    .frame(minWidth: 24)
                VStack(alignment: .leading, spacing: 2) {
                    Text(action.title).font(.subheadline.weight(.semibold)).foregroundStyle(.primary)
                    Text(action.subtitle).font(.caption).foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                Image(systemName: viewModel.action == action ? "largecircle.fill.circle" : "circle")
                    .foregroundStyle(viewModel.action == action ? Color.liteAccent : Color.secondary)
            }
            .padding(10)
            .background(viewModel.action == action ? Color.liteAccent.opacity(0.1) : .clear,
                        in: RoundedRectangle(cornerRadius: 12, style: .continuous))
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(viewModel.action == action ? .isSelected : [])
    }

    // MARK: Proposta

    @ViewBuilder
    private func proposal(_ answer: AdminInspectionAIAnswer) -> some View {
        if answer.isEmpty {
            AdminCard(ariaTitle: "Proposal") {
                AdminSectionNotice(text: String(localized: "Aria had nothing to suggest for this inspection."))
            }
        }
        if let notes = viewModel.proposedNotes { notesCard(notes) }
        if !viewModel.candidates.isEmpty { itemsCard }
        if answer.items.isEmpty == false, viewModel.candidates.isEmpty {
            AdminCard(title: "Checks", systemImage: "checklist") {
                AdminSectionNotice(text: String(localized: "Every suggested check is already in the checklist."),
                                   systemImage: "checkmark.circle")
            }
        }
        if let raw = answer.raw {
            AdminCard(title: "Aria's answer", systemImage: "curlybraces") {
                Text(raw).font(.footnote.monospaced()).textSelection(.enabled)
            }
        }
        VStack(spacing: 10) {
            Button {
                Task { await viewModel.applyProposal() }
            } label: {
                if viewModel.isApplying {
                    ProgressView().frame(maxWidth: .infinity)
                } else {
                    Label("Apply", systemImage: "checkmark").frame(maxWidth: .infinity)
                }
            }
            .ariaProminentGlassButtonStyle(tint: .liteAccent, foreground: .liteOnAccent)
            .disabled(!viewModel.canApply)
            Button {
                withAnimation(.snappy) { viewModel.discard() }
            } label: {
                Label("Discard", systemImage: "trash").frame(maxWidth: .infinity)
            }
            .ariaGlassButtonStyle()
            .disabled(viewModel.isApplying)
        }
    }

    private func notesCard(_ notes: String) -> some View {
        AdminCard(title: "Suggested notes", systemImage: "text.alignleft") {
            Text(notes)
                .font(.subheadline)
                .textSelection(.enabled)
                .fixedSize(horizontal: false, vertical: true)
            Toggle("Replace the notes with this text", isOn: $viewModel.appliesNotes)
                .font(.subheadline)
                .tint(Color.liteAccent)
        }
    }

    private var itemsCard: some View {
        AdminCard(title: "New checks", systemImage: "checklist") {
            Button {
                viewModel.selectAll(viewModel.selectedItems.count != viewModel.candidates.count)
            } label: {
                if viewModel.selectedItems.count == viewModel.candidates.count {
                    Text("Deselect all")
                } else {
                    Text("Select all")
                }
            }
            .font(.footnote.weight(.semibold))
            .tint(Color.liteAccent)
            ForEach(Array(viewModel.candidates.enumerated()), id: \.offset) { index, text in
                Button {
                    viewModel.toggle(index)
                } label: {
                    HStack(alignment: .firstTextBaseline, spacing: 10) {
                        Image(systemName: viewModel.selectedItems.contains(index) ? "checkmark.square.fill" : "square")
                            .foregroundStyle(viewModel.selectedItems.contains(index) ? Color.liteAccent : Color.secondary)
                        Text(text)
                            .font(.subheadline)
                            .foregroundStyle(.primary)
                            .multilineTextAlignment(.leading)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityAddTraits(viewModel.selectedItems.contains(index) ? .isSelected : [])
            }
        }
    }
}
