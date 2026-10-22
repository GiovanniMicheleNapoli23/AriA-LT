//
//  AdminLearnedKnowledgeViewModel.swift
//  AriaLite
//
//  Created by Giovanni Michele on 22/10/26.
//
//  La memoria dell'azienda, come la pagina /settings/memory della web. Vive in AppViewModel: i dati
//  restano fra un cambio di sezione e l'altro. Lo stato si chiede al server (a pagine); stabilimento,
//  autore e ricerca filtrano qui, sui fatti già scaricati. Azioni in +Actions, traduzioni in +Translations.
//

import Foundation
import Observation

@MainActor
@Observable
final class AdminLearnedKnowledgeViewModel {
    let backend: AriaBackend

    /// La lista a schermo, dal più recente, come la dà il server.
    var facts: [AdminMemoryFact] = []
    /// Tutti i fatti visti (anche usciti dalla lista per un cambio di stato): il dettaglio legge da qui.
    var knownFacts: [String: AdminMemoryFact] = [:]
    /// Quanti fatti ci sono in tutto con lo stato scelto.
    var total: Int?
    private(set) var members: [AdminLearnedKnowledgeMember] = []
    private(set) var isLoading = false
    private(set) var isLoadingMore = false
    /// La lista è arrivata almeno una volta per lo stato scelto.
    private(set) var hasLoaded = false
    private(set) var errorMessage: String?
    private(set) var lastUpdated: Date?
    @ObservationIgnored private var loadedKey: String?
    @ObservationIgnored private var membersCompanyId: String?

    // MARK: Traduzioni (vedi +Translations)

    /// Testo nella lingua del telefono, per id del fatto. Manca = si mostra l'originale.
    var translations: [String: String] = [:]
    @ObservationIgnored var requestedTranslations: Set<String> = []
    /// Mostra il testo originale anche dove c'è una traduzione.
    var showsOriginals = false

    // MARK: Azioni (vedi +Actions)

    /// Fatti con una richiesta in corso (approva, rifiuta, elimina).
    var busyFactIds: Set<String> = []
    /// Errore di un'azione: si mostra in un avviso.
    var actionError: String?
    /// Un'informazione dopo un'azione riuscita (es. fatto già noto, rinforzato).
    var actionNotice: String?
    /// Rifiuto o eliminazione in attesa di conferma.
    var pendingConfirmation: AdminMemoryFactConfirmation?

    // MARK: Filtri

    var searchText = ""
    /// `nil`: tutti gli stati (il parametro non si manda).
    var statusFilter: AdminMemoryFactStatus?
    var plantFilter: String?
    var authorFilter: String?

    static let pageSize = 50

    init(backend: AriaBackend) {
        self.backend = backend
    }

    /// Cambia quando va richiesta la lista: azienda o stato scelto (la vista ci appende un `.task`).
    var loadKey: String { "\(backend.activeCompanyId ?? "-")|\(statusFilter?.rawValue ?? "all")" }

    var visibleFacts: [AdminMemoryFact] {
        let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        return facts
            .filter { plantFilter == nil || $0.plantId == nil || $0.plantId == plantFilter }
            .filter { authorFilter == nil || $0.authorKey == authorFilter }
            .filter { query.isEmpty || searchableFields(of: $0).contains { $0.localizedStandardContains(query) } }
    }

    private func searchableFields(of fact: AdminMemoryFact) -> [String] {
        [fact.content, translations[fact.id], fact.context, fact.category, authorName(for: fact)].compactMap { $0 }
    }

