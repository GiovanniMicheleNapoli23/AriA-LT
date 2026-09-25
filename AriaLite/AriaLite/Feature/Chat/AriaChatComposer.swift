//
//  AriaChatComposer.swift
//  AriaLite
//
//  Dove si scrive ad Aria, in stile ChatGPT: una sola barra con "+" a sinistra (foto,
//  galleria, file, stile di risposta, ricerca web), il campo al centro, il microfono
//  per dettare (tocco = detta, pressione lunga = lingua e opzioni) e un pulsante tondo
//  che cambia ruolo (assistente dal vivo → invia → stop). Il contesto aggiunto e gli
//  strumenti attivi stanno sopra il campo, dentro la barra.
//

import PhotosUI
import SwiftUI
import UniformTypeIdentifiers

struct AriaChatComposer: View {
    let chat: AriaAgentChat
    let backend: AriaBackend
    var voice: AriaVoiceViewModel?
    @Binding var draft: String
    var inputFocused: FocusState<Bool>.Binding
    /// Porta alla card che aspetta la decisione (approvazione di un tool).
    var onShowPending: () -> Void

    @State private var tapCount = 0
    @State private var showCamera = false
    @State private var showPhotos = false
    @State private var showFiles = false
    @State private var photoItems: [PhotosPickerItem] = []
    @State private var dictation = AriaDictation()

    private var trimmed: String { draft.trimmingCharacters(in: .whitespacesAndNewlines) }
    private var hasText: Bool { !trimmed.isEmpty }
    private var isLocked: Bool { chat.pendingInterrupt != nil }
    private var hasPlant: Bool { backend.activePlantId != nil }
    private var hasTray: Bool { !chat.contextItems.isEmpty || chat.webSearch || chat.style != .auto }
    private var cameraAvailable: Bool { UIImagePickerController.isSourceTypeAvailable(.camera) }

    /// Gli stessi formati del context dock della web (CONTEXT_FILE_ACCEPT).
    private static let fileTypes: [UTType] = [
        .image, .pdf, .plainText, .commaSeparatedText,
        UTType(filenameExtension: "md"), UTType(filenameExtension: "doc"), UTType(filenameExtension: "docx"),
        UTType(filenameExtension: "xls"), UTType(filenameExtension: "xlsx"),
    ].compactMap { $0 }

    var body: some View {
        Group {
            if isLocked {
                lockedBar
            } else {
                bar
            }
        }
        .padding(.horizontal, 12)
        .padding(.top, 6)
        .padding(.bottom, 8)
        .animation(.snappy(duration: 0.22), value: isLocked)
        .animation(.snappy(duration: 0.22), value: hasTray)
        .fullScreenCover(isPresented: $showCamera) {
            CameraPicker { addImage($0, name: String(localized: "Photo")) }
                .ignoresSafeArea()
        }
        .photosPicker(isPresented: $showPhotos, selection: $photoItems, maxSelectionCount: 10, matching: .images)
        .onChange(of: photoItems) { _, items in
            guard !items.isEmpty else { return }
            photoItems = []
            Task { await loadPhotos(items) }
        }
        .fileImporter(isPresented: $showFiles, allowedContentTypes: Self.fileTypes, allowsMultipleSelection: true) { result in
            if case .success(let urls) = result { addFiles(urls) }
        }
        // Uscendo dalla chat il microfono si spegne.
        .onDisappear { dictation.cancel() }
        // La voce dal vivo usa lo stesso microfono: niente dettatura in parallelo.
        .onChange(of: voice?.isConnecting == true || voice?.isConnected == true) { _, live in
            if live { dictation.cancel() }
        }
    }

    // MARK: Barra

