//
//  AdminWorkOrderFilesViewModel.swift
//  AriaLite
//
//  Created by Giovanni Michele on 22/10/26.
//
//  Allegati di un ordine (GET/POST/DELETE /v1/attachments, entity_type work_order).
//  Si caricano foto (libreria o fotocamera, in JPEG) e documenti (File); ogni caricamento resta in lista
//  con la sua barra. Aprire un file chiede l'URL firmato, lo scarica e lo mostra in anteprima (Quick Look).
//

import Foundation
import Observation
import PhotosUI
import SwiftUI
import UniformTypeIdentifiers

@MainActor
@Observable
final class AdminWorkOrderFilesViewModel {
    let orderId: String
    let backend: AriaBackend

    private(set) var attachments: [AdminWorkOrderAttachment] = []
    private(set) var uploads: [AdminWorkOrderAttachmentUpload] = []
    private(set) var isLoading = false
    private(set) var hasLoaded = false
    private(set) var errorMessage: String?
    /// L'allegato che si sta scaricando per aprirlo.
    private(set) var openingId: String?
    private(set) var deletingId: String?

    /// Sorgenti di caricamento aperte dalla vista.
    var isPickingPhotos = false
    var isShowingCamera = false
    var isImportingFiles = false
    var photoSelection: [PhotosPickerItem] = []
    /// Il file scaricato da mostrare in anteprima.
    var previewURL: URL?
    /// L'allegato da eliminare, in attesa di conferma.
    var pendingDelete: AdminWorkOrderAttachment?

    static let maxPhotos = 10

    init(orderId: String, backend: AriaBackend) {
        self.orderId = orderId
        self.backend = backend
    }

    private var api: AdminWorkOrdersAPI { AdminWorkOrdersAPI(api: backend.api) }

    // MARK: Caricamento elenco

    /// Alla prima apertura della scheda e a ogni aggiornamento del dettaglio.
    func load() async {
        guard !isLoading else { return }
        isLoading = true
        defer { isLoading = false }
        do {
            attachments = Self.newestFirst(try await api.attachments(orderId))
            errorMessage = nil
        } catch {
            if let message = AdminWorkOrderFailure.message(for: error, backend: backend) { errorMessage = message }
        }
        hasLoaded = true
    }

    var rows: [AdminWorkOrderAttachmentRowItem] {
        attachments.map { file in
            AdminWorkOrderAttachmentRowItem(
                id: file.id,
                filename: file.filename ?? String(localized: "Untitled file"),
                icon: AdminWorkOrderAttachmentKind.icon(mimeType: file.mimeType, filename: file.filename),
                subtitle: AdminWorkOrderFormat.joined([
                    file.sizeBytes.map { $0.formatted(.byteCount(style: .file)) },
                    file.uploadedBy,
                    file.createdAt.map(AdminWorkOrderActivityViewModel.relative),
                ]),
                isOpening: openingId == file.id
            )
        }
    }

    var isEmpty: Bool { hasLoaded && attachments.isEmpty && uploads.isEmpty }
    var canUseCamera: Bool { UIImagePickerController.isSourceTypeAvailable(.camera) }

    // MARK: Sorgenti

    func pickPhotos() { isPickingPhotos = true }
    func takePhoto() { isShowingCamera = true }
    func importFiles() { isImportingFiles = true }

    /// Le foto scelte dalla libreria, in JPEG.
    func photosPicked() async {
        let items = photoSelection
        photoSelection = []
        for (index, item) in items.enumerated() {
            guard let data = try? await item.loadTransferable(type: Data.self),
                  let jpeg = UIImage(data: data)?.jpegData(compressionQuality: 0.85) else {
                errorMessage = String(localized: "Couldn't read that photo.")
                continue
            }
            let suffix = items.count > 1 ? "-\(index + 1)" : ""
            await upload(AdminWorkOrderAttachmentFile(data: jpeg, filename: Self.photoName(suffix), mimeType: "image/jpeg"))
        }
    }

    func photoTaken(_ image: UIImage) {
        guard let jpeg = image.jpegData(compressionQuality: 0.85) else { return }
        Task { await upload(AdminWorkOrderAttachmentFile(data: jpeg, filename: Self.photoName(""), mimeType: "image/jpeg")) }
    }

