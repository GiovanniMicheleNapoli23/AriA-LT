//
//  AriaElicitationViewModel.swift
//  AriaLite
//
//  Created by Giovanni Michele on 22/10/26.
//
//  La logica di una domanda guidata: passi, scelta singola / multipla / classifica, "Altra risposta",
//  valore richiesto da un'opzione, motivo di fine procedura, risposta di ogni passo e turno finale.
//  Nasce con una domanda: per un'altra domanda il pannello ne crea uno nuovo (identità della vista).
//

import Foundation
import Observation

@MainActor
@Observable
final class AriaElicitationViewModel {
    let elicitation: AriaElicitation
    /// Riceve il turno composto e le risposte dei singoli passi quando si risponde all'ultimo.
    private let onSubmit: (_ text: String, _ details: [AriaElicitationAnswer]) -> Void

    // MARK: - State

    private(set) var stepIndex = 0
    private var answers: [String?] = []
    private var details: [AriaElicitationAnswer?] = []
    private(set) var selected: [String] = []
    var custom = "" {
        // Nella scelta singola la risposta scritta sostituisce l'opzione.
        didSet { if isSingle, !custom.trimmingCharacters(in: .whitespaces).isEmpty { selected = [] } }
    }
    private(set) var writingCustom = false
    private(set) var followUp: AriaElicitationOption?
    var followUpValue = ""
    /// Conferma di fine procedura: il motivo scelto (obbligatorio per chiudere) e le note.
    var closureReason: AriaClosureReason?
    var closureDetails = ""
    /// Direzione dell'animazione tra un passo e l'altro.
    private(set) var forward = true
    /// Cresce a ogni risposta salvata (passo o turno): la vista chiude la tastiera.
    private(set) var commits = 0

    init(elicitation: AriaElicitation, onSubmit: @escaping (_ text: String, _ details: [AriaElicitationAnswer]) -> Void) {
        self.elicitation = elicitation
        self.onSubmit = onSubmit
    }

    // MARK: - Derived

    var steps: [AriaElicitationStep] { elicitation.allSteps }
    var step: AriaElicitationStep { steps[min(stepIndex, steps.count - 1)] }
    var isLast: Bool { stepIndex >= steps.count - 1 }
    var isSingle: Bool { step.mode != "multi" && step.mode != "rank" }
    var isRank: Bool { step.mode == "rank" }
    var canGoBack: Bool { followUp != nil || stepIndex > 0 }
    /// Cambia a ogni passo o valore richiesto: il contenuto del pannello scorre di lato.
    var pageID: String { "\(stepIndex)-\(followUp?.id ?? "")" }

    private var typed: String { writingCustom ? custom.trimmingCharacters(in: .whitespacesAndNewlines) : "" }
    var hasTypedAnswer: Bool { !typed.isEmpty }

    /// Ha scelto di terminare la procedura: "No, continua" non chiede niente e non aspetta un motivo.
    var endingProcedure: Bool {
        guard elicitation.isClosureConfirmation, isSingle,
              let id = selected.first, let option = step.options.first(where: { $0.id == id }) else { return false }
        return option.value == "end"
    }

    /// Chiudere senza motivo lascia un buco che nessuno può colmare dopo: l'invio aspetta la scelta.
    var closureReady: Bool { !endingProcedure || closureReason != nil }

    var canSubmitFollowUp: Bool { !followUpValue.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }

    /// Scelta multipla / classifica: il pulsante sotto la lista si accende con almeno una risposta.
    var canSubmitSet: Bool { !currentAnswer().isEmpty }

    func rank(of option: AriaElicitationOption) -> Int? {
        selected.firstIndex(of: option.id)
    }

    func isSelected(_ option: AriaElicitationOption) -> Bool {
        selected.contains(option.id)
    }

    /// La risposta del passo dalle opzioni scelte e dal testo scritto (buildAnswer della web).
    func currentAnswer() -> String {
        let picked = selected.compactMap { id in step.options.first { $0.id == id }?.label }
        if endingProcedure, let label = picked.first {
            return AriaElicitationTurn.closureAnswer(label: label, reason: closureReason?.rawValue ?? "", details: closureDetails)
        }
        return AriaElicitationTurn.answer(mode: step.mode, picked: picked, typed: typed)
    }

    // MARK: - Actions

    func pick(_ option: AriaElicitationOption) {
        guard isSingle else {
            if let i = selected.firstIndex(of: option.id) { selected.remove(at: i) } else { selected.append(option.id) }
            return
        }
        // Opzione e risposta scritta non possono essere entrambe la risposta (il testo resta, se si riapre).
        writingCustom = false
        // Un'opzione che promette un valore apre il campo, invece di mandare la promessa come risposta.
        if option.followUp != nil {
            selected = [option.id]
            followUpValue = ""
            forward = true
            followUp = option
            return
        }
        // Si seleziona soltanto (un altro tocco deseleziona): la risposta parte con Invia.
        selected = selected == [option.id] ? [] : [option.id]
    }

    /// "Altra risposta" diventa un campo. Riaperto con del testo già scritto: nella scelta singola è quello la risposta.
    func startCustomAnswer() {
        writingCustom = true
        if isSingle, !custom.trimmingCharacters(in: .whitespaces).isEmpty { selected = [] }
    }

    func clearSelection() {
        selected = []
    }

    func submit() {
        guard closureReady else { return }
        commit(currentAnswer())
    }

    /// Dal campo "Altra risposta" l'invio della tastiera manda solo nella scelta singola.
    func submitFromKeyboard() {
        if isSingle { submit() }
    }

    func submitFollowUp() {
        let value = followUpValue.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let option = followUp, !value.isEmpty else { return }
        commit("\(option.label): \(value)", typed: value)
    }

    func goBack() {
        if followUp != nil {
            forward = false
            followUp = nil
            selected = []
            followUpValue = ""
        } else if stepIndex > 0 {
            forward = false
            stepIndex -= 1
            clearInputs()
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
        commits += 1

        if isLast {
            let filled = answers.map { $0 ?? "" }
            onSubmit(AriaElicitationTurn.assemble(steps: steps, answers: filled, intro: elicitation.assembly?.intro),
                     details.compactMap { $0 })
            resetAll()
        } else {
            forward = true
            stepIndex += 1
            clearInputs()
        }
    }

    private func clearInputs() {
        closureReason = nil
        closureDetails = ""
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
}
