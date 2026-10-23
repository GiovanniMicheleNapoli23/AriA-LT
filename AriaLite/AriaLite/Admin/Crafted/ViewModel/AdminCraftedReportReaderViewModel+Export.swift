//
//  AdminCraftedReportReaderViewModel+Export.swift
//  AriaLite
//
//  Created by Giovanni Michele on 23/10/26.
//
//  Condividere il rapporto: il file che si sta leggendo, con le modifiche scritte dentro; se non si
//  possono scrivere con certezza, l'originale (e si dice). L'anteprima è il file come l'ha dato il server.
//

import Foundation

/// Un file pronto per il foglio di condivisione.
struct AdminCraftedSharedFile: Identifiable, Equatable {
    let url: URL
    var id: URL { url }
}

extension AdminCraftedReportReaderViewModel {
    /// L'originale non ha niente da scrivere: va com'è. Con delle modifiche si riscrive il .docx.
    func share() async {
        guard let document, let file, !isPreparingShare else { return }
        guard currentNumber > 1 else {
            sharedFile = AdminCraftedSharedFile(url: file.url)
            return
        }
        isPreparingShare = true
        defer { isPreparingShare = false }
        do {
            let name = Self.editedName(file.filename, number: currentNumber)
            if let url = try await Self.writeEdited(document, edits: currentEdits, filename: name) {
                sharedFile = AdminCraftedSharedFile(url: url)
            } else {
                // Meglio l'originale che una modifica nel paragrafo sbagliato: si chiede prima.
                showsShareNotice = true
            }
        } catch {
            fail(error)
        }
    }

    func shareOriginal() {
        if let file { sharedFile = AdminCraftedSharedFile(url: file.url) }
    }

    func previewOriginal() {
        previewURL = file?.url
    }

    /// "Nome (v3).docx", come la web.
    static func editedName(_ filename: String, number: Int) -> String {
        let ext = (filename as NSString).pathExtension
        let base = (filename as NSString).deletingPathExtension
        return ext.isEmpty ? "\(base) (v\(number))" : "\(base) (v\(number)).\(ext)"
    }

    /// Scrive il .docx modificato in una cartella temporanea; `nil` se le modifiche non si collocano tutte.
    @concurrent
    private static func writeEdited(_ document: AdminDocxDocument, edits: AdminCraftedReportEdits,
                                    filename: String) async throws -> URL? {
        let result = document.writing(edits)
        guard result.complete else { return nil }
        let folder = FileManager.default.temporaryDirectory.appending(path: "aria-report-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        let url = folder.appending(path: filename)
        try result.data.write(to: url, options: .atomic)
        return url
    }

    // MARK: Errori

    func fail(_ error: any Error) {
        guard let message = AdminCraftedFailure.message(for: error, backend: backend) else { return }
        fail(message: message)
    }

    func fail(message: String) {
        actionError = message
        showsActionError = true
    }
}