    /// I documenti scelti da File: si leggono fuori dal main thread (URL con accesso temporaneo).
    func filesImported(_ result: Result<[URL], any Error>) async {
        switch result {
        case .failure(let error):
            if let message = AdminWorkOrderFailure.message(for: error, backend: backend) { errorMessage = message }
        case .success(let urls):
            for url in urls {
                do { await upload(try await Self.read(url)) }
                catch { errorMessage = String(localized: "Couldn't read \(url.lastPathComponent).") }
            }
        }
    }

    // MARK: Caricamento file

    private func upload(_ file: AdminWorkOrderAttachmentFile) async {
        let upload = AdminWorkOrderAttachmentUpload(id: UUID(), filename: file.filename, progress: 0)
        uploads.append(upload)
        defer { uploads.removeAll { $0.id == upload.id } }
        let uploadId = upload.id
        do {
            let created = try await api.uploadAttachment(file, orderId: orderId, uploadedBy: uploader) { [self] fraction in
                Task { @MainActor in self.setProgress(fraction, for: uploadId) }
            }
            errorMessage = nil
            if let created {
                attachments.removeAll { $0.id == created.id }
                attachments.insert(created, at: 0)
            } else {
                await load()
            }
        } catch {
            if let message = AdminWorkOrderFailure.message(for: error, backend: backend) {
                errorMessage = String(localized: "Upload failed: \(message)")
            }
        }
    }

    private func setProgress(_ fraction: Double, for id: UUID) {
        guard let index = uploads.firstIndex(where: { $0.id == id }) else { return }
        uploads[index].progress = fraction
    }

    /// Chi carica: il nome dell'account, o la sua email.
    private var uploader: String? {
        guard let account = backend.mobileAccount else { return nil }
        let name = account.name.trimmingCharacters(in: .whitespacesAndNewlines)
        return name.isEmpty ? account.email : name
    }

    // MARK: Apertura

    func open(_ id: String) async {
        guard openingId == nil, let file = attachments.first(where: { $0.id == id }) else { return }
        openingId = id
        defer { openingId = nil }
        do {
            let api = api
            let remote = try await api.downloadURL(id)
            previewURL = try await api.download(remote, attachmentId: id, filename: file.filename ?? id)
        } catch {
            if let message = AdminWorkOrderFailure.message(for: error, backend: backend) {
                errorMessage = String(localized: "Couldn't open the file: \(message)")
            }
        }
    }

    // MARK: Eliminazione

    func confirmDelete(_ id: String) {
        pendingDelete = attachments.first { $0.id == id }
    }

    func deleteConfirmed() async {
        guard let file = pendingDelete else { return }
        pendingDelete = nil
        deletingId = file.id
        defer { deletingId = nil }
        do {
            try await api.deleteAttachment(file.id)
            attachments.removeAll { $0.id == file.id }
            errorMessage = nil
        } catch {
            if let message = AdminWorkOrderFailure.message(for: error, backend: backend) { errorMessage = message }
        }
    }

    var isConfirmingDelete: Bool {
        get { pendingDelete != nil }
        set { if !newValue { pendingDelete = nil } }
    }

    // MARK: Utilità

    private static func newestFirst(_ rows: [AdminWorkOrderAttachment]) -> [AdminWorkOrderAttachment] {
        rows.sorted { ($0.createdAt ?? .distantPast) > ($1.createdAt ?? .distantPast) }
    }

    /// "photo-20261022-103015.jpg": la libreria non dà il nome del file.
    private static func photoName(_ suffix: String) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyyMMdd-HHmmss"
        return "photo-\(formatter.string(from: Date()))\(suffix).jpg"
    }

    @concurrent
    private static func read(_ url: URL) async throws -> AdminWorkOrderAttachmentFile {
        let scoped = url.startAccessingSecurityScopedResource()
        defer { if scoped { url.stopAccessingSecurityScopedResource() } }
        let data = try Data(contentsOf: url)
        let mime = UTType(filenameExtension: url.pathExtension)?.preferredMIMEType ?? "application/octet-stream"
        return AdminWorkOrderAttachmentFile(data: data, filename: url.lastPathComponent, mimeType: mime)
    }
}
