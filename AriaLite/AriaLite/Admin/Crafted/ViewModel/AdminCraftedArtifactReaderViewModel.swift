//
//  AdminCraftedArtifactReaderViewModel.swift
//  AriaLite
//
//  Created by Giovanni Michele on 23/10/26.
//
//  Il lettore di un artifact fatto da Crafted (CraftedArtifactReader della web): richiesta, stato, la
//  conversazione di Aria — dal vivo mentre la crea, poi come l'ha tenuta il server — e le sue card.
//  Modifica a mano (+Editing) e versioni (+Versions) stanno nelle estensioni; le bozze sono dizionari
//  semplici per id di messaggio e di tabella, così una proposta di Aria si può stendere sopra.
//

import Foundation
import Observation

@MainActor
@Observable
final class AdminCraftedArtifactReaderViewModel {
    /// Cosa mostra la pagina sotto l'intestazione, nello stesso ordine di precedenza della web.
    enum Phase { case generating, loading, unreadable, failed, content }

    enum Mode: Hashable {
        case read
        case edit
        case compare(number: Int, against: AdminCraftedCompareAgainst)
    }

    enum LoadState { case idle, loading, loaded, unreadable }

    let backend: AriaBackend
    let store: AdminCraftedArtifactStore
    let generator: AdminCraftedGenerator
    let artifactId: String

    /// La conversazione come l'ha tenuta il server, senza la frase con cui l'artifact è stato chiesto.
    private(set) var serverMessages: [AriaAgentMessage] = []
    /// Cosa si può modificare in `serverMessages` (vedi `parts`).
    private(set) var cachedParts: [AdminCraftedEditablePart] = []
    private(set) var loadState: LoadState = .idle
    private(set) var loadError: String?

    // Modalità e bozza (le bozze sono per id di messaggio / di tabella: vedi +Editing).
    var mode: Mode = .read
    var draftTexts: [String: String] = [:]
    var draftTables: [String: [AdminCraftedEditedRow]] = [:]
    var showsDiscard = false

    // Versioni (vedi +Versions).
    var showsHistory = false
    var historyEntries: [AdminCraftedVersionHistoryEntry] = []
    var compareHeader: AdminCraftedCompareHeader?
    var compareBlocks: [AdminCraftedCompareBlock] = []
    /// Cresce a ogni versione salvata: la vista ci aggancia il feedback.
    var savedCount = 0

    var showsRename = false
    var renameText = ""

    // Modifica con Aria (vedi +Aria): il motore, il pannello e la proposta in pagina.
    let ariaEditor: AdminCraftedAriaEditor
    var ariaPanel = AdminCraftedAriaPanelState()
    var ariaProposal: AdminCraftedAriaArtifactProposal?
    /// Si apre Aria da una modifica a mano non salvata: prima si chiede se buttarla.
    var showsAriaDiscard = false

    init(backend: AriaBackend, store: AdminCraftedArtifactStore, generator: AdminCraftedGenerator, artifactId: String) {
        self.backend = backend
        self.store = store
        self.generator = generator
        self.artifactId = artifactId
        ariaEditor = AdminCraftedAriaEditor(backend: backend, companyId: store.companyId)
    }

    private var chat: AriaChatAPI { AriaChatAPI(api: backend.api) }

    // MARK: Intestazione

    /// `nil` se nel frattempo è stato eliminato.
    var artifact: AdminCraftedArtifact? { store.get(artifactId) }
    var title: String { artifact?.title ?? "" }
    var request: String { artifact?.request ?? "" }
    var sessionId: String { artifact?.sessionId ?? "" }
    var isGenerating: Bool { generator.isGenerating(artifactId) }
    var saveFailed: Bool { store.saveFailed }

    var statusText: String {
        guard let artifact else { return "" }
        if isGenerating { return String(localized: "Being made…") }
        switch artifact.status {
        case .generating: return String(localized: "Being made…")
        case .ready: return AdminCraftedVersionMeta.when(artifact.createdAt)
        case .needsChat: return String(localized: "Needs the chat")
        case .failed: return String(localized: "Failed")
        }
    }

    var statusSymbol: String {
        if isGenerating { return "hourglass" }
        switch artifact?.status {
        case .needsChat?: return "bubble.left.and.text.bubble.right"
        case .failed?: return "exclamationmark.triangle"
        default: return "checkmark.circle"
        }
    }

    /// Chi salva le versioni: l'account che ha fatto l'accesso (nome, altrimenti email).
    var authorName: String? {
        guard let account = backend.mobileAccount else { return nil }
        return account.name.isEmpty ? account.email : account.name
    }

    // MARK: Conversazione

