//
//  AriaElicitationPanel.swift
//  AriaLite
//
//  Le domande guidate di Aria (elicitation-panel della web), pensate per il telefono:
//  il pannello prende il posto del composer, si sceglie e si conferma con la freccia
//  sulla riga scelta, si torna alla domanda precedente, "Altra risposta" apre il campo solo se serve,
//  e il pannello si riduce a una pillola per leggere la chat o scrivere liberamente.
//  Le risposte si compongono come fa la web (buildAnswer / assembleChatTurn).
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

    @State private var stepIndex = 0
    @State private var answers: [String?] = []
    @State private var details: [AriaElicitationAnswer?] = []
    @State private var selected: [String] = []
    @State private var custom = ""
    @State private var writingCustom = false
    @State private var followUp: AriaElicitationOption?
    @State private var followUpValue = ""
    /// Direzione dell'animazione tra un passo e l'altro.
    @State private var forward = true
    @FocusState private var fieldFocused: Bool

    private var steps: [AriaElicitationStep] { elicitation.allSteps }
    private var step: AriaElicitationStep { steps[min(stepIndex, steps.count - 1)] }
    private var isLast: Bool { stepIndex >= steps.count - 1 }
    private var isSingle: Bool { step.mode != "multi" && step.mode != "rank" }
    private var canGoBack: Bool { followUp != nil || stepIndex > 0 }
    private var typed: String { writingCustom ? custom.trimmingCharacters(in: .whitespacesAndNewlines) : "" }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            header

            Group {
                if let option = followUp {
                    followUpForm(option)
                } else {
                    VStack(alignment: .leading, spacing: 12) {
                        Text(AriaMarkdown.inline(step.question))
                            .font(.system(size: 17, weight: .semibold))
                            .fixedSize(horizontal: false, vertical: true)
                        if case .learning(let reason?) = kind {
                            Text(AriaMarkdown.inline(reason))
                                .font(.system(size: 13))
                                .foregroundStyle(.secondary)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                        if !isSingle {
                            Text(step.mode == "rank" ? "Tap in order of priority" : "Choose all that apply")
                                .font(.system(size: 12, weight: .medium))
                                .foregroundStyle(.secondary)
                        }
                        options
                        if !isSingle { footer }
                    }
                }
            }
            .id("\(stepIndex)-\(followUp?.id ?? "")")
            .transition(.asymmetric(
                insertion: .move(edge: forward ? .trailing : .leading).combined(with: .opacity),
                removal: .move(edge: forward ? .leading : .trailing).combined(with: .opacity)
            ))
        }
        .padding(.horizontal, 16)
        .padding(.top, 16)
        .padding(.bottom, 8)
        .frame(maxWidth: .infinity, alignment: .leading)
        .clipped()
        // Pannello di vetro fino al bordo dello schermo: la conversazione si intravede sotto.
        .ariaBottomPanel(stroke: kind.isLearning ? AriaLearningStyle.tint.opacity(0.35) : nil)
        .sensoryFeedback(.selection, trigger: selected)
        // Passo successivo o precedente della domanda; l'invio finale lo segnala la chat.
        .sensoryFeedback(.impact(weight: .light), trigger: stepIndex)
        .onChange(of: elicitation.id) { resetAll() }
    }

    // MARK: Intestazione

    private var header: some View {
        HStack(spacing: 8) {
            if canGoBack {
                Button(action: goBack) {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 14, weight: .semibold))
                        .frame(width: 30, height: 30)
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
                    .frame(width: 20, height: 20)
                Text("Aria is asking")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(.secondary)
            }

            Spacer(minLength: 8)

            if steps.count > 1 { progress }

            Button(action: onMinimize) {
                Image(systemName: "chevron.down")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(.secondary)
                    .frame(width: 30, height: 30)
                    .background(Color(.tertiarySystemFill), in: Circle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel(kind.isLearning ? "Not now" : "Hide the question")
        }
        .animation(.snappy, value: canGoBack)
    }

    private var progress: some View {
        HStack(spacing: 6) {
            HStack(spacing: 3) {
                ForEach(steps.indices, id: \.self) { i in
                    Capsule()
                        .fill(i <= stepIndex ? Color.accentColor : Color(.tertiarySystemFill))
                        .frame(width: i == stepIndex ? 16 : 8, height: 5)
                }
            }
            Text(verbatim: "\(stepIndex + 1)/\(steps.count)")
                .font(.system(size: 12, weight: .semibold).monospacedDigit())
                .foregroundStyle(.secondary)
        }
        .animation(.snappy, value: stepIndex)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text("Question \(stepIndex + 1) of \(steps.count)"))
    }

    // MARK: Opzioni

    /// Alta quanto le opzioni (la ScrollView prende l'altezza del contenuto) e ferma: scorre solo
    /// se supera `maxOptionsHeight`, cioè se le opzioni proprio non entrano nello schermo.
    private var options: some View {
        ScrollView { optionList }
            .frame(maxHeight: maxOptionsHeight)
            .fixedSize(horizontal: false, vertical: true)
            .scrollBounceBehavior(.basedOnSize)
    }

    private var optionList: some View {
        VStack(spacing: 8) {
            ForEach(step.options) { optionRow($0) }
            if step.allowCustom { customRow }
        }
    }

    /// Nella scelta singola la riga selezionata porta la freccia d'invio: l'opzione scelta È la risposta.
    private func optionRow(_ option: AriaElicitationOption) -> some View {
        let rank = selected.firstIndex(of: option.id)
        let isOn = rank != nil
        return HStack(spacing: 8) {
            Button {
                pick(option)
            } label: {
                HStack(spacing: 12) {
                    indicator(isOn: isOn, rank: rank)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(option.label)
                            .font(.system(size: 15, weight: isOn ? .semibold : .medium))
                            .foregroundStyle(.primary)
                        if let description = option.description, !description.isEmpty {
                            Text(description)
                                .font(.system(size: 13))
                                .foregroundStyle(.secondary)
                        }
                    }
                    .multilineTextAlignment(.leading)
                    Spacer(minLength: 0)
                    if isSingle, option.followUp != nil {
                        Image(systemName: "chevron.right")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundStyle(.tertiary)
                    }
                }
                .padding(.vertical, 12)
                .frame(maxWidth: .infinity, minHeight: 52, alignment: .leading)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityAddTraits(isOn ? .isSelected : [])

            if isSingle, isOn {
                sendButton(enabled: true, action: submit)
                    .transition(.scale.combined(with: .opacity))
            }
        }
        .padding(.leading, 14)
        .padding(.trailing, isSingle && isOn ? 9 : 14)
        // Sul vetro: riempimenti traslucidi, niente vetro sopra vetro.
        .background(isOn ? Color.accentColor.opacity(0.12) : Color.primary.opacity(0.045),
                    in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous)
            .strokeBorder(isOn ? Color.accentColor.opacity(0.5) : Color.white.opacity(0.35), lineWidth: isOn ? 1.5 : 0.5))
        .animation(.snappy(duration: 0.2), value: isOn)
    }

    @ViewBuilder
    private func indicator(isOn: Bool, rank: Int?) -> some View {
        switch step.mode {
        case "rank":
            ZStack {
                Circle().strokeBorder(isOn ? Color.clear : Color.secondary.opacity(0.5),
                                      style: StrokeStyle(lineWidth: 1.5, dash: [3, 2.5]))
                if let rank {
                    Circle().fill(Color.accentColor)
                    Text(verbatim: "\(rank + 1)")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundStyle(.white)
                }
            }
            .frame(width: 22, height: 22)
        case "multi":
            Image(systemName: isOn ? "checkmark.square.fill" : "square")
                .font(.system(size: 20))
                .foregroundStyle(isOn ? Color.accentColor : .secondary)
                .frame(width: 22, height: 22)
        default:
            Image(systemName: isOn ? "checkmark.circle.fill" : "circle")
                .font(.system(size: 20))
                .foregroundStyle(isOn ? Color.accentColor : Color.secondary.opacity(0.6))
                .frame(width: 22, height: 22)
        }
    }

    /// "Altra risposta": riga compatta che diventa un campo di testo solo quando serve.
    @ViewBuilder
    private var customRow: some View {
        if writingCustom {
            HStack(alignment: .bottom, spacing: 8) {
                TextField(isSingle ? "Type your answer…" : "Add something (optional)…", text: $custom, axis: .vertical)
                    .font(.system(size: 15))
                    .lineLimit(1...4)
                    .focused($fieldFocused)
                    .submitLabel(.send)
                    .onSubmit { if isSingle { submit() } }
                    .onChange(of: custom) { _, value in
                        // Nella scelta singola la risposta scritta sostituisce l'opzione.
                        if isSingle, !value.trimmingCharacters(in: .whitespaces).isEmpty { selected = [] }
                    }
                    .padding(.vertical, 6)
                if isSingle {
                    sendButton(enabled: !typed.isEmpty, action: submit)
                }
            }
            .padding(.leading, 14)
            .padding(.trailing, 8)
            .padding(.vertical, 6)
            .frame(minHeight: 52)
            .background(Color.primary.opacity(0.045), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous)
                .strokeBorder(Color.accentColor.opacity(fieldFocused ? 0.5 : 0.2), lineWidth: 1.5))
            .onAppear { fieldFocused = true }
        } else {
            Button {
                withAnimation(.snappy) {
                    writingCustom = true
                    // Riaperto con del testo già scritto: nella scelta singola è quello la risposta.
                    if isSingle, !custom.trimmingCharacters(in: .whitespaces).isEmpty { selected = [] }
                }
            } label: {
                HStack(spacing: 12) {
                    Image(systemName: "pencil")
                        .font(.system(size: 15, weight: .medium))
                        .frame(width: 22, height: 22)
                    Text("Other answer…")
                        .font(.system(size: 15, weight: .medium))
                    Spacer(minLength: 0)
                }
                .foregroundStyle(.secondary)
                .padding(.horizontal, 14)
                .frame(maxWidth: .infinity, minHeight: 52, alignment: .leading)
                .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .strokeBorder(Color.secondary.opacity(0.35), style: StrokeStyle(lineWidth: 1, dash: [5, 4])))
                .contentShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            }
            .buttonStyle(.plain)
        }
    }

    /// Scelta multipla / classifica: la risposta è l'insieme, quindi un solo pulsante sotto la lista.
    private var footer: some View {
        HStack(spacing: 10) {
            if !selected.isEmpty {
                Button("Clear") { withAnimation(.snappy) { selected = [] } }
                    .font(.system(size: 14, weight: .medium))
                    .buttonStyle(.borderless)
            }
            Spacer()
            Button(action: submit) {
                HStack(spacing: 6) {
                    Text(isLast ? "Send" : "Next")
                    if !selected.isEmpty {
                        Text(verbatim: "\(selected.count)")
                            .font(.system(size: 12, weight: .bold).monospacedDigit())
                            .padding(.horizontal, 6)
                            .padding(.vertical, 1)
                            .background(.white.opacity(0.25), in: Capsule())
                    }
                    Image(systemName: isLast ? "arrow.up" : "arrow.right")
                        .font(.system(size: 13, weight: .bold))
                }
                .font(.system(size: 15, weight: .semibold))
                .padding(.horizontal, 6)
                .padding(.vertical, 4)
            }
            .buttonStyle(.borderedProminent)
            .buttonBorderShape(.capsule)
            .disabled(currentAnswer().isEmpty)
        }
    }

    // MARK: Valore richiesto da un'opzione

    private func followUpForm(_ option: AriaElicitationOption) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Label(option.label, systemImage: "checkmark.circle.fill")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(Color.accentColor)
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(Color.accentColor.opacity(0.1), in: Capsule())
            Text(AriaMarkdown.inline(option.followUp ?? ""))
                .font(.system(size: 17, weight: .semibold))
                .fixedSize(horizontal: false, vertical: true)
            HStack(alignment: .bottom, spacing: 8) {
                TextField("Type your answer…", text: $followUpValue, axis: .vertical)
                    .font(.system(size: 15))
                    .lineLimit(1...4)
                    .focused($fieldFocused)
                    .submitLabel(.send)
                    .onSubmit(submitFollowUp)
                    .padding(.vertical, 6)
                sendButton(enabled: !followUpValue.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
                           action: submitFollowUp)
            }
            .padding(.leading, 14)
            .padding(.trailing, 8)
            .padding(.vertical, 6)
            .frame(minHeight: 52)
            .background(Color.primary.opacity(0.045), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous)
                .strokeBorder(Color.accentColor.opacity(fieldFocused ? 0.5 : 0.2), lineWidth: 1.5))
        }
        .onAppear { fieldFocused = true }
    }

    private func sendButton(enabled: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: isLast ? "arrow.up" : "arrow.right")
                .font(.system(size: 14, weight: .bold))
                .foregroundStyle(.white)
                .frame(width: 34, height: 34)
                .background(enabled ? Color.accentColor : Color.secondary.opacity(0.35), in: Circle())
        }
        .buttonStyle(.plain)
        .disabled(!enabled)
        .accessibilityLabel(isLast ? "Send" : "Next")
    }

    // MARK: Azioni

    private func pick(_ option: AriaElicitationOption) {
        guard isSingle else {
            if let i = selected.firstIndex(of: option.id) { selected.remove(at: i) } else { selected.append(option.id) }
            return
        }
        // Opzione e risposta scritta non possono essere entrambe la risposta (il testo resta, se si riapre).
        writingCustom = false
        fieldFocused = false
        // Un'opzione che promette un valore apre il campo, invece di mandare la promessa come risposta.
        if option.followUp != nil {
            selected = [option.id]
            followUpValue = ""
            move(forward: true) { followUp = option }
            return
        }
        // Si seleziona soltanto (un altro tocco deseleziona): la risposta parte con Invia.
        selected = selected == [option.id] ? [] : [option.id]
    }

    private func submit() {
        commit(currentAnswer())
    }

    private func submitFollowUp() {
        let value = followUpValue.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let option = followUp, !value.isEmpty else { return }
        commit("\(option.label): \(value)", typed: value)
    }

    /// buildAnswer della web.
    private func currentAnswer() -> String {
        let picked = selected.compactMap { id in step.options.first { $0.id == id }?.label }
        switch step.mode {
        case "rank" where !picked.isEmpty:
            let ranked = picked.enumerated().map { "\($0.offset + 1)) \($0.element)" }.joined(separator: ", ")
            let prefix = String(localized: "In order of priority")
            return typed.isEmpty ? "\(prefix): \(ranked)" : "\(prefix): \(ranked). \(typed)"
        case "multi" where !picked.isEmpty:
            let joined = picked.joined(separator: ", ")
            return typed.isEmpty ? joined : "\(joined). \(typed)"
        default:
            if !typed.isEmpty { return picked.first.map { "\($0). \(typed)" } ?? typed }
            return picked.first ?? ""
        }
    }

    /// Salva la risposta del passo; all'ultimo compone il turno e lo manda (commitStepAnswer della web).
    private func commit(_ answer: String, typed customText: String? = nil) {
        let answer = answer.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !answer.isEmpty else { return }
        let chosen = isSingle ? selected.first.flatMap { id in step.options.first { $0.id == id } } : nil
        if answers.count < steps.count {
            answers = Array(repeating: nil, count: steps.count)
            details = Array(repeating: nil, count: steps.count)
        }
        answers[stepIndex] = answer
        details[stepIndex] = AriaElicitationAnswer(key: step.key, value: chosen?.value ?? chosen?.id, text: answer,
                                                   custom: customText ?? typed, file: step.file)
        fieldFocused = false

        if isLast {
            let filled = answers.map { $0 ?? "" }
            onSubmit(Self.assemble(steps: steps, answers: filled, intro: elicitation.assembly?.intro),
                     details.compactMap { $0 })
            resetAll()
        } else {
            move(forward: true) {
                stepIndex += 1
                clearInputs()
            }
        }
    }

    private func goBack() {
        if followUp != nil {
            move(forward: false) {
                followUp = nil
                selected = []
                followUpValue = ""
            }
        } else if stepIndex > 0 {
            move(forward: false) {
                stepIndex -= 1
                clearInputs()
            }
        }
    }

    private func move(forward: Bool, _ change: () -> Void) {
        self.forward = forward
        withAnimation(.snappy(duration: 0.28), change)
    }

    private func clearInputs() {
        selected = []
        custom = ""
        writingCustom = false
        followUp = nil
        followUpValue = ""
    }

    private func resetAll() {
        stepIndex = 0
        answers = []
        details = []
        clearInputs()
    }

    /// assembleChatTurn della web: i passi con `file` non vanno nel turno di chat.
    static func assemble(steps: [AriaElicitationStep], answers: [String], intro: String?) -> String {
        let pairs = zip(steps, answers).filter { $0.0.file == nil }
        let lines = pairs.map { ($0.0, $0.1.trimmingCharacters(in: .whitespacesAndNewlines)) }.filter { !$0.1.isEmpty }
        guard !lines.isEmpty else { return "" }
        if lines.count == 1, pairs.count == 1 { return lines[0].1 }
        let body = lines.map { step, answer in
            let topic = step.topic?.trimmingCharacters(in: .whitespaces)
            return "- \(topic?.isEmpty == false ? topic! : step.question): \(answer)"
        }.joined(separator: "\n")
        if let lead = intro?.trimmingCharacters(in: .whitespacesAndNewlines), !lead.isEmpty { return "\(lead)\n\(body)" }
        return body
    }
}

