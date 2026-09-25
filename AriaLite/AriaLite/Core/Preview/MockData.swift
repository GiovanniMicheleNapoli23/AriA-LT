//
//  MockData.swift
//  AriaLite
//
//  Created by Giovanni Michele on 19/03/26.
//

import Foundation

// ⚠️⚠️⚠️ FAKE DEMO DATA — REMOVE IN PRODUCTION ⚠️⚠️⚠️
// Tutto questo file (password, utenti, work order) è dato mock cablato a scopo demo.
// In produzione va sostituito con i dati provenienti dal backend / store reale.

// MARK: - Passwords

let mockPasswords: [UUID: String] = [
    UUID(uuidString: "00000000-0000-0000-0000-000000000001")!: "ciao123",
    UUID(uuidString: "00000000-0000-0000-0000-000000000002")!: "segret0",
    UUID(uuidString: "00000000-0000-0000-0000-000000000003")!: "test"
]

// MARK: - Users

let mockUsers: [User] = [
    User(
        id: UUID(uuidString: "00000000-0000-0000-0000-000000000001")!,
        username: "mario",
        name: "Mario Rossi"
    ),
    User(
        id: UUID(uuidString: "00000000-0000-0000-0000-000000000002")!,
        username: "luisa",
        name: "Luisa Bianchi"
    ),
    User(
        id: UUID(uuidString: "00000000-0000-0000-0000-000000000003")!,
        username: "giovanni",
        name: "Giovanni Michele"
    )
]

// MARK: - Date helpers (privati al file)

private func today() -> Date {
    Calendar.current.startOfDay(for: Date())
}

private func daysAgo(_ n: Int) -> Date {
    Calendar.current.date(byAdding: .day, value: -n, to: today())!
}