    /// Quella che Aria sta scrivendo adesso, o appena finita e non ancora nel server.
    private var live: AriaAgentMessage? { generator.liveMessage(artifactId) }

    /// Messaggi dell'operatore e risposte di Aria del server; quando non ci sono, la risposta di questa sessione.
    private var baseMessages: [AriaAgentMessage] {
        if !isGenerating, serverMessages.contains(where: { $0.role == .assistant }) { return serverMessages }
        return live.map { [$0] } ?? []
    }

    /// Quello che si legge, con le modifiche dell'ultima versione sopra; senza i messaggi vuoti.
    var shownMessages: [AriaAgentMessage] {
        AdminCraftedEditing.applyEdits(baseMessages, currentEdits).filter { message in
            !message.displayText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || !message.artifacts.isEmpty
        }
    }

    private var hasAnswer: Bool { baseMessages.contains { $0.role == .assistant } }

    /// Aria sta lavorando e non ha ancora scritto né creato niente.
    private var liveIsBlank: Bool {
        guard let live else { return true }
        return live.displayText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && live.artifacts.isEmpty
    }

    var phase: Phase {
        if isGenerating, liveIsBlank { return .generating }
        if !isGenerating, loadState == .unreadable {
            // Il server non si legge: quello che il dispositivo ha tenuto, a meno che sia fallito.
            return artifact?.status == .failed && artifact?.artifacts.isEmpty == true ? .failed : .unreadable
        }
        if !hasAnswer { return loadState == .loaded ? .failed : .loading }
        return .content
    }

    /// Un'artifact che ha chiesto qualcosa ad Aria in chat: una domanda o un'approvazione.
    var asksInChat: Bool {
        guard !isGenerating else { return false }
        if artifact?.status == .needsChat { return true }
        let last = serverMessages.last { $0.role == .assistant }
        return last?.elicitation != nil || last?.interrupt != nil
    }

    var failureNote: String { artifact?.note ?? String(localized: "Making it stopped before it finished.") }

    /// Le card e il testo tenuti sul dispositivo, quando il server non si legge.
    var keptArtifacts: [AriaArtifact] { artifact?.artifacts ?? [] }
    var keptNote: String? { keptArtifacts.isEmpty ? artifact?.note : nil }

    // MARK: Caricamento

    /// Legge la conversazione dal server e la mette in pari con la riga della lista (recordConversation).
    /// Si richiama quando un turno di questa sessione finisce: durante il turno non si fa niente.
    func load() async {
        guard !isGenerating, mode != .edit, artifact != nil else { return }
        if loadState != .loaded { loadState = .loading }
        do {
            var restored = try await chat.messages(sessionId: sessionId).map(AriaAgentMessage.init(persisted:))
            // L'approvazione in attesa non sta fra i messaggi: senza, un turno in pausa si leggerebbe come finito.
            if let pause = await chat.pendingInterrupt(sessionId: sessionId),
               let index = restored.lastIndex(where: { $0.role == .assistant }) {
                restored[index].interrupt = pause
            }
            guard !Task.isCancelled else { return }
            generator.record(artifactId, messages: restored)
            // La prima frase è quella con cui l'artifact è stato chiesto: non si mostra, c'è la richiesta.
            serverMessages = restored.first?.role == .user ? Array(restored.dropFirst()) : restored
            cachedParts = AdminCraftedEditing.editableParts(serverMessages)
            loadError = nil
            loadState = .loaded
            // Un confronto aperto si rifà sulla conversazione appena riletta.
            if case .compare(let number, let against) = mode { openCompare(number, against: against) }
        } catch {
            guard !Task.isCancelled else { return }
            loadError = AdminCraftedFailure.message(for: error, backend: backend)
            if loadState != .loaded { loadState = .unreadable }
        }
    }

    // MARK: Azioni

    func retry() { generator.retry(artifactId) }

    /// Un percorso della web dalle card (es. /work-orders/12): si apre nel browser, sempre filtrato.
    func webURL(for target: String) -> URL? {
        let url = URL(string: target).flatMap { $0.scheme == nil ? URL(string: target, relativeTo: backend.webURL)?.absoluteURL : $0 }
        return url.flatMap(AriaURLPolicy.external)
    }

    // MARK: Rinomina

    func startRename() {
        renameText = title
        showsRename = true
    }

    /// Il titolo è locale (store); anche la sessione prende il nome, ma se il server non risponde il titolo resta.
    func rename() async {
        let newTitle = renameText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !newTitle.isEmpty, newTitle != title else { return }
        store.update(artifactId, title: newTitle)
        // Il nome della sessione è un di più: se il server non risponde, il titolo locale resta.
        try? await chat.rename(sessionId: sessionId, title: newTitle)
    }
}
