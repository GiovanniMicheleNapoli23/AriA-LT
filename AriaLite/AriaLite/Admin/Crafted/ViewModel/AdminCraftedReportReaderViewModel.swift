//
//  AdminCraftedReportReaderViewModel.swift
//  AriaLite
//
//  Created by Giovanni Michele on 23/10/26.
//
//  Il lettore di un rapporto d'intervento (document-reader.tsx della web): scarica il .docx nella lingua
//  scelta, lo legge a blocchi e lo mostra come una pagina; lo zoom, le modifiche a mano e le versioni
//  (per lingua) stanno nelle estensioni. I testi dei blocchi in modifica sono un semplice [String]
//  (`drafts`, uno per blocco): sopra ci si può stendere anche una proposta di Aria.
//

import Foundation
import Observation

@MainActor
@Observable
final class AdminCraftedReportReaderViewModel {
    enum Phase: Equatable { case loading, loaded, failed(String) }
    enum Mode: Equatable { case read, edit, compare(number: Int, against: AdminCraftedCompareAgainst) }

    /// Come si disegna un blocco della pagina.
    enum BlockStyle {
        case plain
        /// Letto diverso dal rapporto scritto dal backend.
        case edited
        /// Nel confronto: le parole aggiunte e tolte.
        case diff([AdminCraftedTextDiff.Segment])
        /// Il paragrafo aperto alla tastiera.
        case editing
        /// Un paragrafo scelto perché Aria lavori su quello.
        case picked
    }

    /// Un rapporto scaricato e letto, tenuto per lingua così tornare a una già letta è immediato.
    struct Loaded: Sendable {
        let file: AriaReportFile
        let document: AdminDocxDocument
    }

    let backend: AriaBackend
    let versions: AdminCraftedReportVersionStore
    let review: AdminCraftedSessionReview

    // Lo stato sotto lo scrive solo il ViewModel (le estensioni stanno in altri file, quindi non private).
    var phase: Phase = .loading
    var locale: String
    /// Il file com'è arrivato dal server: l'anteprima e il "condividi l'originale".
    var file: AriaReportFile?
    var document: AdminDocxDocument?
    /// Il testo di ogni blocco nel rapporto scritto dal backend (la versione 1).
    var originals: [String] = []
    var layout: [AdminCraftedPaperItem] = []
    /// Il testo di ogni blocco nella versione che si sta leggendo (l'ultima, o quella messa a confronto).
    var shown: [String] = []
    var diffs: [Int: [AdminCraftedTextDiff.Segment]] = [:]
    /// La barra del confronto aperto (la stessa degli artifact).
    var compareHeader: AdminCraftedCompareHeader?
    var mode: Mode = .read
    /// I testi in modifica, uno per blocco: vuoto fuori dalla modifica.
    var drafts: [String] = []
    var editingIndex: Int?
    var zoom = 1.0
    var historyEntries: [AdminCraftedVersionHistoryEntry] = []

    var showsHistory = false
    var previewURL: URL?
    var sharedFile: AdminCraftedSharedFile?
    var showsShareNotice = false
    // Modifica con Aria (vedi +Aria): il motore, il pannello e la proposta in pagina.
    let ariaEditor: AdminCraftedAriaEditor
    var ariaPanel = AdminCraftedAriaPanelState()
    var ariaProposal: AdminCraftedAriaReportProposal?
    var showsAriaDiscard = false
    var showsDiscard = false
    /// Sale a ogni salvataggio: la vista ne ricava il segno di conferma.
    var savedCount = 0
    var isPreparingShare = false
    var actionError: String?
    var showsActionError = false

    @ObservationIgnored var cache: [String: Loaded] = [:]
    @ObservationIgnored var loadTask: Task<Void, Never>?
    @ObservationIgnored var pinchBase: Double?

    init(backend: AriaBackend, versions: AdminCraftedReportVersionStore, review: AdminCraftedSessionReview) {
        self.backend = backend
        self.versions = versions
        self.review = review
        // Il rapporto ha il suo stabilimento: Aria lavora lì, non in quello attivo.
        let editor = AdminCraftedAriaEditor(backend: backend, companyId: versions.companyId)
        editor.plantId = review.plantId
        ariaEditor = editor
        // Si apre nella lingua dell'app.
        locale = backend.api.context.locale
    }

    // MARK: Intestazione

    var title: String { review.displayTitle }
    var dateText: String? { review.date?.formatted(date: .abbreviated, time: .omitted) }

    private var hasVerdict: Bool { review.verdict?.isEmpty == false }
    var verdictText: String? { hasVerdict ? AdminCraftedVerdict.label(review.verdict) : nil }
    var verdictImage: String { AdminCraftedVerdict.systemImage(review.verdict) }
    var verdictSourceText: String? { hasVerdict ? AdminCraftedVerdict.sourceLabel(review.verdictSource) : nil }

