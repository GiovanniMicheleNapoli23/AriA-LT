//
//  AdminDocumentUploadView.swift
//  AriaLite
//
//  Created by Giovanni Michele on 22/10/26.
//
//  Il foglio di caricamento, una sola scroll view di schede: stabilimento, cosa fare del documento
//  (indicizzarlo, estrarne i dati), file da Files con l'avviso sui nomi già presenti.
//  Con doppioni chiede se sostituirli o saltarli.
//

import SwiftUI
import UniformTypeIdentifiers

struct AdminDocumentUploadView: View {
    /// In `@State`: il foglio si ricostruisce col genitore, la scelta a metà non deve ripartire da capo.
    @State private var viewModel: AdminDocumentUploadViewModel
    let onUploaded: () -> Void

    @State private var isImporting = false
    @Environment(\.dismiss) private var dismiss

    init(viewModel: AdminDocumentUploadViewModel, onUploaded: @escaping () -> Void) {
        _viewModel = State(initialValue: viewModel)
        self.onUploaded = onUploaded
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    destination
                    pipelines
                    filesSection
                    if let message = viewModel.errorMessage {
                        AdminSectionNotice(text: message, isError: true)
                    }
                }
                .padding(20)
                .ariaReadableWidth()
            }
            .scrollDismissesKeyboard(.interactively)
            .liteBackground()
            .navigationTitle("Upload documents")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                        .disabled(viewModel.isUploading)
                }
                ToolbarItem(placement: .confirmationAction) {
                    if viewModel.isUploading {
                        ProgressView()
                    } else {
                        Button("Upload") { Task { await viewModel.startUpload() } }
                            .disabled(!viewModel.canUpload)
                    }
                }
            }
            .interactiveDismissDisabled(viewModel.isUploading)
            .fileImporter(isPresented: $isImporting, allowedContentTypes: Self.allowedTypes, allowsMultipleSelection: true) { result in
                Task { await viewModel.filesImported(result) }
            }
            .task(id: viewModel.conflictKey) { await viewModel.checkConflicts() }
            .confirmationDialog("Some files already exist", isPresented: $viewModel.showsConflictChoice, titleVisibility: .visible) {
                Button("Replace existing") { Task { await viewModel.upload(replacing: true) } }
                Button("Upload only new files") { Task { await viewModel.upload(replacing: false) } }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text(viewModel.conflictMessage)
            }
            .onChange(of: viewModel.didFinish) { _, finished in
                guard finished else { return }
                onUploaded()
                dismiss()
            }
        }
    }

    /// PDF, Office, testo e immagini: quello che le pipeline sanno leggere.
    private static let allowedTypes: [UTType] = [.pdf, .text, .image, .spreadsheet, .presentation]
        + ["doc", "docx"].compactMap { UTType(filenameExtension: $0) }

    // MARK: Schede

    private var destination: some View {
        AdminCard(title: "Plant", systemImage: "building.2") {
            Picker("Plant", selection: $viewModel.plantId) {
                if viewModel.plantId == nil { Text("Choose").tag(String?.none) }
                ForEach(viewModel.plants) { Text($0.name).tag(Optional($0.id)) }
            }
            .pickerStyle(.menu)
            .labelsHidden()
            .frame(maxWidth: .infinity, alignment: .leading)
            .disabled(viewModel.isUploading)
            caption("Documents are shared with everyone in this plant.")
        }
    }

    private var pipelines: some View {
        AdminCard(title: "After upload", systemImage: "gearshape.2") {
            VStack(alignment: .leading, spacing: 8) {
                Toggle("Index for answers", isOn: $viewModel.runIndexing)
                Toggle("Extract maintenance data", isOn: $viewModel.runExtraction)
            }
            .disabled(viewModel.isUploading)
            caption("Indexing lets Aria cite the document. Extraction proposes assets, spare parts and procedures for review.")
        }
    }

    private var filesSection: some View {
        AdminCard(title: "Files", systemImage: "doc.on.doc") {
            ForEach(viewModel.files) { file in
                AdminDocumentUploadFileRow(file: file, isConflicting: viewModel.isConflicting(file),
                                           canRemove: !viewModel.isUploading) { viewModel.remove(file) }
                Divider()
            }
            Button {
                isImporting = true
            } label: {
                if viewModel.isReading {
                    ProgressView()
                } else {
                    Label("Choose from Files", systemImage: "folder")
                }
            }
            .buttonStyle(.bordered)
            .tint(Color.liteAccent)
            .disabled(viewModel.isUploading || viewModel.isReading)
            if viewModel.isUploading {
                VStack(alignment: .leading, spacing: 6) {
                    ProgressView(value: viewModel.progress)
                    if let name = viewModel.currentFileName {
                        Text("Uploading \(name)…")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                    }
                }
            }
            filesFooter
        }
    }

    @ViewBuilder
    private var filesFooter: some View {
        if viewModel.isCheckingConflicts {
            caption("Checking for files already in this plant…")
        } else if let message = viewModel.conflictCheckError {
            caption("Couldn't check for duplicates: \(message)")
        } else if !viewModel.files.isEmpty {
            caption("\(viewModel.files.count) files · \(viewModel.totalSize)")
        }
    }

    private func caption(_ text: LocalizedStringKey) -> some View {
        Text(text)
            .font(.footnote)
            .foregroundStyle(.secondary)
    }
}
