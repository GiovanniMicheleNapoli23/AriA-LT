//
//  AdminDocumentUploadStoreTests.swift
//  AriaLiteTests
//
//  Created by Giovanni Michele on 27/10/26.
//
//  Il caricamento in background dei documenti, senza rete: il corpo multipart scritto su disco a pezzi,
//  i job salvati e ritrovati, i file scelti e mai inviati buttati, e come si legge l'esito di un invio.
//

import Foundation
import Testing
@testable import AriaLite

struct AdminDocumentUploadStoreTests {
    private let store: AdminDocumentUploadStore

    init() {
        store = AdminDocumentUploadStore(directory: FileManager.default.temporaryDirectory
            .appending(path: "uploads-\(UUID().uuidString)", directoryHint: .isDirectory))
    }

    private func sourceFile(_ contents: Data, name: String = "Manuale \"pompa\".pdf") throws -> URL {
        let url = FileManager.default.temporaryDirectory.appending(path: "\(UUID().uuidString)-\(name)")
        try contents.write(to: url)
        return url
    }

    private func file(_ contents: Data) throws -> AdminDocumentUploadFile {
        let id = UUID()
        let size = try store.writeBody(from: sourceFile(contents), id: id, filename: "a.pdf",
                                       mimeType: "application/pdf", boundary: "b")
        return AdminDocumentUploadFile(id: id, filename: "a.pdf", mimeType: "application/pdf", boundary: "b", size: size)
    }

    private func job(_ file: AdminDocumentUploadFile, at date: Date = .now) -> AdminDocumentUploadJob {
        AdminDocumentUploadJob(file: file, companyId: "c1", plantId: "p1", pipelines: ["ingestion"],
                               replaceExisting: false, createdAt: date)
    }

    @Test func bodyIsTheMultipartFilePartAroundTheWholeFile() throws {
        // Più di un pezzo da 1 MB: la copia a pezzi non perde né ripete byte.
        let contents = Data((0..<(1 << 20) + 4321).map { UInt8($0 % 251) })
        let id = UUID()
        let size = try store.writeBody(from: sourceFile(contents), id: id, filename: "Manuale \"pompa\".pdf",
                                       mimeType: "application/pdf", boundary: "aria-x")

        #expect(size == contents.count)
        let head = Data("--aria-x\r\nContent-Disposition: form-data; name=\"file\"; filename=\"Manuale pompa.pdf\"\r\nContent-Type: application/pdf\r\n\r\n".utf8)
        let expected = head + contents + Data("\r\n--aria-x--\r\n".utf8)
        #expect(try Data(contentsOf: store.bodyURL(for: id)) == expected)
    }

    @Test func unreadableSourceLeavesNoBodyBehind() {
        let id = UUID()
        let missing = FileManager.default.temporaryDirectory.appending(path: "missing-\(UUID().uuidString).pdf")
        #expect(throws: (any Error).self) {
            try store.writeBody(from: missing, id: id, filename: "x.pdf", mimeType: "application/pdf", boundary: "b")
        }
        #expect(!FileManager.default.fileExists(atPath: store.bodyURL(for: id).path))
    }

    @Test func savedJobsComeBackOldestFirstWithTheirFailure() throws {
        let newer = job(try file(Data("2".utf8)), at: .now)
        let older = job(try file(Data("1".utf8)), at: .now.addingTimeInterval(-60))
        try store.save(newer)
        try store.save(older)
        store.markFailed(newer.id, message: "Rete assente")

        let jobs = store.jobs()
        #expect(jobs.map(\.id) == [older.id, newer.id])
        #expect(jobs[0].failure == nil)
        #expect(jobs[1].failure == "Rete assente")
        #expect(jobs[1].plantId == "p1")
    }

    @Test func removedJobIsNotMarkedFailedBackIntoExistence() throws {
        let saved = job(try file(Data("x".utf8)))
        try store.save(saved)
        store.remove(saved.id)
        store.markFailed(saved.id, message: "annullato")

        #expect(store.job(saved.id) == nil)
        #expect(store.jobs().isEmpty)
        #expect(!FileManager.default.fileExists(atPath: store.bodyURL(for: saved.id).path))
    }

    @Test func sweepDropsBodiesNeverHandedOffButKeepsJobs() throws {
        let unsent = try file(Data("scelto e lasciato".utf8))
        let queued = job(try file(Data("affidato".utf8)))
        try store.save(queued)

        store.sweepOrphans()

        #expect(!FileManager.default.fileExists(atPath: store.bodyURL(for: unsent.id).path))
        #expect(FileManager.default.fileExists(atPath: store.bodyURL(for: queued.id).path))
        #expect(store.jobs().map(\.id) == [queued.id])
    }

    @Test func jobWithoutBodyIsDropped() throws {
        let saved = job(try file(Data("x".utf8)))
        try store.save(saved)
        try FileManager.default.removeItem(at: store.bodyURL(for: saved.id))

        #expect(store.jobs().isEmpty)
        #expect(store.job(saved.id) == nil)
    }

    // MARK: Esito

    private func response(_ status: Int) -> HTTPURLResponse {
        HTTPURLResponse(url: URL(string: "https://api.example.com/v1/documents/upload")!, statusCode: status,
                        httpVersion: nil, headerFields: nil)!
    }

    @Test func acceptedUploadIsUploaded() {
        guard case .uploaded = AdminDocumentUploadSession.outcome(response: response(202), data: Data(), error: nil) else {
            Issue.record("202 dovrebbe essere un caricamento riuscito")
            return
        }
    }

    @Test func expiredTokenAsksForARetry() {
        guard case .unauthorized = AdminDocumentUploadSession.outcome(response: response(401), data: Data(), error: nil) else {
            Issue.record("401 dovrebbe chiedere un token nuovo")
            return
        }
    }

    @Test func serverAndNetworkErrorsFail() {
        guard case .failed(let error) = AdminDocumentUploadSession.outcome(
            response: response(413), data: Data(#"{"detail":"too large"}"#.utf8), error: nil) else {
            Issue.record("413 dovrebbe fallire")
            return
        }
        guard case .http(413, _)? = error as? AriaError else {
            Issue.record("413 dovrebbe restare un errore HTTP, è \(error)")
            return
        }
        guard case .failed = AdminDocumentUploadSession.outcome(response: nil, data: Data(),
                                                                error: URLError(.networkConnectionLost)) else {
            Issue.record("Un errore di rete dovrebbe fallire")
            return
        }
    }
}
