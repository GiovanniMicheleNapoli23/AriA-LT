//
//  AriaChatOptionsSheet.swift
//  AriaLite
//
//  Created by Giovanni Michele on 26/09/26.
//
//  Il menu "···" della chat: la procedura della sessione (il "Task & Event Rail" della web).
//  Lo step corrente è la scheda in evidenza, con i suoi task sempre visibili e il prossimo da fare
//  evidenziato; gli step precedenti sono righe compatte con il loro esito, da aprire al bisogno.
//  In fondo la lingua di dettatura e le azioni sulla sessione (chiusura intervento, fine procedura).
//

import SwiftUI

struct AriaChatOptionsSheet: View {
    let chat: AriaAgentChat
    /// Chiusura intervento: la presenta chi apre il foglio, dopo averlo chiuso.
    var onCloseOut: (() -> Void)?

    @Environment(\.dismiss) private var dismiss
    @AppStorage(AriaDictation.languageKey) private var dictationLanguage = AriaDictation.automatic
    @State private var confirmingEnd = false

    var body: some View {
        let steps = chat.sessionTaskLists
        NavigationStack {
            List {
                if let current = steps.first {
                    Section("Current step") {
                        AriaCurrentStepCard(list: current.list, messageId: current.messageId, chat: chat)
                            .listRowInsets(EdgeInsets(top: 14, leading: 14, bottom: 8, trailing: 14))
                    }
                    if steps.count > 1 {
                        Section("Previous steps") {
                            ForEach(steps.dropFirst(), id: \.messageId) { step in
                                AriaPastStepRow(list: step.list, messageId: step.messageId, chat: chat)
                            }
                        }
                    }
                } else {
                    Section {
                        ContentUnavailableView("No procedure yet", systemImage: "list.bullet.clipboard",
                                               description: Text("The steps Aria gives you in this chat will appear here."))
                    }
                }

                Section("Microphone") {
                    Picker(selection: $dictationLanguage) {
                        Text("Automatic").tag(AriaDictation.automatic)
                        ForEach(AriaDictation.languages) { language in
                            Text(verbatim: language.label).tag(language.code)
                        }
                    } label: {
                        Label("Dictation language", systemImage: "mic")
                    }
                    .pickerStyle(.navigationLink)
                }

                if onCloseOut != nil || !steps.isEmpty {
                    Section {
                        if let onCloseOut {
                            Button("Close out intervention", systemImage: "checkmark.seal") {
                                dismiss()
                                onCloseOut()
                            }
                            .disabled(chat.messages.isEmpty || chat.isStreaming)
                        }
                        if !steps.isEmpty {
                            Button("End procedure", systemImage: "door.left.hand.closed", role: .destructive) {
                                confirmingEnd = true
                            }
                            .disabled(chat.isStreaming || chat.pendingInterrupt != nil)
                        }
                    }
                }
            }
            .navigationTitle("Procedure")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
            .confirmationDialog("End the procedure?", isPresented: $confirmingEnd, titleVisibility: .visible) {
                Button("End procedure", role: .destructive) {
                    dismiss()
                    chat.endProcedure()
                }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("Aria will ask you to confirm before closing it.")
            }
        }
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
    }
}

// MARK: - Esito di uno step

/// Come sta uno step: un task segnalato conta più delle spunte (fallito > da cambiare > non chiaro), come nella web.
private struct AriaStepStatus {
    let text: String
    let tint: Color
    let symbol: String
    let isDone: Bool

    init(list: AriaTaskList, messageId: String, chat: AriaAgentChat) {
        let marks = Set(list.tasks.compactMap { chat.taskMark($0, in: messageId) })
        let done = list.tasks.filter { chat.isTaskChecked($0, in: messageId) }.count
        isDone = done == list.tasks.count
        if marks.contains("failed") {
            (text, tint, symbol) = (String(localized: "Failed"), .red, "xmark.octagon.fill")
        } else if marks.contains("modify") {
            (text, tint, symbol) = (String(localized: "To change"), .orange, "pencil.circle.fill")
        } else if marks.contains("unclear") {
            (text, tint, symbol) = (String(localized: "Not clear"), .blue, "questionmark.circle.fill")
        } else if isDone {
            (text, tint, symbol) = (String(localized: "Completed"), .green, "checkmark.circle.fill")
        } else {
            (text, tint, symbol) = (String(localized: "In progress"), .secondary, "circle.dotted")
        }
    }
}

private func ariaStepTint(_ list: AriaTaskList) -> Color { list.isSafety ? .orange : .accentColor }

// MARK: - Step corrente

/// La scheda dello step in corso: etichetta e titolo, avanzamento a segmenti (come nel pannello della chat)
/// e tutti i task. Il prossimo da fare ha lo sfondo colorato.
private struct AriaCurrentStepCard: View {
    let list: AriaTaskList
    let messageId: String
    let chat: AriaAgentChat

