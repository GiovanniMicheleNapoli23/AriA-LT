//
//  AdminMarketplaceItemDetailViewModel.swift
//  AriaLite
//
//  Created by Giovanni Michele on 23/10/26.
//
//  La pagina di un elemento del Marketplace (item-detail.tsx della web): stato e acquisto, riga di
//  contesto, requisiti, fatti e il corpo per tipo (catena del workflow, struttura del full set, skill che
//  porta un pacchetto). Tutta la logica è qui; le viste disegnano soltanto. Il catalogo è già tradotto:
//  i suoi testi passano così come sono, le etichette dell'interfaccia no. Un connettore senza riga sul
//  server si abilita o si collega da qui (come connectorAction della web); il consenso passa da
//  AdminConnectorConsentFlow, lo stesso della pagina del connettore.
//

import Foundation
import Observation

@MainActor
@Observable
final class AdminMarketplaceItemDetailViewModel {
    let item: AdminMarketplaceItem
    /// Il Marketplace padre: da lì si leggono acquisti e connessioni, così la pagina resta viva dopo "Acquista".
    private let marketplace: AdminMarketplaceViewModel

    /// L'alert di conferma dell'acquisto.
    var confirmsPurchase = false

    /// Un'azione sul connettore in corso (abilita, consenso): il pulsante si spegne.
    private(set) var isWorking = false
    /// Esito positivo o prossimo passo, in una riga sotto lo stato.
    private(set) var actionNotice: String?
    /// Il consenso è stato aperto nel browser: al ritorno nell'app si ricaricano i connettori.
    private(set) var awaitingConsent = false
    /// Composio: c'è un progetto sul server per questo connettore? Solo per chi può abilitarlo.
    private(set) var availability: AdminMarketplaceConnectorAvailability = .unknown
    var actionError: String?
    /// Il form della chiave (MaintainX) aperto da qui.
    var credentialsForm: AdminConnectorCredentialsFormViewModel?
    @ObservationIgnored private var didInspect = false

    /// Per `.alert`: chiuderlo azzera l'errore.
    var showsActionError: Bool {
        get { actionError != nil }
        set { if !newValue { actionError = nil } }
    }

    init(item: AdminMarketplaceItem, marketplace: AdminMarketplaceViewModel) {
        self.item = item
        self.marketplace = marketplace
    }

    // MARK: Intestazione

    var ownership: AdminMarketplaceOwnership { marketplace.ownership(of: item) }

    var isPurchased: Bool { ownership == .purchased }

    /// "Skill · MES & ERP · Aria": le parti che mancano saltano.
    var metaLine: String {
        [item.kind.label, item.descriptor, item.publisher]
            .compactMap { $0 }
            .filter { !$0.isEmpty }
            .joined(separator: " · ")
    }

    // MARK: Acquisto e stato

    var canBuy: Bool { marketplace.canBuy(item) }

    /// Cosa mostra la scheda sotto l'intestazione: il pulsante "Acquista…", lo stato dell'elemento o, per un
    /// connettore, le sue azioni.
    var action: AdminMarketplaceItemAction {
        if canBuy { return .buy(price: item.priceText ?? priceAmount) }
        // Un connettore non si compra: si abilita o si collega. Senza integrazione dietro è "in arrivo".
        if item.kind == .connector {
            if item.isPreview {
                return .status(AdminMarketplaceItemStatus(
                    title: String(localized: "Coming soon"), systemImage: "clock", isOwned: false,
                    note: String(localized: "This connector isn't available yet.")))
            }
            return .connector(connectorPanel)
        }
        switch ownership {
        case .included, .purchased:
            return .status(AdminMarketplaceItemStatus(
                title: ownership.label, systemImage: "checkmark.circle.fill", isOwned: true, note: nil))
        case .forSale:
            // In vendita ma non acquistabile da questo ruolo: chi può gestire l'azienda lo fa al posto suo.
            let note = marketplace.canManage ? nil : String(localized: "Ask a company owner or admin to buy it.")
            return .status(AdminMarketplaceItemStatus(
                title: ownership.label, systemImage: "bag", isOwned: false, note: note))
        }
    }

    var purchaseTitle: String { String(localized: "Buy \(item.name)") }

