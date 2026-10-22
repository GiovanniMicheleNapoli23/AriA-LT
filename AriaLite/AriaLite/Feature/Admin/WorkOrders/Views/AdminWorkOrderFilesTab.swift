//
//  AdminWorkOrderFilesTab.swift
//  AriaLite
//
//  Created by Giovanni Michele on 22/10/26.
//
//  Allegati di un ordine (GET/POST/DELETE /v1/attachments, entity_type work_order).
//  Dal menu "Add" si carica da libreria, fotocamera o File; un tocco apre l'anteprima, il menu della riga elimina.
//

import PhotosUI
import QuickLook
import SwiftUI

struct AdminWorkOrderFilesTab: View {
    let viewModel: AdminWorkOrderFilesViewModel

    var body: some View {
        @Bindable var viewModel = viewModel
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 8) {
                AdminWorkOrderCardTitle(title: String(localized: "Files"), icon: "paperclip")
                Spacer(minLength: 0)
                AdminWorkOrderActivityRefreshButton(isLoading: viewModel.isLoading) {
                    Task { await viewModel.load() }
                }
                addMenu
            }
            if let message = viewModel.errorMessage { AdminWorkOrderActivityError(message: message) }
            list
        }
        .task { await viewModel.load() }
        .photosPicker(isPresented: $viewModel.isPickingPhotos, selection: $viewModel.photoSelection,
                      maxSelectionCount: AdminWorkOrderFilesViewModel.maxPhotos, matching: .images)
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
            Text("It will be removed from this work order for everyone.")
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
        VStack(alignment: .leading, spacing: 0) {
            if viewModel.isEmpty {
                Label("No files yet.", systemImage: "doc")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .padding(.vertical, 4)
            } else if !viewModel.hasLoaded && viewModel.attachments.isEmpty {
                ProgressView().frame(maxWidth: .infinity).padding(.vertical, 12)
            }
            ForEach(viewModel.uploads) { upload in
                AdminWorkOrderAttachmentUploadRow(upload: upload)
                if !viewModel.rows.isEmpty || upload.id != viewModel.uploads.last?.id { Divider() }
            }
            ForEach(Array(viewModel.rows.enumerated()), id: \.element.id) { index, row in
                AdminWorkOrderAttachmentRow(row: row, isDeleting: viewModel.deletingId == row.id) {
                    Task { await viewModel.open(row.id) }
                } delete: {
                    viewModel.confirmDelete(row.id)
                }
                if index < viewModel.rows.count - 1 { Divider() }
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 6)
        .frame(maxWidth: .infinity, alignment: .leading)
        .ariaGlass(in: RoundedRectangle(cornerRadius: 16))
    }
}

struct AdminWorkOrderAttachmentRow: View {
    let row: AdminWorkOrderAttachmentRowItem
    let isDeleting: Bool
    let open: () -> Void
    let delete: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            Button(action: open) {
                HStack(spacing: 12) {
                    Image(systemName: row.icon)
                        .font(.title3)
                        .foregroundStyle(Color.accentColor)
                        .frame(width: 30)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(row.filename)
                            .font(.subheadline.weight(.medium))
                            .foregroundStyle(Color.primary)
                            .lineLimit(2)
                        if !row.subtitle.isEmpty {
                            Text(row.subtitle).font(.caption).foregroundStyle(.secondary).lineLimit(1)
                        }
                    }
                    Spacer(minLength: 0)
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityHint("Opens a preview")
            if row.isOpening || isDeleting {
                ProgressView().controlSize(.small)
            } else {
                Menu {
                    Button("Open", systemImage: "eye", action: open)
                    Button("Delete", systemImage: "trash", role: .destructive, action: delete)
                } label: {
                    Image(systemName: "ellipsis")
                        .frame(width: 28, height: 28)
                        .contentShape(Rectangle())
                }
                .accessibilityLabel("Actions")
            }
        }
        .padding(.vertical, 10)
        .disabled(isDeleting)
    }
}

struct AdminWorkOrderAttachmentUploadRow: View {
    let upload: AdminWorkOrderAttachmentUpload

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "arrow.up.doc")
                .font(.title3)
                .foregroundStyle(.secondary)
                .frame(width: 30)
            VStack(alignment: .leading, spacing: 6) {
                Text(upload.filename).font(.subheadline.weight(.medium)).lineLimit(1)
                ProgressView(value: upload.progress)
                Text("Uploading…").font(.caption).foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 10)
        .accessibilityElement(children: .combine)
    }
}
