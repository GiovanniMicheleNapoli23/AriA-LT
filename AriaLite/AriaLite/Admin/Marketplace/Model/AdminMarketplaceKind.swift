//
//  AdminMarketplaceKind.swift
//  AriaLite
//
//  Created by Giovanni Michele on 23/10/26.
//
//  I due assi del catalogo, come in catalog.ts della web: il tipo (le schede in alto, nell'ordine della web)
//  e l'area dell'impianto (l'unica scala che i chip filtrano, uguale per ogni tipo).
//

import Foundation

nonisolated enum AdminMarketplaceKind: String, Decodable, Sendable, CaseIterable, Identifiable {
    // Ordine delle schede della web: i più chiesti prima, i pacchetti dopo quello che contengono.
    case skill
    case connector
    case plugin
    case workflow
    case agentPack = "agent-pack"
    case knowledgePack = "knowledge-pack"
    case fullSet = "full-set"

    var id: String { rawValue }

    var label: String {
        switch self {
        case .skill: String(localized: "Skill")
        case .connector: String(localized: "Connector")
        case .plugin: String(localized: "Plugin")
        case .workflow: String(localized: "Workflow")
        case .agentPack: String(localized: "Agent pack")
        case .knowledgePack: String(localized: "Knowledge pack")
        case .fullSet: String(localized: "Full set")
        }
    }

    var plural: String {
        switch self {
        case .skill: String(localized: "Skills")
        case .connector: String(localized: "Connectors")
        case .plugin: String(localized: "Plugins")
        case .workflow: String(localized: "Workflows")
        case .agentPack: String(localized: "Agent packs")
        case .knowledgePack: String(localized: "Knowledge packs")
        case .fullSet: String(localized: "Full sets")
        }
    }

    var blurb: String {
        switch self {
        case .skill: String(localized: "One job, done the way your plant does it.")
        case .connector: String(localized: "The systems Aria can read and write.")
        case .plugin: String(localized: "Several skills and the connectors they assume, in one move.")
        case .workflow: String(localized: "A chain that runs on a schedule or a plant event.")
        case .agentPack: String(localized: "A whole persona: rules, vocabulary and the skills of a role.")
        case .knowledgePack: String(localized: "The vocabulary and written procedure of a discipline.")
        case .fullSet: String(localized: "Everything for one machine — agent, skills, knowledge and workflows.")
        }
    }

    var systemImage: String {
        switch self {
        case .skill: "sparkles"
        case .connector: "cable.connector"
        case .plugin: "puzzlepiece.extension"
        case .workflow: "point.3.connected.trianglepath.dotted"
        case .agentPack: "person.crop.rectangle.stack"
        case .knowledgePack: "books.vertical"
        case .fullSet: "shippingbox"
        }
    }

    /// Il titolo della lista "cosa aggiunge" nel dettaglio, come `verb()` della web.
    var addsTitle: String {
        switch self {
        case .workflow: String(localized: "What it runs")
        case .agentPack: String(localized: "How it makes the agent behave")
        case .knowledgePack: String(localized: "What it lets Aria answer")
        case .fullSet: String(localized: "What Aria can do on this machine")
        default: String(localized: "What it adds")
        }
    }
}

nonisolated enum AdminMarketplaceArea: String, Sendable, CaseIterable, Identifiable {
    case maintenance = "Maintenance"
    case production = "Production"
    case quality = "Quality"
    case safety = "Safety"
    case supplyChain = "Supply chain"
    case reporting = "Reporting"
    case systemsAndData = "Systems & data"

    var id: String { rawValue }

    /// Un valore nuovo della web finisce in "Sistemi e dati" invece di far saltare la scheda.
    init(raw: String?) {
        self = raw.flatMap(Self.init(rawValue:)) ?? .systemsAndData
    }

    var label: String {
        switch self {
        case .maintenance: String(localized: "Maintenance")
        case .production: String(localized: "Production")
        case .quality: String(localized: "Quality")
        case .safety: String(localized: "Safety")
        case .supplyChain: String(localized: "Supply chain")
        case .reporting: String(localized: "Reporting")
        case .systemsAndData: String(localized: "Systems & data")
        }
    }

    var blurb: String {
        switch self {
        case .maintenance: String(localized: "Failures, plans, work orders.")
        case .production: String(localized: "Lines, alarms, shifts, OEE.")
        case .quality: String(localized: "Audits, deviations, batch records.")
        case .safety: String(localized: "Permits, isolation, HSE rules.")
        case .supplyChain: String(localized: "Parts, purchasing, suppliers.")
        case .reporting: String(localized: "KPIs, energy, what a period cost.")
        case .systemsAndData: String(localized: "Other systems of record, and the channels Aria speaks through.")
        }
    }
}

/// Dove sta un elemento per questa azienda, come `Ownership` della web.
nonisolated enum AdminMarketplaceOwnership: Sendable, Hashable {
    /// Compreso nel piano (ogni connettore, quasi tutte le skill, i workflow).
    case included
    /// Comprato da questo telefono (vedi AdminMarketplacePurchases).
    case purchased
    case forSale

    var label: String {
        switch self {
        case .included: String(localized: "Included in your plan")
        case .purchased: String(localized: "Purchased")
        case .forSale: String(localized: "Not owned")
        }
    }
}
