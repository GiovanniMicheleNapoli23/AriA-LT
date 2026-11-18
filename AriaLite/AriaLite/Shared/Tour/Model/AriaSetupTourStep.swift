//
//  AriaSetupTourStep.swift
//  AriaLite
//
//  Created by Giovanni Michele on 13/11/26.
//
//  I passi di "Primi passi con AriA", nell'ordine in cui si mostrano: ognuno porta in una sezione e indica un
//  elemento. Per ogni passo: sezione della guida, destinazione, simbolo, testi (identici a quelli della web) e
//  chip. Quali passi spettano all'utente lo decide AriaSetupTourAccess.
//

import Foundation

nonisolated enum AriaSetupTourStep: String, CaseIterable, Sendable {
    case upload, extraction, agents, workflows, governance, invite, teams, connectors

    /// La sezione della guida a cui il passo appartiene.
    var section: AriaSetupTourSection {
        switch self {
        case .upload, .extraction: return .knowledge
        case .agents, .workflows, .governance: return .agents
        case .invite, .teams: return .team
        case .connectors: return .marketplace
        }
    }

    /// La sezione dell'app dove il passo si svolge.
    var destination: AriaDestination {
        switch self {
        case .upload: return .adminDocuments
        case .extraction: return .adminExtractionReview
        case .agents, .workflows, .governance: return .adminAgentStudio
        case .invite: return .adminMembers
        case .teams: return .adminTeams
        case .connectors: return .adminMarketplace
        }
    }

    /// Il posto del passo nel giro completo: serve a trovare il successivo quando un passo sparisce.
    var order: Int { Self.allCases.firstIndex(of: self) ?? 0 }

    var symbol: String {
        switch self {
        case .upload: return "doc.text"
        case .extraction: return "text.viewfinder"
        case .agents: return "cpu"
        case .workflows: return "flowchart"
        case .governance: return "shield.lefthalf.filled"
        case .invite: return "person.badge.plus"
        case .teams: return "person.3"
        case .connectors: return "puzzlepiece.extension"
        }
    }

    var title: LocalizedStringResource {
        switch self {
        case .upload: return "Upload now: precise from the first minute"
        case .extraction: return "AriA extracts your data"
        case .agents: return "Agents"
        // Chiave propria: altrove nell'app "Workflows" è tradotto "Workflow", la web qui dice "Automazioni".
        case .workflows: return LocalizedStringResource("tour.guide.workflows", defaultValue: "Workflows")
        case .governance: return "Governance"
        case .invite: return "Invite your team"
        case .teams: return "Organise people into teams"
        case .connectors: return "Your industry's best, ready to use"
        }
    }

    /// Il testo del passo. Senza nessun sito il caricamento non si può fare: la web mostra allora la variante
    /// `noPlant` ("site" al posto di "plant" nell'inglese dell'app).
    func message(hasSite: Bool = true) -> LocalizedStringResource {
        switch self {
        case .upload:
            if !hasSite {
                return "Documents are filed by site. Choose a site from the selector on Home, then come back here to upload them."
            }
            return "Upload your documents and AriA is at its most precise from day one. Otherwise it learns on the job, day by day."
        case .extraction:
            return "AriA finds them in the documents you upload. Review them here before they join your data: approve what is right, reject the rest."
        case .agents:
            return "Build and customize your agents to fit the way you work, so they stay reliable and secure."
        case .workflows:
            return "Have AriA build autonomous workflows that solve complex problems or routine tasks while you work on something else."
        case .governance:
            return "Apply your company's policies, standards and rules directly to agentic operations."
        case .invite:
            return "Send an invitation by email: each colleague gets their own account and works from the same knowledge and the same agents."
        case .teams:
            return "Group people into teams to assign work and decide what each team sees."
        case .connectors:
            return "Find and use knowledge, methods and workflows already proven in your industry. Connect the tools you already use, pick skills and plugins to boost AriA's performance, and knowledge packs to make the system as reliable as it can be."
        }
    }

    /// I chip sotto il testo: l'elenco che il testo non scrive (formati, cosa si estrae, i team).
    var chips: [LocalizedStringResource] {
        switch self {
        case .upload: return ["PDF", "Wiring diagrams", "DWG", "DXF", "DOCX", "Excel", "Others"]
        case .extraction: return ["Assets", "Alarms", "Maintenance plans", "Spare parts"]
        case .teams: return ["Maintenance", "Production", "Quality"]
        default: return []
        }
    }

    /// Il nome con cui "Avanti · …" annuncia questo passo: il titolo della pagina nel menu della web; per i
    /// passi dell'Agent Studio il nome del tab, cioè il titolo del passo.
    var screenName: LocalizedStringResource {
        switch self {
        case .upload: return "Documents"
        case .extraction: return "Extraction Review"
        case .agents, .workflows, .governance: return title
        case .invite: return "Members"
        // Chiave propria: la sidebar dell'app traduce "Teams" con "Squadre", la web qui dice "Team".
        case .teams: return LocalizedStringResource("tour.guide.teams", defaultValue: "Teams")
        case .connectors: return "Marketplace"
        }
    }
}
