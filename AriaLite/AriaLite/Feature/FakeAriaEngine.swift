//
//  FakeAriaEngine.swift
//  AriaLite
//
//  ⚠️⚠️⚠️ FAKE Aria backend simulator — REMOVE / REPLACE IN PRODUCTION ⚠️⚠️⚠️
//  Simula intent-detection, una knowledge base di procedure e le risposte del vero
//  Aria Engine usando i dati mock. Usato dalla chat (tab Assistant) e dall'assistente
//  dentro la manutenzione. I contenuti dell'assistente sono in inglese (non localizzati).
//

import SwiftUI

// FAKE: intenti "di servizio" (gli aiuti sulle procedure usano la knowledge base).
enum AriaIntent {
    case greeting
    case capabilities
    case thanks
    case openWorkOrders
    case latestStatus
    case findOrder
    case countOrders
    case generic
}

// Suggerimento / quick-reply. Può portare un intento, oppure una risposta diretta
// (knowledge base) con eventuali follow-up annidati.
struct AriaSuggestion: Identifiable {
    let id = UUID()
    let text: String
    var intent: AriaIntent = .generic
    var answer: String? = nil
    var followUps: [AriaSuggestion] = []
}

// Risposta del motore: testo + eventuali schede work order + follow-up.
struct AriaResponse {
    let text: String
    var workOrders: [WorkOrder] = []
    var followUps: [AriaSuggestion] = []
}

// FAKE: motore di chat simulato. Tutto cablato sui dati mock + knowledge base.
struct FakeAriaEngine {
    let viewModel: AppViewModel
    var workOrder: WorkOrder? = nil
    var step: ChecklistItem? = nil

    // MARK: - Dati

    private var assigned: [WorkOrder] {
        guard let user = viewModel.loggedInUser else { return [] }
        return mockWorkOrders.filter { $0.assignedUserID == user.id }
    }
    private var openOrders: [WorkOrder] {
        assigned.filter { !viewModel.submittedWorkOrders.contains($0.id) }
    }

    // MARK: - Suggerimenti (UI chrome, localizzati)

    var quickSuggestions: [AriaSuggestion] {
        [
            AriaSuggestion(
                text: String(localized: "Help me with the generator"),
                answer: "The generator service covers four checks: oil level, air filter, drive belt and a cold-start test. Which one should we walk through?",
                followUps: [
                    suggestion(for: airFilterProc),
                    suggestion(for: driveBeltProc),
                    suggestion(for: oilProc),
                    suggestion(for: coldStartProc)
                ]
            ),
            AriaSuggestion(text: String(localized: "Show open work orders"), intent: .openWorkOrders),
            AriaSuggestion(text: String(localized: "What's the status of the latest order?"), intent: .latestStatus),
            AriaSuggestion(text: String(localized: "Help me find a specific order"), intent: .findOrder)
        ]
    }

    // MARK: - Intent detection (FAKE, parole chiave IT/EN)

    // Risposta deterministica per richieste "note" (procedure, work order, social).
    // Restituisce nil se la richiesta va gestita dal modello on-device (Apple Intelligence).
    func knownResponse(to text: String) -> AriaResponse? {
        let t = text.lowercased()
        let firstWord = t.split(whereSeparator: { !$0.isLetter }).first.map(String.init) ?? ""
        let greetings: Set<String> = ["hi", "hello", "hey", "hola", "ciao", "salve", "buongiorno", "ehi"]
        if greetings.contains(firstWord) { return response(for: .greeting) }

        // Procedure (knowledge base) — match per parola chiave.
        if let proc = procedure(matching: t) {
            return AriaResponse(text: proc.answer, followUps: proc.followUps)
        }

        if t.contains("how many") || t.contains("quant") { return response(for: .countOrders) }
        if t.contains("open") || t.contains("apert") { return response(for: .openWorkOrders) }
        if t.contains("status") || t.contains("stato") || t.contains("latest")
            || t.contains("ultim") || t.contains("recent") { return response(for: .latestStatus) }
        if t.contains("find") || t.contains("trova") || t.contains("cerca") || t.contains("specif") { return response(for: .findOrder) }
        if t.contains("thank") || t.contains("grazie") { return response(for: .thanks) }
        if t.contains("help") || t.contains("aiut") || t.contains("what can you")
            || t.contains("cosa puoi") || t.contains("come funzion") { return response(for: .capabilities) }
        if t.contains("work order") || t.contains("order") || t.contains("ordin") { return response(for: .openWorkOrders) }
        return nil
    }

