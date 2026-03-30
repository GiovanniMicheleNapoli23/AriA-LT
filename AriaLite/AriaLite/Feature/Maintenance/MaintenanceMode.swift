//
//  WorkorderDetailView.swift
//  AriaLite
//
//  Created by Giovanni Michele on 19/03/26.
//

import SwiftUI
import PhotosUI

// MARK: - MaintenanceModeView
struct MaintenanceModeView: View {
    let workOrder: WorkOrder
    let viewModel: AppViewModel
    let voice: AriaVoiceViewModel          // ← passa dall'esterno

    @State private var showPhotoSource: Bool = false
    @State private var showCamera: Bool = false
    @State private var currentStepIndex: Int = 0
    @State private var noteText: String = ""
    @State private var showNoteEditor: Bool = false
    @State private var selectedPhotoItems: [PhotosPickerItem] = []
    @State private var showAIHelp: Bool = false           // ← NUOVO
    @Namespace private var glassNamespace
    @Environment(\.dismiss) private var dismiss

    private var currentItem: ChecklistItem {
        workOrder.checklist[currentStepIndex]
    }

    private var isCurrentCompleted: Bool {
        viewModel.isItemCompleted(currentItem, in: workOrder.id)
    }

    private var currentNote: FieldNote? {
        viewModel.fieldNotes[workOrder.id]?[currentItem.id]
    }

    private var currentPhotos: [PhotoAttachment] {
        let all = viewModel.photoAttachments[workOrder.id] ?? []
        return all.filter { $0.checklistItemID == currentItem.id }
    }

    private var completedCount: Int {
        workOrder.checklist.filter { viewModel.isItemCompleted($0, in: workOrder.id) }.count
    }

    private var allCompleted: Bool {
        completedCount == workOrder.checklist.count
    }

    private func goNext() {
        viewModel.toggleItem(
            workOrderID: workOrder.id,
            itemID: currentItem.id,
            current: false
        )
        withAnimation(.spring(duration: 0.3)) {
            currentStepIndex += 1
        }
    }

    var body: some View {
        NavigationStack {
            ZStack(alignment: .bottom) {
                LinearGradient(
                    colors: [Color.liteBackground, Color.liteAccent.opacity(0.12)],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                .ignoresSafeArea()

                ScrollView {
                    VStack(spacing: 14) {
                        stepHeaderCard
                        noteAndPhotoRow
                        if !workOrder.documents.isEmpty {
                            documentsCard
                        }
                        Color.clear.frame(height: 110)
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, 12)
                }

                navigationBar
            }
            .navigationTitle(workOrder.title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                Button(role: .close) { dismiss() }
            }
            .onChange(of: viewModel.submissionStatus) { _, status in
                if case .success = status {
                    dismiss()
                    viewModel.submissionStatus = .idle
                }
            }
            .sheet(isPresented: $showNoteEditor) {
                NoteEditorSheet(
                    text: $noteText,
                    onSave: {
                        viewModel.upsertNote(
                            workOrderID: workOrder.id,
                            itemID: currentItem.id,
                            text: noteText
                        )
                        showNoteEditor = false
                    },
                    onCancel: { showNoteEditor = false }
                )
                .presentationDetents([.medium])
            }
            .sheet(isPresented: $showAIHelp) {                    // ← NUOVO
                AIHelpSheet(currentItem: currentItem, voice: voice)
            }
            .onChange(of: selectedPhotoItems) { _, items in
                Task {
                    for item in items {
                        if let data = try? await item.loadTransferable(type: Data.self) {
                            let photo = PhotoAttachment(
                                id: UUID(),
                                filename: "\(UUID().uuidString).jpg",
                                base64Data: data.base64EncodedString(),
                                capturedAt: Date(),
                                checklistItemID: currentItem.id
                            )
                            viewModel.addPhoto(photo, to: workOrder.id)
                        }
                    }
                    selectedPhotoItems = []
                }
            }
        }
        .preferredColorScheme(.light)
    }

    // MARK: - Step Header Card
    private var stepHeaderCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("Passo \(currentStepIndex + 1) di \(workOrder.checklist.count)")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(Color.liteAccent)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 4)
                    .background(Color.liteAccent.opacity(0.1))
                    .clipShape(Capsule())

                Spacer()

