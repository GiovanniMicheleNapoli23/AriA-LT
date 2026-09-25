//
//  AriaLearningViews.swift
//  AriaLite
//
//  Il Real-time Learning della web, sul telefono: quando Aria non è sicura di una risposta l'avviso esce
//  dalla Dynamic Island (AriaIsland) e la domanda prende il posto del composer (AriaElicitationPanel,
//  variante `.learning`). Qui ci sono l'identità visiva, la card che la sostituisce quando si è risposto
//  (learning-learned-card della web) e il chip per riaprirla da una risposta precedente (ValidationChip).
//

import SwiftUI

enum AriaLearningStyle {
    static let tint = Color.purple
    static let symbol = "graduationcap.fill"
}

struct AriaLearningIcon: View {
    var size: CGFloat = 20

    var body: some View {
        Image(systemName: AriaLearningStyle.symbol)
            .font(.system(size: size * 0.5, weight: .semibold))
            .foregroundStyle(.white)
            .frame(width: size, height: size)
            .background(AriaLearningStyle.tint.gradient, in: Circle())
            .accessibilityHidden(true)
    }
}

/// "Real-time Learning" nell'intestazione del pannello.
struct AriaLearningBadge: View {
    var body: some View {
        HStack(spacing: 8) {
            AriaLearningIcon()
            Text("Real-time Learning")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(AriaLearningStyle.tint)
        }
    }
}

// MARK: - Esito

/// Prende il posto della domanda appena risposta: prima "Aria sta imparando…", poi cosa ha imparato,
/// con il contesto da rivedere e, per i fatti ancora in proposta, la richiesta di validazione agli admin.
struct AriaLearningOutcomePanel: View {
    let outcome: AriaLearningOutcome
    let chat: AriaAgentChat

    @State private var showContext = false
    @State private var notified: Set<String> = []
    @State private var notifying = false

