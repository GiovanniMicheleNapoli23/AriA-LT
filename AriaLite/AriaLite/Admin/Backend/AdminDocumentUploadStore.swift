//
//  AdminDocumentUploadStore.swift
//  AriaLite
//
//  Created by Giovanni Michele on 27/10/26.
//
//  La cartella dei caricamenti (Application Support/DocumentUploads, fuori dal backup): per ogni documento
//  il corpo multipart `<id>.body` e il job `<id>.json`. Un corpo senza job è un file scelto e mai inviato
//  (foglio chiuso, app chiusa a metà): si butta. Un caricamento riuscito cancella entrambi.
//

import Foundation

nonisolated struct AdminDocumentUploadStore: Sendable {
    let directory: URL

    static let shared = AdminDocumentUploadStore(
        directory: URL.applicationSupportDirectory.appending(path: "DocumentUploads", directoryHint: .isDirectory))

    func bodyURL(for id: UUID) -> URL { directory.appending(path: "\(id.uuidString).body") }
    private func jobURL(for id: UUID) -> URL { directory.appending(path: "\(id.uuidString).json") }

    // MARK: Corpo multipart

    /// Scrive header della parte `file`, il contenuto di `source` a pezzi da 1 MB e la chiusura.
    /// Restituisce il peso del file letto.
    func writeBody(from source: URL, id: UUID, filename: String, mimeType: String, boundary: String) throws -> Int {
        try prepareDirectory()
        let target = bodyURL(for: id)
        guard FileManager.default.createFile(atPath: target.path, contents: nil) else {
            throw CocoaError(.fileWriteUnknown)
        }
        do {
            let output = try FileHandle(forWritingTo: target)
            defer { try? output.close() }
            let input = try FileHandle(forReadingFrom: source)
            defer { try? input.close() }
            try output.write(contentsOf: Self.head(filename: filename, mimeType: mimeType, boundary: boundary))
            var size = 0
            while true {
                let chunk = try autoreleasepool { try input.read(upToCount: 1 << 20) }
                guard let chunk, !chunk.isEmpty else { break }
                try output.write(contentsOf: chunk)
                size += chunk.count
            }
            try output.write(contentsOf: Self.tail(boundary: boundary))
            return size
        } catch {
            try? FileManager.default.removeItem(at: target)
            throw error
        }
    }

    static func head(filename: String, mimeType: String, boundary: String) -> Data {
        // Finiscono negli header della parte: via virgolette e a capo.
        func header(_ value: String) -> String {
            String(String.UnicodeScalarView(value.unicodeScalars.filter { $0 != "\"" && $0 != "\r" && $0 != "\n" }))
        }
        return Data(("--\(boundary)\r\nContent-Disposition: form-data; name=\"file\"; filename=\"\(header(filename))\"\r\n"
            + "Content-Type: \(header(mimeType))\r\n\r\n").utf8)
    }

    static func tail(boundary: String) -> Data { Data("\r\n--\(boundary)--\r\n".utf8) }

    /// Un file scelto e non più da inviare.
    func discardBody(_ id: UUID) {
        try? FileManager.default.removeItem(at: bodyURL(for: id))
    }

    // MARK: Job

    func save(_ job: AdminDocumentUploadJob) throws {
        try prepareDirectory()
        try JSONEncoder().encode(job).write(to: jobURL(for: job.id), options: .atomic)
    }

    func job(_ id: UUID) -> AdminDocumentUploadJob? {
        guard let data = try? Data(contentsOf: jobURL(for: id)) else { return nil }
        return try? JSONDecoder().decode(AdminDocumentUploadJob.self, from: data)
    }

    /// I job salvati, dal più vecchio. Un job senza corpo non si può più inviare: si toglie.
    func jobs() -> [AdminDocumentUploadJob] {
        let files = (try? FileManager.default.contentsOfDirectory(at: directory, includingPropertiesForKeys: nil)) ?? []
        return files
            .filter { $0.pathExtension == "json" }
            .compactMap { UUID(uuidString: $0.deletingPathExtension().lastPathComponent) }
            .compactMap { id -> AdminDocumentUploadJob? in
                guard FileManager.default.fileExists(atPath: bodyURL(for: id).path) else {
                    remove(id)
                    return nil
                }
                return job(id)
            }
            .sorted { $0.createdAt < $1.createdAt }
    }

    /// Segna il fallimento, se il job c'è ancora (uno tolto dalla lista non torna).
    func markFailed(_ id: UUID, message: String) {
        guard var job = job(id) else { return }
        job.failure = message
        try? save(job)
    }

    func remove(_ id: UUID) {
        try? FileManager.default.removeItem(at: jobURL(for: id))
        try? FileManager.default.removeItem(at: bodyURL(for: id))
    }

    func removeAll() {
        try? FileManager.default.removeItem(at: directory)
    }

    /// Butta i corpi rimasti senza job.
    func sweepOrphans() {
        let files = (try? FileManager.default.contentsOfDirectory(at: directory, includingPropertiesForKeys: nil)) ?? []
        let jobs = Set(files.filter { $0.pathExtension == "json" }.map { $0.deletingPathExtension().lastPathComponent })
        for file in files where file.pathExtension == "body" && !jobs.contains(file.deletingPathExtension().lastPathComponent) {
            try? FileManager.default.removeItem(at: file)
        }
    }

    private func prepareDirectory() throws {
        guard !FileManager.default.fileExists(atPath: directory.path) else { return }
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        // Copie di file dell'azienda in attesa di invio: non vanno nel backup.
        var folder = directory
        var values = URLResourceValues()
        values.isExcludedFromBackup = true
        try? folder.setResourceValues(values)
    }
}
