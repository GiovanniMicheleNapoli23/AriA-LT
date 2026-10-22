//
//  AriaLearningOutcomePanel.swift
//  AriaLite
//
//  Created by Giovanni Michele on 22/10/26.
//
//  Prende il posto della domanda appena risposta: prima "Aria sta imparando…", poi cosa ha imparato,
//  con il contesto da rivedere e, per i fatti ancora in proposta, la richiesta di validazione agli admin.
//  La logica sta in AriaLearningOutcomeViewModel.
//

import SwiftUI

struct AriaLearningOutcomePanel: View {
    let outcome: AriaLearningOutcome

    @State private var model: AriaLearningOutcomeViewModel
    /// In orizzontale su iPhone lo schermo è basso: intestazione e azioni devono restare nella chat.
    @Environment(\.verticalSizeClass) private var verticalSizeClass
    /// Il pulsante di chiusura cresce con il testo (Dynamic Type).
    @ScaledMetric(relativeTo: .caption) private var closeSize: CGFloat = 30

    init(outcome: AriaLearningOutcome, chat: AriaAgentChat) {
        self.outcome = outcome
        _model = State(initialValue: AriaLearningOutcomeViewModel(chat: chat))
    }

    /// Altezza massima di fatti e contesto (scorrono insieme).
    private var maxContentHeight: CGFloat {
        if verticalSizeClass == .compact { return 120 }
        return model.showContext ? 360 : 240
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .top, spacing: 10) {
                AriaLearningIcon(size: 30)
                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.callout.weight(.semibold))
                    Text(subtitle)
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
                .fixedSize(horizontal: false, vertical: true)
                Spacer(minLength: 8)
                if outcome.isSaving {
                    ProgressView()
                        .padding(.top, 4)
                } else {
                    Button { model.dismiss() } label: {
                        Image(systemName: "xmark")
                            .font(.caption.weight(.bold))
                            .foregroundStyle(.secondary)
                            .frame(width: closeSize, height: closeSize)
                            .background(Color(.tertiarySystemFill), in: Circle())
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Close")
                }
            }

            if model.showsItems(outcome) {
                ScrollView {
                    VStack(spacing: 8) {
                        ForEach(Array(outcome.items.enumerated()), id: \.offset) { _, item in
                            itemRow(item)
                        }
                        // Il contesto scorre con i fatti: intestazione e azioni restano sempre visibili.
                        if model.showContext { context }
                    }
                }
                .frame(maxHeight: maxContentHeight)
                .fixedSize(horizontal: false, vertical: true)
                .scrollBounceBehavior(.basedOnSize)
                .task(id: outcome.items) { model.requestTranslations(outcome) }
            }

            if !outcome.isSaving { actions }
        }
        .padding(.horizontal, 16)
        .padding(.top, 16)
        .padding(.bottom, 8)
        .frame(maxWidth: .infinity, alignment: .leading)
        .ariaBottomPanel(stroke: AriaLearningStyle.tint.opacity(0.35))
        .animation(.snappy(duration: 0.3), value: outcome)
        .animation(.snappy(duration: 0.25), value: model.showContext)
        .sensoryFeedback(.success, trigger: outcome.isSaving) { was, now in was && !now }
    }

    private var title: LocalizedStringKey {
        switch model.phase(outcome) {
        case .saving: "Aria is learning…"
        case .learned: "Aria learned something new"
        case .proposed: "Saved for review"
        }
    }

    private var subtitle: LocalizedStringKey {
        switch model.phase(outcome) {
        case .saving: "Saving your answer to the plant's knowledge."
        case .learned: "Added to the company's learned knowledge."
        case .proposed: "Filed as a proposal — it needs approval before use."
        }
    }

    private func itemRow(_ item: AriaMemoryValidationResponse.Item) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 6) {
                Image(systemName: "sparkles")
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(AriaLearningStyle.tint)
                Text(item.isProposed ? LocalizedStringKey("To review") : "Learned")
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(item.isProposed ? .orange : .green)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 2)
                    .background((item.isProposed ? Color.orange : Color.green).opacity(0.12), in: Capsule())
            }
            Text(model.text(item))
                .font(.subheadline)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.primary.opacity(0.045), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
    }

    private var context: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Question")
                .font(.caption2.weight(.semibold))
                .foregroundStyle(.secondary)
                .textCase(.uppercase)
            Text(AriaMarkdown.inline(outcome.question))
                .font(.footnote)
            Text(outcome.response?.context == nil ? LocalizedStringKey("Validated answer") : "Context")
                .font(.caption2.weight(.semibold))
                .foregroundStyle(.secondary)
                .textCase(.uppercase)
                .padding(.top, 4)
            Text(AriaMarkdown.inline(outcome.response?.context ?? outcome.answer))
                .font(.footnote)
                .foregroundStyle(.secondary)
                .lineLimit(8)
        }
        .fixedSize(horizontal: false, vertical: true)
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.primary.opacity(0.045), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        .transition(.opacity.combined(with: .move(edge: .bottom)))
    }

    /// Con il testo molto grande i due pulsanti non stanno su una riga: vanno uno sotto l'altro.
    private var actions: some View {
        ViewThatFits(in: .horizontal) {
            HStack(spacing: 8) {
                contextButton
                Spacer(minLength: 0)
                primaryButton
            }
            VStack(alignment: .leading, spacing: 8) {
                contextButton
                primaryButton
            }
        }
        .padding(.bottom, 4)
    }

    private var contextButton: some View {
        Button { model.toggleContext() } label: {
            Label(model.showContext ? LocalizedStringKey("Hide context") : "Review context", systemImage: "book")
                .font(.subheadline.weight(.medium))
                .padding(.horizontal, 4)
                .padding(.vertical, 2)
        }
        .buttonStyle(.bordered)
        .buttonBorderShape(.capsule)
    }

    @ViewBuilder private var primaryButton: some View {
        if model.canNotify(outcome) {
            Button { model.notify(outcome) } label: {
                HStack(spacing: 6) {
                    if model.notifying { ProgressView().controlSize(.small).tint(.white) }
                    else { Image(systemName: "bell.fill") }
                    Text("Notify")
                }
                .font(.subheadline.weight(.semibold))
                .padding(.horizontal, 4)
                .padding(.vertical, 2)
            }
            .buttonStyle(.borderedProminent)
            .buttonBorderShape(.capsule)
            .tint(AriaLearningStyle.tint)
            .disabled(model.notifying)
        } else {
            Button("Done") { model.dismiss() }
                .font(.subheadline.weight(.semibold))
                .buttonStyle(.borderedProminent)
                .buttonBorderShape(.capsule)
                .tint(AriaLearningStyle.tint)
        }
    }
}
