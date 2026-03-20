//
//  MockData.swift
//  AriaLite
//
//  Created by Giovanni Michele on 19/03/26.
//

import Foundation


// Password separate dal modello User — simulate un secure store
let mockPasswords: [UUID: String] = [
    UUID(uuidString: "00000000-0000-0000-0000-000000000001")!: "ciao123",
    UUID(uuidString: "00000000-0000-0000-0000-000000000002")!: "segret0",
    UUID(uuidString: "00000000-0000-0000-0000-000000000003")!: "test"
]

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

let mockWorkOrders: [WorkOrder] = [

    // ── Mario: 2 WorkOrder ─────────────────────────────────────────
    WorkOrder(
        id: UUID(uuidString: "A0000000-0000-0000-0000-000000000001")!,
        assignedUserID: UUID(uuidString: "00000000-0000-0000-0000-000000000001")!,
        title: "Manutenzione Generatore",
        checklist: [
            ChecklistItem(id: UUID(uuidString: "C1000000-0000-0000-0000-000000000001")!, text: "Controlla livello olio", description: "apri il filtro, fai ispezione se ci sono perdite, sostituisci l'olio se necessario", isCompleted: false),
            ChecklistItem(id: UUID(uuidString: "C1000000-0000-0000-0000-000000000002")!, text: "Pulizia filtri aria", isCompleted: false),
            ChecklistItem(id: UUID(uuidString: "C1000000-0000-0000-0000-000000000003")!, text: "Verifica cinghia di trasmissione", isCompleted: false),
            ChecklistItem(id: UUID(uuidString: "C1000000-0000-0000-0000-000000000004")!, text: "Test avvio a freddo", isCompleted: false)
        ],
        documents: [
            ProcedureDocument(
                id: UUID(uuidString: "D1000000-0000-0000-0000-000000000001")!,
                title: "Manuale Generatore XG-500",
                notes: "Fare riferimento a pag. 12 per le specifiche olio",
                photos: ["manuale_xg500_copertina.png"]
            ),
            ProcedureDocument(
                id: UUID(uuidString: "D1000000-0000-0000-0000-000000000002")!,
                title: "Schema Manutenzione Periodica",
                notes: nil,
                photos: []
            )
        ]
    ),

    WorkOrder(
        id: UUID(uuidString: "A0000000-0000-0000-0000-000000000002")!,
        assignedUserID: UUID(uuidString: "00000000-0000-0000-0000-000000000001")!,
        title: "Sostituzione Pompa Idraulica",
        checklist: [
            ChecklistItem(id: UUID(uuidString: "C2000000-0000-0000-0000-000000000001")!, text: "Scarico pressione impianto", isCompleted: false),
            ChecklistItem(id: UUID(uuidString: "C2000000-0000-0000-0000-000000000002")!, text: "Rimozione pompa vecchia", isCompleted: false),
            ChecklistItem(id: UUID(uuidString: "C2000000-0000-0000-0000-000000000003")!, text: "Installazione pompa nuova", isCompleted: false),
            ChecklistItem(id: UUID(uuidString: "C2000000-0000-0000-0000-000000000004")!, text: "Test tenuta sotto pressione", isCompleted: false),
            ChecklistItem(id: UUID(uuidString: "C2000000-0000-0000-0000-000000000005")!, text: "Firma modulo collaudo", isCompleted: false)
        ],
        documents: [
            ProcedureDocument(
                id: UUID(uuidString: "D2000000-0000-0000-0000-000000000001")!,
                title: "Scheda Tecnica Pompa P-200",
                notes: "Coppia di serraggio: 45 Nm",
                photos: ["pompa_p200_schema.png", "pompa_p200_dettaglio.png"]
            )
        ]
    ),

    // ── Luisa: 2 WorkOrder ────────────────────────────────────────
    WorkOrder(
        id: UUID(uuidString: "A0000000-0000-0000-0000-000000000003")!,
        assignedUserID: UUID(uuidString: "00000000-0000-0000-0000-000000000002")!,
        title: "Ispezione Quadro Elettrico",
        checklist: [
            ChecklistItem(id: UUID(uuidString: "C3000000-0000-0000-0000-000000000001")!, text: "Verifica interruttori differenziali", isCompleted: false),
            ChecklistItem(id: UUID(uuidString: "C3000000-0000-0000-0000-000000000002")!, text: "Controllo serraggi morsetti", isCompleted: false),
            ChecklistItem(id: UUID(uuidString: "C3000000-0000-0000-0000-000000000003")!, text: "Misurazione isolamento cavi", isCompleted: false)
        ],
        documents: [
            ProcedureDocument(
                id: UUID(uuidString: "D3000000-0000-0000-0000-000000000001")!,
                title: "Schema Quadro Generale",
                notes: nil,
                photos: []
            )
        ]
    ),

    WorkOrder(
        id: UUID(uuidString: "A0000000-0000-0000-0000-000000000004")!,
        assignedUserID: UUID(uuidString: "00000000-0000-0000-0000-000000000002")!,
        title: "Calibrazione Sensori Temperatura",
        checklist: [
            ChecklistItem(id: UUID(uuidString: "C4000000-0000-0000-0000-000000000001")!, text: "Connessione al calibratore certificato", isCompleted: false),
            ChecklistItem(id: UUID(uuidString: "C4000000-0000-0000-0000-000000000002")!, text: "Verifica punto zero (0°C)", isCompleted: false),
            ChecklistItem(id: UUID(uuidString: "C4000000-0000-0000-0000-000000000003")!, text: "Verifica punto pieno (100°C)", isCompleted: false),
            ChecklistItem(id: UUID(uuidString: "C4000000-0000-0000-0000-000000000004")!, text: "Registrazione valori su modulo", isCompleted: false)
        ],
        documents: [
            ProcedureDocument(
                id: UUID(uuidString: "D4000000-0000-0000-0000-000000000001")!,
                title: "Procedura Calibrazione ISO-9001",
                notes: "Scostamento max ammesso: ±0.5°C",
                photos: ["calibrazione_procedura.pdf"]
            )
        ]
    ),

    // ── Giovanni: 1 WorkOrder ─────────────────────────────────────
    WorkOrder(
        id: UUID(uuidString: "A0000000-0000-0000-0000-000000000005")!,
        assignedUserID: UUID(uuidString: "00000000-0000-0000-0000-000000000003")!,
        title: "Revisione Impianto Antincendio",
        checklist: [
            ChecklistItem(id: UUID(uuidString: "C5000000-0000-0000-0000-000000000001")!, text: "Verifica estintori (scadenza e carica)", isCompleted: false),
            ChecklistItem(id: UUID(uuidString: "C5000000-0000-0000-0000-000000000002")!, text: "Test rilevatori di fumo", isCompleted: false),
            ChecklistItem(id: UUID(uuidString: "C5000000-0000-0000-0000-000000000003")!, text: "Controllo porte tagliafuoco", isCompleted: false),
            ChecklistItem(id: UUID(uuidString: "C5000000-0000-0000-0000-000000000004")!, text: "Ispezione naspi e idranti", isCompleted: false),
            ChecklistItem(id: UUID(uuidString: "C5000000-0000-0000-0000-000000000005")!, text: "Compilazione registro antincendio", isCompleted: false)
        ],
        documents: [
            ProcedureDocument(
                id: UUID(uuidString: "D5000000-0000-0000-0000-000000000001")!,
                title: "Normativa UNI EN 3 – Estintori",
                notes: "Verificare conformità etichetta CE",
                photos: ["uni_en3_estratto.png"]
            ),
            ProcedureDocument(
                id: UUID(uuidString: "D5000000-0000-0000-0000-000000000002")!,
                title: "Planimetria Zone Antincendio",
                notes: nil,
                photos: ["planimetria_piano1.png", "planimetria_piano2.png"]
            )
        ]
    )
]
