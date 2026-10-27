//
//  AdminMarketplaceItem.swift
//  AriaLite
//
//  Created by Giovanni Michele on 23/10/26.
//
//  Un elemento del catalogo del Marketplace, come `MarketplaceItem` della web: skill, connettore, plugin,
//  workflow, agent pack, knowledge pack o full set. Arriva da MarketplaceCatalog.json (vedi
//  scripts/export-marketplace-catalog.mjs), già tradotto da AdminMarketplaceCatalog. Ogni tipo porta la sua
//  parte in più (`workflow`, `fullSet`, …); le altre restano nil.
//

import Foundation

nonisolated struct AdminMarketplaceItem: Decodable, Sendable, Hashable, Identifiable {
    /// Unico in tutto il catalogo: `"<kind>:<sourceId>"`.
    let id: String
    /// L'id nel suo catalogo. Per un connettore è anche il `provider` del server.
    let sourceId: String
    let kind: AdminMarketplaceKind
    let name: String
    let summary: String
    /// "Aria" per quelli del prodotto, "La tua azienda" per quelli dell'azienda.
    let publisher: String
    let area: AdminMarketplaceArea
    /// La parola del catalogo d'origine ("MES & ERP", "Life sciences"): contesto, mai un filtro.
    let descriptor: String?
    /// Il nome dell'icona Lucide della web (vedi AdminMarketplaceSymbol).
    let icon: String?
    /// Cosa aggiunge, come frasi verbali.
    let adds: [String]
    /// I connettori che si aspetta, per id (= provider).
    let needs: [String]
    let isNew: Bool
    let keywords: [String]
    /// Solo i full set: la macchina per cui sono fatti.
    let machine: Machine?
    /// Prezzo mensile in euro; nil = incluso nel piano.
    let monthlyPrice: Int?

    let connector: ConnectorInfo?
    let plugin: PluginInfo?
    let workflow: WorkflowInfo?
    let agentPack: AgentPackInfo?
    let knowledgePack: KnowledgePackInfo?
    let fullSet: FullSetInfo?

    var isIncluded: Bool { monthlyPrice == nil }

    /// Un connettore senza integrazione dietro: "in arrivo", mai da collegare né da comprare.
    var isPreview: Bool { connector?.preview == true }

    // MARK: Parti per tipo

    nonisolated struct Machine: Decodable, Sendable, Hashable {
        let manufacturer: String
        let type: String
        let model: String
        let industry: String
    }

    nonisolated struct ConnectorInfo: Decodable, Sendable, Hashable {
        let category: String
        let vendors: String
        let preview: Bool
        let custom: Bool
        /// `api-key` (MaintainX, chiave dell'azienda) o `oauth` (consenso nel browser); nil = in arrivo.
        let auth: String?
        /// `one-click`: un owner lo abilita (PUT …/register) e poi ogni membro collega il suo account.
        let setup: String?
        /// Il server MCP da registrare all'abilitazione (Composio o Notion).
        let endpoint: String?
        /// L'organizzazione la dà il primo consenso di un owner/admin (Dynamics, Salesforce).
        let orgFromConsent: Bool?
        /// Il colore del marchio, "#RRGGBB".
        let brandHex: String?
        /// Il logo nel catalogo degli asset ("ConnectorBrands/<id>"); nil se la web non ne ha uno autentico.
        let brandImage: String?

        var isOneClick: Bool { setup == "one-click" }
        var usesAPIKey: Bool { auth == "api-key" }
        /// Il consenso finisce sulla pagina web di Composio (`/connectors/composio/verify`), non sul backend.
        var isComposio: Bool {
            guard let url = endpoint.flatMap(URL.init(string:)), url.scheme == "https",
                  let host = url.host()?.lowercased() else { return false }
            return host == "composio.dev" || host.hasSuffix(".composio.dev")
        }
    }

    nonisolated struct PluginInfo: Decodable, Sendable, Hashable {
        /// Le skill che installa, per sourceId.
        let skills: [String]
    }

    nonisolated struct WorkflowInfo: Decodable, Sendable, Hashable {
        /// Già in parole: "Every day at 07:00", "When an alarm is raised".
        let trigger: String
        let steps: [Step]

        nonisolated struct Step: Decodable, Sendable, Hashable {
            /// `connector`, `agent` o `action`.
            let kind: String
            let title: String
            let detail: String?
            /// Solo per `connector`.
            let connectorId: String?
        }
    }

    nonisolated struct AgentPackInfo: Decodable, Sendable, Hashable {
        /// L'agente che configura (nome interno, non tradotto).
        let agent: String
        let role: String
        let rules: Int
        let terms: Int
        /// Le skill che porta con sé, per sourceId.
        let skills: [String]
    }

    nonisolated struct KnowledgePackInfo: Decodable, Sendable, Hashable {
        let discipline: String
        let terms: Int
        let procedures: Int
        let standards: [String]?
    }

    nonisolated struct FullSetInfo: Decodable, Sendable, Hashable {
        let rules: [String]
        let policies: [Policy]
        /// Gli altri elementi che installa, per id globale (`"skill:shift-handover"`).
        let components: [String]
        let facts: [String]
        let glossary: [GlossaryEntry]
        let procedures: [Procedure]
        let learned: [LearnedFact]
        let alarms: [Alarm]
        let maintenancePlans: [MaintenancePlan]
        let spareParts: [SparePart]
        let checklists: [Checklist]
        let documents: [Document]

        /// Tutte le voci che il set scrive, nei cinque posti: il numero della scheda.
        var entryCount: Int {
            rules.count + facts.count + glossary.count + procedures.count + learned.count + alarms.count
                + maintenancePlans.count + spareParts.count + checklists.count + documents.count + policies.count
        }

        nonisolated struct Policy: Decodable, Sendable, Hashable {
            /// Approval, Escalation, Access, Data (già tradotto).
            let label: String
            let text: String
        }

        nonisolated struct GlossaryEntry: Decodable, Sendable, Hashable {
            let term: String
            let definition: String
        }

        nonisolated struct Procedure: Decodable, Sendable, Hashable {
            let title: String
            let steps: [String]
        }

        nonisolated struct LearnedFact: Decodable, Sendable, Hashable {
            let content: String
            let context: String
            let category: String
        }

        nonisolated struct Alarm: Decodable, Sendable, Hashable {
            let code: String
            let description: String
            let category: String
            let typicalCauses: [String]
            let resolutionSteps: [String]
        }

        nonisolated struct MaintenancePlan: Decodable, Sendable, Hashable {
            let name: String
            /// daily, weekly, monthly, quarterly, yearly o custom (a ore di marcia): vedi `frequencyLabel`.
            let frequency: String
            let durationMinutes: Int
            let steps: [String]
        }

        nonisolated struct SparePart: Decodable, Sendable, Hashable {
            let code: String
            let name: String
            let category: String
        }

        nonisolated struct Checklist: Decodable, Sendable, Hashable {
            let name: String
            let tasks: [String]
        }

        nonisolated struct Document: Decodable, Sendable, Hashable {
            let title: String
            let note: String
        }
    }

    // MARK: Decodifica

    private enum CodingKeys: String, CodingKey {
        case id, sourceId, kind, name, summary, publisher, area, descriptor, icon, adds, needs, isNew, keywords
        case machine, monthlyPrice, connector, plugin, workflow, agentPack, knowledgePack, fullSet
    }

    init(from decoder: any Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(String.self, forKey: .id)
        sourceId = try c.decode(String.self, forKey: .sourceId)
        kind = try c.decode(AdminMarketplaceKind.self, forKey: .kind)
        name = try c.decode(String.self, forKey: .name)
        summary = try c.decodeIfPresent(String.self, forKey: .summary) ?? ""
        publisher = try c.decodeIfPresent(String.self, forKey: .publisher) ?? "Aria"
        area = AdminMarketplaceArea(raw: try c.decodeIfPresent(String.self, forKey: .area))
        descriptor = try c.decodeIfPresent(String.self, forKey: .descriptor)
        icon = try c.decodeIfPresent(String.self, forKey: .icon)
        adds = try c.decodeIfPresent([String].self, forKey: .adds) ?? []
        needs = try c.decodeIfPresent([String].self, forKey: .needs) ?? []
        isNew = try c.decodeIfPresent(Bool.self, forKey: .isNew) ?? false
        keywords = try c.decodeIfPresent([String].self, forKey: .keywords) ?? []
        machine = try c.decodeIfPresent(Machine.self, forKey: .machine)
        monthlyPrice = try c.decodeIfPresent(Int.self, forKey: .monthlyPrice)
        connector = try c.decodeIfPresent(ConnectorInfo.self, forKey: .connector)
        plugin = try c.decodeIfPresent(PluginInfo.self, forKey: .plugin)
        workflow = try c.decodeIfPresent(WorkflowInfo.self, forKey: .workflow)
        agentPack = try c.decodeIfPresent(AgentPackInfo.self, forKey: .agentPack)
        knowledgePack = try c.decodeIfPresent(KnowledgePackInfo.self, forKey: .knowledgePack)
        fullSet = try c.decodeIfPresent(FullSetInfo.self, forKey: .fullSet)
    }
}

