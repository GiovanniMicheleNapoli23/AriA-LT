//
//  AriaProcedureDock.swift
//  AriaLite
//
//  Created by Giovanni Michele on 26/09/26.
//
//  Quando Aria manda una checklist insieme a una domanda, in basso non c'è la domanda
//  ma la procedura: un task alla volta, "Fatto" per spuntarlo, "Indietro" per tornare al
//  task prima, e in alto il menu per chiedere aiuto su quel task. Finita la checklist
//  compare la domanda di Aria. La logica sta in AriaTaskStepViewModel.
//

import SwiftUI

struct AriaProcedureDock: View {
    let list: AriaTaskList
    let messageId: String
    let chat: AriaAgentChat

    var body: some View {
        AriaProcedureDockContent(model: AriaTaskStepViewModel(chat: chat, list: list, messageId: messageId))
            // Il view model nasce con la lista: una revisione riparte da capo.
            .id(list)
    }
}

private struct AriaProcedureDockContent: View {
    @State private var model: AriaTaskStepViewModel
    /// In orizzontale su iPhone lo schermo è basso: il pannello non deve coprire tutta la chat.
    @Environment(\.verticalSizeClass) private var verticalSizeClass
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    /// Una riga del task: i limiti d'altezza crescono con il testo, così almeno una riga si legge sempre.
    @ScaledMetric(relativeTo: .body) private var taskLine: CGFloat = 24
    @ScaledMetric(relativeTo: .callout) private var backSize: CGFloat = 50
    @ScaledMetric(relativeTo: .subheadline) private var menuSize: CGFloat = 34

    /// Testo grande o telefono in orizzontale: il pannello resta compatto sopra il composer.
    private var isTight: Bool { verticalSizeClass == .compact || dynamicTypeSize.isAccessibilitySize }

    /// Alto quanto il testo; scorre solo se il task è lunghissimo (in orizzontale oltre due righe).
    private var taskMaxHeight: CGFloat {
        verticalSizeClass == .compact ? max(48, taskLine) : max(220, taskLine * 3)
    }

    init(model: @autoclosure () -> AriaTaskStepViewModel) {
        _model = State(wrappedValue: model())
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            AriaTaskStepHeader(list: model.list, titleOpacity: 0.85) {
                if let task = model.next { problemMenu(task) }
            }
            AriaTaskSegments(model: model)
                .accessibilityElement(children: .ignore)
                .accessibilityLabel(Text("\(model.doneCount) of \(model.tasks.count) tasks done"))

            if let task = model.next {
                // Il task è l'azione da fare adesso: è il testo più in evidenza del pannello.
                VStack(alignment: .leading, spacing: 6) {
                    Text("Task \(task.index) of \(model.tasks.count)")
                        .font(.footnote.weight(.semibold))
                        .foregroundStyle(.secondary)
                    ScrollView {
                        Text(AriaMarkdown.inline(task.text))
                            .font(.body)
                            .lineSpacing(3)
                            .foregroundStyle(.primary)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    .frame(maxHeight: taskMaxHeight)
                    .fixedSize(horizontal: false, vertical: true)
                    .scrollBounceBehavior(.basedOnSize)
                    if let mark = model.mark(task) { AriaTaskMarkBadge(mark: mark) }
                }
                .id(task.id)
                .transition(.asymmetric(insertion: .move(edge: model.forward ? .trailing : .leading).combined(with: .opacity),
                                        removal: .move(edge: model.forward ? .leading : .trailing).combined(with: .opacity)))

                actions(task)
            }

            if !isTight {
                Label("Complete the steps to answer Aria's question", systemImage: "lock.fill")
                    .font(.caption.weight(.medium))
                    .foregroundStyle(.tertiary)
                    .frame(maxWidth: .infinity)
            }
        }
        .animation(.snappy, value: model.next?.id)
        .padding(.horizontal, 16)
        .padding(.top, 16)
        .padding(.bottom, 8)
        .frame(maxWidth: .infinity, alignment: .leading)
        .clipped()
        // Pannello di vetro fino al bordo dello schermo; il bordo arancione resta per la sicurezza.
        .ariaBottomPanel(stroke: model.isSafety ? model.list.stepTint.opacity(0.35) : nil)
        .sensoryFeedback(trigger: model.doneCount) { old, new in model.feedback(from: old, to: new) }
        .modifier(AriaTaskQuestionAlert(model: model))
    }

    private func actions(_ task: AriaTaskList.Task) -> some View {
        HStack(spacing: 10) {
            // Al primo task non c'è niente a cui tornare: il pulsante non si mostra, "Fatto" prende tutta la riga.
            if model.previous != nil {
                Button { model.goBack() } label: {
                    Image(systemName: "chevron.left")
                        .font(.callout.weight(.semibold))
                        .foregroundStyle(.primary)
                        .frame(width: backSize, height: backSize)
                        .background(Color(.tertiarySystemFill), in: Circle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Back")
                .transition(.scale.combined(with: .opacity))
            }

            Button { model.complete(task) } label: {
                Label(model.isLastRemaining(task) ? LocalizedStringKey("Complete step") : "Done", systemImage: "checkmark")
                    .font(.headline)
                    .frame(maxWidth: .infinity, minHeight: 50)
            }
            .buttonStyle(.borderedProminent)
            .buttonBorderShape(.capsule)
            .tint(model.list.stepTint)
        }
        .animation(.snappy, value: model.previous == nil)
    }

    private func problemMenu(_ task: AriaTaskList.Task) -> some View {
        Menu {
            Button("Not clear", systemImage: "questionmark.circle") { model.assist(.unclear, task) }
            Button("Change it", systemImage: "pencil") { model.assist(.modify, task) }
            Button("It failed", systemImage: "xmark.octagon", role: .destructive) { model.assist(.failed, task) }
            Button("Ask about it", systemImage: "bubble.left") { model.ask(about: task) }
            Divider()
            Button("End procedure", systemImage: "door.left.hand.closed") { model.endProcedure() }
        } label: {
            Image(systemName: "exclamationmark.bubble")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.primary)
                .frame(width: menuSize, height: menuSize)
                .background(Color(.tertiarySystemFill), in: Circle())
                .contentShape(Circle())
        }
        .accessibilityLabel("Problem")
    }
}