    private var bar: some View {
        VStack(alignment: .leading, spacing: 8) {
            if hasTray {
                tray
                    .transition(.move(edge: .bottom).combined(with: .opacity))
            }
            if let error = dictation.error {
                Label(error, systemImage: "mic.slash")
                    .font(.system(size: 12))
                    .foregroundStyle(.red)
                    .padding(.horizontal, 10)
                    .padding(.top, 6)
                    .transition(.opacity)
            }

            HStack(alignment: .bottom, spacing: 2) {
                plusMenu

                TextField(dictation.isListening ? "Listening…" : "Ask Aria", text: $draft, axis: .vertical)
                    .font(.system(size: 17))
                    .lineLimit(1...6)
                    .focused(inputFocused)
                    .padding(.vertical, 9)
                    .padding(.leading, 2)

                micButton

                primaryButton
                    .padding(.leading, 2)
            }
        }
        .animation(.snappy(duration: 0.2), value: dictation.error)
        .padding(6)
        // Liquid Glass (material prima di iOS 26): i messaggi scorrono sotto la barra.
        .ariaGlass(in: RoundedRectangle(cornerRadius: 26, style: .continuous), interactive: true)
    }

    // MARK: "+"

    private var plusMenu: some View {
        Menu {
            Section {
                Button("Camera", systemImage: "camera") { showCamera = true }
                    .disabled(!cameraAvailable)
                Button("Photos", systemImage: "photo.on.rectangle") { showPhotos = true }
                Button("Files", systemImage: "paperclip") { showFiles = true }
            }
            Section {
                Picker(selection: Binding(get: { chat.style }, set: { chat.style = $0 })) {
                    ForEach(AriaChatStyle.allCases, id: \.self) { style in
                        Label(style.title, systemImage: style.icon).tag(style)
                    }
                } label: {
                    Label("Response style", systemImage: chat.style.icon)
                }
                .pickerStyle(.menu)
                Toggle(isOn: Binding(get: { chat.webSearch }, set: { chat.webSearch = $0 })) {
                    Label("Web search", systemImage: "globe")
                }
            }
        } label: {
            Image(systemName: "plus")
                .font(.system(size: 20, weight: .regular))
                .foregroundStyle(.primary)
                .frame(width: 38, height: 38)
                .contentShape(Circle())
        }
        .accessibilityLabel("Add")
    }

    // MARK: Microfono (dettatura)

    /// Tocco = detta nel campo. La lingua di dettatura sta nel menu "···" della chat.
    private var micButton: some View {
        Button(action: toggleDictation) {
            ZStack {
                if dictation.isListening {
                    Circle()
                        .fill(Color.accentColor.opacity(0.14))
                        .scaleEffect(1 + CGFloat(dictation.level) * 0.35)
                        .animation(.linear(duration: 0.09), value: dictation.level)
                }
                Image(systemName: dictation.isListening ? "mic.fill" : "mic")
                    .font(.system(size: 18, weight: .regular))
                    .foregroundStyle(dictation.isListening ? Color.accentColor : .primary)
                    .contentTransition(.symbolEffect(.replace))
            }
            .frame(width: 38, height: 38)
            .contentShape(Circle())
        }
        .buttonStyle(.plain)
        .disabled(voice?.isConnected == true || voice?.isConnecting == true)
        .accessibilityLabel(dictation.isListening ? "Stop dictation" : "Dictate")
    }

    private func toggleDictation() {
        // Il testo dettato si aggiunge a quello già scritto, non lo sostituisce.
        let prefix = draft.trimmingCharacters(in: .whitespacesAndNewlines)
        Task {
            await dictation.toggle { transcript in
                draft = prefix.isEmpty ? transcript : prefix + " " + transcript
            }
        }
    }

    // MARK: Contesto e strumenti attivi

    private var tray: some View {
        ScrollView(.horizontal) {
            HStack(alignment: .bottom, spacing: 8) {
                if chat.webSearch {
                    toolPill(String(localized: "Web search"), icon: "globe") { chat.webSearch = false }
                }
                if chat.style != .auto {
                    toolPill(chat.style.shortTitle, icon: chat.style.icon) { chat.style = .auto }
                }
                ForEach(chat.contextItems) { item in
                    contextTile(item)
                }
            }
            .padding(.horizontal, 6)
            .padding(.top, 6)
        }
        .scrollIndicators(.hidden)
    }