// MARK: - Testi derivati

extension AdminMarketplaceItem {
    /// Il numero della scheda: "4 skill", "6 passi", "12 termini · 3 procedure".
    var scale: String {
        switch kind {
        case .skill:
            String(localized: "\(adds.count) abilities")
        case .plugin:
            String(localized: "\(plugin?.skills.count ?? 0) skills")
        case .connector:
            String(localized: "\(adds.count) capabilities")
        case .workflow:
            String(localized: "\(workflow?.steps.count ?? 0) steps")
        case .agentPack:
            [String(localized: "\(agentPack?.rules ?? 0) rules"),
             String(localized: "\(agentPack?.terms ?? 0) terms")].joined(separator: " · ")
        case .knowledgePack:
            [String(localized: "\(knowledgePack?.terms ?? 0) terms"),
             String(localized: "\(knowledgePack?.procedures ?? 0) procedures")].joined(separator: " · ")
        case .fullSet:
            [String(localized: "\(fullSet?.entryCount ?? 0) entries"),
             String(localized: "\(fullSet?.components.count ?? 0) components")].joined(separator: " · ")
        }
    }

    /// "29 €/mese"; nil se è incluso nel piano.
    var priceText: String? {
        guard let monthlyPrice else { return nil }
        let amount = monthlyPrice.formatted(.currency(code: "EUR").precision(.fractionLength(0)))
        return String(localized: "\(amount)/mo")
    }

