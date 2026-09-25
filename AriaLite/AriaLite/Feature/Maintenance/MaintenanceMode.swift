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
    let voice: AriaVoiceViewModel

    @State private var showPhotoSource: Bool = false
    @State private var showCamera: Bool = false
    @State private var currentStepIndex: Int = 0
    @State private var noteText: String = ""
    @State private var showNoteEditor: Bool = false
    @State private var selectedPhotoItems: [PhotosPickerItem] = []
    @State private var showAIHelp: Bool = false
    @Namespace private var glassNamespace
    @Environment(\.dismiss) private var dismiss

    // MARK: - Safe current item
    private var currentItem: ChecklistItem? {
        guard workOrder.checklist.indices.contains(currentStepIndex) else { return nil }
        return workOrder.checklist[currentStepIndex]
    }

    private var isCurrentCompleted: Bool {
        guard let item = currentItem else { return false }
        return viewModel.isItemCompleted(item, in: workOrder.id)
    }

    private var currentNote: FieldNote? {
        guard let item = currentItem else { return nil }
        return viewModel.fieldNotes[workOrder.id]?[item.id]
    }

    private var currentPhotos: [PhotoAttachment] {
        guard let item = currentItem else { return [] }
        let all = viewModel.photoAttachments[workOrder.id] ?? []
        return all.filter { $0.checklistItemID == item.id }
    }

    private var completedCount: Int {
        workOrder.checklist.filter { viewModel.isItemCompleted($0, in: workOrder.id) }.count
    }

    private var allCompleted: Bool {
        completedCount == workOrder.checklist.count
    }

    private func goNext() {
        guard let item = currentItem else { return }
        viewModel.toggleItem(
            workOrderID: workOrder.id,
            itemID: item.id,
            current: false
        )
        let nextIndex = currentStepIndex + 1
        guard nextIndex < workOrder.checklist.count else { return }
        withAnimation(.spring(duration: 0.3)) {
            currentStepIndex = nextIndex
        }
    }

    var body: some View {
        NavigationStack {
            Group {
                if workOrder.checklist.isEmpty {
                    ContentUnavailableView(
                        "No steps available",
                        systemImage: "list.bullet.clipboard",
                        description: Text("This task has no checklist items.")
                    )
                } else {
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
                                Color.clear.frame(height: 110)
                            }
                            .padding(.horizontal, 16)
                            .padding(.top, 12)
                        }

                        navigationBar
                    }
                }
            }
            .navigationTitle(workOrder.title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { toolbarContent }
            .onChange(of: viewModel.submissionStatus) { _, status in
                if case .success = status {
                    dismiss()
                    viewModel.submissionStatus = .idle
                }
            }
            .sheet(isPresented: $showNoteEditor) {
                if let item = currentItem {
                    NoteEditorSheet(
                        text: $noteText,
                        onSave: {
                            viewModel.upsertNote(
                                workOrderID: workOrder.id,
                                itemID: item.id,
                                text: noteText
                            )
                            showNoteEditor = false
                        },
                        onCancel: { showNoteEditor = false }
                    )
                    .presentationDetents([.medium])
                }
            }
            .sheet(isPresented: $showAIHelp) {
                if let item = currentItem {
                    AIHelpSheet(currentItem: item, workOrder: workOrder)
                }
            }
            .onChange(of: selectedPhotoItems) { _, items in
                guard let item = currentItem else { return }
                Task {
                    for photoItem in items {
                        if let data = try? await photoItem.loadTransferable(type: Data.self) {
                            let photo = PhotoAttachment(
                                id: UUID(),
                                filename: "\(UUID().uuidString).jpg",
                                base64Data: data.base64EncodedString(),
                                capturedAt: Date(),
                                checklistItemID: item.id
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

    // MARK: - Toolbar
    @ToolbarContentBuilder
    private var toolbarContent: some ToolbarContent {
        ToolbarItem(placement: .principal) {
            Text(workOrder.title)
                .font(.system(size: 17, weight: .semibold))
                .lineLimit(1)
                .minimumScaleFactor(0.6)
        }
        ToolbarItem(placement: .topBarTrailing) {
            if #available(iOS 26.0, *) {
                Button(role: .close) { dismiss() }
            } else {
                Button {
                    dismiss()
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(.secondary)
                }
            }
        }
    }

    // MARK: - Step Header Card
    private var stepHeaderCard: some View {
        guard let item = currentItem else { return AnyView(EmptyView()) }
        return AnyView(
            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    Text("Step \(currentStepIndex + 1) of \(workOrder.checklist.count)")
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
                        Text(isCurrentCompleted ? String(localized: "Completed") : String(localized: "To do"))
                            .font(.system(size: 12, weight: .medium))
                            .foregroundStyle(isCurrentCompleted ? Color.green : Color.liteText.opacity(0.4))
                    }
                }

                Text(item.text)
                    .font(.system(size: 20, weight: .bold))
                    .foregroundStyle(Color.liteText)
                    .fixedSize(horizontal: false, vertical: true)

                if let description = item.description, !description.isEmpty {
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
                        ForEach(Array(workOrder.checklist.enumerated()), id: \.offset) { index, checkItem in
                            let done = viewModel.isItemCompleted(checkItem, in: workOrder.id)
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
                        Text("\(completedCount)/\(workOrder.checklist.count) completed")
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
                    Text(currentNote == nil ? String(localized: "Add Notes") : String(localized: "Technical Notes"))
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(Color.liteText)
                    Text(currentNote?.text ?? String(localized: "No notes"))
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
        .ariaGlass(in: RoundedRectangle(cornerRadius: 16), interactive: true)
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
                    Text("Photos")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(Color.liteText)
                    Text(currentPhotos.isEmpty ? String(localized: "No photos") : String(localized: "\(currentPhotos.count) attached"))
                        .font(.system(size: 12))
                        .foregroundStyle(Color.liteText.opacity(currentPhotos.isEmpty ? 0.35 : 0.6))
                }
            }
            .padding(16)
            .frame(maxWidth: .infinity, minHeight: 130, alignment: .topLeading)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .ariaGlass(in: RoundedRectangle(cornerRadius: 16), interactive: true)
        .sheet(isPresented: $showPhotoSource) {
            PhotoSourceSheet(selectedPhotoItems: $selectedPhotoItems) {
                showCamera = true
            }
        }
        .fullScreenCover(isPresented: $showCamera) {
            CameraPicker { image in
                guard let item = currentItem else { return }
                if let data = image.jpegData(compressionQuality: 0.8) {
                    let photo = PhotoAttachment(
                        id: UUID(),
                        filename: "\(UUID().uuidString).jpg",
                        base64Data: data.base64EncodedString(),
                        capturedAt: Date(),
                        checklistItemID: item.id
                    )
                    viewModel.addPhoto(photo, to: workOrder.id)
                }
            }
            .ignoresSafeArea()
        }
    }

    // MARK: - Navigation Bar
    private var navigationBar: some View {
        AriaGlassEffectContainer(spacing: 12) {
            VStack(spacing: 0) {

                // ── Ask AI ──────────────────────────────────────────
                Button { showAIHelp = true } label: {
                    HStack(spacing: 12) {
                        AriaOrb()
                            .frame(width: 32, height: 32)
                            .shadow(color: Color.liteAccent.opacity(0.4), radius: 5)

                        VStack(alignment: .leading, spacing: 1) {
                            Text("Ask AriA")
                                .font(.system(size: 16, weight: .semibold, design: .rounded))
                            Text("Get help with this step")
                                .font(.system(size: 12))
                                .foregroundStyle(Color.liteAccent.opacity(0.7))
                        }

                        Spacer()

                        Image(systemName: "arrow.up.right")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundStyle(Color.liteAccent.opacity(0.7))
                    }
                    .foregroundStyle(Color.liteAccent)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 12)
                    .frame(maxWidth: .infinity)
                    .background(
                        LinearGradient(
                            colors: [Color.liteAccent.opacity(0.14), Color.liteAccent.opacity(0.05)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        in: RoundedRectangle(cornerRadius: 14)
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 14)
                            .strokeBorder(Color.liteAccent.opacity(0.20), lineWidth: 1)
                    )
                }
                .buttonStyle(.plain)
                .padding(.horizontal, 20)
                .padding(.top, 14)
                .padding(.bottom, 10)

                // ── Navigation ──────────────────────────────────────
                HStack(spacing: 12) {
                    Button {
                        withAnimation(.spring(duration: 0.3)) { currentStepIndex -= 1 }
                    } label: {
                        HStack(spacing: 6) {
                            Image(systemName: "chevron.left")
                                .font(.system(size: 14, weight: .semibold))
                            Text("Previous")
                                .font(.system(size: 15, weight: .semibold))
                        }
                        .padding(.horizontal, 20)
                        .padding(.vertical, 14)
                    }
                    .ariaGlassButtonStyle()
                    .disabled(currentStepIndex == 0)
                    .ariaGlassEffectID("prev", in: glassNamespace)

                    Spacer()

                    Group {
                        if currentStepIndex < workOrder.checklist.count - 1 {
                            Button {
                                goNext()
                            } label: {
                                HStack(spacing: 6) {
                                    Text("Next")
                                        .font(.system(size: 15, weight: .semibold))
                                    Image(systemName: "chevron.right")
                                        .font(.system(size: 14, weight: .semibold))
                                }
                                .padding(.horizontal, 28)
                                .padding(.vertical, 14)
                            }
                            .ariaProminentGlassButtonStyle(tint: Color.liteAccent)
                            .ariaGlassEffectID("main-action", in: glassNamespace)
                        } else {
                            submitButton
                                .ariaGlassEffectID("main-action", in: glassNamespace)
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
                guard let item = currentItem else { return }
                viewModel.toggleItem(
                    workOrderID: workOrder.id,
                    itemID: item.id,
                    current: false
                )
                Task { await viewModel.submitReport(for: workOrder) }
            } label: {
                Label("Send", systemImage: "paperplane.fill")
                    .font(.system(size: 15, weight: .semibold))
                    .padding(.horizontal, 28)
                    .padding(.vertical, 14)
            }
            .ariaProminentGlassButtonStyle(tint: Color.liteAccent)

        case .sending:
            HStack(spacing: 8) {
                ProgressView()
                Text("Sending...").font(.system(size: 15, weight: .medium))
            }
            .padding(.horizontal, 28)
            .padding(.vertical, 14)
            .ariaGlass(in: Capsule(), tint: Color.liteAccent.opacity(0.2))

        case .success:
            Label("Success!", systemImage: "checkmark.circle.fill")
                .font(.system(size: 15, weight: .semibold))
                .padding(.horizontal, 28)
                .padding(.vertical, 14)
                .ariaGlass(in: Capsule(), tint: .green.opacity(0.3))

        case .failure:
            Button {
                Task { await viewModel.submitReport(for: workOrder) }
            } label: {
                Label("Try again", systemImage: "arrow.clockwise")
                    .font(.system(size: 15, weight: .semibold))
                    .padding(.horizontal, 28)
                    .padding(.vertical, 14)
            }
            .ariaProminentGlassButtonStyle(tint: .red)
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

            Text("Add Photo")
                .font(.system(size: 17, weight: .semibold))
                .foregroundStyle(.primary)
                .padding(.top, 4)

            HStack(spacing: 16) {
                // Galleria
                PhotosPicker(selection: $selectedPhotoItems, matching: .images) {
                    PhotoSourceTile(
                        icon: "photo.on.rectangle.angled",
                        label: String(localized: "Gallery")
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
                        label: String(localized: "Camera")
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