    var purchaseMessage: String {
        let terms = String(localized: "\(item.kind.label) by \(item.publisher). It's added to your company's plan for \(priceAmount) a month.")
        let billing = String(localized: "Billing isn't live yet: the purchase is recorded on this device.")
        return terms + " " + billing
    }

    /// Il prezzo senza "/mese": la frase dell'alert ha già "al mese".
    private var priceAmount: String {
        item.monthlyPrice?.formatted(.currency(code: "EUR").precision(.fractionLength(0))) ?? ""
    }

    func buy() {
        guard canBuy else { return }
        marketplace.purchase(item)
    }

    // MARK: Connettore

    private var provider: String { item.sourceId }

    /// Sul server c'è la riga? Allora la pagina dice com'è e porta al connettore; altrimenti propone il primo passo.
    private var connectorPanel: AdminMarketplaceConnectorPanel {
        if let row = marketplace.connector(for: provider) { return panel(for: row) }
        guard let info = item.connector else { return notSetUp }
        // Come `connectorAction` della web: un membro non abilita né collega, dice a chi chiedere.
        guard marketplace.canManage else {
            return AdminMarketplaceConnectorPanel(status: askAdmin, command: nil, isChecking: false, openProvider: nil)
        }
        if info.isOneClick {
            if needsInspection, availability == .unavailable {
                return AdminMarketplaceConnectorPanel(
                    status: AdminMarketplaceItemStatus(
                        title: nil, systemImage: "exclamationmark.circle", isOwned: false,
                        note: String(localized: "This connector isn't available on this server yet.")),
                    command: nil, isChecking: false, openProvider: nil)
            }
            return offering(.enable, checking: needsInspection && availability == .checking)
        }
        if info.usesAPIKey { return offering(.connectWithKey) }
        if info.auth == "oauth" { return offering(.connect) }
        return notSetUp
    }

    private func offering(_ command: AdminMarketplaceConnectorCommand, checking: Bool = false) -> AdminMarketplaceConnectorPanel {
        AdminMarketplaceConnectorPanel(status: nil, command: command, isChecking: checking, openProvider: nil)
    }

    private var askAdmin: AdminMarketplaceItemStatus {
        AdminMarketplaceItemStatus(title: nil, systemImage: "link.badge.plus", isOwned: false,
                                   note: String(localized: "Ask a company owner or admin to enable it."))
    }

    private var notSetUp: AdminMarketplaceConnectorPanel {
        AdminMarketplaceConnectorPanel(
            status: AdminMarketplaceItemStatus(
                title: nil, systemImage: "link.badge.plus", isOwned: false,
                note: String(localized: "Not set up for your company yet. Connect it from Aria on the web.")),
            command: nil, isChecking: false, openProvider: nil)
    }

    /// La riga esiste: lo stato (per un connettore per-membro, quello del mio account) e il link al connettore.
    private func panel(for row: AdminConnector) -> AdminMarketplaceConnectorPanel {
        let grant = row.isPerMember ? row.myGrant : nil
        let status: AdminMarketplaceItemStatus
        if row.isPerMember, grant == nil {
            status = AdminMarketplaceItemStatus(
                title: String(localized: "Your account isn't connected"), systemImage: AdminConnectorStatus.disconnected.systemImage,
                isOwned: false, note: nil)
        } else {
            let raw = grant?.status ?? row.status
            let known = AdminConnectorStatus(raw: raw)
            let note = known == .connected
                ? grant?.accountEmail.map { String(localized: "Connected as \($0)") }
                : (grant?.lastError ?? row.lastError)
            status = AdminMarketplaceItemStatus(
                title: AdminConnectorStatus.label(for: raw), systemImage: known.systemImage,
                isOwned: known == .connected, note: note)
        }
        return AdminMarketplaceConnectorPanel(status: status, command: nil, isChecking: false, openProvider: row.provider)
    }

    /// Composio, senza riga, per chi può abilitare: prima si chiede al server se ha il progetto.
    private var needsInspection: Bool {
        guard let info = item.connector else { return false }
        return info.isOneClick && info.isComposio && marketplace.canManage && !marketplace.hasServerConnector(provider)
    }