// MARK: - Work Orders
// Proprietà calcolata: le date (today()/daysAgo) sono sempre relative ad adesso,
// così i work order "di oggi" non slittano a ieri se l'app resta aperta oltre la mezzanotte.
var mockWorkOrders: [WorkOrder] { [

    // ── Mario ─────────────────────────────────────────────────────

    WorkOrder(
        id: UUID(uuidString: "A0000000-0000-0000-0000-000000000001")!,
        assignedUserID: UUID(uuidString: "00000000-0000-0000-0000-000000000001")!,
        title: String(localized: "Generator Maintenance"),
        checklist: [
            ChecklistItem(
                id: UUID(uuidString: "C1000000-0000-0000-0000-000000000001")!,
                text: String(localized: "Check oil level"),
                description: String(localized: "Open the filter cap and visually inspect for any leaks. Replace the oil if the level is below minimum or if it appears dark."),
                isCompleted: false
            ),
            ChecklistItem(
                id: UUID(uuidString: "C1000000-0000-0000-0000-000000000002")!,
                text: String(localized: "Air filter cleaning"),
                description: String(localized: "Remove the air filter and blow out dust and debris with compressed air. Replace the filter if it shows tears or excessive clogging."),
                isCompleted: false
            ),
            ChecklistItem(
                id: UUID(uuidString: "C1000000-0000-0000-0000-000000000003")!,
                text: String(localized: "Drive belt inspection"),
                description: String(localized: "Check belt tension: allowable deflection is 10–15 mm under manual pressure. Check for absence of cracks or wear on the sides."),
                isCompleted: false
            ),
            ChecklistItem(
                id: UUID(uuidString: "C1000000-0000-0000-0000-000000000004")!,
                text: String(localized: "Cold start test"),
                description: String(localized: "Perform a cold start without pre-heating and verify the engine reaches nominal speed within 30 seconds. Note any abnormal sounds."),
                isCompleted: false
            )
        ],
        documents: [
            ProcedureDocument(
                id: UUID(uuidString: "D1000000-0000-0000-0000-000000000001")!,
                title: String(localized: "Generator XG-500 Manual"),
                notes: "Refer to p. 12 for oil specifications. Use only SAE 10W-40 oil with API SL certification.",
                photos: ["manual_xg500_cover.png"]
            ),
            ProcedureDocument(
                id: UUID(uuidString: "D1000000-0000-0000-0000-000000000002")!,
                title: String(localized: "Periodic Maintenance Schedule"),
                notes: "Service interval: every 250 operating hours or 6 months, whichever comes first.",
                photos: []
            )
        ],
        scheduledDate: today()
    ),

    WorkOrder(
        id: UUID(uuidString: "A0000000-0000-0000-0000-000000000002")!,
        assignedUserID: UUID(uuidString: "00000000-0000-0000-0000-000000000001")!,
        title: String(localized: "Hydraulic Pump Replacement"),
        checklist: [
            ChecklistItem(
                id: UUID(uuidString: "C2000000-0000-0000-0000-000000000001")!,
                text: String(localized: "Depressurize the system"),
                description: String(localized: "Before any work, bring the system pressure to zero using the dedicated relief valve. Wait 5 minutes before proceeding."),
                isCompleted: false
            ),
            ChecklistItem(
                id: UUID(uuidString: "C2000000-0000-0000-0000-000000000002")!,
                text: String(localized: "Remove old pump"),
                description: String(localized: "Disconnect the hydraulic fittings and electrical cables from the pump. Use a collection tray for residual fluid and dispose of it properly."),
                isCompleted: false
            ),
            ChecklistItem(
                id: UUID(uuidString: "C2000000-0000-0000-0000-000000000003")!,
                text: String(localized: "Install new pump"),
                description: String(localized: "Position the new pump according to the orientation shown in the diagram. Apply Loctite 577 sealant to the threads before tightening."),
                isCompleted: false
            ),
            ChecklistItem(
                id: UUID(uuidString: "C2000000-0000-0000-0000-000000000004")!,
                text: String(localized: "Pressure leak test"),
                description: String(localized: "Gradually bring the system to nominal pressure (80 bar) and hold for 10 minutes. Visually inspect all fittings for leaks."),
                isCompleted: false
            ),
            ChecklistItem(
                id: UUID(uuidString: "C2000000-0000-0000-0000-000000000005")!,
                text: String(localized: "Sign commissioning form"),
                description: String(localized: "Fill in and sign the commissioning form with date, measured pressure, and technician name. Attach a copy to the machine file."),
                isCompleted: false
            )
        ],
        documents: [
            ProcedureDocument(
                id: UUID(uuidString: "D2000000-0000-0000-0000-000000000001")!,
                title: String(localized: "Pump P-200 Technical Datasheet"),
                notes: "Fitting torque: 45 Nm. Nominal flow rate: 12 L/min at 1450 rpm. Recommended fluid: ISO VG 46.",
                photos: ["pump_p200_diagram.png", "pump_p200_detail.png"]
            )
        ],
        scheduledDate: today()
    ),

    // ── Luisa ─────────────────────────────────────────────────────

    WorkOrder(
        id: UUID(uuidString: "A0000000-0000-0000-0000-000000000003")!,
        assignedUserID: UUID(uuidString: "00000000-0000-0000-0000-000000000001")!,
        title: String(localized: "Electrical Panel Inspection"),
        checklist: [
            ChecklistItem(
                id: UUID(uuidString: "C3000000-0000-0000-0000-000000000001")!,
                text: String(localized: "Check residual current devices"),
                description: String(localized: "Press the test button on each RCD and verify it trips correctly. Record the IDs of any non-responding units for immediate replacement."),
                isCompleted: false
            ),
            ChecklistItem(
                id: UUID(uuidString: "C3000000-0000-0000-0000-000000000002")!,
                text: String(localized: "Check terminal tightness"),
                description: String(localized: "Use a cross-head screwdriver to check tightening resistance on all terminals. Loose terminals are a primary cause of electrical arcing and overheating."),
                isCompleted: false
            ),
            ChecklistItem(
                id: UUID(uuidString: "C3000000-0000-0000-0000-000000000003")!,
                text: String(localized: "Cable insulation measurement"),
                description: String(localized: "Use a 500V DC megohmmeter on each outgoing line from the panel. Minimum acceptable value is 1 MΩ; cables below threshold must be replaced."),
                isCompleted: false
            )
        ],
        documents: [
            ProcedureDocument(
                id: UUID(uuidString: "D3000000-0000-0000-0000-000000000001")!,
                title: String(localized: "Main Panel Wiring Diagram"),
                notes: "Diagram updated in 2023. Verify it matches the physical state of the panel; report any discrepancies to the technical manager.",
                photos: []
            )
        ],
        scheduledDate: today()
    ),

    WorkOrder(
        id: UUID(uuidString: "A0000000-0000-0000-0000-000000000004")!,
        assignedUserID: UUID(uuidString: "00000000-0000-0000-0000-000000000001")!,
        title: String(localized: "Temperature Sensor Calibration"),
        checklist: [
            ChecklistItem(
                id: UUID(uuidString: "C4000000-0000-0000-0000-000000000001")!,
                text: String(localized: "Connect to certified calibrator"),
                description: String(localized: "Connect the sensor to the reference calibrator using the appropriate adapter. Verify the calibrator has a valid calibration certificate."),
                isCompleted: false
            ),
            ChecklistItem(
                id: UUID(uuidString: "C4000000-0000-0000-0000-000000000002")!,
                text: String(localized: "Zero point check (0°C)"),
                description: String(localized: "Immerse the sensor in a melting ice bath (0°C ± 0.1°C). Wait 3 minutes for stabilization and record the value read by the sensor."),
                isCompleted: false
            ),
            ChecklistItem(
                id: UUID(uuidString: "C4000000-0000-0000-0000-000000000003")!,
                text: String(localized: "Full scale check (100°C)"),
                description: String(localized: "Bring the thermal bath to 100°C and wait at least 5 minutes for stabilization. Maximum allowable deviation from the calibrator is ±0.5°C."),
                isCompleted: false
            ),
            ChecklistItem(
                id: UUID(uuidString: "C4000000-0000-0000-0000-000000000004")!,
                text: String(localized: "Record values on form"),
                description: String(localized: "Transcribe the measured values into the attached ISO-9001 form fields. The form must be signed, dated, and archived in the document system within 24 hours."),
                isCompleted: false
            )
        ],
        documents: [
            ProcedureDocument(
                id: UUID(uuidString: "D4000000-0000-0000-0000-000000000001")!,
                title: String(localized: "ISO-9001 Calibration Procedure"),
                notes: "Maximum allowable deviation: ±0.5°C. If the threshold is exceeded, the sensor must be declared non-conforming and replaced before being returned to service.",
                photos: ["calibration_procedure.pdf"]
            )
        ],
        scheduledDate: daysAgo(3)
    ),

    // ── Giovanni ──────────────────────────────────────────────────

    WorkOrder(
        id: UUID(uuidString: "A0000000-0000-0000-0000-000000000005")!,
        assignedUserID: UUID(uuidString: "00000000-0000-0000-0000-000000000001")!,
        title: String(localized: "Fire Safety System Inspection"),
        checklist: [
            ChecklistItem(
                id: UUID(uuidString: "C5000000-0000-0000-0000-000000000001")!,
                text: String(localized: "Check fire extinguishers (expiry and charge)"),
                description: String(localized: "Check the expiry label on each extinguisher and verify the pressure indicator is in the green range. Expired extinguishers must be isolated and flagged for servicing."),
                isCompleted: false
            ),
            ChecklistItem(
                id: UUID(uuidString: "C5000000-0000-0000-0000-000000000002")!,
                text: String(localized: "Smoke detector test"),
                description: String(localized: "Use the dedicated spray (not a lighter or flame) to test each detector. Verify the alarm panel receives the signal correctly within 10 seconds."),
                isCompleted: false
            ),
            ChecklistItem(
                id: UUID(uuidString: "C5000000-0000-0000-0000-000000000003")!,
                text: String(localized: "Fire door inspection"),
                description: String(localized: "Verify that fire doors close automatically upon release. Check the integrity of intumescent seals and the absence of obstructions."),
                isCompleted: false
            ),
            ChecklistItem(
                id: UUID(uuidString: "C5000000-0000-0000-0000-000000000004")!,
                text: String(localized: "Hose reels and hydrant inspection"),
                description: String(localized: "Partially unroll each hose reel and check for cracks or leaks. Verify the nozzle is present and the hydrant coupling is not corroded."),
                isCompleted: false
            ),
            ChecklistItem(
                id: UUID(uuidString: "C5000000-0000-0000-0000-000000000005")!,
                text: String(localized: "Fill in fire safety register"),
                description: String(localized: "Complete the fire safety register with the date, outcome of each check, and technician name. The register must be kept on-site and available for fire brigade inspections."),
                isCompleted: false
            )
        ],
        documents: [
            ProcedureDocument(
                id: UUID(uuidString: "D5000000-0000-0000-0000-000000000001")!,
                title: String(localized: "Standard UNI EN 3 – Fire Extinguishers"),
                notes: "Verify CE label compliance and presence of serial number. Extinguishers without CE marking cannot be returned to service.",
                photos: ["uni_en3_extract.png"]
            ),
            ProcedureDocument(
                id: UUID(uuidString: "D5000000-0000-0000-0000-000000000002")!,
                title: String(localized: "Fire Zone Floor Plan"),
                notes: "Floor plan updated January 2024. Verify that the indicated escape routes are clear of obstacles before closing the report.",
                photos: ["floorplan_floor1.png", "floorplan_floor2.png"]
            )
        ],
        scheduledDate: today()
    ),

    // Additional past work order for Giovanni (to test the Past section)
    WorkOrder(
        id: UUID(uuidString: "A0000000-0000-0000-0000-000000000006")!,
        assignedUserID: UUID(uuidString: "00000000-0000-0000-0000-000000000001")!,
        title: String(localized: "Server Room UPS Check"),
        checklist: [
            ChecklistItem(
                id: UUID(uuidString: "C6000000-0000-0000-0000-000000000001")!,
                text: String(localized: "Check UPS battery status"),
                description: String(localized: "Access the UPS control panel and check battery state of health (SOH%). Replace batteries if SOH drops below 80%."),
                isCompleted: true
            ),
            ChecklistItem(
                id: UUID(uuidString: "C6000000-0000-0000-0000-000000000002")!,
                text: String(localized: "Manual bypass test"),
                description: String(localized: "Perform the manual bypass transfer following the procedure in the manual. Verify that loads remain powered throughout the entire operation without interruption."),
                isCompleted: true
            ),
            ChecklistItem(
                id: UUID(uuidString: "C6000000-0000-0000-0000-000000000003")!,
                text: String(localized: "Ventilation filter cleaning"),
                description: String(localized: "Remove the front filters and blow out dust with low-pressure compressed air. Heavily clogged filters must be replaced to prevent overheating."),
                isCompleted: true
            )
        ],
        documents: [
            ProcedureDocument(
                id: UUID(uuidString: "D6000000-0000-0000-0000-000000000001")!,
                title: String(localized: "APC Smart-UPS 3000 Manual"),
                notes: "For the runtime test follow the procedure on p. 34. Minimum expected runtime at 50% load: 18 minutes.",
                photos: ["ups_apc_manual.png"]
            )
        ],
        scheduledDate: daysAgo(5)
    )
] }
