//
//  AriaChatOptionsSheet.swift
//  AriaLite
//
//  Il menu "···" della chat: lo storico della procedura della sessione (il "Task & Event Rail"
//  della web: step corrente e step precedenti con il loro esito, task spuntabili), la lingua
//  di dettatura del microfono e le azioni sulla sessione (chiusura intervento, fine procedura).
//

import SwiftUI

struct AriaChatOptionsSheet: View {
    let chat: AriaAgentChat
    /// Chiusura intervento: la presenta chi apre il foglio, dopo averlo chiuso.
    var onCloseOut: (() -> Void)?

    @Environment(\.dismiss) private var dismiss
    @AppStorage(AriaDictation.languageKey) private var dictationLanguage = AriaDictation.automatic

    var body: some View {
        let steps = chat.sessionTaskLists
        NavigationStack {
            List {
                if let current = steps.first {
                    Section("Current step") {
                        AriaStepHistoryRow(list: current.list, messageId: current.messageId, chat: chat, expanded: true)
                    }
                    if steps.count > 1 {
                        Section("Previous steps") {
                            ForEach(steps.dropFirst(), id: \.messageId) { step in
                                AriaStepHistoryRow(list: step.list, messageId: step.messageId, chat: chat, expanded: false)
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
                    Picker("Dictation language", selection: $dictationLanguage) {
                        Text("Automatic").tag(AriaDictation.automatic)
                        ForEach(AriaDictation.languages) { language in
                            Text(verbatim: language.label).tag(language.code)
                        }
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
                                dismiss()
                                chat.endProcedure()
                            }
                            .disabled(chat.isStreaming || chat.pendingInterrupt != nil)
                        }
                    }
                }
            }
            .navigationTitle("This chat")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
    }
}

// MARK: - Step

/// Uno step della sessione: etichetta, titolo (mai tagliato), esito e, aperto, i suoi task.
private struct AriaStepHistoryRow: View {
    let list: AriaTaskList
    let messageId: String
    let chat: AriaAgentChat

    @State private var isExpanded: Bool

    init(list: AriaTaskList, messageId: String, chat: AriaAgentChat, expanded: Bool) {
        self.list = list
        self.messageId = messageId
        self.chat = chat
        _isExpanded = State(initialValue: expanded)
    }

    private var tint: Color { list.isSafety ? .orange : .accentColor }
    private var doneCount: Int { list.tasks.filter { chat.isTaskChecked($0, in: messageId) }.count }

    /// Esito come nella web: un task segnalato conta più delle spunte (fallito > da cambiare > non chiaro).
    private var outcome: (text: String, tint: Color) {
        let marks = Set(list.tasks.compactMap { chat.taskMark($0, in: messageId) })
        if marks.contains("failed") { return (String(localized: "Failed"), .red) }
        if marks.contains("modify") { return (String(localized: "To change"), .orange) }
        if marks.contains("unclear") { return (String(localized: "Not clear"), .blue) }
        if doneCount == list.tasks.count { return (String(localized: "Completed"), .green) }
        return (String(localized: "In progress"), .secondary)
    }

    var body: some View {
        DisclosureGroup(isExpanded: $isExpanded) {
            ForEach(list.tasks) { task in
                let checked = chat.isTaskChecked(task, in: messageId)
                Button {
                    withAnimation(.snappy) { chat.toggleTask(task, in: messageId) }
                } label: {
                    HStack(alignment: .top, spacing: 12) {
                        Image(systemName: checked ? "checkmark.circle.fill" : "circle")
                            .font(.system(size: 20))
                            .foregroundStyle(checked ? Color.green : tint.opacity(0.5))
                            .contentTransition(.symbolEffect(.replace))
                        VStack(alignment: .leading, spacing: 4) {
                            Text(AriaMarkdown.inline(task.text))
                                .font(.system(size: 15))
                                .foregroundStyle(checked ? .secondary : .primary)
                                .strikethrough(checked, color: .secondary)
                                .fixedSize(horizontal: false, vertical: true)
                            if let mark = chat.taskMark(task, in: messageId) { ariaTaskMarkBadge(mark) }
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
            }
        } label: {
            HStack(alignment: .top, spacing: 10) {
                Image(systemName: list.isSafety ? "exclamationmark.shield.fill" : "list.bullet.clipboard")
                    .foregroundStyle(tint)
                    .padding(.top, 2)
                VStack(alignment: .leading, spacing: 4) {
                    Text(list.label)
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(tint)
                    Text(list.stepTitle)
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(.primary)
                        .fixedSize(horizontal: false, vertical: true)
                    HStack(spacing: 8) {
                        AriaBadge(text: outcome.text, tint: outcome.tint)
                        Text(verbatim: "\(doneCount)/\(list.tasks.count)")
                            .font(.system(size: 12, weight: .medium).monospacedDigit())
                            .foregroundStyle(.secondary)
                            .contentTransition(.numericText())
                    }
                }
            }
            .padding(.vertical, 2)
        }
        .tint(.secondary)
        .sensoryFeedback(trigger: doneCount) { old, new in ariaTaskFeedback(from: old, to: new, of: list.tasks.count) }
    }
}
