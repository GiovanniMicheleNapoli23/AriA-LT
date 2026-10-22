//
//  AriaProcedureSteps.swift
//  AriaLite
//
//  Created by Giovanni Michele on 22/10/26.
//
//  Gli step della procedura nel menu "···": lo step corrente come scheda con tutti i task e il prossimo
//  evidenziato, gli step precedenti come righe compatte con il loro esito. La logica sta in AriaTaskStepViewModel.
//

import SwiftUI

/// La scheda dello step in corso: etichetta e titolo, avanzamento a segmenti (come nel pannello della chat)
/// e tutti i task. Il prossimo da fare ha lo sfondo colorato.
struct AriaCurrentStepCard: View {
    let list: AriaTaskList
    let messageId: String
    let chat: AriaAgentChat

    var body: some View {
        AriaCurrentStepCardContent(model: AriaTaskStepViewModel(chat: chat, list: list, messageId: messageId))
            .id(list)
    }
}

private struct AriaCurrentStepCardContent: View {
    @State private var model: AriaTaskStepViewModel

    init(model: @autoclosure () -> AriaTaskStepViewModel) {
        _model = State(wrappedValue: model())
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            AriaTaskStepHeader(list: model.list, titleStyle: .body) {
                // "In corso" è lo stato normale, non serve dirlo: si segnala solo l'eccezione o il traguardo.
                if model.outcome != .inProgress { AriaBadge(text: model.outcome.text, tint: model.outcome.tint) }
            }
            VStack(alignment: .leading, spacing: 6) {
                AriaTaskSegments(model: model)
                Text("\(model.doneCount) of \(model.tasks.count) tasks done")
                    .font(.caption.weight(.medium).monospacedDigit())
                    .foregroundStyle(.secondary)
                    .contentTransition(.numericText())
            }
            .accessibilityElement(children: .combine)
            VStack(spacing: 2) {
                ForEach(model.tasks) { task in
                    AriaProcedureTaskRow(model: model, task: task, isNext: model.isNext(task))
                }
            }
            .padding(.horizontal, -10)
        }
        .padding(.vertical, 4)
        .sensoryFeedback(trigger: model.doneCount) { old, new in model.feedback(from: old, to: new) }
    }
}

/// Una riga compatta: l'icona dice l'esito a colpo d'occhio; si apre per vedere (e correggere) i task.
struct AriaPastStepRow: View {
    let list: AriaTaskList
    let messageId: String
    let chat: AriaAgentChat

    var body: some View {
        AriaPastStepRowContent(model: AriaTaskStepViewModel(chat: chat, list: list, messageId: messageId))
            .id(list)
    }
}

private struct AriaPastStepRowContent: View {
    @State private var model: AriaTaskStepViewModel
    /// La colonna dell'icona d'esito cresce con il testo (Dynamic Type).
    @ScaledMetric(relativeTo: .title2) private var markerWidth: CGFloat = 28

    init(model: @autoclosure () -> AriaTaskStepViewModel) {
        _model = State(wrappedValue: model())
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Button { model.toggleExpanded() } label: {
                HStack(spacing: 12) {
                    Image(systemName: model.outcome.symbol)
                        .font(.title2)
                        .foregroundStyle(model.outcome.tint)
                        .frame(width: markerWidth)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(model.list.label)
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(model.list.stepTint)
                        Text(model.list.stepTitle)
                            .font(.subheadline.weight(.medium))
                            .foregroundStyle(.primary)
                            .multilineTextAlignment(.leading)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    Text(verbatim: "\(model.doneCount)/\(model.tasks.count)")
                        .font(.footnote.weight(.medium).monospacedDigit())
                        .foregroundStyle(.secondary)
                    Image(systemName: "chevron.right")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.tertiary)
                        .rotationEffect(.degrees(model.isExpanded ? 90 : 0))
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityValue(Text(model.outcome.text))
            .accessibilityAddTraits(.isHeader)

            if model.isExpanded {
                VStack(spacing: 2) {
                    ForEach(model.tasks) { task in
                        AriaProcedureTaskRow(model: model, task: task, isNext: false)
                    }
                }
                .padding(.horizontal, -10)
                .transition(.opacity)
            }
        }
        .animation(.snappy, value: model.isExpanded)
        .padding(.vertical, 4)
        .sensoryFeedback(trigger: model.doneCount) { old, new in model.feedback(from: old, to: new) }
    }
}

/// Un task: il cerchio si spunta con un tocco (tutta la riga è il bersaglio). Fatto = grigio e barrato.
private struct AriaProcedureTaskRow: View {
    let model: AriaTaskStepViewModel
    let task: AriaTaskList.Task
    /// Il prossimo task da fare: lo sfondo lo distingue dagli altri.
    let isNext: Bool
    /// La colonna del cerchio cresce con il testo (Dynamic Type).
    @ScaledMetric(relativeTo: .title2) private var markerWidth: CGFloat = 28

    var body: some View {
        let checked = model.isChecked(task)
        let tint = model.list.stepTint
        Button { model.toggle(task) } label: {
            HStack(alignment: .top, spacing: 12) {
                Image(systemName: checked ? "checkmark.circle.fill" : "circle")
                    .font(.title2)
                    .foregroundStyle(checked ? Color.green : (isNext ? tint : Color.secondary.opacity(0.6)))
                    .contentTransition(.symbolEffect(.replace))
                    .frame(width: markerWidth)
                VStack(alignment: .leading, spacing: 4) {
                    Text(AriaMarkdown.inline(task.text))
                        .font(.subheadline)
                        .foregroundStyle(checked ? .secondary : .primary)
                        .strikethrough(checked, color: .secondary)
                        .multilineTextAlignment(.leading)
                        .fixedSize(horizontal: false, vertical: true)
                    if let mark = model.mark(task) { AriaTaskMarkBadge(mark: mark) }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 10)
            .background(isNext && !checked ? tint.opacity(0.1) : .clear,
                        in: RoundedRectangle(cornerRadius: 12, style: .continuous))
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .animation(.snappy, value: checked)
        .accessibilityAddTraits(checked ? .isSelected : [])
    }
}
