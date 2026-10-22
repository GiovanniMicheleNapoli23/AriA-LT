//
//  AriaTaskChecklistCard.swift
//  AriaLite
//
//  Created by Giovanni Michele on 22/10/26.
//
//  La checklist dello step (`aria.task_list`) dentro una risposta: spunte locali che finiscono nelle
//  istruzioni, e per ogni task la richiesta di aiuto ad Aria (non chiaro / da cambiare / fallito / domanda).
//  Solo la checklist più recente si può toccare. La logica sta in AriaTaskStepViewModel.
//

import SwiftUI

struct AriaTaskChecklistCard: View {
    let list: AriaTaskList
    let messageId: String
    let chat: AriaAgentChat
    var isLatest: Bool

    var body: some View {
        AriaTaskChecklistCardContent(model: AriaTaskStepViewModel(chat: chat, list: list, messageId: messageId), isLatest: isLatest)
            // Il view model nasce con la lista: una revisione riparte da capo.
            .id(list)
    }
}

private struct AriaTaskChecklistCardContent: View {
    @State private var model: AriaTaskStepViewModel
    let isLatest: Bool

    init(model: @autoclosure () -> AriaTaskStepViewModel, isLatest: Bool) {
        _model = State(wrappedValue: model())
        self.isLatest = isLatest
    }

    var body: some View {
        AriaCard(tint: model.isSafety ? .orange : .liteAccent) {
            HStack {
                Label(model.list.label, systemImage: model.isSafety ? "exclamationmark.shield.fill" : "list.bullet.clipboard")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(model.isSafety ? .orange : Color.liteAccent)
                Spacer()
                Text(verbatim: "\(model.doneCount)/\(model.tasks.count)")
                    .font(.system(size: 12, weight: .medium).monospacedDigit())
                    .foregroundStyle(.secondary)
            }
            Text(model.list.stepTitle).font(.system(size: 15, weight: .semibold))

            ForEach(model.tasks) { task in
                HStack(alignment: .top, spacing: 10) {
                    Button { model.toggle(task) } label: {
                        Image(systemName: model.isChecked(task) ? "checkmark.circle.fill" : "circle")
                            .font(.system(size: 18))
                            .foregroundStyle(model.isChecked(task) ? .green : Color.liteAccent.opacity(0.5))
                    }
                    .buttonStyle(.plain)
                    .disabled(!isLatest)

                    VStack(alignment: .leading, spacing: 3) {
                        Text(AriaMarkdown.inline(task.text)).font(.system(size: 14))
                        if let mark = model.mark(task) { AriaTaskMarkBadge(mark: mark) }
                    }
                    Spacer(minLength: 0)

                    if isLatest {
                        Menu {
                            Button("Not clear", systemImage: "questionmark.circle") { model.assist(.unclear, task) }
                            Button("Change it", systemImage: "pencil") { model.assist(.modify, task) }
                            Button("It failed", systemImage: "xmark.octagon", role: .destructive) { model.assist(.failed, task) }
                            Button("Ask about it", systemImage: "bubble.left") { model.ask(about: task) }
                        } label: {
                            Image(systemName: "ellipsis.circle").foregroundStyle(.secondary)
                        }
                        .disabled(model.isStreaming)
                    }
                }
            }

            if isLatest {
                Button("End procedure", systemImage: "door.left.hand.closed") { model.endProcedure() }
                    .font(.system(size: 13, weight: .semibold))
                    .buttonStyle(.borderless)
                    .disabled(model.isStreaming)
            }
        }
        .sensoryFeedback(trigger: model.doneCount) { old, new in model.feedback(from: old, to: new) }
        .modifier(AriaTaskQuestionAlert(model: model))
    }
}