    private var pending: [String] {
        outcome.items.filter(\.isProposed).compactMap(\.factId).filter { !notified.contains($0) }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .top, spacing: 10) {
                AriaLearningIcon(size: 30)
                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.system(size: 16, weight: .semibold))
                    Text(subtitle)
                        .font(.system(size: 13))
                        .foregroundStyle(.secondary)
                }
                .fixedSize(horizontal: false, vertical: true)
                Spacer(minLength: 8)
                if outcome.isSaving {
                    ProgressView()
                        .padding(.top, 4)
                } else {
                    Button { chat.dismissLearningOutcome() } label: {
                        Image(systemName: "xmark")
                            .font(.system(size: 12, weight: .bold))
                            .foregroundStyle(.secondary)
                            .frame(width: 30, height: 30)
                            .background(Color(.tertiarySystemFill), in: Circle())
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Close")
                }
            }

            if !outcome.items.isEmpty {
                ScrollView {
                    VStack(spacing: 8) {
                        ForEach(Array(outcome.items.enumerated()), id: \.offset) { _, item in
                            itemRow(item)
                        }
                    }
                }
                .frame(maxHeight: 240)
                .fixedSize(horizontal: false, vertical: true)
                .scrollBounceBehavior(.basedOnSize)
            }

            if showContext { context }

            if !outcome.isSaving { actions }
        }
        .padding(.horizontal, 16)
        .padding(.top, 16)
        .padding(.bottom, 8)
        .frame(maxWidth: .infinity, alignment: .leading)
        .ariaBottomPanel(stroke: AriaLearningStyle.tint.opacity(0.35))
        .animation(.snappy(duration: 0.3), value: outcome)
        .animation(.snappy(duration: 0.25), value: showContext)
        .sensoryFeedback(.success, trigger: outcome.isSaving) { was, now in was && !now }
    }

    private var title: LocalizedStringKey {
        if outcome.isSaving { return "Aria is learning…" }
        return outcome.learnedSomething || outcome.items.isEmpty ? "Aria learned something new" : "Saved for review"
    }

    private var subtitle: LocalizedStringKey {
        if outcome.isSaving { return "Saving your answer to the plant's knowledge." }
        return outcome.learnedSomething || outcome.items.isEmpty
            ? "Added to the company's learned knowledge."
            : "Filed as a proposal — it needs approval before use."
    }

    private func itemRow(_ item: AriaMemoryValidationResponse.Item) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 6) {
                Image(systemName: "sparkles")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(AriaLearningStyle.tint)
                Text(item.isProposed ? LocalizedStringKey("To review") : "Learned")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(item.isProposed ? .orange : .green)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 2)
                    .background((item.isProposed ? Color.orange : Color.green).opacity(0.12), in: Capsule())
            }
            Text(item.content)
                .font(.system(size: 14))
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.primary.opacity(0.045), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
    }

    private var context: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Question")
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(.secondary)
                .textCase(.uppercase)
            Text(AriaMarkdown.inline(outcome.question))
                .font(.system(size: 13))
            Text(outcome.response?.context == nil ? LocalizedStringKey("Validated answer") : "Context")
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(.secondary)
                .textCase(.uppercase)
                .padding(.top, 4)
            Text(AriaMarkdown.inline(outcome.response?.context ?? outcome.answer))
                .font(.system(size: 13))
                .foregroundStyle(.secondary)
                .lineLimit(8)
        }
        .fixedSize(horizontal: false, vertical: true)
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.primary.opacity(0.045), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        .transition(.opacity.combined(with: .move(edge: .bottom)))
    }

    private var actions: some View {
        HStack(spacing: 8) {
            Button {
                showContext.toggle()
            } label: {
                Label(showContext ? LocalizedStringKey("Hide context") : "Review context", systemImage: "book")
                    .font(.system(size: 14, weight: .medium))
                    .padding(.horizontal, 4)
                    .padding(.vertical, 2)
            }
            .buttonStyle(.bordered)
            .buttonBorderShape(.capsule)

            Spacer(minLength: 0)

            if !pending.isEmpty {
                Button {
                    notify()
                } label: {
                    HStack(spacing: 6) {
                        if notifying { ProgressView().controlSize(.small).tint(.white) }
                        else { Image(systemName: "bell.fill") }
                        Text("Notify")
                    }
                    .font(.system(size: 14, weight: .semibold))
                    .padding(.horizontal, 4)
                    .padding(.vertical, 2)
                }
                .buttonStyle(.borderedProminent)
                .buttonBorderShape(.capsule)
                .tint(AriaLearningStyle.tint)
                .disabled(notifying)
            } else {
                Button("Done") { chat.dismissLearningOutcome() }
                    .font(.system(size: 14, weight: .semibold))
                    .buttonStyle(.borderedProminent)
                    .buttonBorderShape(.capsule)
                    .tint(AriaLearningStyle.tint)
            }
        }
        .padding(.bottom, 4)
    }

    private func notify() {
        let ids = pending
        notifying = true
        Task {
            if await chat.notifyLearning(ids) { notified.formUnion(ids) }
            notifying = false
        }
    }
}

// MARK: - Chip

/// Sotto una risposta di cui Aria non è sicura: riapre la sua domanda di Real-time Learning.
struct AriaLearningChip: View {
    var action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 8) {
                AriaLearningIcon(size: 20)
                Text("Aria isn't sure — help it learn")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(AriaLearningStyle.tint)
                Image(systemName: "chevron.right")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(AriaLearningStyle.tint.opacity(0.7))
            }
            .padding(.leading, 6)
            .padding(.trailing, 12)
            .padding(.vertical, 6)
            .background(AriaLearningStyle.tint.opacity(0.1), in: Capsule())
            .overlay(Capsule().strokeBorder(AriaLearningStyle.tint.opacity(0.25), lineWidth: 0.5))
        }
        .buttonStyle(.plain)
    }
}
