//
//  AdminWorkOrderCreateView.swift
//  AriaLite
//
//  Created by Giovanni Michele on 22/10/26.
//
//  La creazione di un ordine a passi, in uno sheet: una pagina per passo (TabView a pagine, si scorre anche
//  col dito), la barra dei passi in cima e Back / Next in fondo; l'ultima pagina è il riepilogo con
//  "Create Work Order". Passi, controlli e salvataggio stanno in AdminWorkOrderFormViewModel; qui solo le
//  pagine, il fuoco e la chiusura.
//

import SwiftUI

struct AdminWorkOrderCreateView: View {
    @Bindable var viewModel: AdminWorkOrderFormViewModel
    @Environment(\.dismiss) private var dismiss
    @Environment(\.verticalSizeClass) private var verticalSizeClass
    @FocusState private var focused: AdminWorkOrderCreateField?

    /// In orizzontale con la tastiera aperta lo spazio è poco: restano la barra dei passi e il campo.
    private var isCramped: Bool { verticalSizeClass == .compact && focused != nil }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                AdminWorkOrderFormStepHeader(steps: viewModel.steps, current: viewModel.step,
                                             isCompact: isCramped) { step in
                    withAnimation { viewModel.go(to: step) }
                }
                TabView(selection: $viewModel.step) {
                    ForEach(viewModel.steps) { step in
                        AdminWorkOrderCreateStepPage(step: step, viewModel: viewModel, focused: $focused)
                            .tag(step)
                    }
                }
                .tabViewStyle(.page(indexDisplayMode: .never))
                if !isCramped { bottomBar }
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle(viewModel.title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
            .onChange(of: viewModel.step) { focused = nil }
            .task { await viewModel.loadChoices() }
        }
        .interactiveDismissDisabled(viewModel.hasChanges || viewModel.isSaving)
    }

    // MARK: Barra in fondo

    private var bottomBar: some View {
        VStack(spacing: 8) {
            if let issue = viewModel.currentIssue {
                Label(issue, systemImage: "exclamationmark.circle")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .transition(.opacity)
            }
            HStack(spacing: 12) {
                if !viewModel.isFirstStep {
                    Button { withAnimation { viewModel.goBack() } } label: {
                        Label("Back", systemImage: "chevron.left")
                            .font(.body.weight(.semibold))
                            .frame(maxWidth: .infinity, minHeight: 46)
                    }
                    .ariaGlassButtonStyle()
                    .foregroundStyle(Color.liteText)
                }
                if viewModel.isLastStep { createButton } else { nextButton }
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
        .animation(.snappy, value: viewModel.currentIssue)
    }

    private var nextButton: some View {
        Button { withAnimation { viewModel.advance() } } label: {
            HStack(spacing: 6) {
                Text("Next")
                Image(systemName: "chevron.right")
            }
            .font(.body.weight(.semibold))
            .frame(maxWidth: .infinity, minHeight: 46)
        }
        .ariaAccentGlassButtonStyle()
        .disabled(!viewModel.canAdvance)
    }

    private var createButton: some View {
        Button {
            focused = nil
            Task { if await viewModel.save() { dismiss() } }
        } label: {
            Group {
                if viewModel.isSaving {
                    ProgressView().tint(Color.liteOnAccent)
                } else {
                    Label("Create Work Order", systemImage: "checkmark")
                }
            }
            .font(.body.weight(.semibold))
            .frame(maxWidth: .infinity, minHeight: 46)
        }
        .ariaAccentGlassButtonStyle()
        .disabled(!viewModel.canSave)
    }
}
