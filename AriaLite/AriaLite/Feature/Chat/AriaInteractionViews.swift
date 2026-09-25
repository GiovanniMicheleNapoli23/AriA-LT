//
//  AriaInteractionViews.swift
//  AriaLite
//
//  Dove l'operatore risponde ad Aria: approvazione dei tool (con parametri
//  modificabili), conferma LOTO, domande guidate e checklist di procedura.
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

// MARK: - Domande guidate

/// elicitation-panel della web: una o più domande (single / multi / rank), risposta libera,
/// valore richiesto da un'opzione (follow_up). Le risposte si compongono come fa la web.
struct AriaElicitationPanel: View {
    let elicitation: AriaElicitation
    var onSubmit: (_ text: String, _ details: [AriaElicitationAnswer]) -> Void

    @State private var stepIndex = 0
    @State private var answers: [String] = []
    @State private var details: [AriaElicitationAnswer] = []
    @State private var selected: [String] = []
    @State private var custom = ""
    @State private var customChosen = false
    @State private var followUpValue = ""

    private var steps: [AriaElicitationStep] { elicitation.allSteps }
    private var step: AriaElicitationStep { steps[min(stepIndex, steps.count - 1)] }
    private var isLast: Bool { stepIndex >= steps.count - 1 }

    private var followUpOption: AriaElicitationOption? {
        guard step.mode == "single", let id = selected.first else { return nil }
        return step.options.first { $0.id == id && $0.followUp != nil }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text(AriaMarkdown.inline(step.question))
                    .font(.system(size: 15, weight: .semibold))
                Spacer()
                if steps.count > 1 {
                    Text(verbatim: "\(stepIndex + 1)/\(steps.count)")
                        .font(.system(size: 12, weight: .medium).monospacedDigit())
                        .foregroundStyle(.secondary)
                }
            }

            ScrollView {
                VStack(spacing: 6) {
                    ForEach(step.options) { option in optionRow(option) }
                }
            }
            .frame(maxHeight: 260)
            .scrollBounceBehavior(.basedOnSize)

            if let option = followUpOption, let prompt = option.followUp {
                Text(prompt).font(.system(size: 13, weight: .medium))
                TextField("Or type your answer…", text: $followUpValue)
                    .textFieldStyle(.roundedBorder)
            } else if step.allowCustom {
                TextField("Or type your answer…", text: $custom, axis: .vertical)
                    .lineLimit(1...3)
                    .textFieldStyle(.roundedBorder)
                    .onChange(of: custom) { _, value in
                        // Risposta scritta e opzione non possono essere entrambe la risposta (single).
                        customChosen = !value.trimmingCharacters(in: .whitespaces).isEmpty
                        if customChosen, step.mode == "single" { selected = [] }
                    }
            }

            HStack {
                Spacer()
                Button(isLast ? "Send" : "Next") { advance() }
                    .buttonStyle(.borderedProminent)
                    .disabled(currentAnswer().isEmpty)
            }
        }
        .padding(14)
        .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 18, style: .continuous).strokeBorder(Color.liteAccent.opacity(0.25), lineWidth: 1))
        .onChange(of: elicitation.id) { reset(all: true) }
    }

    private func optionRow(_ option: AriaElicitationOption) -> some View {
        let rank = selected.firstIndex(of: option.id)
        let isOn = rank != nil
        return Button {
            toggle(option)
        } label: {
            HStack(alignment: .top, spacing: 10) {
                Group {
                    if step.mode == "rank", let rank {
                        Text(verbatim: "\(rank + 1)")
                            .font(.system(size: 12, weight: .bold))
                            .foregroundStyle(.white)
                            .frame(width: 20, height: 20)
                            .background(Color.liteAccent, in: Circle())
                    } else {
                        Image(systemName: step.mode == "single"
                              ? (isOn ? "largecircle.fill.circle" : "circle")
                              : (isOn ? "checkmark.square.fill" : "square"))
                            .foregroundStyle(isOn ? Color.liteAccent : .secondary)
                            .frame(width: 20, height: 20)
                    }
                }
                VStack(alignment: .leading, spacing: 2) {
                    Text(option.label)
                        .font(.system(size: 14, weight: isOn ? .semibold : .regular))
                        .foregroundStyle(.primary)
                    if let description = option.description, !description.isEmpty {
                        Text(description).font(.system(size: 12)).foregroundStyle(.secondary)
                    }
                }
                Spacer(minLength: 0)
            }
            .padding(10)
            .background(isOn ? Color.liteAccent.opacity(0.08) : Color.clear, in: RoundedRectangle(cornerRadius: 12))
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    private func toggle(_ option: AriaElicitationOption) {
        customChosen = false
        custom = ""
        if step.mode == "single" {
            selected = selected.first == option.id ? [] : [option.id]
            followUpValue = ""
        } else if let i = selected.firstIndex(of: option.id) {
            selected.remove(at: i)
        } else {
            selected.append(option.id)
        }
    }

    /// buildAnswer della web.
    private func currentAnswer() -> String {
        let typed = customChosen ? custom.trimmingCharacters(in: .whitespacesAndNewlines) : ""
        let picked = selected.compactMap { id in step.options.first { $0.id == id }?.label }
        if let option = followUpOption {
            let value = followUpValue.trimmingCharacters(in: .whitespacesAndNewlines)
            return value.isEmpty ? "" : "\(option.label): \(value)"
        }
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

    private func advance() {
        let answer = currentAnswer()
        guard !answer.isEmpty else { return }
        let chosen = selected.first.flatMap { id in step.options.first { $0.id == id } }
        answers.append(answer)
        details.append(AriaElicitationAnswer(key: step.key, value: chosen?.value ?? chosen?.id, text: answer,
                                             custom: customChosen ? custom : followUpValue, file: step.file))
        if isLast {
            onSubmit(Self.assemble(steps: steps, answers: answers, intro: elicitation.assembly?.intro), details)
            reset(all: true)
        } else {
            stepIndex += 1
            reset(all: false)
        }
    }

    private func reset(all: Bool) {
        if all {
            stepIndex = 0
            answers = []
            details = []
        }
        selected = []
        custom = ""
        customChosen = false
        followUpValue = ""
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
                Button("End procedure", systemImage: "flag.checkered") { chat.endProcedure() }
                    .font(.system(size: 13, weight: .semibold))
                    .buttonStyle(.borderless)
                    .disabled(chat.isStreaming)
            }
        }
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
