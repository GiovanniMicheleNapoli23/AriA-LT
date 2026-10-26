//
//  AdminWorkOrderAssistantSheet.swift
//  AriaLite
//
//  Created by Giovanni Michele on 22/10/26.
//
//  L'assistente AI di un ordine, in un foglio sopra il dettaglio: l'ordine su cui lavora, le scorciatoie
//  in una griglia che si adatta alla larghezza (due colonne su iPhone, di più su iPad), le risposte della
//  sessione e il prompt libero fisso in basso, come una chat. Su iPhone parte a metà schermo e si apre
//  del tutto quando arriva una risposta; su iPad è un foglio centrato. La logica sta in
//  AdminWorkOrderAssistantViewModel.
//

import SwiftUI

struct AdminWorkOrderAssistantSheet: View {
    @Bindable var viewModel: AdminWorkOrderAssistantViewModel
    @Environment(\.dismiss) private var dismiss
    @Environment(\.horizontalSizeClass) private var sizeClass
    @FocusState private var promptFocused: Bool
    @State private var detent: PresentationDetent = .medium
    /// Il riquadro dell'icona delle scorciatoie cresce col glifo (Dynamic Type).
    @ScaledMetric(relativeTo: .body) private var tileIconSide: CGFloat = 36

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    contextHeader
                    if let failure = viewModel.failure { failureCard(failure) }
                    if let message = viewModel.applyError { warning(message) }
                    if viewModel.entries.isEmpty {
                        shortcutsGrid
                    } else {
                        shortcutsStrip
                        answers
                    }
                }
                .padding(.horizontal, sizeClass == .regular ? 24 : 16)
                .padding(.vertical, 12)
                .ariaReadableWidth()
            }
            .scrollDismissesKeyboard(.interactively)
            .safeAreaInset(edge: .bottom) { composer }
            .liteBackground()
            .navigationTitle("AI assistant")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
        .presentationDetents([.medium, .large], selection: $detent)
        .presentationSizing(.form)
        .presentationDragIndicator(.visible)
        // La risposta ha bisogno di spazio: il foglio si apre del tutto.
        .onChange(of: viewModel.entries.count) { _, count in
            if count > 0 { withAnimation(.snappy) { detent = .large } }
        }
        .onChange(of: promptFocused) { _, focused in
            if focused { withAnimation(.snappy) { detent = .large } }
        }
    }

    // MARK: Ordine

    private var contextHeader: some View {
        HStack(spacing: 12) {
            AriaOrb(mood: viewModel.isRunning ? .thinking : .idle, isAnimating: viewModel.isRunning, radius: 0.9)
                .frame(width: 44, height: 44)
            VStack(alignment: .leading, spacing: 2) {
                Text("Working on")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Text(viewModel.order.title)
                    .font(.headline)
                    .foregroundStyle(Color.liteText)
                    .lineLimit(2)
            }
            Spacer(minLength: 0)
        }
    }

    // MARK: Scorciatoie

    /// Prima della prima risposta: riquadri con icona, titolo e cosa fanno.
    private var shortcutsGrid: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Shortcuts")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.secondary)
            LazyVGrid(columns: [GridItem(.adaptive(minimum: sizeClass == .regular ? 200 : 150), spacing: 10)],
                      spacing: 10) {
                ForEach(viewModel.quickActions) { action in
                    shortcutTile(action)
                }
            }
            Label("Suggested changes are saved only when you tap Apply.", systemImage: "info.circle")
                .font(.footnote)
                .foregroundStyle(.secondary)
                .padding(.top, 4)
        }
    }

    private func shortcutTile(_ action: AdminWorkOrderAIAction) -> some View {
        let running = viewModel.isRunning(action)
        return Button { Task { await viewModel.run(action) } } label: {
            VStack(alignment: .leading, spacing: 10) {
                ZStack {
                    if running {
                        ProgressView().controlSize(.small)
                    } else {
                        Image(systemName: action.systemImage)
                            .font(.body.weight(.semibold))
                            .foregroundStyle(Color.liteAccent)
                    }
                }
                .frame(width: tileIconSide, height: tileIconSide)
                .background(Color.liteAccent.opacity(0.1), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
                VStack(alignment: .leading, spacing: 2) {
                    Text(action.title)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(Color.liteText)
                    Text(action.subtitle)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(2, reservesSpace: true)
                }
                .multilineTextAlignment(.leading)
            }
            .padding(12)
            .frame(maxWidth: .infinity, alignment: .leading)
            .contentShape(RoundedRectangle(cornerRadius: 16))
        }
        .buttonStyle(.plain)
        .ariaGlass(in: RoundedRectangle(cornerRadius: 16), interactive: true)
        .disabled(viewModel.isRunning)
        .opacity(viewModel.isRunning && !running ? 0.5 : 1)
    }

    /// Dopo la prima risposta le scorciatoie si fanno piccole: lo spazio va alle risposte.
    private var shortcutsStrip: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(viewModel.quickActions) { action in
                    chip(action.title, systemImage: action.systemImage, isRunning: viewModel.isRunning(action)) {
                        Task { await viewModel.run(action) }
                    }
                }
            }
            .padding(.vertical, 2)
        }
        .scrollClipDisabled()
    }

    private func chip(_ title: String, systemImage: String, isRunning: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 6) {
                if isRunning {
                    ProgressView().controlSize(.mini)
                } else {
                    Image(systemName: systemImage)
                }
                Text(title)
            }
            .font(.subheadline.weight(.semibold))
            .padding(.horizontal, 14)
            .frame(minHeight: 36)
            .foregroundStyle(Color.liteText)
            .background(Color.liteAccent.opacity(0.08), in: Capsule())
            .overlay(Capsule().stroke(Color.liteBorder, lineWidth: 0.5))
        }
        .buttonStyle(.plain)
        .disabled(viewModel.isRunning)
        .opacity(viewModel.isRunning && !isRunning ? 0.5 : 1)
    }

    // MARK: Prompt libero

    private var composer: some View {
        HStack(alignment: .bottom, spacing: 8) {
            TextField("Ask anything about this work order…", text: $viewModel.customPrompt, axis: .vertical)
                .lineLimit(1...5)
                .font(.body)
                .focused($promptFocused)
                .submitLabel(.send)
                .onSubmit { send() }
                .padding(.vertical, 6)
            if viewModel.isSendingPrompt {
                ProgressView().frame(width: 34, height: 34)
            } else {
                Button("Send", systemImage: "arrow.up.circle.fill", action: send)
                    .labelStyle(.iconOnly)
                    .font(.title)
                    .foregroundStyle(viewModel.canSendPrompt ? Color.liteAccent : Color.secondary.opacity(0.4))
                    .disabled(!viewModel.canSendPrompt)
            }
        }
        .padding(.leading, 16)
        .padding(.trailing, 6)
        .padding(.vertical, 6)
        .ariaGlass(in: RoundedRectangle(cornerRadius: 24, style: .continuous))
        .padding(.horizontal, sizeClass == .regular ? 24 : 12)
        .padding(.bottom, 8)
        .ariaReadableWidth()
    }

    private func send() {
        promptFocused = false
        Task { await viewModel.sendPrompt() }
    }

    // MARK: Risposte

    private var answers: some View {
        ForEach(viewModel.entries) { entry in
            AdminWorkOrderAssistantCard(
                entry: entry,
                rows: viewModel.fieldRows(for: entry),
                canApplyFields: viewModel.canApplyFields(entry),
                canUseTextAsDescription: viewModel.canUseTextAsDescription(entry),
                canAppendToNotes: viewModel.canAppendToNotes(entry),
                isApplying: viewModel.applyingEntryId == entry.id,
                isBusy: viewModel.isApplying,
                onApply: { kind in Task { await viewModel.apply(kind, from: entry) } },
                onCopy: { AriaPasteboard.copy(viewModel.copyText(for: entry)) }
            )
        }
    }

    // MARK: Errori

    private func failureCard(_ failure: AdminWorkOrderAssistantFailure) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .top) {
                Label(failure.message, systemImage: "exclamationmark.triangle.fill")
                    .font(.subheadline)
                    .foregroundStyle(.orange)
                    .textSelection(.enabled)
                Spacer(minLength: 4)
                Button("Dismiss", systemImage: "xmark") { viewModel.dismissFailure() }
                    .labelStyle(.iconOnly)
                    .font(.caption.weight(.bold))
                    .foregroundStyle(.secondary)
            }
            if !failure.validActions.isEmpty {
                Text("Actions the server accepts:")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 6) {
                        ForEach(failure.validActions, id: \.self) { action in
                            chip(action, systemImage: "arrow.right.circle", isRunning: viewModel.runningAction == action) {
                                Task { await viewModel.runServerAction(action) }
                            }
                        }
                    }
                }
                .scrollClipDisabled()
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.orange.opacity(0.1), in: RoundedRectangle(cornerRadius: 16))
    }

    private func warning(_ message: String) -> some View {
        Label(message, systemImage: "exclamationmark.triangle.fill")
            .font(.subheadline)
            .foregroundStyle(.orange)
            .padding(14)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color.orange.opacity(0.1), in: RoundedRectangle(cornerRadius: 16))
    }
}
