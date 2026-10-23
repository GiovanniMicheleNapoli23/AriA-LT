//
//  AdminAgentStudioApprovalDetailView.swift
//  AriaLite
//
//  Created by Giovanni Michele on 22/10/26.
//
//  Il dettaglio di un'approvazione, come /agent-studio/approvals/{id} della web: cosa chiede il passo,
//  gli argomenti dell'azione, la scheda e la decisione (approva o rifiuta con una nota, con conferma).
//

import SwiftUI

struct AdminAgentStudioApprovalDetailView: View {
    @State private var viewModel: AdminAgentStudioApprovalViewModel
    @FocusState private var commentFocused: Bool

    init(viewModel: AdminAgentStudioApprovalViewModel) {
        _viewModel = State(initialValue: viewModel)
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                if viewModel.approval == nil {
                    loadingOrError
                } else {
                    header
                    if viewModel.canDecide { decisionCard }
                    if !viewModel.argumentRows.isEmpty { argumentsCard }
                    detailsCard
                    runLink
                }
            }
            .padding(20)
            .ariaReadableWidth()
        }
        .scrollDismissesKeyboard(.interactively)
        .liteBackground()
        .navigationTitle(viewModel.title)
        .navigationBarTitleDisplayMode(.inline)
        .refreshable { await viewModel.load() }
        .task { await viewModel.load() }
        .alert(confirmationTitle, isPresented: $viewModel.showsDecisionConfirmation,
               presenting: viewModel.decisionToConfirm) { decision in
            if decision == .approve {
                Button("Approve") { confirm(decision) }
            } else {
                Button("Reject", role: .destructive) { confirm(decision) }
            }
            Button("Cancel", role: .cancel) {}
        } message: { _ in
            Text("Once decided, the run resumes on the server.")
        }
        .alert("Couldn't save the decision", isPresented: $viewModel.showsActionError) {
            Button("OK") {}
        } message: {
            Text(viewModel.actionError ?? "")
        }
    }

    private func confirm(_ decision: AdminAgentStudioDecision) {
        commentFocused = false
        Task { await viewModel.decide(decision) }
    }

    private var confirmationTitle: Text {
        viewModel.decisionToConfirm == .reject ? Text("Reject this step?") : Text("Approve this step?")
    }

    @ViewBuilder
    private var loadingOrError: some View {
        if let message = viewModel.loadError {
            VStack(spacing: 14) {
                ContentUnavailableView("Can't load this approval", systemImage: "exclamationmark.triangle",
                                       description: Text(message))
                Button {
                    Task { await viewModel.load() }
                } label: {
                    Label("Retry", systemImage: "arrow.clockwise")
                }
                .ariaGlassButtonStyle()
            }
            .padding(.top, 40)
        } else {
            ProgressView()
                .frame(maxWidth: .infinity)
                .padding(.top, 60)
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .firstTextBaseline, spacing: 10) {
                Text(viewModel.title)
                    .font(.title3.weight(.bold))
                    .textSelection(.enabled)
                Spacer(minLength: 8)
                if let status = viewModel.approval?.status { AdminAgentStudioBadge(status: status) }
            }
            if let instructions = viewModel.approval?.instructions {
                Text(instructions)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .textSelection(.enabled)
                    .fixedSize(horizontal: false, vertical: true)
            }
            if let message = viewModel.loadError {
                AdminSectionNotice(text: message, isError: true)
            }
            if viewModel.isExpired, viewModel.approval?.isPending == true {
                AdminSectionNotice(text: String(localized: "This approval has expired."), systemImage: "clock")
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .ariaGlass(in: RoundedRectangle(cornerRadius: 16))
    }

    private var decisionCard: some View {
        AdminCard(title: "Decision", systemImage: "hand.thumbsup") {
            VStack(alignment: .leading, spacing: 12) {
                TextField("Note (optional)", text: $viewModel.comment, axis: .vertical)
                    .lineLimit(2...5)
                    .focused($commentFocused)
                    .padding(10)
                    .background(Color.secondary.opacity(0.08), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
                ViewThatFits(in: .horizontal) {
                    HStack(spacing: 10) { decisionButtons }
                    VStack(spacing: 10) { decisionButtons }
                }
            }
        }
    }

    @ViewBuilder
    private var decisionButtons: some View {
        Button(role: .destructive) {
            viewModel.decisionToConfirm = .reject
        } label: {
            decisionLabel("Reject", systemImage: "xmark", isBusy: viewModel.deciding == .reject)
        }
        .buttonStyle(.bordered)
        Button {
            viewModel.decisionToConfirm = .approve
        } label: {
            decisionLabel("Approve", systemImage: "checkmark", isBusy: viewModel.deciding == .approve)
        }
        .buttonStyle(.borderedProminent)
        .tint(Color.liteAccent)
        .foregroundStyle(Color.liteOnAccent)
    }

    private func decisionLabel(_ title: LocalizedStringKey, systemImage: String, isBusy: Bool) -> some View {
        HStack(spacing: 6) {
            if isBusy { ProgressView().controlSize(.small) } else { Image(systemName: systemImage) }
            Text(title)
        }
        .font(.subheadline.weight(.semibold))
        .frame(maxWidth: .infinity)
    }

    private var argumentsCard: some View {
        AdminCard(title: "Proposed action", systemImage: "curlybraces") {
            let rows = viewModel.argumentRows
            VStack(spacing: 0) {
                ForEach(rows) { row in
                    AdminFieldRow(field: row, showsDivider: row != rows.last)
                }
            }
        }
    }

    private var detailsCard: some View {
        AdminCard(title: "Details", systemImage: "info.circle") {
            let fields = viewModel.fields
            VStack(spacing: 0) {
                ForEach(fields) { field in
                    AdminFieldRow(field: field, showsDivider: field != fields.last)
                }
            }
        }
    }

    @ViewBuilder
    private var runLink: some View {
        if let runId = viewModel.approval?.runId {
            NavigationLink(value: AdminAgentStudioRoute.run(workflowId: viewModel.approval?.workflowId, runId: runId)) {
                AdminAgentStudioListRow(systemImage: "play.circle", title: String(localized: "Open the run"),
                                        subtitle: viewModel.approval?.workflowName)
            }
            .buttonStyle(.plain)
        }
    }
}
