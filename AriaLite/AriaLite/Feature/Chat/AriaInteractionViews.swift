//
//  AriaInteractionViews.swift
//  AriaLite
//
//  Dove l'operatore risponde ad Aria: approvazione dei tool (con parametri
//  modificabili), conferma LOTO e checklist di procedura. Le domande guidate
//  sono in AriaElicitationPanel.swift.
//

import SwiftUI

// MARK: - Approvazione tool

/// interrupt-approval-card della web: ogni parametro semplice è modificabile;
/// se cambia qualcosa, "Approva con modifiche" manda decision "edit" con gli args completi.
struct AriaApprovalCard: View {
    let interrupt: AriaInterrupt
    var onDecide: (AriaResumeDecision) -> Void

    @State private var edited: [String: AriaJSON] = [:]

    private var original: [String: AriaJSON] { interrupt.args ?? [:] }
    private var isEdited: Bool { edited != original }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Label(AriaChatCopy.toolLabel(interrupt.name ?? ""), systemImage: "hand.raised.fill")
                    .font(.system(size: 15, weight: .semibold))
                Spacer()
                AriaBadge(text: String(localized: "awaiting approval"), tint: .orange)
            }
            if let warning = interrupt.warning, !warning.isEmpty {
                Text(AriaMarkdown.inline(warning)).font(.system(size: 13)).foregroundStyle(.orange)
            }

            ForEach(original.keys.sorted(), id: \.self) { key in
                argField(key)
            }

            HStack {
                Button("Reject", role: .destructive) { onDecide(.reject) }
                    .buttonStyle(.bordered)
                Spacer()
                Button(isEdited ? "Approve with changes" : "Approve") {
                    onDecide(isEdited ? .edit(edited) : .approve)
                }
                .buttonStyle(.borderedProminent)
            }
        }
        .padding(14)
        .background(Color.orange.opacity(0.07), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous).strokeBorder(Color.orange.opacity(0.35), lineWidth: 1))
        .onAppear { edited = original }
        .onChange(of: interrupt.interruptId) { edited = original }
    }

    @ViewBuilder
    private func argField(_ key: String) -> some View {
        let label = key.replacingOccurrences(of: "_", with: " ").capitalizedFirst
        switch edited[key] ?? original[key] ?? .null {
        case .bool(let value):
            Toggle(label, isOn: Binding(get: { value }, set: { edited[key] = .bool($0) }))
                .font(.system(size: 13))
        case .number(let value):
            VStack(alignment: .leading, spacing: 3) {
                Text(label).font(.system(size: 11, weight: .semibold)).foregroundStyle(.secondary)
                TextField(label, value: Binding(get: { value }, set: { edited[key] = .number($0) }), format: .number)
                    .keyboardType(.decimalPad)
                    .textFieldStyle(.roundedBorder)
            }
        case .string(let value):
            VStack(alignment: .leading, spacing: 3) {
                Text(label).font(.system(size: 11, weight: .semibold)).foregroundStyle(.secondary)
                TextField(label, text: Binding(get: { value }, set: { edited[key] = .string($0) }), axis: .vertical)
                    .lineLimit(1...5)
                    .textFieldStyle(.roundedBorder)
            }
        case .array(let items) where key == "moves":
            // Spostamenti di calendario: tabella in sola lettura.
            VStack(alignment: .leading, spacing: 4) {
                Text(label).font(.system(size: 11, weight: .semibold)).foregroundStyle(.secondary)
                ForEach(Array(items.enumerated()), id: \.offset) { _, move in
                    let id = (move["work_order_id"] ?? move["workOrderId"] ?? move["id"])?.stringValue ?? ""
                    let to = (move["due_date"] ?? move["dueDate"] ?? move["to"])?.stringValue ?? ""
                    Text(verbatim: "WO \(id)\(move["title"]?.stringValue.map { " · \($0)" } ?? ""): \(move["from"]?.stringValue.map { "\($0) → " } ?? "")\(to)")
                        .font(.system(size: 12))
                }
            }
        case .null:
            EmptyView()
        case let other:
            VStack(alignment: .leading, spacing: 3) {
                Text(label).font(.system(size: 11, weight: .semibold)).foregroundStyle(.secondary)
                Text(verbatim: other.compactDescription)
                    .font(.system(size: 11, design: .monospaced))
                    .foregroundStyle(.secondary)
                    .lineLimit(6)
            }
        }
    }
}

/// Riga che resta al posto della card dopo la decisione.
struct AriaInterruptOutcomeLine: View {
    let outcome: AriaInterruptOutcome

    var body: some View {
        let (text, icon, tint): (LocalizedStringKey, String, Color) = switch outcome {
        case .approved: ("Approved", "checkmark.circle.fill", .green)
        case .edited: ("Approved with changes", "checkmark.circle.fill", .green)
        case .rejected: ("Rejected", "xmark.circle.fill", .red)
        case .lotoConfirmed: ("LOTO confirmed", "lock.fill", .green)
        case .lotoDeclined: ("LOTO not confirmed", "lock.open.fill", .orange)
        }
        Label(text, systemImage: icon)
            .font(.system(size: 12, weight: .medium))
            .foregroundStyle(tint)
    }
}