    var isSearching: Bool { !searchText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
    var hasLocalFilters: Bool { plantFilter != nil || authorFilter != nil }

    func clearFilters() {
        plantFilter = nil
        authorFilter = nil
    }

    var plants: [AriaPlant] { backend.plants }

    func plantName(_ id: String?) -> String? {
        guard let id else { return nil }
        return plants.first { $0.id == id }?.name ?? id
    }

    /// Gli autori dei fatti scaricati, per il filtro: (chiave, nome), in ordine di nome.
    var authors: [(key: String, name: String)] {
        let keys = Set(facts.compactMap(\.authorKey))
        return keys.map { key in (key, memberName(for: key) ?? facts.first { $0.authorKey == key }?.creator ?? key) }
            .sorted { $0.name.localizedStandardCompare($1.name) == .orderedAscending }
    }

    var statusFilterLabel: String { statusFilter?.label ?? String(localized: "All") }
    var plantFilterLabel: String { plantName(plantFilter) ?? String(localized: "All plants") }
    var authorFilterLabel: String {
        guard let key = authorFilter else { return String(localized: "Anyone") }
        return authors.first { $0.key == key }?.name ?? key
    }

    var subtitle: String {
        let count = visibleFacts.count
        guard let total, !isSearching, !hasLocalFilters, total > count else { return String(localized: "\(count) facts") }
        return String(localized: "\(count) of \(total) facts")
    }

    // MARK: Nomi

    private func memberName(for key: String) -> String? {
        members.first { $0.matches(key) }?.displayName
    }

    /// Chi ha proposto il fatto: il membro, altrimenti il nome scritto o l'id.
    func authorName(for fact: AdminMemoryFact) -> String? {
        if let key = fact.createdBy, let name = memberName(for: key) { return name }
        return fact.creator ?? fact.createdBy
    }

    /// Chi l'ha validato; `system` è l'approvazione automatica di Aria.
    func validatorName(for fact: AdminMemoryFact) -> String? {
        guard let key = fact.validatedBy else { return nil }
        if fact.isAutoValidated { return String(localized: "Aria (automatic)") }
        return memberName(for: key) ?? key
    }

    func fact(id: String) -> AdminMemoryFact? { knownFacts[id] }

    /// "Marco Rossi · Linea 2 · 3 giorni fa": la riga sotto il testo nella lista.
    func metaLine(for fact: AdminMemoryFact) -> String {
        [authorName(for: fact), plantName(fact.plantId),
         fact.createdAt?.formatted(.relative(presentation: .named))].compactMap { $0 }.joined(separator: " · ")
    }

    // MARK: Caricamento

    var canLoadMore: Bool {
        guard hasLoaded, let total else { return false }
        return facts.count < total
    }

    func load() async {
        guard let companyId = backend.activeCompanyId else {
            errorMessage = AriaError.missingCompany.localizedDescription
            return
        }
        let status = statusFilter
        // Altra azienda o altro stato: la lista vecchia non vale, non si mostra mentre arriva la nuova.
        let key = loadKey
        if key != loadedKey {
            facts = []
            total = nil
            hasLoaded = false
            errorMessage = nil
            loadedKey = key
        }
        isLoading = true
        defer { isLoading = false }
        async let membersLoad: Void = loadMembers(companyId: companyId)
        do {
            let page = try await backend.api.call(AdminLearnedKnowledgeAPI.facts(
                companyId: companyId, status: status?.rawValue, limit: Self.pageSize, offset: 0))
            // Lo stato è cambiato durante la richiesta: questa risposta non vale più.
            guard key == loadKey, !Task.isCancelled else { await membersLoad; return }
            facts = page.facts
            total = page.total
            remember(page.facts)
            hasLoaded = true
            errorMessage = nil
            lastUpdated = .now
            if let author = authorFilter, !authors.contains(where: { $0.key == author }) { authorFilter = nil }
            requestTranslations(for: page.facts)
        } catch {
            if key == loadKey, let message = AdminLearnedKnowledgeFailure.message(for: error, backend: backend) {
                errorMessage = message
            }
        }
        await membersLoad
    }

    /// La pagina dopo: si aggiunge in fondo, senza doppioni (un fatto nuovo sposta gli offset).
    func loadMore() async {
        guard canLoadMore, !isLoadingMore, let companyId = backend.activeCompanyId else { return }
        let key = loadKey
        isLoadingMore = true
        defer { isLoadingMore = false }
        do {
            let page = try await backend.api.call(AdminLearnedKnowledgeAPI.facts(
                companyId: companyId, status: statusFilter?.rawValue, limit: Self.pageSize, offset: facts.count))
            guard key == loadKey else { return }
            let known = Set(facts.map(\.id))
            let fresh = page.facts.filter { !known.contains($0.id) }
            facts += fresh
            errorMessage = nil
            if let pageTotal = page.total { total = pageTotal }
            // Pagina vuota: il totale era vecchio, non si chiede altro.
            if page.facts.isEmpty { total = facts.count }
            remember(fresh)
            requestTranslations(for: fresh)
        } catch {
            // La lista resta: il motivo va nella riga sottile sopra, come per un aggiornamento fallito.
            if key == loadKey { errorMessage = AdminLearnedKnowledgeFailure.message(for: error, backend: backend) }
        }
    }

    /// I membri servono solo per i nomi: se il ruolo non li vede si mostrano gli id, senza errori.
    private func loadMembers(companyId: String) async {
        guard membersCompanyId != companyId else { return }
        guard let rows = try? await backend.api.call(AdminLearnedKnowledgeAPI.members()) else { return }
        members = rows.items
        membersCompanyId = companyId
    }

    func remember(_ rows: [AdminMemoryFact]) {
        for fact in rows { knownFacts[fact.id] = fact }
    }

    /// Il fatto che rispetta ancora lo stato filtrato resta in lista.
    func matchesStatusFilter(_ fact: AdminMemoryFact) -> Bool {
        statusFilter == nil || fact.status == statusFilter?.rawValue
    }

    func makeDetailViewModel(factId: String) -> AdminMemoryFactDetailViewModel {
        AdminMemoryFactDetailViewModel(list: self, factId: factId)
    }

    func makeCreateForm() -> AdminMemoryFactFormViewModel {
        AdminMemoryFactFormViewModel(backend: backend, editing: nil)
    }

    var canCreate: Bool { backend.activeCompanyId != nil && (backend.activePlantId != nil || !backend.plants.isEmpty) }

    /// All'uscita dall'account: non resta niente dell'azienda precedente.
    func reset() {
        facts = []
        knownFacts = [:]
        total = nil
        members = []
        isLoading = false
        isLoadingMore = false
        hasLoaded = false
        errorMessage = nil
        lastUpdated = nil
        loadedKey = nil
        membersCompanyId = nil
        translations = [:]
        requestedTranslations = []
        showsOriginals = false
        busyFactIds = []
        actionError = nil
        actionNotice = nil
        pendingConfirmation = nil
        searchText = ""
        statusFilter = nil
        plantFilter = nil
        authorFilter = nil
    }
}