    /// Una volta sola per pagina (il view model resta in cache). Se la domanda fallisce si lascia abilitare:
    /// il server rifiuterà lui se serve.
    func prepare() async {
        guard needsInspection, !didInspect, let companyId = marketplace.backend.activeCompanyId,
              let endpoint = item.connector?.endpoint else { return }
        didInspect = true
        availability = .checking
        do {
            let inspection = try await marketplace.backend.api.call(
                AdminMarketplaceAPI.inspectOAuth(companyId: companyId, AdminConnectorInspectRequest(mcpUrl: endpoint)))
            availability = inspection.platformClientAvailable == false ? .unavailable : .available
        } catch {
            availability = .unknown
            // La pagina è sparita a metà: la prossima volta si riprova.
            didInspect = !Task.isCancelled
        }
    }

    func run(_ command: AdminMarketplaceConnectorCommand,
             authenticate: AdminConnectorConsentFlow.Authenticate, open: AdminConnectorConsentFlow.Open) async {
        AriaAuthTrace.step("connector.run", "\(command) \(provider)")
        switch command {
        case .connectWithKey: openCredentialsForm()
        case .enable: await enable(authenticate: authenticate, open: open)
        case .connect: await connect(authenticate: authenticate, open: open)
        }
    }

    /// Abilita un one-click: registra il server (mai su una riga che c'è già) e poi parte il consenso di chi
    /// chiama. Se il consenso fallisce o si annulla la riga resta, e la pagina offre "Apri connettore".
    private func enable(authenticate: AdminConnectorConsentFlow.Authenticate, open: AdminConnectorConsentFlow.Open) async {
        guard let info = item.connector, let endpoint = info.endpoint else { return }
        await perform { companyId in
            // La lista può non essere ancora arrivata: senza di lei non si sa se la riga c'è già.
            if !marketplace.hasLoaded { await marketplace.load() }
            if !marketplace.hasServerConnector(provider) {
                let body = AdminConnectorRegister(mcpUrl: endpoint, connectionScope: "user", displayName: item.name)
                let row = try await marketplace.backend.api.call(
                    AdminMarketplaceAPI.register(companyId: companyId, provider: provider, body))
                marketplace.apply(row)
            }
            let start = try await marketplace.backend.api.call(
                AdminMarketplaceAPI.startMyOAuth(companyId: companyId, provider: provider))
            let outcome = await consentFlow.run(authorizeURL: start.authorizeUrl, composio: info.isComposio,
                                                fallbackName: item.name, authenticate: authenticate, open: open)
            await finish(outcome)
        }
    }

    /// Odoo: consenso aziendale in sola lettura; il backend chiude il ritorno, al rientro si ricarica.
    private func connect(authenticate: AdminConnectorConsentFlow.Authenticate, open: AdminConnectorConsentFlow.Open) async {
        await perform { companyId in
            let start = try await marketplace.backend.api.call(
                AdminMarketplaceAPI.startOAuth(companyId: companyId, provider: provider, requestWrite: false))
            let outcome = await consentFlow.run(authorizeURL: start.authorizeUrl, composio: false,
                                                fallbackName: item.name, authenticate: authenticate, open: open)
            await finish(outcome)
        }
    }

    private var consentFlow: AdminConnectorConsentFlow { AdminConnectorConsentFlow(backend: marketplace.backend) }

    private func finish(_ outcome: AdminConnectorConsentFlow.Outcome) async {
        AriaAuthTrace.step("connector.outcome", String(describing: outcome))
        switch outcome {
        case .connected(let notice):
            actionNotice = notice
            await marketplace.load()
        case .cancelled:
            await marketplace.load()
        case .browser(let notice):
            awaitingConsent = true
            actionNotice = notice
        case .failed(let message):
            actionError = message
        }
    }

    /// L'app torna in primo piano dopo il consenso nel browser: si rilegge la lista una volta.
    func returnedFromConsent() async {
        guard awaitingConsent else { return }
        awaitingConsent = false
        actionNotice = nil
        await marketplace.load()
    }

    /// MaintainX: la chiave dell'azienda si incolla nel form; salvata, la riga entra nella lista.
    private func openCredentialsForm() {
        credentialsForm = AdminConnectorCredentialsFormViewModel(
            backend: marketplace.backend, maintainX: nil, onSaved: { [weak self] in self?.marketplace.apply($0) })
    }

