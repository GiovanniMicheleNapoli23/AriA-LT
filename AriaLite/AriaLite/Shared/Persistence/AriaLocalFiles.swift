//
//  AriaLocalFiles.swift
//  AriaLite
//
//  Created by Giovanni Michele on 24/10/26.
//
//  I file con dati dell'azienda che l'app scrive da sé (documenti scaricati, report esportati, Crafted):
//  cifrati finché il telefono è bloccato, e quelli temporanei via all'uscita dall'account.
//

import Foundation

nonisolated enum AriaLocalFiles {
    /// Le cartelle in tmp/ dei file aperti in anteprima o da condividere.
    private static let temporaryFolders = ["AdminWorkOrderFiles", "AdminDocumentPreviews"]
    /// Prefisso delle cartelle dei report .docx (chat e Crafted).
    private static let reportFolderPrefix = "aria-report-"

    /// Cifrato a telefono bloccato; un file già aperto si può finire di scrivere.
    static func protect(_ url: URL) {
        try? FileManager.default.setAttributes([.protectionKey: FileProtectionType.completeUnlessOpen],
                                               ofItemAtPath: url.path(percentEncoded: false))
    }

    /// Documenti scaricati ed esportati: non restano sul telefono per l'account successivo.
    static func removeTemporaryDocuments() {
        let fileManager = FileManager.default
        let tmp = fileManager.temporaryDirectory
        for name in temporaryFolders {
            try? fileManager.removeItem(at: tmp.appending(path: name, directoryHint: .isDirectory))
        }
        let reports = (try? fileManager.contentsOfDirectory(at: tmp, includingPropertiesForKeys: nil)) ?? []
        for url in reports where url.lastPathComponent.hasPrefix(reportFolderPrefix) {
            try? fileManager.removeItem(at: url)
        }
    }
}
