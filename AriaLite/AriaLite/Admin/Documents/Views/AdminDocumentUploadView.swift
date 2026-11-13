//
//  AdminDocumentUploadView.swift
//  AriaLite
//
//  Created by Giovanni Michele on 22/10/26.
//
//  Il foglio di caricamento, una sola scroll view di schede: prima i file (un'area da toccare finché non ce ne
//  sono, poi l'elenco con l'avviso sui nomi già presenti), poi lo stabilimento e cosa fare del documento
//  (indicizzarlo, estrarne i dati). Il pulsante in basso dice quanti file parte; con doppioni chiede se
//  sostituirli o saltarli, poi affida i file al caricamento in background e chiude il foglio.
//

import SwiftUI
import UniformTypeIdentifiers

struct AdminDocumentUploadView: View {
    /// In `@State`: il foglio si ricostruisce col genitore, la scelta a metà non deve ripartire da capo.
    @State private var viewModel: AdminDocumentUploadViewModel

    @State private var isImporting = false
    @Environment(\.dismiss) private var dismiss

    init(viewModel: AdminDocumentUploadViewModel) {
        _viewModel = State(initialValue: viewModel)
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    filesSection
                    destination
                    pipelines
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
            }
            .safeAreaInset(edge: .bottom, spacing: 0) { uploadBar }
            .interactiveDismissDisabled(viewModel.isUploading)
            .fileImporter(isPresented: $isImporting, allowedContentTypes: Self.allowedTypes, allowsMultipleSelection: true) { result in
                Task { await viewModel.filesImported(result) }
            }
            .task(id: viewModel.conflictKey) { await viewModel.checkConflicts() }
            .alert("Some files already exist", isPresented: $viewModel.showsConflictChoice) {
                Button("Replace existing") { Task { await viewModel.upload(replacing: true) } }
                Button("Upload only new files") { Task { await viewModel.upload(replacing: false) } }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text(viewModel.conflictMessage)
            }
            .onChange(of: viewModel.didFinish) { _, finished in
                if finished { dismiss() }
            }
        }
    }

    /// PDF, Office, testo e immagini: quello che le pipeline sanno leggere.
    private static let allowedTypes: [UTType] = [.pdf, .text, .image, .spreadsheet, .presentation]
        + ["doc", "docx"].compactMap { UTType(filenameExtension: $0) }

    // MARK: Schede

    private var filesSection: some View {
        AdminCard(title: "Files", systemImage: "doc.on.doc") {
            if viewModel.files.isEmpty {
                AdminDocumentUploadDropZone(isReading: viewModel.isReading) { isImporting = true }
                    .disabled(viewModel.isUploading || viewModel.isReading)
            } else {
                VStack(spacing: 10) {
                    ForEach(viewModel.files) { file in
                        AdminDocumentUploadFileRow(file: file, isConflicting: viewModel.isConflicting(file),
                                                   canRemove: !viewModel.isUploading) { viewModel.remove(file) }
                        Divider()
                    }
                }
                Button {
                    isImporting = true
                } label: {
                    HStack(spacing: 8) {
                        if viewModel.isReading {
                            ProgressView().controlSize(.small)
                        } else {
                            Image(systemName: "plus.circle.fill")
                        }
                        Text("Add more files")
                    }
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(Color.liteAccent)
                    .frame(minHeight: 44)
                }
                .buttonStyle(.plain)
                .disabled(viewModel.isUploading || viewModel.isReading)
            }
            filesFooter
        }
        .animation(.snappy, value: viewModel.files.count)
    }

    private var destination: some View {
        AdminCard(title: "Site", systemImage: "building.2") {
            Menu {
                Picker("Site", selection: $viewModel.plantId) {
                    ForEach(viewModel.plants) { Text($0.name).tag(Optional($0.id)) }
                }
            } label: {
                HStack(spacing: 8) {
                    Group {
                        if let name = viewModel.plantName {
                            Text(verbatim: name).foregroundStyle(Color.liteText)
                        } else {
                            Text("Choose a site").foregroundStyle(.secondary)
                        }
                    }
                    .font(.body.weight(.medium))
                    .lineLimit(1)
                    Spacer(minLength: 8)
                    Image(systemName: "chevron.up.chevron.down")
                        .font(.footnote.weight(.semibold))
                        .foregroundStyle(.secondary)
                }
                .padding(.horizontal, 14)
                .frame(minHeight: 48)
                .background(Color.primary.opacity(0.06), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                .contentShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            }
            .buttonStyle(.plain)
            .disabled(viewModel.isUploading)
            caption("Documents are shared with everyone on this site.")
        }
    }

    private var pipelines: some View {
        AdminCard(title: "After upload", systemImage: "gearshape.2") {
            VStack(spacing: 8) {
                AdminDocumentPipelineToggle(title: "Index for answers",
                                            detail: "Aria can find and cite the document in chat.",
                                            systemImage: "text.magnifyingglass", isOn: $viewModel.runIndexing)
                Divider()
                AdminDocumentPipelineToggle(title: "Extract maintenance data",
                                            detail: "Proposes assets, spare parts and procedures for you to review.",
                                            systemImage: "wrench.and.screwdriver", isOn: $viewModel.runExtraction)
            }
            .disabled(viewModel.isUploading)
            if viewModel.pipelines.isEmpty {
                caption("Turn on at least one to upload.")
            }
        }
        .animation(.snappy, value: viewModel.pipelines.isEmpty)
    }

    // MARK: Pulsante

    private var uploadBar: some View {
        VStack(spacing: 8) {
            Button {
                Task { await viewModel.startUpload() }
            } label: {
                HStack(spacing: 8) {
                    if viewModel.isUploading {
                        ProgressView().tint(Color.liteOnAccent)
                    } else {
                        Image(systemName: "arrow.up.circle.fill")
                    }
                    if viewModel.files.isEmpty {
                        Text("Upload")
                    } else {
                        Text("Upload \(viewModel.files.count) files")
                    }
                }
                .font(.headline)
                .frame(maxWidth: .infinity, minHeight: 32)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
            .tint(Color.liteAccent)
            .foregroundStyle(Color.liteOnAccent)
            .disabled(!viewModel.canUpload)
            Label("Uploads continue in the background, even if you leave the app.", systemImage: "icloud.and.arrow.up")
                .font(.caption)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .padding(.horizontal, 20)
        .padding(.top, 12)
        .padding(.bottom, 8)
        .ariaReadableWidth()
        .frame(maxWidth: .infinity)
        .background(.bar)
    }

    @ViewBuilder
    private var filesFooter: some View {
        if viewModel.isCheckingConflicts {
            caption("Checking for files already on this site…")
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