// MARK: - Pannello ridotto

/// La domanda ancora aperta mentre si legge la chat o si scrive liberamente: un tocco la riapre.
struct AriaElicitationPill: View {
    let elicitation: AriaElicitation
    var isLearning = false
    var onExpand: () -> Void

    var body: some View {
        Button(action: onExpand) {
            HStack(spacing: 10) {
                if isLearning {
                    AriaLearningIcon(size: 22)
                } else {
                    AriaOrb()
                        .frame(width: 22, height: 22)
                }
                VStack(alignment: .leading, spacing: 1) {
                    Text(isLearning ? LocalizedStringKey("Real-time Learning") : "Aria is asking")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(isLearning ? AriaLearningStyle.tint : .secondary)
                    Text(AriaMarkdown.inline(elicitation.allSteps.first?.question ?? elicitation.question))
                        .font(.system(size: 14, weight: .medium))
                        .foregroundStyle(.primary)
                        .lineLimit(1)
                }
                Spacer(minLength: 8)
                Text("Answer")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(isLearning ? AriaLearningStyle.tint : Color.accentColor, in: Capsule())
            }
            .padding(.leading, 12)
            .padding(.trailing, 8)
            .padding(.vertical, 8)
            .ariaGlass(in: Capsule(), interactive: true)
            .contentShape(Capsule())
        }
        .buttonStyle(.plain)
    }
}
