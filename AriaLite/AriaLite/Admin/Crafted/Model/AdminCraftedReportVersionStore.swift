//
//  AdminCraftedReportVersionStore.swift
//  AriaLite
//
//  Created by Giovanni Michele on 23/10/26.
//
//  Le versioni dei rapporti d'intervento, tenute sul dispositivo (reportVersions della web). Uno store
//  per azienda: Application Support/Crafted/<azienda>/report-versions.json, chiavi
//  `<sessione>:<episodio>:<lingua>` (AdminCraftedReportEditing.key) — ogni lingua è un documento a sé.
//  Scritto in modo atomico; un file danneggiato si legge come "nessuna modifica".
//

import Foundation
import Observation

@MainActor
@Observable
final class AdminCraftedReportVersionStore {
    let companyId: String
    /// Chiave della resa → le sue versioni, dalla più vecchia.
    private(set) var versionsByKey: [String: [AdminCraftedReportVersion]] = [:]
    /// L'ultimo salvataggio su disco non è riuscito: la memoria resta valida.
    private(set) var saveFailed = false

    private let fileURL: URL

    /// `baseURL` come in AdminCraftedArtifactStore: i test passano una cartella temporanea.
    init(companyId: String, baseURL: URL? = nil) {
        self.companyId = companyId
        fileURL = AdminCraftedStorage.fileURL(baseURL: baseURL ?? AdminCraftedStorage.defaultBaseURL,
                                              companyId: companyId, name: "report-versions.json")
        versionsByKey = Self.load(fileURL)
    }

    /// Le versioni di una resa, dalla più vecchia.
    func versions(_ key: String) -> [AdminCraftedReportVersion] { versionsByKey[key] ?? [] }

    /// Le chiavi che hanno almeno una versione.
    var allKeys: Set<String> { Set(versionsByKey.filter { !$0.value.isEmpty }.keys) }

    /// Il rapporto ha modifiche in una lingua qualsiasi (il segno "modificato" della lista).
    func hasVersions(sessionId: String, episode: Int) -> Bool {
        let prefix = "\(sessionId):\(episode):"
        return versionsByKey.contains { $0.key.hasPrefix(prefix) && !$0.value.isEmpty }
    }

    /// Salva la versione successiva; una rimessa com'era si salva uguale, marcata come tale.
    @discardableResult
    func add(_ key: String, edits: AdminCraftedReportEdits, author: String?,
             restoredFrom: Int? = nil, via: AdminCraftedAriaRequest? = nil) -> AdminCraftedReportVersion {
        let list = versionsByKey[key] ?? []
        let version = AdminCraftedReportVersion(
            id: AdminCraftedStorage.newID(), number: (list.last?.number ?? 1) + 1, createdAt: AdminCraftedStorage.now(), author: author,
            kind: restoredFrom == nil ? .edit : .restore, restoredFrom: restoredFrom, via: via, edits: edits
        )
        versionsByKey[key] = list + [version]
        save()
        return version
    }

    private func save() {
        do {
            try AdminCraftedStorage.write(AdminCraftedStorage.encoder().encode(versionsByKey), to: fileURL)
            saveFailed = false
        } catch {
            saveFailed = true
        }
    }

    private static func load(_ url: URL) -> [String: [AdminCraftedReportVersion]] {
        guard let data = AdminCraftedStorage.read(url),
              let raw = try? AdminCraftedStorage.decoder().decode([String: AriaLossyArray<AdminCraftedReportVersion>].self, from: data)
        else { return [:] }
        return raw.mapValues(\.items)
    }
}