    /// Tutto quello che la ricerca deve raggiungere: chi scrive "pareto", "ALCOA" o un codice allarme
    /// sta nominando quello che vuole, non il nome della scheda.
    nonisolated var searchHaystack: [String] {
        var text = [name, summary, publisher, area.label, kind.label, descriptor ?? ""] + adds + keywords
        if let machine {
            text += [machine.manufacturer, machine.type, machine.model, machine.industry]
        }
        if let fullSet {
            text += fullSet.alarms.map { "\($0.code) \($0.description)" }
            text += fullSet.glossary.map(\.term)
            text += fullSet.spareParts.map(\.name)
            text += fullSet.procedures.map(\.title)
        }
        return text
    }

    func matches(_ query: String) -> Bool {
        let query = query.trimmingCharacters(in: .whitespacesAndNewlines)
        return query.isEmpty || searchHaystack.contains { $0.localizedStandardContains(query) }
    }
}

extension AdminMarketplaceItem.FullSetInfo.MaintenancePlan {
    /// "Trimestrale · 45 min"; `custom` è a ore di marcia.
    var frequencyLabel: String {
        let frequency = switch frequency {
        case "daily": String(localized: "Daily")
        case "weekly": String(localized: "Weekly")
        case "monthly": String(localized: "Monthly")
        case "quarterly": String(localized: "Quarterly")
        case "yearly": String(localized: "Yearly")
        case "custom": String(localized: "On running hours")
        default: frequency.prefix(1).uppercased() + frequency.dropFirst()
        }
        return "\(frequency) · \(durationMinutes) min"
    }
}