    private var tint: Color { ariaStepTint(list) }
    private var doneCount: Int { list.tasks.filter { chat.isTaskChecked($0, in: messageId) }.count }
    private var nextTask: AriaTaskList.Task? { list.tasks.first { !chat.isTaskChecked($0, in: messageId) } }
    private var status: AriaStepStatus { AriaStepStatus(list: list, messageId: messageId, chat: chat) }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            header
            progress
            VStack(spacing: 2) {
                ForEach(list.tasks) { task in
                    AriaTaskRow(task: task, list: list, messageId: messageId, chat: chat, isNext: task.id == nextTask?.id)
                }
            }
            .padding(.horizontal, -10)
        }
        .padding(.vertical, 4)
        .sensoryFeedback(trigger: doneCount) { old, new in ariaTaskFeedback(from: old, to: new, of: list.tasks.count) }
    }

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
                    .font(.system(size: 17, weight: .semibold))
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 4)
            // "In corso" è lo stato normale, non serve dirlo: si segnala solo l'eccezione o il traguardo.
            if status.symbol != "circle.dotted" { AriaBadge(text: status.text, tint: status.tint) }
        }
    }

    private var progress: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 4) {
                ForEach(list.tasks) { task in
                    Capsule()
                        .fill(segmentColor(task))
                        .frame(height: 4)
                }
            }
            .animation(.snappy, value: doneCount)
            Text("\(doneCount) of \(list.tasks.count) tasks done")
                .font(.system(size: 12, weight: .medium).monospacedDigit())
                .foregroundStyle(.secondary)
                .contentTransition(.numericText())
        }
        .accessibilityElement(children: .combine)
    }

    private func segmentColor(_ task: AriaTaskList.Task) -> Color {
        if chat.isTaskChecked(task, in: messageId) { return tint }
        if task.id == nextTask?.id { return tint.opacity(0.35) }
        return Color(.tertiarySystemFill)
    }
}

// MARK: - Step precedente

/// Una riga compatta: l'icona dice l'esito a colpo d'occhio; si apre per vedere (e correggere) i task.
private struct AriaPastStepRow: View {
    let list: AriaTaskList
    let messageId: String
    let chat: AriaAgentChat

    @State private var isExpanded = false

    private var status: AriaStepStatus { AriaStepStatus(list: list, messageId: messageId, chat: chat) }
    private var doneCount: Int { list.tasks.filter { chat.isTaskChecked($0, in: messageId) }.count }

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Button {
                withAnimation(.snappy) { isExpanded.toggle() }
            } label: {
                HStack(spacing: 12) {
                    Image(systemName: status.symbol)
                        .font(.system(size: 22))
                        .foregroundStyle(status.tint)
                        .frame(width: 28)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(list.label)
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundStyle(ariaStepTint(list))
                        Text(list.stepTitle)
                            .font(.system(size: 15, weight: .medium))
                            .foregroundStyle(.primary)
                            .multilineTextAlignment(.leading)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    Text(verbatim: "\(doneCount)/\(list.tasks.count)")
                        .font(.system(size: 13, weight: .medium).monospacedDigit())
                        .foregroundStyle(.secondary)
                    Image(systemName: "chevron.right")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(.tertiary)
                        .rotationEffect(.degrees(isExpanded ? 90 : 0))
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityValue(Text(status.text))
            .accessibilityAddTraits(.isHeader)

            if isExpanded {
                VStack(spacing: 2) {
                    ForEach(list.tasks) { task in
                        AriaTaskRow(task: task, list: list, messageId: messageId, chat: chat, isNext: false)
                    }
                }
                .padding(.horizontal, -10)
                .transition(.opacity)
            }
        }
        .padding(.vertical, 4)
        .sensoryFeedback(trigger: doneCount) { old, new in ariaTaskFeedback(from: old, to: new, of: list.tasks.count) }
    }
}

// MARK: - Task

/// Un task: il cerchio si spunta con un tocco (tutta la riga è il bersaglio). Fatto = grigio e barrato.
private struct AriaTaskRow: View {
    let task: AriaTaskList.Task
    let list: AriaTaskList
    let messageId: String
    let chat: AriaAgentChat
    /// Il prossimo task da fare: lo sfondo lo distingue dagli altri.
    let isNext: Bool

    private var tint: Color { ariaStepTint(list) }

    var body: some View {
        let checked = chat.isTaskChecked(task, in: messageId)
        Button {
            withAnimation(.snappy) { chat.toggleTask(task, in: messageId) }
        } label: {
            HStack(alignment: .top, spacing: 12) {
                Image(systemName: checked ? "checkmark.circle.fill" : "circle")
                    .font(.system(size: 22))
                    .foregroundStyle(checked ? Color.green : (isNext ? tint : Color.secondary.opacity(0.6)))
                    .contentTransition(.symbolEffect(.replace))
                    .frame(width: 28)
                VStack(alignment: .leading, spacing: 4) {
                    Text(AriaMarkdown.inline(task.text))
                        .font(.system(size: 15))
                        .foregroundStyle(checked ? .secondary : .primary)
                        .strikethrough(checked, color: .secondary)
                        .multilineTextAlignment(.leading)
                        .fixedSize(horizontal: false, vertical: true)
                    if let mark = chat.taskMark(task, in: messageId) { ariaTaskMarkBadge(mark) }
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
        .accessibilityAddTraits(checked ? .isSelected : [])
    }
}
