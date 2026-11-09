//
//  AdminCraftedArtifactStore.swift
//  AriaLite
//
//  Created by Giovanni Michele on 23/10/26.
//
//  Gli artifact fatti dalla pagina Crafted, tenuti sul dispositivo (craftedArtifacts della web) perché
//  il server non ha ancora un'API per loro. Uno store per azienda: un file JSON in
//  Application Support/Crafted/<azienda>/artifacts.json, scritto in modo atomico, con le stesse chiavi
//  della web. Un file danneggiato si legge come vuoto. Dal più nuovo al più vecchio.
//

import Foundation
import Observation

@MainActor
@Observable
final class AdminCraftedArtifactStore {
    let companyId: String
    /// Dal più nuovo al più vecchio.
    private(set) var list: [AdminCraftedArtifact] = []
    /// L'ultimo salvataggio su disco non è riuscito (disco pieno…): la lista in memoria resta valida.
    private(set) var saveFailed = false

    private let fileURL: URL

    /// `baseURL` è la cartella da cui parte il file di ogni azienda (di default Application Support/Crafted); i test passano una temporanea.
    init(companyId: String, baseURL: URL? = nil) {
        self.companyId = companyId
        fileURL = AdminCraftedStorage.fileURL(baseURL: baseURL ?? AdminCraftedStorage.defaultBaseURL,
                                              companyId: companyId, name: "artifacts.json")
        list = Self.load(fileURL)
    }

    func get(_ id: String) -> AdminCraftedArtifact? { list.first { $0.id == id } }

    // MARK: Scritture

    @discardableResult
    func create(request: String, sessionId: String) -> AdminCraftedArtifact {
        let now = AdminCraftedStorage.now()
        let request = request.trimmingCharacters(in: .whitespacesAndNewlines)
        let artifact = AdminCraftedArtifact(
            id: AdminCraftedStorage.newID(), title: AdminCraftedOutcome.titleFrom(request), request: request,
            sessionId: sessionId, status: .generating, artifacts: [], note: nil, versions: nil, createdAt: now, updatedAt: now
        )
        list.insert(artifact, at: 0)
        save()
        return artifact
    }

    /// Cambia solo quello che si passa. `note`: `nil` lascia com'è, `.some(nil)` la cancella.
    func update(_ id: String, title: String? = nil, status: AdminCraftedArtifactStatus? = nil,
                artifacts: [AriaArtifact]? = nil, note: String?? = nil) {
        guard let index = list.firstIndex(where: { $0.id == id }) else { return }
        if let title { list[index].title = title }
        if let status { list[index].status = status }
        if let artifacts { list[index].artifacts = artifacts }
        if let note { list[index].note = note }
        list[index].updatedAt = AdminCraftedStorage.now()
        save()
    }

    /// Scrive l'esito di un turno (stato, card, nota e, se la risposta ne dà uno, il titolo).
    /// Se nel frattempo è stato eliminato non c'è niente da aggiornare.
    func update(_ id: String, outcome: AdminCraftedOutcome) {
        update(id, title: outcome.title, status: outcome.status, artifacts: outcome.artifacts, note: .some(outcome.note))
    }

    /// Salva la versione successiva; una rimessa com'era si salva uguale, marcata come tale.
    /// Niente di quello che c'è già nella cronologia si riscrive.
    @discardableResult
    func addVersion(_ id: String, edits: AdminCraftedArtifactEdits, author: String?,
                    restoredFrom: Int? = nil, via: AdminCraftedAriaRequest? = nil) -> AdminCraftedArtifactVersion? {
        guard let index = list.firstIndex(where: { $0.id == id }) else { return nil }
        let versions = list[index].versions ?? []
        let version = AdminCraftedArtifactVersion(
            id: AdminCraftedStorage.newID(), number: AdminCraftedEditing.currentNumber(versions.map(\.number)) + 1,
            createdAt: AdminCraftedStorage.now(), author: author, kind: restoredFrom == nil ? .edit : .restore,
            restoredFrom: restoredFrom, via: via, edits: edits
        )
        list[index].versions = versions + [version]
        list[index].updatedAt = version.createdAt
        save()
        return version
    }

    /// Toglie l'artifact e lo restituisce, per l'Annulla.
    @discardableResult
    func remove(_ id: String) -> AdminCraftedArtifact? {
        guard let index = list.firstIndex(where: { $0.id == id }) else { return nil }
        let removed = list.remove(at: index)
        save()
        return removed
    }

    /// Rimette uno appena tolto (l'Annulla del toast).
    func restore(_ artifact: AdminCraftedArtifact) {
        list = [artifact] + list.filter { $0.id != artifact.id }
        save()
    }

    // MARK: Disco

    private func save() {
        do {
            try AdminCraftedStorage.write(AdminCraftedStorage.encoder().encode(list), to: fileURL)
            saveFailed = false
        } catch {
            saveFailed = true
        }
    }

    /// Gli elementi che non si leggono si scartano; un file che non è una lista è una lista vuota.
    private static func load(_ url: URL) -> [AdminCraftedArtifact] {
        guard let data = AdminCraftedStorage.read(url),
              let lossy = try? AdminCraftedStorage.decoder().decode(AriaLossyArray<AdminCraftedArtifact>.self, from: data) else { return [] }
        return lossy.items
    }
}