    private func toolPill(_ title: String, icon: String, remove: @escaping () -> Void) -> some View {
        HStack(spacing: 6) {
            Image(systemName: icon).font(.system(size: 12, weight: .semibold))
            Text(title).font(.system(size: 13, weight: .medium))
            Button(action: remove) {
                Image(systemName: "xmark")
                    .font(.system(size: 10, weight: .bold))
                    .frame(width: 18, height: 18)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Remove")
        }
        .foregroundStyle(Color.accentColor)
        .padding(.leading, 11)
        .padding(.trailing, 6)
        .frame(height: 32)
        .background(Color.accentColor.opacity(0.12), in: Capsule())
    }

    @ViewBuilder
    private func contextTile(_ item: AriaContextItem) -> some View {
        Group {
            if item.kind == .image, let data = item.thumbnail, let image = UIImage(data: data) {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
                    .frame(width: 56, height: 56)
                    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            } else {
                HStack(spacing: 8) {
                    Image(systemName: "doc.fill")
                        .font(.system(size: 18))
                        .foregroundStyle(Color.accentColor)
                    VStack(alignment: .leading, spacing: 1) {
                        Text(item.name)
                            .font(.system(size: 13, weight: .medium))
                            .lineLimit(1)
                        if let size = item.size {
                            Text(Int64(size), format: .byteCount(style: .file))
                                .font(.system(size: 11))
                                .foregroundStyle(.secondary)
                        }
                    }
                    .frame(maxWidth: 140, alignment: .leading)
                }
                .padding(.horizontal, 10)
                .frame(height: 56)
                .background(Color(.tertiarySystemFill), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
            }
        }
        .overlay(alignment: .topTrailing) {
            Button {
                withAnimation(.snappy) { chat.contextItems.removeAll { $0.id == item.id } }
            } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 9, weight: .bold))
                    .foregroundStyle(.white)
                    .frame(width: 20, height: 20)
                    .background(Color.black.opacity(0.6), in: Circle())
            }
            .buttonStyle(.plain)
            .offset(x: 6, y: -6)
            .accessibilityLabel(Text("Remove \(item.name)"))
        }
        .padding(.top, 6)
        .padding(.trailing, 6)
    }

    // MARK: Aggiunta

    private func addImage(_ image: UIImage, name: String) {
        let thumbnail = image.preparingThumbnail(of: CGSize(width: 168, height: 168)) ?? image
        let item = AriaContextItem(kind: .image, name: name, thumbnail: thumbnail.jpegData(compressionQuality: 0.8))
        withAnimation(.snappy) { chat.contextItems.append(item) }
    }

    private func loadPhotos(_ items: [PhotosPickerItem]) async {
        for item in items {
            guard let data = try? await item.loadTransferable(type: Data.self),
                  let image = UIImage(data: data) else { continue }
            addImage(image, name: String(localized: "Photo"))
        }
    }

    private func addFiles(_ urls: [URL]) {
        for url in urls {
            let scoped = url.startAccessingSecurityScopedResource()
            defer { if scoped { url.stopAccessingSecurityScopedResource() } }
            let isImage = UTType(filenameExtension: url.pathExtension)?.conforms(to: .image) == true
            if isImage, let data = try? Data(contentsOf: url), let image = UIImage(data: data) {
                addImage(image, name: url.lastPathComponent)
            } else {
                let size = (try? url.resourceValues(forKeys: [.fileSizeKey]))?.fileSize
                let item = AriaContextItem(kind: .document, name: url.lastPathComponent, size: size)
                withAnimation(.snappy) { chat.contextItems.append(item) }
            }
        }
    }

    // MARK: Pulsante principale

    private var showsStop: Bool { !hasText && (chat.isStreaming || voice?.isConnected == true) }

    private var primaryButton: some View {
        Button(action: primaryAction) {
            ZStack {
                Circle()
                    .fill(buttonTint)
                    .frame(width: 38, height: 38)
                if let voice, voice.isConnecting, !hasText, !chat.isStreaming {
                    ProgressView().tint(.white)
                } else {
                    Image(systemName: symbol)
                        .font(.system(size: 15, weight: .bold))
                        .foregroundStyle(.white)
                        .contentTransition(.symbolEffect(.replace))
                }
            }
        }
        .buttonStyle(.plain)
        .disabled(hasText ? (chat.isStreaming || !hasPlant) : (!chat.isStreaming && voice == nil))
        .opacity(hasText && (chat.isStreaming || !hasPlant) ? 0.4 : 1)
        .accessibilityLabel(showsStop ? "Stop" : (hasText || voice == nil ? "Send" : "Voice"))
        // L'invio lo segnala la chat (AriaChatHaptics); qui solo stop e voce.
        .sensoryFeedback(.impact(weight: .medium), trigger: tapCount)
        .sensoryFeedback(.impact(weight: .light), trigger: chat.contextItems.count) { old, new in new > old }
    }

    private var buttonTint: Color {
        if showsStop { return .red }
        if !hasText && voice == nil { return Color.secondary.opacity(0.35) }
        return .accentColor
    }

    private var symbol: String {
        if hasText { return "arrow.up" }
        if showsStop { return "stop.fill" }
        return voice == nil ? "arrow.up" : "waveform"
    }

    private func primaryAction() {
        if hasText {
            send()
        } else if chat.isStreaming {
            chat.stop()
            tapCount += 1
        } else {
            dictation.cancel()
            voice?.toggleConnection()
            tapCount += 1
        }
    }

    private func send() {
        // Il messaggio parte così com'è: il resto della dettatura non deve riempire di nuovo il campo.
        dictation.cancel()
        chat.send(draft)
        draft = ""
        inputFocused.wrappedValue = false
    }

    // MARK: In attesa di una decisione

    /// Con una pausa aperta il backend non accetta nuovi turni: si dice perché e dove decidere.
    private var lockedBar: some View {
        HStack(spacing: 12) {
            Image(systemName: chat.pendingInterrupt?.kind == .loto ? "lock.shield.fill" : "hand.raised.fill")
                .font(.system(size: 18))
                .foregroundStyle(.orange)
            VStack(alignment: .leading, spacing: 2) {
                Text("Aria is waiting for your decision")
                    .font(.system(size: 14, weight: .semibold))
                Text("Approve or reject the action to continue.")
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)
            }
            Spacer(minLength: 4)
            Button("Review", action: onShowPending)
                .font(.system(size: 14, weight: .semibold))
                .buttonStyle(.borderedProminent)
                .buttonBorderShape(.capsule)
                .tint(.orange)
        }
        .padding(12)
        .background(Color.orange.opacity(0.1), in: RoundedRectangle(cornerRadius: 22, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 22, style: .continuous).strokeBorder(Color.orange.opacity(0.3), lineWidth: 1))
    }
}

// MARK: - Stile di risposta

extension AriaChatStyle {
    var title: String {
        switch self {
        case .auto: String(localized: "Auto")
        case .detailed: String(localized: "Detailed")
        case .compact: String(localized: "Compact (operator)")
        }
    }

    var shortTitle: String {
        switch self {
        case .auto: String(localized: "Auto")
        case .detailed: String(localized: "Detailed")
        case .compact: String(localized: "Compact")
        }
    }

    var icon: String {
        switch self {
        case .auto: "wand.and.sparkles"
        case .detailed: "text.alignleft"
        case .compact: "text.line.first.and.arrowtriangle.forward"
        }
    }
}
