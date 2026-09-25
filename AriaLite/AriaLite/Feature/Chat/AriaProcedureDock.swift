//
//  AriaProcedureDock.swift
//  AriaLite
//
//  Quando Aria manda una checklist insieme a una domanda, in basso non c'è la domanda
//  ma la procedura: un task alla volta, "Fatto" per spuntarlo, "Indietro" per tornare al
//  task prima, e in alto il menu per chiedere aiuto su quel task. Finita la checklist
//  compare la domanda di Aria.
//

import SwiftUI

struct AriaProcedureDock: View {
    let list: AriaTaskList
    let messageId: String
    let chat: AriaAgentChat

    @State private var askingTask: AriaTaskList.Task?
    @State private var question = ""
    /// Direzione dell'animazione tra un task e l'altro.
    @State private var forward = true

    private var doneCount: Int { list.tasks.filter { chat.isTaskChecked($0, in: messageId) }.count }
    private var next: AriaTaskList.Task? { list.tasks.first { !chat.isTaskChecked($0, in: messageId) } }
    /// Il task prima di quello corrente (spuntato per forza: il corrente è il primo non spuntato).
    private var previous: AriaTaskList.Task? {
        guard let next, let i = list.tasks.firstIndex(where: { $0.id == next.id }), i > 0 else { return nil }
        return list.tasks[i - 1]
    }
    private var tint: Color { list.isSafety ? .orange : .accentColor }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            header
            segments