    var sessionId: String { review.sessionId }
    var languages: [AdminCraftedReportLanguage] { AdminCraftedReportLanguage.all }
    var languageName: String { AdminCraftedReportLanguage.native(locale) }

    var isEditing: Bool { mode == .edit }
    var saveFailed: Bool { versions.saveFailed }
    /// Si modifica solo un rapporto letto e con del testo.
    var canEdit: Bool { phase == .loaded && !originals.isEmpty }

    // MARK: Caricamento

    /// Chiamato all'apertura: se il rapporto è già a schermo non si tocca (la modifica in corso resta).
    func load() async {
        if phase == .loaded, document != nil { return }
        let code = locale
        if let hit = cache[code] {
            show(hit)
            return
        }
        guard let companyId = backend.activeCompanyId else {
            phase = .failed(AriaError.missingCompany.localizedDescription)
            return
        }
        phase = .loading
        do {
            let downloaded = try await AriaChatAPI(api: backend.api)
                .reportDocument(companyId: companyId, sessionId: review.sessionId, locale: code,
                                episode: review.episode, title: review.title)
            guard code == locale, !Task.isCancelled else { return }
            // Il file c'è anche se non si legge: si può comunque condividere com'è.
            file = downloaded
            let parsed = try await Self.parse(downloaded)
            guard code == locale, !Task.isCancelled else { return }
            let loaded = Loaded(file: downloaded, document: parsed)
            cache[code] = loaded
            show(loaded)
        } catch {
            guard code == locale, let message = AdminCraftedFailure.message(for: error, backend: backend) else { return }
            phase = .failed(message)
        }
    }

    /// La lettura del file (zip e XML) non sta sul main thread.
    @concurrent
    private static func parse(_ file: AriaReportFile) async throws -> AdminDocxDocument {
        try AdminDocxDocument(data: Data(contentsOf: file.url))
    }

    private func show(_ loaded: Loaded) {
        file = loaded.file
        document = loaded.document
        originals = loaded.document.texts
        layout = AdminCraftedPaperItem.layout(of: loaded.document)
        drafts = []
        editingIndex = nil
        mode = .read
        refreshShown()
        phase = .loaded
    }

    /// Un'altra lingua è un altro documento, con le sue versioni (pickLocale della web).
    func selectLanguage(_ code: String) {
        guard code != locale else { return }
        loadTask?.cancel()
        locale = code
        mode = .read
        drafts = []
        editingIndex = nil
        compareHeader = nil
        showsHistory = false
        // Un'altra lingua è un altro documento: quello che Aria stava facendo sul vecchio non vale.
        closeAria()
        file = nil
        document = nil
        originals = []
        layout = []
        shown = []
        diffs = [:]
        phase = .loading
        loadTask = Task { await load() }
    }

    func retry() async {
        phase = .loading
        await load()
    }

    // MARK: Blocchi

    /// Il testo di un blocco come lo mostra la pagina adesso.
    func text(at index: Int) -> String {
        let source = isEditing ? drafts : (ariaProposal?.texts ?? shown)
        return source.indices.contains(index) ? source[index] : ""
    }

    func blockStyle(at index: Int) -> BlockStyle {
        switch mode {
        case .compare:
            return diffs[index].map { .diff($0) } ?? .plain
        case .edit:
            if editingIndex == index { return .editing }
            return isChanged(index) ? .edited : .plain
        case .read:
            if ariaProposal != nil, let segments = ariaProposal?.diffs[index] { return .diff(segments) }
            if ariaProposal == nil, isAriaPicked(index) { return .picked }
            return isChanged(index) ? .edited : .plain
        }
    }

    private func isChanged(_ index: Int) -> Bool {
        originals.indices.contains(index) && text(at: index) != originals[index]
    }

    private func block(at index: Int) -> AdminDocxDocument.Block? {
        guard let blocks = document?.blocks, blocks.indices.contains(index) else { return nil }
        return blocks[index]
    }

    /// 0 per il titolo del documento, N per `HeadingN`; `nil` per un paragrafo normale.
    func headingLevel(at index: Int) -> Int? {
        guard let item = block(at: index), item.isHeading else { return nil }
        return item.headingLevel ?? 1
    }

    /// Un paragrafo vuoto fuori da una tabella è solo spazio fra due altri: non si apre alla tastiera.
    func isEditable(_ index: Int) -> Bool {
        guard isEditing, let item = block(at: index) else { return false }
        return item.table != nil || !text(at: index).trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }
}