// MARK: - LOTO

/// loto-confirm-dialog della web: blocca finché l'operatore non risponde.
struct AriaLotoSheet: View {
    let interrupt: AriaInterrupt
    var onDecide: (AriaResumeDecision) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            HStack(spacing: 10) {
                Image(systemName: "lock.shield.fill")
                    .font(.system(size: 26))
                    .foregroundStyle(.red)
                Text("Safety confirmation required")
                    .font(.system(size: 20, weight: .bold))
            }
            if let alarm = interrupt.alarmCode, !alarm.isEmpty {
                AriaBadge(text: "\(String(localized: "Alarm")): \(alarm)", tint: .red)
            }
            ScrollView {
                AriaMarkdownView(text: AriaAgentMessage.stripElicitBlock(interrupt.warning ?? ""))
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            VStack(spacing: 10) {
                Button {
                    onDecide(.loto(confirmed: true))
                } label: {
                    Text("I have performed LOTO").frame(maxWidth: .infinity).padding(.vertical, 6)
                }
                .buttonStyle(.borderedProminent)
                .tint(.red)
                Button {
                    onDecide(.loto(confirmed: false))
                } label: {
                    Text("Not yet").frame(maxWidth: .infinity).padding(.vertical, 6)
                }
                .buttonStyle(.bordered)
            }
        }
        .padding(24)
        .presentationDetents([.medium, .large])
        .interactiveDismissDisabled()
    }
}

// MARK: - Checklist di procedura

/// La checklist dello step (`aria.task_list`): spunte locali che finiscono nelle istruzioni,
/// e per ogni task la richiesta di aiuto ad Aria (non chiaro / da cambiare / fallito / domanda).
struct AriaTaskChecklistCard: View {
    let list: AriaTaskList
    let messageId: String
    let chat: AriaAgentChat
    var isLatest: Bool

    @State private var askingTask: AriaTaskList.Task?
    @State private var question = ""

    private var doneCount: Int { list.tasks.filter { chat.isTaskChecked($0, in: messageId) }.count }

    var body: some View {
        AriaCard(tint: list.isSafety ? .orange : .liteAccent) {
            HStack {
                Label(list.label, systemImage: list.isSafety ? "exclamationmark.shield.fill" : "list.bullet.clipboard")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(list.isSafety ? .orange : Color.liteAccent)
                Spacer()
                Text(verbatim: "\(doneCount)/\(list.tasks.count)")
                    .font(.system(size: 12, weight: .medium).monospacedDigit())
                    .foregroundStyle(.secondary)
            }
            Text(list.stepTitle).font(.system(size: 15, weight: .semibold))

            ForEach(list.tasks) { task in
                HStack(alignment: .top, spacing: 10) {
                    Button {
                        chat.toggleTask(task, in: messageId)
                    } label: {
                        Image(systemName: chat.isTaskChecked(task, in: messageId) ? "checkmark.circle.fill" : "circle")
                            .font(.system(size: 18))
                            .foregroundStyle(chat.isTaskChecked(task, in: messageId) ? .green : Color.liteAccent.opacity(0.5))
                    }
                    .buttonStyle(.plain)
                    .disabled(!isLatest)

                    VStack(alignment: .leading, spacing: 3) {
                        Text(AriaMarkdown.inline(task.text)).font(.system(size: 14))
                        if let mark = chat.taskMark(task, in: messageId) { markBadge(mark) }
                    }
                    Spacer(minLength: 0)

                    if isLatest {
                        Menu {
                            Button("Not clear", systemImage: "questionmark.circle") { chat.assist(.unclear, task: task, list: list, in: messageId) }
                            Button("Change it", systemImage: "pencil") { chat.assist(.modify, task: task, list: list, in: messageId) }
                            Button("It failed", systemImage: "xmark.octagon", role: .destructive) { chat.assist(.failed, task: task, list: list, in: messageId) }
                            Button("Ask about it", systemImage: "bubble.left") { askingTask = task }
                        } label: {
                            Image(systemName: "ellipsis.circle").foregroundStyle(.secondary)
                        }
                        .disabled(chat.isStreaming)
                    }
                }
            }

            if isLatest {
                Button("End procedure", systemImage: "door.left.hand.closed") { chat.endProcedure() }
                    .font(.system(size: 13, weight: .semibold))
                    .buttonStyle(.borderless)
                    .disabled(chat.isStreaming)
            }
        }
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

    private func markBadge(_ mark: String) -> some View {
        switch mark {
        case "failed": AriaBadge(text: String(localized: "Failed"), tint: .red)
        case "modify": AriaBadge(text: String(localized: "To change"), tint: .orange)
        default: AriaBadge(text: String(localized: "Not clear"), tint: .blue)
        }
    }
}
