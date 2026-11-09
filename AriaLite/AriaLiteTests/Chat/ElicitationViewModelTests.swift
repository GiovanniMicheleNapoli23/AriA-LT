//
//  ElicitationViewModelTests.swift
//  AriaLiteTests
//
//  Created by Giovanni Michele on 22/10/26.
//
//  La logica delle domande guidate senza interfaccia: scelta singola che si seleziona e si deseleziona,
//  scelta multipla e classifica, "Altra risposta", valore richiesto da un'opzione, motivo di fine procedura,
//  passi in catena e turno composto come fa la web.
//

import Foundation
import Testing
@testable import AriaLite

@MainActor
struct ElicitationViewModelTests {
    /// Le risposte inviate dall'ultimo passo.
    private final class Sent {
        var text: String?
        var details: [AriaElicitationAnswer] = []
    }

    private func decode(_ json: String) throws -> AriaElicitation {
        try JSONDecoder().decode(AriaElicitation.self, from: Data(json.utf8))
    }

    private func model(_ elicitation: AriaElicitation) -> (AriaElicitationViewModel, Sent) {
        let sent = Sent()
        let model = AriaElicitationViewModel(elicitation: elicitation) { text, details in
            sent.text = text
            sent.details = details
        }
        return (model, sent)
    }

    private let single = AriaElicitation(id: "q1", question: "Is the guard closed?", allowCustom: true, options: [
        AriaElicitationOption(id: "a", label: "Yes", description: nil, followUp: nil, value: "yes"),
        AriaElicitationOption(id: "b", label: "No", description: nil, followUp: nil, value: "no"),
        AriaElicitationOption(id: "c", label: "Other temperature", description: nil, followUp: "Which one?", value: nil),
    ])

    // MARK: Scelta singola

    @Test("Un tocco seleziona, un altro deseleziona; la risposta parte con Invia")
    func singleSelectToggles() {
        let (model, sent) = model(single)
        model.pick(single.options[0])
        #expect(model.selected == ["a"])
        model.pick(single.options[0])
        #expect(model.selected.isEmpty)
        model.pick(single.options[1])
        model.submit()
        #expect(sent.text == "No")
        #expect(sent.details.first?.value == "no")
    }

    @Test("La risposta scritta sostituisce l'opzione scelta")
    func customReplacesOption() {
        let (model, sent) = model(single)
        model.pick(single.options[0])
        model.startCustomAnswer()
        model.custom = "Half open"
        #expect(model.selected.isEmpty)
        #expect(model.hasTypedAnswer)
        model.submitFromKeyboard()
        #expect(sent.text == "Half open")
    }

    @Test("Un'opzione che chiede un valore apre il campo e manda «etichetta: valore»")
    func followUpOption() {
        let (model, sent) = model(single)
        model.pick(single.options[2])
        #expect(model.followUp?.id == "c")
        #expect(model.canGoBack)
        #expect(!model.canSubmitFollowUp)
        model.followUpValue = "  80 °C "
        model.submitFollowUp()
        #expect(sent.text == "Other temperature: 80 °C")
        #expect(sent.details.first?.custom == "80 °C")
    }

    @Test("Indietro da un valore richiesto torna alle opzioni senza selezione")
    func backFromFollowUp() {
        let (model, _) = model(single)
        model.pick(single.options[2])
        model.goBack()
        #expect(model.followUp == nil)
        #expect(model.selected.isEmpty)
        #expect(!model.forward)
    }

    // MARK: Multipla e classifica

    @Test("Scelta multipla: le etichette unite, più il testo aggiunto")
    func multiJoinsLabels() throws {
        let elicitation = try decode(#"{"id":"m","question":"Which lights?","mode":"multi","allow_custom":true,"options":[{"id":"r","label":"Red"},{"id":"g","label":"Green"}]}"#)
        let (model, sent) = model(elicitation)
        #expect(!model.canSubmitSet)
        model.pick(elicitation.options[1])
        model.pick(elicitation.options[0])
        model.startCustomAnswer()
        model.custom = "blinking"
        #expect(model.canSubmitSet)
        model.submit()
        #expect(sent.text == "Green, Red. blinking")
    }

    @Test("Classifica: l'ordine dei tocchi è la priorità")
    func rankKeepsOrder() throws {
        let elicitation = try decode(#"{"id":"k","question":"Order","mode":"rank","options":[{"id":"x","label":"Pump"},{"id":"y","label":"Valve"}]}"#)
        let (model, sent) = model(elicitation)
        model.pick(elicitation.options[1])
        model.pick(elicitation.options[0])
        #expect(model.rank(of: elicitation.options[1]) == 0)
        model.submit()
        #expect(sent.text == "\(String(localized: "In order of priority")): 1) Valve, 2) Pump")
    }

    // MARK: Passi in catena

    @Test("Più passi: si avanza, si torna indietro, e all'ultimo parte il turno composto")
    func chainedSteps() throws {
        let elicitation = try decode(#"""
        {"id":"c","question":"","assembly":{"intro":"Check results"},"steps":[
          {"id":"s1","question":"Pressure ok?","topic":"Pressure","options":[{"id":"p1","label":"Yes"}]},
          {"id":"s2","question":"Leaks?","topic":"Leaks","options":[{"id":"l1","label":"None"}]}
        ]}
        """#)
        let (model, sent) = model(elicitation)
        model.pick(model.step.options[0])
        model.submit()
        #expect(model.stepIndex == 1)
        #expect(model.isLast)
        #expect(sent.text == nil)
        model.goBack()
        #expect(model.stepIndex == 0)
        model.pick(model.step.options[0])
        model.submit()
        model.pick(model.step.options[0])
        model.submit()
        #expect(sent.text == "Check results\n- Pressure: Yes\n- Leaks: None")
        #expect(sent.details.count == 2)
        #expect(model.stepIndex == 0)
    }

    // MARK: Fine procedura

    @Test("Terminare la procedura aspetta il motivo e lo manda in coda all'etichetta")
    func closureNeedsReason() throws {
        let elicitation = try decode(#"{"id":"e","question":"End?","reason":"closure_confirmation","options":[{"id":"y","label":"Yes, end the procedure.","value":"end"},{"id":"n","label":"No, continue","value":"continue"}]}"#)
        let (model, sent) = model(elicitation)
        model.pick(elicitation.options[0])
        #expect(model.endingProcedure)
        #expect(!model.closureReady)
        model.submit()
        #expect(sent.text == nil)
        model.closureReason = .shiftEnd
        model.closureDetails = "Night shift arrives"
        model.submit()
        #expect(sent.text == "Yes, end the procedure. Reason: shift_end. Details: Night shift arrives")
    }

    @Test("«No, continua» non chiede un motivo")
    func continueNeedsNoReason() throws {
        let elicitation = try decode(#"{"id":"e","question":"End?","reason":"closure_confirmation","options":[{"id":"y","label":"Yes","value":"end"},{"id":"n","label":"No, continue","value":"continue"}]}"#)
        let (model, sent) = model(elicitation)
        model.pick(elicitation.options[1])
        #expect(!model.endingProcedure)
        #expect(model.closureReady)
        model.submit()
        #expect(sent.text == "No, continue")
    }
}