    func credentialsSaved() async {
        actionNotice = String(localized: "Credential saved and verified.")
        await marketplace.load()
    }

    /// Un'azione alla volta, con l'errore in un avviso.
    private func perform(_ action: (String) async throws -> Void) async {
        guard let companyId = marketplace.backend.activeCompanyId else {
            actionError = AriaError.missingCompany.localizedDescription
            return
        }
        isWorking = true
        actionNotice = nil
        defer { isWorking = false }
        do {
            try await action(companyId)
        } catch {
            AriaAuthTrace.step("connector.error", String(describing: error))
            actionError = AdminMarketplaceFailure.message(for: error, backend: marketplace.backend)
        }
    }

    // MARK: Richiede

    /// I connettori che l'elemento si aspetta, senza doppioni, con il nome e se sono collegati.
    var requirements: [AdminMarketplaceRequirement] {
        var seen = Set<String>()
        return item.needs.filter { seen.insert($0).inserted }.map { provider in
            AdminMarketplaceRequirement(
                id: provider, name: marketplace.connectorName(provider), isConnected: marketplace.isConnected(provider))
        }
    }

    /// "2/3 connected".
    var requiresSummary: String {
        let list = requirements
        return String(localized: "\(list.filter(\.isConnected).count)/\(list.count) connected")
    }

    // MARK: Dettagli

    var facts: [AdminMarketplaceFact] {
        var rows = [AdminMarketplaceFact(label: String(localized: "License"), value: ownership.label)]
        // Un full set è fatto per una macchina: la scheda dice quale, con le parole dei filtri della vetrina.
        if let machine = item.machine {
            rows += [
                AdminMarketplaceFact(label: String(localized: "Manufacturer"), value: machine.manufacturer),
                AdminMarketplaceFact(label: String(localized: "Model"), value: machine.model),
                AdminMarketplaceFact(label: String(localized: "Machine"), value: machine.type),
                AdminMarketplaceFact(label: String(localized: "Industry"), value: machine.industry)
            ]
        }
        rows += [
            AdminMarketplaceFact(label: String(localized: "Publisher"), value: item.publisher),
            AdminMarketplaceFact(label: String(localized: "Area"), value: item.area.label),
            AdminMarketplaceFact(
                label: item.kind == .connector ? String(localized: "Surface") : String(localized: "Size"),
                value: item.scale)
        ]
        return rows
    }

    // MARK: Corpo per tipo

    var bodyKind: AdminMarketplaceItemBody {
        switch item.kind {
        case .workflow where item.workflow != nil: .workflow
        case .fullSet where item.fullSet != nil: .fullSet
        default: .adds
        }
    }

    /// Il tocco su un componente o una skill porta alla sua pagina.
    func route(for other: AdminMarketplaceItem) -> AdminMarketplaceRoute {
        marketplace.route(for: other)
    }

    // MARK: Workflow

    /// "Come funziona": il trigger e poi un passo per riga, nell'ordine in cui girano.
    var timeline: [AdminMarketplaceTimelineRow] {
        guard let workflow = item.workflow else { return [] }
        let trigger = AdminMarketplaceTimelineRow(
            id: 0, tag: String(localized: "Trigger"), systemImage: "bolt", title: workflow.trigger, detail: nil)
        let steps = workflow.steps.enumerated().map { index, step in
            AdminMarketplaceTimelineRow(
                id: index + 1, tag: String(localized: "Step \(index + 1)"), systemImage: Self.symbol(forStep: step.kind),
                title: step.title, detail: step.detail)
        }
        return [trigger] + steps
    }

    private static func symbol(forStep kind: String) -> String {
        switch kind {
        case "connector": "cable.connector"
        case "agent": "cpu"
        default: "paperplane"
        }
    }

    // MARK: Pacchetti

    /// La frase di "Chi configura" dell'agent pack.
    var agentPackSentence: String? {
        guard let pack = item.agentPack else { return nil }
        return String(localized: "It rewrites the \(pack.role) — \(pack.rules) rules and \(pack.terms) glossary terms land on that agent's canvas, where you can edit or drop any of them before saving.")
    }

