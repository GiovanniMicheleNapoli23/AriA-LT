//
//  AdminMaintenanceFilesCard.swift
//  AriaLite
//
//  Created by Giovanni Michele on 22/10/26.
//
//  Gli allegati del piano. Dal menu "Add" si carica da libreria, fotocamera o File; un tocco apre
//  l'anteprima, il menu della riga elimina (con conferma). Le righe sono quelle degli allegati degli ordini.
//

import PhotosUI
import QuickLook
import SwiftUI

struct AdminMaintenanceFilesCard: View {
    let viewModel: AdminMaintenanceFilesViewModel

    var body: some View {
        @Bindable var viewModel = viewModel
        AdminCard(title: "Files", systemImage: "paperclip") {
            HStack(spacing: 4) {
                AdminWorkOrderActivityRefreshButton(isLoading: viewModel.isLoading) {
                    Task { await viewModel.load() }
                }
                addMenu
            }
        } content: {
            VStack(alignment: .leading, spacing: 10) {
                if let message = viewModel.errorMessage { AdminWorkOrderActivityError(message: message) }
                list
            }
        }
        .task { if !viewModel.hasLoaded { await viewModel.load() } }
        .photosPicker(isPresented: $viewModel.isPickingPhotos, selection: $viewModel.photoSelection,
                      maxSelectionCount: AdminMaintenanceFilesViewModel.maxPhotos, matching: .images)
        .onChange(of: viewModel.photoSelection) { _, items in
            if !items.isEmpty { Task { await viewModel.photosPicked() } }
        }
        .fileImporter(isPresented: $viewModel.isImportingFiles, allowedContentTypes: [.item],
                      allowsMultipleSelection: true) { result in
            Task { await viewModel.filesImported(result) }
        }
        .fullScreenCover(isPresented: $viewModel.isShowingCamera) {
            CameraPicker { viewModel.photoTaken($0) }.ignoresSafeArea()
        }
        .quickLookPreview($viewModel.previewURL)
        .confirmationDialog("Delete this file?", isPresented: $viewModel.isConfirmingDelete, titleVisibility: .visible) {
            Button("Delete", role: .destructive) { Task { await viewModel.deleteConfirmed() } }
        } message: {
            Text("It will be removed from this plan for everyone.")
        }
    }

    private var addMenu: some View {
        Menu {
            Button("Photo Library", systemImage: "photo.on.rectangle") { viewModel.pickPhotos() }
            if viewModel.canUseCamera {
                Button("Take Photo", systemImage: "camera") { viewModel.takePhoto() }
            }
            Button("Choose File", systemImage: "folder") { viewModel.importFiles() }
        } label: {
            Label("Add", systemImage: "plus")
                .font(.subheadline.weight(.semibold))
        }
    }

    @ViewBuilder
    private var list: some View {
        let rows = viewModel.rows
        VStack(alignment: .leading, spacing: 0) {
            if viewModel.isEmpty {
                AdminSectionNotice(text: String(localized: "No files yet."), systemImage: "doc")
            } else if !viewModel.hasLoaded && rows.isEmpty {
                ProgressView().frame(maxWidth: .infinity).padding(.vertical, 12)
            }
            ForEach(viewModel.uploads) { upload in
                AdminWorkOrderAttachmentUploadRow(upload: upload)
                if !rows.isEmpty || upload.id != viewModel.uploads.last?.id { Divider() }
            }
            ForEach(Array(rows.enumerated()), id: \.element.id) { index, row in
                AdminWorkOrderAttachmentRow(row: row, isDeleting: viewModel.deletingId == row.id) {
                    Task { await viewModel.open(row.id) }
                } delete: {
                    viewModel.confirmDelete(row.id)
                }
                if index < rows.count - 1 { Divider() }
            }
        }
    }
}