    // Fallback locale (usato se Apple Intelligence non è disponibile).
    func reply(to text: String) -> AriaResponse {
        knownResponse(to: text) ?? response(for: .generic)
    }

    // Contesto testuale (work order / step) passato al modello on-device.
    func llmContext() -> String? {
        var parts: [String] = []
        if let workOrder { parts.append("Work order: \(workOrder.title).") }
        if let step {
            parts.append("Current step: \(step.text).")
            if let d = step.description, !d.isEmpty { parts.append("Step details: \(d)") }
        }
        return parts.isEmpty ? nil : parts.joined(separator: " ")
    }

    // MARK: - Risposte di servizio

    func response(for intent: AriaIntent) -> AriaResponse {
        switch intent {
        case .greeting:
            return AriaResponse(
                text: "Hi! I'm AriA, your maintenance assistant. Ask me about a work order or any step of a procedure.",
                followUps: Array(quickSuggestions.prefix(2))
            )
        case .capabilities:
            return AriaResponse(
                text: "I can show your work orders, summarize their status, and walk you through any step — from a drive-belt inspection to a megohmmeter test. Try one of these:",
                followUps: quickSuggestions
            )
        case .thanks:
            return AriaResponse(text: "You're welcome — happy to help. Stay safe out there!")
        case .countOrders:
            return AriaResponse(text: "You have \(openOrders.count) open work orders.", workOrders: openOrders)
        case .openWorkOrders:
            guard !openOrders.isEmpty else {
                return AriaResponse(text: String(localized: "All your work orders are completed. Nothing open right now."))
            }
            return AriaResponse(text: String(localized: "Here are your open work orders:"), workOrders: openOrders)
        case .latestStatus:
            guard let latest = assigned.max(by: { $0.scheduledDate < $1.scheduledDate }) else {
                return AriaResponse(text: String(localized: "You don't have any work orders yet."))
            }
            return AriaResponse(text: String(localized: "Here's your most recent work order:"), workOrders: [latest])
        case .findOrder:
            guard !assigned.isEmpty else {
                return AriaResponse(text: String(localized: "You don't have any work orders yet."))
            }
            return AriaResponse(
                text: String(localized: "Here are all your work orders — tell me which one you're looking for:"),
                workOrders: assigned
            )
        case .generic:
            return AriaResponse(
                text: "I can help with your work orders and any maintenance step. Try one of these:",
                followUps: quickSuggestions
            )
        }
    }

    // MARK: - Aiuto sullo step corrente (manutenzione)

    func stepIntro() -> AriaResponse {
        guard let step else { return response(for: .capabilities) }
        if let proc = procedure(matching: step.text.lowercased()) {
            return AriaResponse(text: proc.answer, followUps: proc.followUps)
        }
        // Step non in knowledge base: AriA usa la descrizione reale dello step.
        let body = step.description ?? ""
        let text = "Here's how to approach this step:\n\n" + step.text + (body.isEmpty ? "" : "\n\n" + body)
        return AriaResponse(text: text)
    }

    // MARK: - Knowledge base (FAKE, contenuti tecnici in inglese)

    private struct Proc {
        let keywords: [String]
        let prompt: String          // etichetta usata come follow-up cliccabile
        let answer: String          // guida principale
        let followUps: [AriaSuggestion]
    }

    private func qa(_ question: String, _ answer: String) -> AriaSuggestion {
        AriaSuggestion(text: question, answer: answer)
    }
    private func suggestion(for proc: Proc) -> AriaSuggestion {
        AriaSuggestion(text: proc.prompt, answer: proc.answer, followUps: proc.followUps)
    }

    private func procedure(matching text: String) -> Proc? {
        procedures.first { proc in proc.keywords.contains { text.contains($0) } }
    }