    /// La frase di "Cosa arriva nella tua base di conoscenza" del knowledge pack.
    var knowledgeSentence: String? {
        guard let pack = item.knowledgePack else { return nil }
        return String(localized: "\(pack.terms) glossary terms and \(pack.procedures) written procedures, from \(pack.discipline.localizedLowercase) practice.")
    }

    var standards: [String] { item.knowledgePack?.standards ?? [] }

    /// Le skill che un plugin installa o un agent pack porta: quelle che il catalogo conosce, in ordine.
    var bundledSkills: [AdminMarketplaceItem] {
        let sourceIds = item.plugin?.skills ?? item.agentPack?.skills ?? []
        return marketplace.items(ids: sourceIds.map { "\(AdminMarketplaceKind.skill.rawValue):\($0)" })
    }

    var bundledSkillsTitle: String {
        item.kind == .plugin
            ? String(localized: "Skills it installs (\(bundledSkills.count))")
            : String(localized: "Skills it brings (\(bundledSkills.count))")
    }

    // MARK: Full set

    var fullSetInfo: AdminMarketplaceItem.FullSetInfo? { item.fullSet }

    /// I posti dove il set scrive, solo con le sezioni non vuote e il loro numero.
    var setPlaces: [AdminMarketplaceSetPlace] {
        guard let info = item.fullSet else { return [] }
        return AdminMarketplaceSetDestination.allCases.compactMap { destination in
            let sections = destination.sections.compactMap { section -> AdminMarketplaceSetSectionSummary? in
                let count = section.count(in: info)
                return count > 0 ? AdminMarketplaceSetSectionSummary(section: section, count: count) : nil
            }
            return sections.isEmpty ? nil : AdminMarketplaceSetPlace(destination: destination, sections: sections)
        }
    }

    /// I componenti che il set porta dagli altri scaffali, raggruppati per tipo nell'ordine della vetrina.
    var setComponentGroups: [AdminMarketplaceComponentGroup] {
        guard let info = item.fullSet else { return [] }
        let parts = marketplace.items(ids: info.components)
        return AdminMarketplaceKind.allCases.compactMap { kind in
            let items = parts.filter { $0.kind == kind }
            return items.isEmpty ? nil : AdminMarketplaceComponentGroup(kind: kind, items: items)
        }
    }

    var setComponentsTitle: String {
        String(localized: "Components (\(setComponentGroups.reduce(0) { $0 + $1.items.count }))")
    }

    /// "Cosa c'è nel set": un posto per riga con i suoi numeri, e in fondo i componenti.
    var setOverview: [AdminMarketplaceSetOverviewRow] {
        var rows = setPlaces.map {
            AdminMarketplaceSetOverviewRow(id: $0.id, label: $0.title, phrases: $0.sections.map(\.countPhrase))
        }
        let groups = setComponentGroups
        if !groups.isEmpty {
            rows.append(AdminMarketplaceSetOverviewRow(
                id: "components", label: String(localized: "Components"), phrases: groups.map(\.countPhrase)))
        }
        return rows
    }

    /// I connettori non fanno parte di nessun set: servono le credenziali dell'azienda.
    var showsConnectorsFootnote: Bool { !item.needs.isEmpty }

    // MARK: Testi delle righe del set

    func stepsMeta(_ count: Int) -> String { String(localized: "\(count) steps") }

    func tasksMeta(_ count: Int) -> String { String(localized: "\(count) tasks") }

    /// "contesto · Categoria", sotto un fatto imparato.
    func learnedCaption(_ fact: AdminMarketplaceItem.FullSetInfo.LearnedFact) -> String {
        "\(fact.context) · \(categoryLabel(fact.category))"
    }

    /// Solo la prima lettera maiuscola, come il `capitalize` della web: "HVAC" resta "HVAC".
    func categoryLabel(_ raw: String) -> String {
        raw.prefix(1).uppercased() + raw.dropFirst()
    }
}

// MARK: - Tipi di supporto

/// Il corpo della pagina: la catena del workflow, la struttura del full set o l'elenco di cosa aggiunge.
nonisolated enum AdminMarketplaceItemBody: Sendable {
    case workflow, fullSet, adds
}

