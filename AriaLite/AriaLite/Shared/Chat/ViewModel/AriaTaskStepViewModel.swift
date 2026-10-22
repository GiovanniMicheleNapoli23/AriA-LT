//
//  AriaTaskStepViewModel.swift
//  AriaLite
//
//  Created by Giovanni Michele on 22/10/26.
//
//  La logica di uno step di procedura (`aria.task_list`), la stessa per il pannello in basso, la checklist
//  in chat e il menu "···": spunte, task in corso e precedente, esito dello step, aiuto su un task
//  (non chiaro / da cambiare / fallito / domanda) e fine procedura.
//  Nasce con una lista: una revisione della lista è un view model nuovo (identità della vista).
//

import Foundation
import Observation
import SwiftUI

@MainActor
@Observable
final class AriaTaskStepViewModel {
    let chat: AriaAgentChat
    let list: AriaTaskList
    let messageId: String

    /// L'esito dell'aiuto chiesto su un task.
    enum Mark: Equatable {
        case failed, modify, unclear

        init(_ raw: String) {
            switch raw {
            case "failed": self = .failed
            case "modify": self = .modify
            default: self = .unclear
            }
        }
    }

    /// Come sta uno step: un task segnalato conta più delle spunte (fallito > da cambiare > non chiaro), come nella web.
    enum Outcome: Equatable {
        case failed, toChange, notClear, completed, inProgress
    }

    // MARK: - State

    /// Il task su cui si sta scrivendo una domanda (alert).
    private(set) var askingTask: AriaTaskList.Task?
    var question = ""
    /// Direzione dell'animazione tra un task e l'altro.
    private(set) var forward = true
    /// Una riga dello storico aperta per vedere (e correggere) i task.
    private(set) var isExpanded = false

    init(chat: AriaAgentChat, list: AriaTaskList, messageId: String) {
        self.chat = chat
        self.list = list
        self.messageId = messageId
    }

    // MARK: - Derived

    var tasks: [AriaTaskList.Task] { list.tasks }
    var isSafety: Bool { list.isSafety }
    var isStreaming: Bool { chat.isStreaming }
    var doneCount: Int { list.tasks.filter { chat.isTaskChecked($0, in: messageId) }.count }
    var isDone: Bool { doneCount == list.tasks.count }

    /// Il task in corso: il primo non spuntato.
    var next: AriaTaskList.Task? { list.tasks.first { !chat.isTaskChecked($0, in: messageId) } }

    /// Il task prima di quello corrente (spuntato per forza: il corrente è il primo non spuntato).
    var previous: AriaTaskList.Task? {
        guard let next, let i = list.tasks.firstIndex(where: { $0.id == next.id }), i > 0 else { return nil }
        return list.tasks[i - 1]
    }

    func isChecked(_ task: AriaTaskList.Task) -> Bool {
        chat.isTaskChecked(task, in: messageId)
    }

    func isNext(_ task: AriaTaskList.Task) -> Bool {
        task.id == next?.id
    }

    func mark(_ task: AriaTaskList.Task) -> Mark? {
        chat.taskMark(task, in: messageId).map(Mark.init)
    }

    /// Spuntarlo completa lo step.
    func isLastRemaining(_ task: AriaTaskList.Task) -> Bool {
        list.tasks.filter { !chat.isTaskChecked($0, in: messageId) }.count == 1 && next?.id == task.id
    }

    var outcome: Outcome {
        let marks = Set(list.tasks.compactMap { mark($0) })
        if marks.contains(.failed) { return .failed }
        if marks.contains(.modify) { return .toChange }
        if marks.contains(.unclear) { return .notClear }
        return isDone ? .completed : .inProgress
    }

    var isAsking: Bool {
        get { askingTask != nil }
        set { if !newValue { askingTask = nil } }
    }

    /// Un task spuntato è un colpo deciso, l'ultimo è il successo della checklist; togliere una spunta è più leggero.
    static func feedback(from old: Int, to new: Int, of total: Int) -> SensoryFeedback? {
        guard new != old else { return nil }
        if new < old { return .selection }
        return new == total ? .success : .impact(weight: .medium)
    }

    func feedback(from old: Int, to new: Int) -> SensoryFeedback? {
        Self.feedback(from: old, to: new, of: list.tasks.count)
    }

    // MARK: - Actions

    func toggle(_ task: AriaTaskList.Task) {
        chat.toggleTask(task, in: messageId)
    }

    /// "Fatto": spunta il task in corso e passa al successivo.
    func complete(_ task: AriaTaskList.Task) {
        forward = true
        chat.toggleTask(task, in: messageId)
    }

    /// "Indietro": toglie la spunta al task precedente, che torna in corso.
    func goBack() {
        guard let previous else { return }
        forward = false
        chat.toggleTask(previous, in: messageId)
    }

    func assist(_ action: AriaStepAssist, _ task: AriaTaskList.Task) {
        chat.assist(action, task: task, list: list, in: messageId)
    }

    func ask(about task: AriaTaskList.Task) {
        askingTask = task
    }

    func sendQuestion() {
        if let task = askingTask, !question.isEmpty {
            chat.assist(.ask, task: task, list: list, in: messageId, custom: question)
        }
        question = ""
    }

    func cancelQuestion() {
        question = ""
    }

    func endProcedure() {
        chat.endProcedure()
    }

    func toggleExpanded() {
        isExpanded.toggle()
    }
}