                HStack(spacing: 5) {
                    Image(systemName: isCurrentCompleted ? "checkmark.circle.fill" : "circle")
                        .font(.system(size: 14))
                        .foregroundStyle(isCurrentCompleted ? Color.green : Color.liteAccent.opacity(0.3))
                        .contentTransition(.symbolEffect(.replace))
                    Text(isCurrentCompleted ? "Completato" : "Da fare")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(isCurrentCompleted ? Color.green : Color.liteText.opacity(0.4))
                }
            }

            Text(currentItem.text)
                .font(.system(size: 20, weight: .bold))
                .foregroundStyle(Color.liteText)
                .fixedSize(horizontal: false, vertical: true)

            if let description = currentItem.description, !description.isEmpty {
                Text(description)
                    .font(.system(size: 14))
                    .foregroundStyle(Color.liteText.opacity(0.6))
                    .fixedSize(horizontal: false, vertical: true)
                    .lineSpacing(3)
            }

            VStack(spacing: 6) {
                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        Capsule()
                            .fill(Color.liteAccent.opacity(0.12))
                            .frame(height: 4)
                        Capsule()
                            .fill(Color.liteAccent)
                            .frame(
                                width: geo.size.width * CGFloat(completedCount) / CGFloat(workOrder.checklist.count),
                                height: 4
                            )
                            .animation(.spring(duration: 0.4), value: completedCount)
                    }
                }
                .frame(height: 4)

                HStack(spacing: 5) {
                    ForEach(Array(workOrder.checklist.enumerated()), id: \.offset) { index, item in
                        let done = viewModel.isItemCompleted(item, in: workOrder.id)
                        let isCurrent = index == currentStepIndex
                        Circle()
                            .fill(
                                done
                                    ? Color.liteAccent
                                    : isCurrent
                                        ? Color.liteAccent.opacity(0.55)
                                        : Color.liteAccent.opacity(0.15)
                            )
                            .frame(width: isCurrent ? 9 : 6, height: isCurrent ? 9 : 6)
                            .animation(.spring(duration: 0.3), value: isCurrent)
                            .animation(.spring(duration: 0.3), value: done)
                            .onTapGesture {
                                withAnimation(.spring(duration: 0.3)) { currentStepIndex = index }
                            }
                    }
                    Spacer()
                    Text("\(completedCount)/\(workOrder.checklist.count) completati")
                        .font(.system(size: 11))
                        .foregroundStyle(Color.liteText.opacity(0.4))
                }
            }
            .padding(.top, 4)
        }
        .padding(20)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.liteAccent.opacity(0.04))
        .clipShape(RoundedRectangle(cornerRadius: 20))
        .overlay(
            RoundedRectangle(cornerRadius: 20)
                .strokeBorder(Color.liteAccent.opacity(0.12), lineWidth: 1)
        )
    }

    // MARK: - Note + Photo Row
    private var noteAndPhotoRow: some View {
        HStack(spacing: 12) {
            noteCard
            photoCard
        }
    }

    // MARK: - Note Card
    private var noteCard: some View {
        Button {
            noteText = currentNote?.text ?? ""
            showNoteEditor = true
        } label: {
            VStack(alignment: .leading, spacing: 10) {
                ZStack {
                    Circle()
                        .fill(Color.liteAccent.opacity(0.1))
                        .frame(width: 38, height: 38)
                    Image(systemName: currentNote == nil ? "square.and.pencil" : "note.text")
                        .font(.system(size: 16))
                        .foregroundStyle(Color.liteAccent)
                        .contentTransition(.symbolEffect(.replace))
                }

                Spacer()

                VStack(alignment: .leading, spacing: 3) {
                    Text(currentNote == nil ? "Aggiungi nota" : "Nota tecnica")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(Color.liteText)
                    Text(currentNote?.text ?? "Nessuna nota")
                        .font(.system(size: 12))
                        .foregroundStyle(Color.liteText.opacity(currentNote == nil ? 0.35 : 0.6))
                        .lineLimit(2)
                }
            }
            .padding(16)
            .frame(maxWidth: .infinity, minHeight: 130, alignment: .topLeading)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .glassEffect(.regular.interactive(), in: RoundedRectangle(cornerRadius: 16))
    }

    // MARK: - Photo Card
    private var photoCard: some View {
        Button {
            showPhotoSource = true
        } label: {
            VStack(alignment: .leading, spacing: 10) {
                ZStack {
                    Circle()
                        .fill(Color.liteAccent.opacity(0.1))
                        .frame(width: 38, height: 38)
                    Image(systemName: currentPhotos.isEmpty ? "camera" : "photo.stack")
                        .font(.system(size: 16))
                        .foregroundStyle(Color.liteAccent)
                        .contentTransition(.symbolEffect(.replace))
                }

                Spacer()

                VStack(alignment: .leading, spacing: 3) {
                    Text("Foto")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(Color.liteText)
                    Text(currentPhotos.isEmpty ? "Nessuna foto" : "\(currentPhotos.count) allegate")
                        .font(.system(size: 12))
                        .foregroundStyle(Color.liteText.opacity(currentPhotos.isEmpty ? 0.35 : 0.6))
                }
            }
            .padding(16)
            .frame(maxWidth: .infinity, minHeight: 130, alignment: .topLeading)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .glassEffect(.regular.interactive(), in: RoundedRectangle(cornerRadius: 16))
        .sheet(isPresented: $showPhotoSource) {
            PhotoSourceSheet(selectedPhotoItems: $selectedPhotoItems) {
                showCamera = true
            }
        }
        .fullScreenCover(isPresented: $showCamera) {
            CameraPicker { image in
                if let data = image.jpegData(compressionQuality: 0.8) {
                    let photo = PhotoAttachment(
                        id: UUID(),
                        filename: "\(UUID().uuidString).jpg",
                        base64Data: data.base64EncodedString(),
                        capturedAt: Date(),
                        checklistItemID: currentItem.id
                    )
                    viewModel.addPhoto(photo, to: workOrder.id)
                }
            }
            .ignoresSafeArea()
        }
    }

    // MARK: - Documents Card
    private var documentsCard: some View {
        DisclosureGroup {
            ForEach(workOrder.documents) { doc in
                VStack(alignment: .leading, spacing: 4) {
                    Text(doc.title)
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(Color.liteText)
                    if let notes = doc.notes {
                        Text(notes)
                            .font(.system(size: 12))
                            .foregroundStyle(.secondary)
                    }
                    if !doc.photos.isEmpty {
                        Text(doc.photos.joined(separator: " · "))
                            .font(.caption2)
                            .foregroundStyle(.tertiary)
                    }
                }
                .padding(.vertical, 6)
            }
        } label: {
            Label("Documenti di riferimento (\(workOrder.documents.count))", systemImage: "doc.text")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(Color.liteText)
        }
        .padding(16)
        .glassEffect(.regular, in: RoundedRectangle(cornerRadius: 16))
    }

    // MARK: - Navigation Bar
    private var navigationBar: some View {
        GlassEffectContainer(spacing: 12) {
            VStack(spacing: 0) {

                // ── Ask help to AI ──────────────────────────────── ← NUOVO
                Button { showAIHelp = true } label: {
                    HStack(spacing: 7) {
                        Image(systemName: "sparkles")
                            .font(.headline)
                        Text("Ask help to AI")
                            .font(.headline)
                    }
                    .frame(maxWidth: .infinity/2)
                    .padding(.vertical, 15)
                    .foregroundStyle(Color.liteAccent)
                    .background(Color.liteAccent.opacity(0.08), in: RoundedRectangle(cornerRadius: 10))
                    .overlay(
                        RoundedRectangle(cornerRadius: 10)
                            .strokeBorder(Color.liteAccent.opacity(0.15), lineWidth: 1)
                    )
                }
                .buttonStyle(.plain)
                .padding(.horizontal, 20)
                .padding(.top, 14)
                .padding(.bottom, 10)

                // ── Navigazione esistente ───────────────────────────
                HStack(spacing: 12) {
                    Button {
                        withAnimation(.spring(duration: 0.3)) { currentStepIndex -= 1 }
                    } label: {
                        HStack(spacing: 6) {
                            Image(systemName: "chevron.left")
                                .font(.system(size: 14, weight: .semibold))
                            Text("Indietro")
                                .font(.system(size: 15, weight: .semibold))
                        }
                        .padding(.horizontal, 20)
                        .padding(.vertical, 14)
                    }
                    .buttonStyle(.glass)
                    .disabled(currentStepIndex == 0)
                    .glassEffectID("prev", in: glassNamespace)

                    Spacer()

                    Group {
                        if currentStepIndex < workOrder.checklist.count - 1 {
                            Button {
                                goNext()
                            } label: {
                                HStack(spacing: 6) {
                                    Text("Avanti")
                                        .font(.system(size: 15, weight: .semibold))
                                    Image(systemName: "chevron.right")
                                        .font(.system(size: 14, weight: .semibold))
                                }
                                .padding(.horizontal, 28)
                                .padding(.vertical, 14)
                            }
                            .buttonStyle(.glassProminent)
                            .tint(Color.liteAccent)
                            .glassEffectID("main-action", in: glassNamespace)
                        } else {
                            submitButton
                                .glassEffectID("main-action", in: glassNamespace)
                        }
                    }
                    .animation(.spring(duration: 0.4), value: currentStepIndex)
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 14)
                .padding(.bottom, 8)
            }
        }
    }

    // MARK: - Submit Button
    @ViewBuilder
    private var submitButton: some View {
        switch viewModel.submissionStatus {
        case .idle:
            Button {
                viewModel.toggleItem(
                    workOrderID: workOrder.id,
                    itemID: currentItem.id,
                    current: false
                )
                Task { await viewModel.submitReport(for: workOrder) }
            } label: {
                Label("Invia Resoconto", systemImage: "paperplane.fill")
                    .font(.system(size: 15, weight: .semibold))
                    .padding(.horizontal, 28)
                    .padding(.vertical, 14)
            }
            .buttonStyle(.glassProminent)
            .tint(Color.liteAccent)

        case .sending:
            HStack(spacing: 8) {
                ProgressView()
                Text("Invio…").font(.system(size: 15, weight: .medium))
            }
            .padding(.horizontal, 28)
            .padding(.vertical, 14)
            .glassEffect(.regular.tint(Color.liteAccent.opacity(0.2)), in: Capsule())

        case .success:
            Label("Inviato!", systemImage: "checkmark.circle.fill")
                .font(.system(size: 15, weight: .semibold))
                .padding(.horizontal, 28)
                .padding(.vertical, 14)
                .glassEffect(.regular.tint(.green.opacity(0.3)), in: Capsule())

        case .failure:
            Button {
                Task { await viewModel.submitReport(for: workOrder) }
            } label: {
                Label("Riprova", systemImage: "arrow.clockwise")
                    .font(.system(size: 15, weight: .semibold))
                    .padding(.horizontal, 28)
                    .padding(.vertical, 14)
            }
            .buttonStyle(.glassProminent)
            .tint(.red)
        }
    }
}

// MARK: - PhotoSourceSheet

struct PhotoSourceSheet: View {
    @Binding var selectedPhotoItems: [PhotosPickerItem]
    let onCamera: () -> Void
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(spacing: 16) {
            // Handle
            Capsule()
                .fill(Color.secondary.opacity(0.3))
                .frame(width: 36, height: 4)
                .padding(.top, 10)

            Text("Aggiungi foto")
                .font(.system(size: 17, weight: .semibold))
                .foregroundStyle(.primary)
                .padding(.top, 4)

            HStack(spacing: 16) {
                // Galleria
                PhotosPicker(selection: $selectedPhotoItems, matching: .images) {
                    PhotoSourceTile(
                        icon: "photo.on.rectangle.angled",
                        label: "Galleria"
                    )
                }
                .buttonStyle(.plain)
                .onChange(of: selectedPhotoItems) { _, items in
                    if !items.isEmpty { dismiss() }
                }

                // Fotocamera
                Button {
                    dismiss()
                    onCamera()
                } label: {
                    PhotoSourceTile(
                        icon: "camera",
                        label: "Fotocamera"
                    )
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 24)
        }
        .presentationDetents([.height(200)])
        
    }
}

// MARK: - PhotoSourceTile

private struct PhotoSourceTile: View {
    let icon: String
    let label: String

    var body: some View {
        VStack(spacing: 12) {
            ZStack {
                Circle()
                    .fill(Color(.systemGray5))
                    .frame(width: 64, height: 64)
                Image(systemName: icon)
                    .font(.system(size: 26, weight: .medium))
                    .foregroundStyle(Color.liteAccent)
            }
            Text(label)
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(.primary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 20)
        .background(Color(.systemGray6), in: RoundedRectangle(cornerRadius: 18))
    }
}