nonisolated enum AdminMarketplaceItemAction: Sendable, Equatable {
    /// Acquistabile: il pulsante con il prezzo ("29 €/mese").
    case buy(price: String)
    case status(AdminMarketplaceItemStatus)
    /// Un connettore: lo stato, il passo che si può fare e il link alla pagina del connettore.
    case connector(AdminMarketplaceConnectorPanel)
}

/// Cosa offre la scheda di un connettore: ogni parte può mancare.
nonisolated struct AdminMarketplaceConnectorPanel: Sendable, Equatable {
    let status: AdminMarketplaceItemStatus?
    let command: AdminMarketplaceConnectorCommand?
    /// Il pulsante è spento in attesa di sapere se il server può abilitarlo.
    let isChecking: Bool
    /// Il connettore ha una riga sul server: il link "Apri connettore" va a questo provider.
    let openProvider: String?
}

/// Il passo che un owner o admin fa su un connettore senza riga.
nonisolated enum AdminMarketplaceConnectorCommand: Sendable, Equatable {
    /// One-click: registra il server e collega il mio account.
    case enable
    /// MaintainX: la chiave dell'azienda.
    case connectWithKey
    /// Odoo: il consenso aziendale nel browser.
    case connect

    var title: String {
        switch self {
        case .enable: String(localized: "Enable and connect my account")
        case .connectWithKey: String(localized: "Connect with API key")
        case .connect: String(localized: "Connect")
        }
    }

    var systemImage: String {
        switch self {
        case .enable: "link.badge.plus"
        case .connectWithKey: "key"
        case .connect: "arrow.up.forward.app"
        }
    }
}

/// Se il server può abilitare un connettore Composio (`platform_client_available` di oauth/inspect).
nonisolated enum AdminMarketplaceConnectorAvailability: Sendable, Equatable {
    /// Non chiesto, o la domanda è fallita: si lascia abilitare, deciderà il server.
    case unknown
    case checking
    case available
    case unavailable
}

nonisolated struct AdminMarketplaceItemStatus: Sendable, Equatable {
    let title: String?
    let systemImage: String
    /// Già dell'azienda (incluso o acquistato): la spunta è piena, non grigia.
    let isOwned: Bool
    let note: String?
}

nonisolated struct AdminMarketplaceRequirement: Identifiable, Sendable, Equatable {
    /// Il provider del connettore.
    let id: String
    let name: String
    let isConnected: Bool
}

nonisolated struct AdminMarketplaceFact: Identifiable, Sendable, Equatable {
    let label: String
    let value: String
    var id: String { label }
}

nonisolated struct AdminMarketplaceTimelineRow: Identifiable, Sendable, Equatable {
    let id: Int
    /// "Trigger" o "Step 2".
    let tag: String
    let systemImage: String
    let title: String
    let detail: String?
}

// MARK: Struttura del full set

/// Le sezioni di un full set, come `SetSectionKey` della web.
nonisolated enum AdminMarketplaceSetSection: String, CaseIterable, Identifiable, Sendable {
    case rules, facts, glossary, procedures, learned, alarms, maintenancePlans, spareParts, checklists, documents, policies

    var id: String { rawValue }

    var title: String {
        switch self {
        case .rules: String(localized: "Rules & thresholds")
        case .facts: String(localized: "Facts")
        case .glossary: String(localized: "Glossary")
        case .procedures: String(localized: "Procedures")
        case .learned: String(localized: "Learned facts")
        case .alarms: String(localized: "Alarms")
        case .maintenancePlans: String(localized: "Maintenance plans")
        case .spareParts: String(localized: "Spare parts")
        case .checklists: String(localized: "Checklist templates")
        case .documents: String(localized: "Documents to upload")
        case .policies: String(localized: "Policies")
        }
    }

    func count(in info: AdminMarketplaceItem.FullSetInfo) -> Int {
        switch self {
        case .rules: info.rules.count
        case .facts: info.facts.count
        case .glossary: info.glossary.count
        case .procedures: info.procedures.count
        case .learned: info.learned.count
        case .alarms: info.alarms.count
        case .maintenancePlans: info.maintenancePlans.count
        case .spareParts: info.spareParts.count
        case .checklists: info.checklists.count
        case .documents: info.documents.count
        case .policies: info.policies.count
        }
    }

    /// "4 rules": una chiave per sezione, così il catalogo può avere le varianti di plurale.
    func countPhrase(_ n: Int) -> String {
        switch self {
        case .rules: String(localized: "\(n) rules")
        case .facts: String(localized: "\(n) facts")
        case .glossary: String(localized: "\(n) terms")
        case .procedures: String(localized: "\(n) procedures")
        case .learned: String(localized: "\(n) learned facts")
        case .alarms: String(localized: "\(n) alarms")
        case .maintenancePlans: String(localized: "\(n) maintenance plans")
        case .spareParts: String(localized: "\(n) spare parts")
        case .checklists: String(localized: "\(n) checklists")
        case .documents: String(localized: "\(n) documents")
        case .policies: String(localized: "\(n) policies")
        }
    }
}

