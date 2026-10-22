//
//  AriaElicitationPanel.swift
//  AriaLite
//
//  Created by Giovanni Michele on 26/09/26.
//
//  Le domande guidate di Aria (elicitation-panel della web), pensate per il telefono:
//  il pannello prende il posto del composer, si sceglie e si conferma con la freccia
//  sulla riga scelta, si torna alla domanda precedente, "Altra risposta" apre il campo solo se serve,
//  e il pannello si riduce a una pillola per leggere la chat o scrivere liberamente.
//  Le risposte si compongono come fa la web (AriaElicitationTurn); la logica sta in AriaElicitationViewModel.
//  La conferma di fine procedura (`reason: closure_confirmation`) chiede anche il motivo: scegliendo "end"
//  compaiono i 16 motivi e le note facoltative, e la risposta parte come "<label>. Reason: <codice>. Details: <nota>".
//

import SwiftUI

struct AriaElicitationPanel: View {
    /// Chi chiede: una domanda della conversazione o il Real-time Learning (la risposta insegna ad Aria,
    /// non diventa un turno di chat).
    enum Kind: Equatable {
        case question
        case learning(reason: String?)

        var isLearning: Bool { if case .learning = self { true } else { false } }
    }

    let elicitation: AriaElicitation
    var kind: Kind = .question
    /// Oltre questa altezza le opzioni scorrono. È solo un paracadute (schermo piccolo, tastiera aperta):
    /// di norma il pannello è alto quanto le domande.
    var maxOptionsHeight: CGFloat = 520
    var onSubmit: (_ text: String, _ details: [AriaElicitationAnswer]) -> Void
    /// Riduce il pannello: torna il composer per scrivere liberamente.
    var onMinimize: () -> Void

    var body: some View {
        AriaElicitationPanelContent(elicitation: elicitation, kind: kind, maxOptionsHeight: maxOptionsHeight,
                                    onSubmit: onSubmit, onMinimize: onMinimize)
            // Il view model nasce con la domanda: una domanda nuova riparte da capo.
            .id(elicitation.id)
    }
}

private struct AriaElicitationPanelContent: View {
    let kind: AriaElicitationPanel.Kind
    let maxOptionsHeight: CGFloat
    var onMinimize: () -> Void

    @State private var model: AriaElicitationViewModel
    @FocusState private var fieldFocused: Bool
    @ScaledMetric(relativeTo: .footnote) private var headerButtonSide: CGFloat = 30
    @ScaledMetric(relativeTo: .footnote) private var orbSide: CGFloat = 20

