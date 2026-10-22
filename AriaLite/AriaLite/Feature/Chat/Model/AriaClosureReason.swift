//
//  AriaClosureReason.swift
//  AriaLite
//
//  Created by Giovanni Michele on 22/10/26.
//
//  I motivi del dialogo di fine procedura (CLOSURE_REASONS di aria-web, stesso ordine). Sul filo va il codice
//  in inglese; il testo mostrato all'operatore è la traduzione.
//

import Foundation

enum AriaClosureReason: String, CaseIterable, Identifiable, Sendable {
    case cannotProceed = "cannot_proceed"
    case workAlone = "work_alone"
    case waitingSpecialist = "waiting_specialist"
    case vendor
    case missingParts = "missing_parts"
    case missingTools = "missing_tools"
    case unsafe
    case falseAlarm = "false_alarm"
    case documentation
    case wrongAnswers = "wrong_answers"
    case uiBug = "ui_bug"
    case productionPriority = "production_priority"
    case reassigned
    case shiftEnd = "shift_end"
    case personalEmergency = "personal_emergency"
    case other

    var id: String { rawValue }

    var label: String {
        switch self {
        case .cannotProceed: String(localized: "I can't get any further on my own")
        case .workAlone: String(localized: "I'd rather carry on without guidance")
        case .waitingSpecialist: String(localized: "Waiting for an electrician or a specialist")
        case .vendor: String(localized: "I need to contact the supplier for support")
        case .missingParts: String(localized: "The parts or spares I need are not available")
        case .missingTools: String(localized: "I don't have the tools or the access I need")
        case .unsafe: String(localized: "It is not safe to continue right now")
        case .falseAlarm: String(localized: "The alarm was false — it cleared on its own")
        case .documentation: String(localized: "The documentation does not match this machine")
        case .wrongAnswers: String(localized: "Too many wrong or unhelpful answers")
        case .uiBug: String(localized: "Something in the interface is broken")
        case .productionPriority: String(localized: "Production needs the line back now")
        case .reassigned: String(localized: "My supervisor is reassigning the job")
        case .shiftEnd: String(localized: "My shift is ending")
        case .personalEmergency: String(localized: "I have a personal emergency")
        case .other: String(localized: "Another reason — I'll describe it")
        }
    }
}