    private var procedures: [Proc] {
        [
            // ───── Generator Maintenance ─────
            oilProc, airFilterProc, driveBeltProc, coldStartProc,

            // ───── Hydraulic Pump Replacement ─────
            Proc(keywords: ["depressur", "system pressure"],
                 prompt: "How do I depressurize the system safely?",
                 answer: "Stop the prime mover, then open the dedicated relief/bleed valve to bring system pressure to 0 bar and confirm it on the gauge. Wait 5 minutes for accumulators to discharge and lock out the energy source before opening any fitting.",
                 followUps: [
                    qa("Why wait 5 minutes after relieving pressure?", "Accumulators and trapped fluid can hold injection-risk pressure for minutes after the pump stops. Opening a joint early can spray hot oil — always verify zero on the gauge first."),
                    qa("Do I need to drain the reservoir?", "Usually no — just relieve the pressure. Drain only if you'll open a connection below fluid level; otherwise a catch tray for the line residual is enough.")
                 ]),
            Proc(keywords: ["remove old pump", "old pump", "rimuovi la vecchia"],
                 prompt: "How do I remove the old pump?",
                 answer: "Tag and disconnect the electrical leads, then the suction and pressure lines, capping every port as you go. Support the pump weight before undoing the coupling and mounting bolts, and collect residual fluid for proper disposal.",
                 followUps: [
                    qa("How do I avoid contamination?", "Cap each port and line the instant it's disconnected and keep the bay clean — particle ingress is the number-one cause of premature failure on the new pump."),
                    qa("What about the coupling?", "Mark the coupling position before removal so you have a reference; you'll re-check shaft alignment to spec (typically under 0.05 mm) when fitting the replacement.")
                 ]),
            Proc(keywords: ["install new pump", "new pump", "installa la nuova"],
                 prompt: "How do I install the new pump?",
                 answer: "Mount the pump in the orientation shown on the diagram, fit a new coupling and seals, and apply Loctite 577 to tapered threads only. Align the shaft to spec, connect suction then pressure lines, and prime it before start-up.",
                 followUps: [
                    qa("How do I prime the pump?", "Fill the housing with clean fluid through the highest port, bleed air at the outlet, and jog the motor briefly. Never dry-run a hydraulic pump — it wipes the internals in seconds."),
                    qa("What fitting torque should I use?", "Follow the datasheet (about 45 Nm here), tighten in a cross pattern, and don't over-torque tapered fittings — that's what cracks ports.")
                 ]),
            Proc(keywords: ["leak test", "pressure leak", "tenuta in pressione"],
                 prompt: "How do I run the pressure leak test?",
                 answer: "Bring the system up in stages to nominal pressure (80 bar), pausing at each step to watch the gauge. Hold at full pressure for 10 minutes and inspect every joint — a stable gauge and dry fittings is a pass.",
                 followUps: [
                    qa("How much pressure drop is acceptable?", "On a static hold, essentially none beyond thermal settling. A steady fall points to an internal leak or a weeping joint — find and fix it before returning to service."),
                    qa("How do I find a high-pressure leak safely?", "Trace suspected pinholes with a piece of cardboard, never your hand — a fine jet at 80 bar can inject through skin.")
                 ]),
            Proc(keywords: ["commissioning", "messa in servizio"],
                 prompt: "What goes on the commissioning form?",
                 answer: "Record the date, measured pressure, fluid type and level, and any anomalies, then sign it. File a copy in the machine logbook and update the asset's maintenance history.",
                 followUps: [
                    qa("What must the form include?", "Asset ID, test pressure and result, parts replaced, and the technician's name, signature and date — it's the traceability record for the job."),
                    qa("Who keeps the record?", "A copy stays in the machine file on site; the original goes into the maintenance management system per your QA procedure.")
                 ]),

            // ───── Electrical Panel Inspection ─────
            Proc(keywords: ["residual current", "rcd", "differenzial"],
                 prompt: "How do I check the residual current devices?",
                 answer: "With the circuit energised, press the TEST button on each RCD — it must trip within the rated time (≤300 ms for a 30 mA type). Record any device that won't trip or won't reset and isolate it for replacement.",
                 followUps: [
                    qa("Isn't pressing TEST enough?", "The button only checks the trip mechanism. Periodically use an RCD tester to verify the actual trip current and time (e.g. ≤30 mA, ≤300 ms) for real compliance."),
                    qa("An RCD won't reset — what now?", "There's likely a genuine earth fault downstream. Isolate the circuits and megger-test to locate the leakage rather than forcing the device back on.")
                 ]),
            Proc(keywords: ["terminal", "morsetti", "tightness"],
                 prompt: "How do I check terminal tightness?",
                 answer: "With the panel dead and proven dead, torque each terminal to the maker's value with a calibrated screwdriver (typically 1.5–3.5 Nm for control terminals). Loose joints overheat — thermography under load helps spot them first.",
                 followUps: [
                    qa("Why do terminals loosen over time?", "Thermal cycling and conductor creep, especially on aluminium and stranded copper. Re-torque at scheduled intervals and use spring washers where the maker specifies them."),
                    qa("Can I check tightness on a live panel?", "No — torque checks are done dead. On a live panel use infrared thermography to find hot joints, then schedule a dead re-torque.")
                 ]),
            Proc(keywords: ["insulation", "megohm", "isolamento", "megger"],
                 prompt: "How do I measure cable insulation?",
                 answer: "De-energise and disconnect sensitive electronics, then apply 500 V DC with a megohmmeter from each outgoing line to earth. The minimum acceptable value is 1 MΩ; a downward trend signals moisture or insulation ageing.",
                 followUps: [
                    qa("What test voltage and limit apply?", "500 V DC for LV installations. 1 MΩ is the code minimum, but healthy cable usually reads tens to hundreds of MΩ — anything under 1 MΩ should be replaced."),
                    qa("Why disconnect electronics first?", "500 V DC will destroy drives, PLCs and surge protectors, and they'd also give you false low readings. Isolate or unplug them before testing.")
                 ]),

            // ───── Temperature Sensor Calibration ─────
            Proc(keywords: ["certified calibrator", "calibrator", "calibratore"],
                 prompt: "How do I connect to the certified calibrator?",
                 answer: "Connect the sensor to a reference calibrator that has a valid, in-date certificate, using the correct adapter and a 3- or 4-wire connection for RTDs. Let the loop stabilise before taking any reading.",
                 followUps: [
                    qa("Why does the certificate matter?", "Traceability — your result is only valid if the reference is traceable to a national standard and still within its calibration interval. Note the certificate number on the record."),
                    qa("Does lead resistance affect the reading?", "On RTDs, yes. Use a 3- or 4-wire connection (or proper compensation) so cable resistance doesn't add an apparent temperature error.")
                 ]),
            Proc(keywords: ["zero point", "0°c", "punto zero"],
                 prompt: "How do I do the zero-point check?",
                 answer: "Immerse the sensor in a stirred melting-ice bath at 0 °C ±0.1 °C, wait about 3 minutes for it to stabilise, then record the reading. The deviation should fall inside the sensor's tolerance band.",
                 followUps: [
                    qa("How do I make a proper ice bath?", "Use crushed ice from distilled water with just enough water to make a slush, stir it, and immerse the sensor to the correct depth without touching the container walls."),
                    qa("What deviation is acceptable?", "It depends on class — a Class A Pt100 is about ±0.15 °C at 0 °C. If you exceed it, apply an offset if the device allows, otherwise flag the sensor.")
                 ]),
            Proc(keywords: ["full scale", "100°c", "fondo scala"],
                 prompt: "How do I do the full-scale check?",
                 answer: "Bring the thermal bath to 100 °C, wait at least 5 minutes for stability, and compare against the reference. The maximum allowable deviation here is ±0.5 °C — record the actual value at the point.",
                 followUps: [
                    qa("What if it's outside ±0.5 °C?", "Apply the span/offset adjustment if the instrument supports it and re-verify. If it can't be brought in, declare it non-conforming and replace it before return to service."),
                    qa("Should I check a mid-scale point too?", "For critical loops, yes — add a midpoint such as 50 °C to catch non-linearity, not just the two end points.")
                 ]),
            Proc(keywords: ["record values", "iso-9001", "record the values"],
                 prompt: "How do I record the calibration values?",
                 answer: "Transcribe the as-found and as-left readings into the ISO-9001 form with the reference certificate number, ambient conditions and pass/fail. Sign, date and archive it in the document system within 24 hours.",
                 followUps: [
                    qa("What's 'as-found' vs 'as-left'?", "As-found is the reading before any adjustment; as-left is after. Both are required to prove drift and that the device was returned in tolerance."),
                    qa("Where is the record stored?", "In the QMS/document system referenced by the asset, and retained for the period your ISO-9001 procedure specifies.")
                 ]),

            // ───── Fire Safety System Inspection ─────
            Proc(keywords: ["extinguisher", "estintori"],
                 prompt: "How do I check the fire extinguishers?",
                 answer: "Confirm each extinguisher's service label is current, the pressure gauge sits in the green, and the pin and tamper seal are intact with no corrosion or damage. Tag any expired or discharged unit out of service immediately.",
                 followUps: [
                    qa("How often are extinguishers serviced?", "A visual check monthly, professional maintenance annually, and a periodic discharge/overhaul (often every 5–6 years) according to the local standard."),
                    qa("The gauge is in the red — what now?", "Remove it from service and fit a spare. An over- or under-pressurised extinguisher may not discharge and must go for overhaul.")
                 ]),
            Proc(keywords: ["smoke detector", "rilevatori", "detector"],
                 prompt: "How do I test the smoke detectors?",
                 answer: "Use approved aerosol test smoke (never an open flame) and confirm the panel registers the correct zone within about 10 seconds, the sounders activate, and the event is logged. Reset the panel afterwards.",
                 followUps: [
                    qa("Why not use a lighter?", "An open flame can damage the sensor and is itself a fire risk. Canned test smoke gives a repeatable, sensor-safe stimulus."),
                    qa("A detector doesn't report to the panel?", "Check the loop wiring and address, clean or replace the head, and confirm the zone mapping — a missing signal is a critical fault to clear.")
                 ]),
            Proc(keywords: ["fire door", "tagliafuoco"],
                 prompt: "How do I inspect the fire doors?",
                 answer: "Confirm each door self-closes fully from any angle and latches without binding. Check the intumescent and smoke seals are continuous and intact, hinges are sound, and nothing props or obstructs the door.",
                 followUps: [
                    qa("What gap tolerance applies?", "Typically ≤4 mm around the leaf and ≤8 mm at the threshold — check the door's certification. Excess gaps let smoke pass and defeat the rating."),
                    qa("Can a fire door be held open?", "Only on an approved automatic hold-open device linked to the alarm that releases on activation — never with a wedge or hook.")
                 ]),
            Proc(keywords: ["hose reel", "hydrant", "naspi", "idranti"],
                 prompt: "How do I inspect the hose reels and hydrants?",
                 answer: "Partially run out each hose reel to check for cracks, kinks or leaks, confirm the nozzle is present and operable, and verify hydrant couplings are uncorroded and capped. Check the isolating valve is open and signage is clear.",
                 followUps: [
                    qa("Do I need to pressurise them?", "Verify static pressure and flow at the periodic test interval. For a routine check, confirm valve position, hose condition and nozzle without a full discharge."),
                    qa("A coupling is corroded — action?", "Tag it, replace the coupling or gasket, and re-test. A seized coupling means the brigade can't connect when it matters most.")
                 ]),
            Proc(keywords: ["fire safety register", "registro antincendio", "fire register"],
                 prompt: "What goes in the fire safety register?",
                 answer: "Record the date, the outcome of each check, any defects raised and the technician's name. Keep it on site and available for fire-brigade inspection, and raise work orders for every non-conformity.",
                 followUps: [
                    qa("What must the register capture?", "All tests and inspections, faults found and rectified, plus drills and training — it's the legal evidence of ongoing fire-safety management."),
                    qa("How long is it retained?", "Per local regulation — commonly several years on site. Keep superseded pages too; don't discard them.")
                 ]),

            // ───── Server Room UPS Check ─────
            Proc(keywords: ["ups battery", "battery status", "batteria ups", "soh"],
                 prompt: "How do I check the UPS battery status?",
                 answer: "Open the UPS console and read battery State of Health (SOH%) and string voltage. Replace the set if SOH drops below about 80%, or if any block shows high internal resistance, bulging or heat.",
                 followUps: [
                    qa("Why replace at 80% SOH?", "Below roughly 80% capacity the rated runtime is no longer guaranteed and degradation accelerates. Replace the whole string, not single blocks, to avoid imbalance."),
                    qa("What's the battery design life?", "VRLA blocks are typically rated 3–5 years at 20 °C, and every ~8–10 °C above that roughly halves life — so room cooling really matters.")
                 ]),
            Proc(keywords: ["bypass"],
                 prompt: "How do I run the manual bypass test?",
                 answer: "Follow the maker's make-before-break sequence to transfer the load to maintenance bypass, confirming it stays powered with no drop. Verify the UPS can then be fully isolated, and transfer back the same way.",
                 followUps: [
                    qa("What does make-before-break mean?", "The bypass path is established before the UPS path opens, so the load is never unpowered. Doing the steps out of order will drop the load."),
                    qa("Why test the bypass at all?", "So you can service or swap the UPS without an outage. An untested bypass is the classic cause of an accidental shutdown.")
                 ]),
            Proc(keywords: ["ventilation", "filtro di ventilazione"],
                 prompt: "How do I clean the ventilation filters?",
                 answer: "Remove the front intake filters and clear the dust with low-pressure compressed air or a vacuum; wash washable types and refit only when fully dry. Replace heavily clogged filters — restricted airflow makes the UPS overheat and derate.",
                 followUps: [
                    qa("How often should these be cleaned?", "Monthly to quarterly depending on room cleanliness. A clogged filter raises internal temperature and shortens both battery and electronics life."),
                    qa("Can I run it without the filter?", "No — unfiltered air fouls the boards and heatsinks. If a filter is damaged, fit the correct replacement before returning the unit to service.")
                 ])
        ]
    }