            if let task = next {
                // Il task è l'azione da fare adesso: è il testo più in evidenza del pannello.
                VStack(alignment: .leading, spacing: 6) {
                    Text("Task \(task.index) of \(list.tasks.count)")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(.secondary)
                    ScrollView {
                        Text(AriaMarkdown.inline(task.text))
                            .font(.system(size: 17))
                            .lineSpacing(3)
                            .foregroundStyle(.primary)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    // Alto quanto il testo; scorre solo se il task è lunghissimo.
                    .frame(maxHeight: 220)
                    .fixedSize(horizontal: false, vertical: true)
                    .scrollBounceBehavior(.basedOnSize)
                    if let mark = chat.taskMark(task, in: messageId) { ariaTaskMarkBadge(mark) }
                }
                .id(task.id)
                .transition(.asymmetric(insertion: .move(edge: forward ? .trailing : .leading).combined(with: .opacity),
                                        removal: .move(edge: forward ? .leading : .trailing).combined(with: .opacity)))

                actions(task)
            }

            Label("Complete the steps to answer Aria's question", systemImage: "lock.fill")
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(.tertiary)
                .frame(maxWidth: .infinity)
        }
        .padding(.horizontal, 16)
        .padding(.top, 16)
        .padding(.bottom, 8)
        .frame(maxWidth: .infinity, alignment: .leading)
        .clipped()
        // Pannello di vetro fino al bordo dello schermo; il bordo arancione resta per la sicurezza.
        .ariaBottomPanel(stroke: list.isSafety ? tint.opacity(0.35) : nil)
        .sensoryFeedback(trigger: doneCount) { old, new in ariaTaskFeedback(from: old, to: new, of: list.tasks.count) }
        .alert("Ask about this step", isPresented: Binding(get: { askingTask != nil }, set: { if !$0 { askingTask = nil } })) {
            TextField("Your question", text: $question)
            Button("Cancel", role: .cancel) { question = "" }
            Button("Send") {
                if let task = askingTask, !question.isEmpty {
                    chat.assist(.ask, task: task, list: list, in: messageId, custom: question)
                }
                question = ""
            }
        }
    }

    /// Lo step è il contesto del task: etichetta colorata sopra, titolo sotto (va a capo, non si taglia mai).
    private var header: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: list.isSafety ? "exclamationmark.shield.fill" : "list.bullet.clipboard.fill")
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(tint)
                .frame(width: 34, height: 34)
                .background(tint.opacity(0.14), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
            VStack(alignment: .leading, spacing: 2) {
                Text(list.label.uppercased())
                    .font(.system(size: 11, weight: .bold))
                    .tracking(0.6)
                    .foregroundStyle(tint)
                Text(list.stepTitle)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(.primary.opacity(0.85))
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 4)
            if let task = next { problemMenu(task) }
        }
    }

    /// Un segmento per task: pieno se fatto, evidenziato quello in corso. Dice insieme quanti sono e dove si è.
    private var segments: some View {
        HStack(spacing: 4) {
            ForEach(list.tasks) { task in
                Capsule()
                    .fill(segmentColor(task))
                    .frame(height: 4)
            }
        }
        .animation(.snappy, value: doneCount)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text("\(doneCount) of \(list.tasks.count) tasks done"))
    }

    private func segmentColor(_ task: AriaTaskList.Task) -> Color {
        if chat.isTaskChecked(task, in: messageId) { return tint }
        if task.id == next?.id { return tint.opacity(0.35) }
        return Color(.tertiarySystemFill)
    }

    private func actions(_ task: AriaTaskList.Task) -> some View {
        HStack(spacing: 10) {
            // Al primo task non c'è niente a cui tornare: il pulsante non si mostra, "Fatto" prende tutta la riga.
            if let previous {
                Button {
                    forward = false
                    withAnimation(.snappy) { chat.toggleTask(previous, in: messageId) }
                } label: {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(.primary)
                        .frame(width: 50, height: 50)
                        .background(Color(.tertiarySystemFill), in: Circle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Back")
                .transition(.scale.combined(with: .opacity))
            }

            Button {
                forward = true
                withAnimation(.snappy) { chat.toggleTask(task, in: messageId) }
            } label: {
                Label(isLastTask(task) ? LocalizedStringKey("Complete step") : "Done", systemImage: "checkmark")
                    .font(.system(size: 17, weight: .semibold))
                    .frame(maxWidth: .infinity, minHeight: 50)
            }
            .buttonStyle(.borderedProminent)
            .buttonBorderShape(.capsule)
            .tint(tint)
        }
        .animation(.snappy, value: previous == nil)
    }

    private func isLastTask(_ task: AriaTaskList.Task) -> Bool {
        list.tasks.filter { !chat.isTaskChecked($0, in: messageId) }.count == 1 && next?.id == task.id
    }

    private func problemMenu(_ task: AriaTaskList.Task) -> some View {
        Menu {
            Button("Not clear", systemImage: "questionmark.circle") { chat.assist(.unclear, task: task, list: list, in: messageId) }
            Button("Change it", systemImage: "pencil") { chat.assist(.modify, task: task, list: list, in: messageId) }
            Button("It failed", systemImage: "xmark.octagon", role: .destructive) { chat.assist(.failed, task: task, list: list, in: messageId) }
            Button("Ask about it", systemImage: "bubble.left") { askingTask = task }
            Divider()
            Button("End procedure", systemImage: "door.left.hand.closed") { chat.endProcedure() }
        } label: {
            Image(systemName: "exclamationmark.bubble")
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(.primary)
                .frame(width: 34, height: 34)
                .background(Color(.tertiarySystemFill), in: Circle())
                .contentShape(Circle())
        }
        .accessibilityLabel("Problem")
    }
}

/// Un task spuntato è un colpo deciso, l'ultimo è il successo della checklist; togliere una spunta è più leggero.
func ariaTaskFeedback(from old: Int, to new: Int, of total: Int) -> SensoryFeedback? {
    guard new != old else { return nil }
    if new < old { return .selection }
    return new == total ? .success : .impact(weight: .medium)
}

/// L'esito dell'aiuto chiesto su un task (non chiaro / da cambiare / fallito).
@ViewBuilder
func ariaTaskMarkBadge(_ mark: String) -> some View {
    switch mark {
    case "failed": AriaBadge(text: String(localized: "Failed"), tint: .red)
    case "modify": AriaBadge(text: String(localized: "To change"), tint: .orange)
    default: AriaBadge(text: String(localized: "Not clear"), tint: .blue)
    }
}
