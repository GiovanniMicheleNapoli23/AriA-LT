//
//  MockData.swift
//  AriaLite
//
//  Created by Giovanni Michele on 19/03/26.
//

import Foundation


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

let mockWorkOrders: [WorkOrder] = [

    // ── Mario ─────────────────────────────────────────────────────

    WorkOrder(
        id: UUID(uuidString: "A0000000-0000-0000-0000-000000000001")!,
        assignedUserID: UUID(uuidString: "00000000-0000-0000-0000-000000000001")!,
        title: "Manutenzione Generatore",
        checklist: [
            ChecklistItem(
                id: UUID(uuidString: "C1000000-0000-0000-0000-000000000001")!,
                text: "Controlla livello olio",
                description: "Apri il tappo del filtro e ispeziona visivamente per eventuali perdite. Sostituisci l'olio se il livello è sotto il minimo o se risulta scuro.",
                isCompleted: false
            ),
            ChecklistItem(
                id: UUID(uuidString: "C1000000-0000-0000-0000-000000000002")!,
                text: "Pulizia filtri aria",
                description: "Rimuovi il filtro aria e soffia via polvere e detriti con aria compressa. Sostituisci il filtro se presenta strappi o ostruzione eccessiva.",
                isCompleted: false
            ),
            ChecklistItem(
                id: UUID(uuidString: "C1000000-0000-0000-0000-000000000003")!,
                text: "Verifica cinghia di trasmissione",
                description: "Controlla la tensione della cinghia: la freccia ammessa è di 10–15 mm con pressione manuale. Verifica l'assenza di cricche o usura sui fianchi.",
                isCompleted: false
            ),
            ChecklistItem(
                id: UUID(uuidString: "C1000000-0000-0000-0000-000000000004")!,
                text: "Test avvio a freddo",
                description: "Esegui l'avvio a freddo senza preriscaldamento e verifica che il motore raggiunga il regime nominale entro 30 secondi. Annota eventuali anomalie sonore.",
                isCompleted: false
            )
        ],
        documents: [
            ProcedureDocument(
                id: UUID(uuidString: "D1000000-0000-0000-0000-000000000001")!,
                title: "Manuale Generatore XG-500",
                notes: "Fare riferimento a pag. 12 per le specifiche olio. Usare esclusivamente olio SAE 10W-40 certificato API SL.",
                photos: ["manuale_xg500_copertina.png"]
            ),
            ProcedureDocument(
                id: UUID(uuidString: "D1000000-0000-0000-0000-000000000002")!,
                title: "Schema Manutenzione Periodica",
                notes: "Cadenza interventi: ogni 250 ore di funzionamento o 6 mesi, a seconda di quale condizione si verifica prima.",
                photos: []
            )
        ],
        scheduledDate: today()
    ),

    WorkOrder(
        id: UUID(uuidString: "A0000000-0000-0000-0000-000000000002")!,
        assignedUserID: UUID(uuidString: "00000000-0000-0000-0000-000000000001")!,
        title: "Sostituzione Pompa Idraulica",
        checklist: [
            ChecklistItem(
                id: UUID(uuidString: "C2000000-0000-0000-0000-000000000001")!,
                text: "Scarico pressione impianto",
                description: "Prima di qualsiasi intervento, portare la pressione dell'impianto a zero tramite la valvola di sfogo dedicata. Attendere 5 minuti prima di procedere.",
                isCompleted: false
            ),
            ChecklistItem(
                id: UUID(uuidString: "C2000000-0000-0000-0000-000000000002")!,
                text: "Rimozione pompa vecchia",
                description: "Disconnetti i raccordi idraulici e i cavi elettrici della pompa. Utilizza bacinella di raccolta per il fluido residuo e smaltiscilo correttamente.",
                isCompleted: false
            ),
            ChecklistItem(
                id: UUID(uuidString: "C2000000-0000-0000-0000-000000000003")!,
                text: "Installazione pompa nuova",
                description: "Posiziona la nuova pompa rispettando l'orientamento indicato nello schema. Applica sigillante Loctite 577 sui filetti prima del serraggio.",
                isCompleted: false
            ),
            ChecklistItem(
                id: UUID(uuidString: "C2000000-0000-0000-0000-000000000004")!,
                text: "Test tenuta sotto pressione",
                description: "Porta l'impianto gradualmente a pressione nominale (80 bar) e mantienila per 10 minuti. Verifica visivamente l'assenza di perdite su tutti i raccordi.",
                isCompleted: false
            ),
            ChecklistItem(
                id: UUID(uuidString: "C2000000-0000-0000-0000-000000000005")!,
                text: "Firma modulo collaudo",
                description: "Compila e firma il modulo di collaudo con data, pressione rilevata e nominativo del tecnico. Allegare copia al fascicolo macchina.",
                isCompleted: false
            )
        ],
        documents: [
            ProcedureDocument(
                id: UUID(uuidString: "D2000000-0000-0000-0000-000000000001")!,
                title: "Scheda Tecnica Pompa P-200",
                notes: "Coppia di serraggio raccordi: 45 Nm. Portata nominale: 12 L/min a 1450 rpm. Fluido consigliato: ISO VG 46.",
                photos: ["pompa_p200_schema.png", "pompa_p200_dettaglio.png"]
            )
        ],
        scheduledDate: daysAgo(1)
    ),

    // ── Luisa ─────────────────────────────────────────────────────

    WorkOrder(
        id: UUID(uuidString: "A0000000-0000-0000-0000-000000000003")!,
        assignedUserID: UUID(uuidString: "00000000-0000-0000-0000-000000000002")!,
        title: "Ispezione Quadro Elettrico",
        checklist: [
            ChecklistItem(
                id: UUID(uuidString: "C3000000-0000-0000-0000-000000000001")!,
                text: "Verifica interruttori differenziali",
                description: "Premi il pulsante di test su ogni differenziale e verifica che scatti correttamente. Annota gli ID di quelli che non rispondono per sostituzione immediata.",
                isCompleted: false
            ),
            ChecklistItem(
                id: UUID(uuidString: "C3000000-0000-0000-0000-000000000002")!,
                text: "Controllo serraggi morsetti",
                description: "Con cacciavite a croce misura la resistenza al serraggio di tutti i morsetti. I morsetti allentati sono causa primaria di archi elettrici e surriscaldamenti.",
                isCompleted: false
            ),
            ChecklistItem(
                id: UUID(uuidString: "C3000000-0000-0000-0000-000000000003")!,
                text: "Misurazione isolamento cavi",
                description: "Usa il megaohmmetro a 500V DC su ogni linea in uscita dal quadro. Il valore minimo accettabile è 1 MΩ; sotto soglia il cavo va sostituito.",
                isCompleted: false
            )
        ],
        documents: [
            ProcedureDocument(
                id: UUID(uuidString: "D3000000-0000-0000-0000-000000000001")!,
                title: "Schema Quadro Generale",
                notes: "Schema aggiornato al 2023. Verificare che corrisponda allo stato fisico del quadro; segnalare eventuali discrepanze al responsabile tecnico.",
                photos: []
            )
        ],
        scheduledDate: today()
    ),

    WorkOrder(
        id: UUID(uuidString: "A0000000-0000-0000-0000-000000000004")!,
        assignedUserID: UUID(uuidString: "00000000-0000-0000-0000-000000000002")!,
        title: "Calibrazione Sensori Temperatura",
        checklist: [
            ChecklistItem(
                id: UUID(uuidString: "C4000000-0000-0000-0000-000000000001")!,
                text: "Connessione al calibratore certificato",
                description: "Collega il sensore al calibratore di riferimento tramite adattatore appropriato. Verifica che il calibratore abbia il certificato di taratura in corso di validità.",
                isCompleted: false
            ),
            ChecklistItem(
                id: UUID(uuidString: "C4000000-0000-0000-0000-000000000002")!,
                text: "Verifica punto zero (0°C)",
                description: "Immergi il sensore nel bagno di ghiaccio fondente (0°C ± 0.1°C). Attendi 3 minuti per la stabilizzazione e registra il valore letto dal sensore.",
                isCompleted: false
            ),
            ChecklistItem(
                id: UUID(uuidString: "C4000000-0000-0000-0000-000000000003")!,
                text: "Verifica punto pieno (100°C)",
                description: "Porta il bagno termico a 100°C e attendi la stabilizzazione per almeno 5 minuti. Lo scostamento max ammesso rispetto al calibratore è ±0.5°C.",
                isCompleted: false
            ),
            ChecklistItem(
                id: UUID(uuidString: "C4000000-0000-0000-0000-000000000004")!,
                text: "Registrazione valori su modulo",
                description: "Trascrivi i valori rilevati nei campi del modulo ISO-9001 allegato. Il modulo va firmato, datato e archiviato nel sistema documentale entro 24 ore.",
                isCompleted: false
            )
        ],
        documents: [
            ProcedureDocument(
                id: UUID(uuidString: "D4000000-0000-0000-0000-000000000001")!,
                title: "Procedura Calibrazione ISO-9001",
                notes: "Scostamento massimo ammesso: ±0.5°C. In caso di superamento della soglia il sensore va dichiarato non conforme e sostituito prima della rimessa in servizio.",
                photos: ["calibrazione_procedura.pdf"]
            )
        ],
        scheduledDate: daysAgo(3)
    ),

    // ── Giovanni ──────────────────────────────────────────────────

    WorkOrder(
        id: UUID(uuidString: "A0000000-0000-0000-0000-000000000005")!,
        assignedUserID: UUID(uuidString: "00000000-0000-0000-0000-000000000003")!,
        title: "Revisione Impianto Antincendio",
        checklist: [
            ChecklistItem(
                id: UUID(uuidString: "C5000000-0000-0000-0000-000000000001")!,
                text: "Verifica estintori (scadenza e carica)",
                description: "Controlla l'etichetta di scadenza su ogni estintore e verifica che l'indicatore di pressione sia nel range verde. Gli estintori scaduti vanno isolati e segnalati per revisione.",
                isCompleted: false
            ),
            ChecklistItem(
                id: UUID(uuidString: "C5000000-0000-0000-0000-000000000002")!,
                text: "Test rilevatori di fumo",
                description: "Usa lo spray apposito (non accendino o fiamma) per testare ogni rilevatore. Verifica che la centrale di allarme riceva correttamente il segnale entro 10 secondi.",
                isCompleted: false
            ),
            ChecklistItem(
                id: UUID(uuidString: "C5000000-0000-0000-0000-000000000003")!,
                text: "Controllo porte tagliafuoco",
                description: "Verifica che le porte tagliafuoco si chiudano automaticamente al rilascio. Controlla l'integrità delle guarnizioni intumescenti e l'assenza di ostruzioni.",
                isCompleted: false
            ),
            ChecklistItem(
                id: UUID(uuidString: "C5000000-0000-0000-0000-000000000004")!,
                text: "Ispezione naspi e idranti",
                description: "Svolgi parzialmente la manichetta di ogni naspo e verifica l'assenza di cricche o perdite. Controlla che la lancia sia presente e che il raccordo idrante non sia ossidato.",
                isCompleted: false
            ),
            ChecklistItem(
                id: UUID(uuidString: "C5000000-0000-0000-0000-000000000005")!,
                text: "Compilazione registro antincendio",
                description: "Compila il registro antincendio con data, esito di ogni verifica e nominativo del tecnico. Il registro deve essere conservato in loco e disponibile per ispezioni dei VVF.",
                isCompleted: false
            )
        ],
        documents: [
            ProcedureDocument(
                id: UUID(uuidString: "D5000000-0000-0000-0000-000000000001")!,
                title: "Normativa UNI EN 3 – Estintori",
                notes: "Verificare conformità etichetta CE e presenza del numero di matricola. Gli estintori privi di marcatura CE non possono essere rimessi in servizio.",
                photos: ["uni_en3_estratto.png"]
            ),
            ProcedureDocument(
                id: UUID(uuidString: "D5000000-0000-0000-0000-000000000002")!,
                title: "Planimetria Zone Antincendio",
                notes: "Planimetria aggiornata a Gennaio 2024. Verificare che i percorsi di esodo indicati siano liberi da ostacoli prima di chiudere il verbale.",
                photos: ["planimetria_piano1.png", "planimetria_piano2.png"]
            )
        ],
        scheduledDate: today()
    ),

    // Work order passato aggiuntivo per Giovanni (per testare la sezione Passati)
    WorkOrder(
        id: UUID(uuidString: "A0000000-0000-0000-0000-000000000006")!,
        assignedUserID: UUID(uuidString: "00000000-0000-0000-0000-000000000003")!,
        title: "Controllo UPS Sala Server",
        checklist: [
            ChecklistItem(
                id: UUID(uuidString: "C6000000-0000-0000-0000-000000000001")!,
                text: "Verifica stato batterie UPS",
                description: "Accedi al pannello di controllo dell'UPS e controlla lo stato di salute delle batterie (SOH%). Sostituire le batterie se SOH scende sotto l'80%.",
                isCompleted: true
            ),
            ChecklistItem(
                id: UUID(uuidString: "C6000000-0000-0000-0000-000000000002")!,
                text: "Test bypass manuale",
                description: "Esegui il trasferimento in bypass manuale seguendo la procedura del manuale. Verifica che i carichi rimangano alimentati durante tutta la manovra senza interruzioni.",
                isCompleted: true
            ),
            ChecklistItem(
                id: UUID(uuidString: "C6000000-0000-0000-0000-000000000003")!,
                text: "Pulizia filtri ventilazione",
                description: "Rimuovi i filtri frontali e soffia via la polvere con aria compressa a bassa pressione. Filtri molto intasati vanno sostituiti per evitare surriscaldamenti.",
                isCompleted: true
            )
        ],
        documents: [
            ProcedureDocument(
                id: UUID(uuidString: "D6000000-0000-0000-0000-000000000001")!,
                title: "Manuale UPS APC Smart-UPS 3000",
                notes: "Per il test di autonomia seguire la procedura a pag. 34. Durata minima attesa con carico al 50%: 18 minuti.",
                photos: ["ups_apc_manuale.png"]
            )
        ],
        scheduledDate: daysAgo(5)
    )
]