/// I posti di Aria dove un set scrive, come `SET_DESTINATIONS` della web.
nonisolated enum AdminMarketplaceSetDestination: String, CaseIterable, Identifiable, Sendable {
    case agentStudio, learnedKnowledge, plantRecords, documents, policies

    var id: String { rawValue }

    var title: String {
        switch self {
        case .agentStudio: String(localized: "Agent Studio")
        case .learnedKnowledge: String(localized: "Learned knowledge")
        case .plantRecords: String(localized: "Plant records")
        case .documents: String(localized: "Documents")
        case .policies: String(localized: "Company policies")
        }
    }

    var systemImage: String {
        switch self {
        case .agentStudio: "person.crop.rectangle.stack"
        case .learnedKnowledge: "brain"
        case .plantRecords: "tray.full"
        case .documents: "doc.text"
        case .policies: "checkmark.shield"
        }
    }

    var blurb: String {
        switch self {
        case .agentStudio:
            String(localized: "Written onto the agents' canvas — the limits, facts, words and procedures they reason with.")
        case .learnedKnowledge:
            String(localized: "Field-proven facts, filed as pending so someone who knows the machine approves them first.")
        case .plantRecords:
            String(localized: "Staged as drafts in each list, to approve like records extracted from a document.")
        case .documents:
            String(localized: "The manuals the set is grounded on. They belong to the maker, so you upload your own copies.")
        case .policies:
            String(localized: "Who approves, who is alerted, who can see what, how long records are kept.")
        }
    }

    var sections: [AdminMarketplaceSetSection] {
        switch self {
        case .agentStudio: [.rules, .facts, .glossary, .procedures]
        case .learnedKnowledge: [.learned]
        case .plantRecords: [.alarms, .maintenancePlans, .spareParts, .checklists]
        case .documents: [.documents]
        case .policies: [.policies]
        }
    }
}

nonisolated struct AdminMarketplaceSetSectionSummary: Identifiable, Sendable, Equatable {
    let section: AdminMarketplaceSetSection
    let count: Int
    var id: String { section.id }
    var title: String { section.title }
    var countPhrase: String { section.countPhrase(count) }
}

nonisolated struct AdminMarketplaceSetPlace: Identifiable, Sendable, Equatable {
    let destination: AdminMarketplaceSetDestination
    /// Solo le sezioni non vuote.
    let sections: [AdminMarketplaceSetSectionSummary]
    var id: String { destination.id }
    var title: String { destination.title }
    var blurb: String { destination.blurb }
    var systemImage: String { destination.systemImage }
}

nonisolated struct AdminMarketplaceSetOverviewRow: Identifiable, Sendable, Equatable {
    let id: String
    let label: String
    let phrases: [String]
}

nonisolated struct AdminMarketplaceComponentGroup: Identifiable, Sendable, Equatable {
    let kind: AdminMarketplaceKind
    let items: [AdminMarketplaceItem]
    var id: String { kind.id }

    /// Il plurale, o il singolare quando ce n'è uno solo.
    var title: String { items.count == 1 ? kind.label : kind.plural }
    /// "2 skill", "1 agent pack": in minuscolo come nella riga della web.
    var countPhrase: String { "\(items.count) \(title.localizedLowercase)" }
}
