//
//  AdminCraftedViewModel+Actions.swift
//  AriaLite
//
//  Created by Giovanni Michele on 23/10/26.
//
//  Le azioni della lista di Crafted: aprire un lettore, il composer, eliminare un artifact con l'Annulla
//  e i lettori (che si creano una volta sola finché la schermata è aperta).
//

import Foundation

extension AdminCraftedViewModel {
    /// Quanto resta l'Annulla dopo un'eliminazione.
    private static let undoDuration: Duration = .seconds(6)

    // MARK: Aprire

    func open(_ item: AdminCraftedItem) {
        guard path.last?.id != item.id else { return }
        path.append(item)
    }

    /// L'artifact di una riga, se è uno (i rapporti vengono dal server e non si eliminano da qui).
    func artifact(of item: AdminCraftedItem) -> AdminCraftedArtifact? {
        if case .artifact(let artifact) = item { return artifact }
        return nil
    }

    // MARK: Composer

    /// Si può chiedere qualcosa solo con un'azienda (lo store è per azienda).
    var canCompose: Bool { generator != nil }

    func openComposer() {
        syncCompany()
        guard let generator else { return }
        composer = AdminCraftedComposerViewModel(generator: generator) { [weak self] artifact in
            guard let self else { return }
            // Creato, in lista e aperto subito: la riga c'è prima che Aria abbia cominciato.
            composer = nil
            open(.artifact(artifact))
        }
    }

    func closeComposer() { composer = nil }

    // MARK: Eliminare

    /// Toglie l'artifact (e ferma il turno se Aria ci stava lavorando); l'Annulla lo rimette.
    func delete(_ artifact: AdminCraftedArtifact) {
        generator?.cancel(artifact.id)
        guard let removed = store?.remove(artifact.id) else { return }
        path.removeAll { $0.id == "art:\(removed.id)" }
        lastRemoved = removed
        undoTask?.cancel()
        undoTask = Task(name: "aria.crafted.undo") { [weak self] in
            try? await Task.sleep(for: Self.undoDuration)
            guard !Task.isCancelled else { return }
            self?.lastRemoved = nil
        }
    }

    func undoDelete() {
        guard let removed = lastRemoved else { return }
        store?.restore(removed)
        // Il turno è stato fermato: la riga non resta "in creazione" per sempre, si può riprovare.
        if removed.status == .generating {
            store?.update(removed.id, status: .failed, artifacts: [], note: .some(String(localized: "Making it stopped before it finished.")))
        }
        dismissUndo()
    }

    func dismissUndo() {
        undoTask?.cancel()
        undoTask = nil
        lastRemoved = nil
    }

    // MARK: Lettori

    /// Il lettore di un artifact (nil senza azienda).
    func makeArtifactReader(_ artifact: AdminCraftedArtifact) -> AdminCraftedArtifactReaderViewModel? {
        guard let store, let generator else { return nil }
        return AdminCraftedArtifactReaderViewModel(backend: backend, store: store, generator: generator, artifactId: artifact.id)
    }

    /// Il lettore di un rapporto (nil senza azienda).
    func makeReportReader(_ review: AdminCraftedSessionReview) -> AdminCraftedReportReaderViewModel? {
        guard let reportVersions else { return nil }
        return AdminCraftedReportReaderViewModel(backend: backend, versions: reportVersions, review: review)
    }

    /// Lo stesso lettore finché la riga è nel percorso: rifarlo a ogni disegno butterebbe via modifiche e posizione.
    func artifactReader(for artifact: AdminCraftedArtifact) -> AdminCraftedArtifactReaderViewModel? {
        let key = "art:\(artifact.id)"
        if let reader = artifactReaders[key] { return reader }
        guard let reader = makeArtifactReader(artifact) else { return nil }
        artifactReaders[key] = reader
        return reader
    }

    func reportReader(for review: AdminCraftedSessionReview) -> AdminCraftedReportReaderViewModel? {
        let key = AdminCraftedItem.report(review).id
        if let reader = reportReaders[key] { return reader }
        guard let reader = makeReportReader(review) else { return nil }
        reportReaders[key] = reader
        return reader
    }

    /// I lettori di schermate che non sono più aperte si lasciano andare.
    func pruneReaders() {
        let open = Set(path.map(\.id))
        artifactReaders = artifactReaders.filter { open.contains($0.key) }
        reportReaders = reportReaders.filter { open.contains($0.key) }
    }
}