    // ───── Generator step procedures (referenced by the quick suggestion) ─────

    private var oilProc: Proc {
        Proc(keywords: ["oil level", "oil", "olio"],
             prompt: "How do I check the oil level?",
             answer: "Shut the engine down and let it sit 2–3 minutes so the oil drains back to the sump, then pull the dipstick, wipe it, reinsert fully and read. Keep the level between MIN and MAX; top up or change with SAE 10W-40 (API SL) if it's below minimum or looks dark.",
             followUps: [
                qa("Which oil grade should I use?", "SAE 10W-40 meeting API SL or higher. Don't mix grades, and if the oil looks milky it's water-contaminated and must be drained, not topped up."),
                qa("How often should the oil be changed?", "Every 250 operating hours or 6 months, whichever comes first — sooner in dusty environments or under continuous heavy load.")
             ])
    }
    private var airFilterProc: Proc {
        Proc(keywords: ["air filter", "filtro dell'aria", "filtro aria"],
             prompt: "How do I clean the air filter?",
             answer: "Remove the element and blow it from the clean (inside) side outward with dry compressed air below 3 bar. Inspect it against a light: replace it if you see tears, oil soaking, or daylight blocked by clogging. Never wash a paper element.",
             followUps: [
                qa("Can I reuse the filter after cleaning?", "A paper element can be cleaned a couple of times, but replace it after about 3 cleanings or 500 hours. Foam/oiled elements are washed and re-oiled instead of blown."),
                qa("What if the filter is oily?", "Oil on the air side usually means crankcase blow-by or an overfilled sump — fix the cause first, then fit a new element.")
             ])
    }
    private var driveBeltProc: Proc {
        Proc(keywords: ["drive belt", "belt", "cinghia"],
             prompt: "How do I do the drive belt inspection?",
             answer: "With the engine off and cool, press the belt midway between pulleys — deflection should be 10–15 mm under firm thumb pressure. Check both flanks for cracks, glazing or fraying and verify the pulleys are aligned.",
             followUps: [
                qa("How do I set the correct belt tension?", "Loosen the alternator pivot and adjusting bolts, lever it outward to 10–15 mm deflection (or the maker's Newton/frequency spec), torque the bolts, then re-check after a short run-in."),
                qa("When should the belt be replaced?", "At any sign of cracking, glazing, chunking or stretch beyond the adjustment range — and replace as a matched set if the drive uses more than one belt.")
             ])
    }
    private var coldStartProc: Proc {
        Proc(keywords: ["cold start", "cold-start", "avviamento", "freddo"],
             prompt: "What does the cold start test involve?",
             answer: "From a cold engine with no pre-heat, crank and confirm it reaches nominal rpm within about 30 seconds and stabilises without surging. Watch the exhaust colour, listen for knocking or rattling, and log oil pressure and any fault codes.",
             followUps: [
                qa("What if it won't reach nominal speed?", "Suspect fuel delivery (clogged filter or air in the lines), low battery/cranking voltage, or a governor/actuator fault — check fuel pressure and battery state of health first."),
                qa("Is white or blue smoke a problem?", "A brief puff of white smoke when cold can be normal; persistent white means coolant or unburnt fuel, and blue means oil burning — investigate before returning to service.")
             ])
    }
}