    init(elicitation: AriaElicitation, kind: AriaElicitationPanel.Kind, maxOptionsHeight: CGFloat,
         onSubmit: @escaping (_ text: String, _ details: [AriaElicitationAnswer]) -> Void, onMinimize: @escaping () -> Void) {
        _model = State(initialValue: AriaElicitationViewModel(elicitation: elicitation, onSubmit: onSubmit))
        self.kind = kind
        self.maxOptionsHeight = maxOptionsHeight
        self.onMinimize = onMinimize
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            header

            Group {
                if let option = model.followUp {
                    AriaElicitationFollowUpForm(model: model, option: option, fieldFocused: $fieldFocused)
                } else {
                    VStack(alignment: .leading, spacing: 12) {
                        scrolling {
                            VStack(alignment: .leading, spacing: 12) {
                                Text(AriaMarkdown.inline(model.step.question))
                                    .font(.headline)
                                    .fixedSize(horizontal: false, vertical: true)
                                if case .learning(let reason?) = kind {
                                    Text(AriaMarkdown.inline(reason))
                                        .font(.footnote)
                                        .foregroundStyle(.secondary)
                                        .fixedSize(horizontal: false, vertical: true)
                                }
                                if !model.isSingle {
                                    Text(model.isRank ? "Tap in order of priority" : "Choose all that apply")
                                        .font(.caption.weight(.medium))
                                        .foregroundStyle(.secondary)
                                }
                                optionList
                            }
                        }
                        if !model.isSingle { footer }
                    }
                }
            }
            .id(model.pageID)
            .transition(.asymmetric(
                insertion: .move(edge: model.forward ? .trailing : .leading).combined(with: .opacity),
                removal: .move(edge: model.forward ? .leading : .trailing).combined(with: .opacity)
            ))
        }
        .animation(.snappy(duration: 0.28), value: model.pageID)
        .padding(.horizontal, 16)
        .padding(.top, 16)
        .padding(.bottom, 8)
        .frame(maxWidth: .infinity, alignment: .leading)
        .clipped()
        // Pannello di vetro fino al bordo dello schermo: la conversazione si intravede sotto.
        .ariaBottomPanel(stroke: kind.isLearning ? AriaLearningStyle.tint.opacity(0.35) : nil)
        .sensoryFeedback(.selection, trigger: model.selected)
        // Passo successivo o precedente della domanda; l'invio finale lo segnala la chat.
        .sensoryFeedback(.impact(weight: .light), trigger: model.stepIndex)
        // Risposta salvata (passo successivo o invio): la tastiera si chiude.
        .onChange(of: model.commits) { fieldFocused = false }
    }

    // MARK: Intestazione

    private var header: some View {
        HStack(spacing: 8) {
            if model.canGoBack {
                Button { model.goBack() } label: {
                    Image(systemName: "chevron.left")
                        .font(.footnote.weight(.semibold))
                        .frame(width: headerButtonSide, height: headerButtonSide)
                        .background(Color(.tertiarySystemFill), in: Circle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Back")
                .transition(.scale.combined(with: .opacity))
            }

            if kind.isLearning {
                AriaLearningBadge()
            } else {
                AriaOrb()
                    .frame(width: orbSide, height: orbSide)
                Text("Aria is asking")
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(.secondary)
            }

            Spacer(minLength: 8)

            if model.steps.count > 1 { progress }

            Button(action: onMinimize) {
                Image(systemName: "chevron.down")
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(.secondary)
                    .frame(width: headerButtonSide, height: headerButtonSide)
                    .background(Color(.tertiarySystemFill), in: Circle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel(kind.isLearning ? "Not now" : "Hide the question")
        }
        .animation(.snappy, value: model.canGoBack)
    }

    private var progress: some View {
        HStack(spacing: 6) {
            HStack(spacing: 3) {
                ForEach(model.steps.indices, id: \.self) { i in
                    Capsule()
                        .fill(i <= model.stepIndex ? Color.accentColor : Color(.tertiarySystemFill))
                        .frame(width: i == model.stepIndex ? 16 : 8, height: 5)
                }
            }
            Text(verbatim: "\(model.stepIndex + 1)/\(model.steps.count)")
                .font(.caption.weight(.semibold).monospacedDigit())
                .foregroundStyle(.secondary)
        }
        .animation(.snappy, value: model.stepIndex)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text("Question \(model.stepIndex + 1) of \(model.steps.count)"))
    }

    // MARK: Opzioni

    /// Alta quanto il contenuto (la ScrollView prende l'altezza del contenuto) e ferma: scorre solo
    /// se supera `maxOptionsHeight`, cioè se domanda e opzioni proprio non entrano nello schermo
    /// (iPhone in orizzontale con la tastiera): l'intestazione e il pulsante d'invio restano visibili.
    private func scrolling(@ViewBuilder _ content: () -> some View) -> some View {
        ScrollView { content() }
            .frame(maxHeight: maxOptionsHeight)
            .fixedSize(horizontal: false, vertical: true)
            .scrollBounceBehavior(.basedOnSize)
    }

    private var optionList: some View {
        VStack(spacing: 8) {
            ForEach(model.step.options) { option in
                AriaElicitationOptionRow(model: model, option: option) {
                    // Nella scelta singola opzione e risposta scritta si escludono: il campo perde il fuoco.
                    if model.isSingle { fieldFocused = false }
                    model.pick(option)
                }
            }
            if model.endingProcedure { AriaClosureReasonForm(model: model, fieldFocused: $fieldFocused) }
            if model.step.allowCustom { AriaElicitationCustomRow(model: model, fieldFocused: $fieldFocused) }
        }
        .animation(.snappy(duration: 0.2), value: model.endingProcedure)
        .animation(.snappy, value: model.writingCustom)
    }

    /// Scelta multipla / classifica: la risposta è l'insieme, quindi un solo pulsante sotto la lista.
    private var footer: some View {
        HStack(spacing: 10) {
            if !model.selected.isEmpty {
                Button("Clear") { model.clearSelection() }
                    .font(.subheadline.weight(.medium))
                    .buttonStyle(.borderless)
            }
            Spacer()
            Button { model.submit() } label: {
                HStack(spacing: 6) {
                    Text(model.isLast ? "Send" : "Next")
                    if !model.selected.isEmpty {
                        Text(verbatim: "\(model.selected.count)")
                            .font(.caption.weight(.bold).monospacedDigit())
                            .padding(.horizontal, 6)
                            .padding(.vertical, 1)
                            .background(.white.opacity(0.25), in: Capsule())
                    }
                    Image(systemName: model.isLast ? "arrow.up" : "arrow.right")
                        .font(.footnote.weight(.bold))
                }
                .font(.subheadline.weight(.semibold))
                .padding(.horizontal, 6)
                .padding(.vertical, 4)
            }
            .buttonStyle(.borderedProminent)
            .buttonBorderShape(.capsule)
            .disabled(!model.canSubmitSet)
        }
        .animation(.snappy, value: model.selected.isEmpty)
    }
}
