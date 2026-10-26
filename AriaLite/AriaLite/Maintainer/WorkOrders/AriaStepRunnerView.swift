//
//  AriaStepRunnerView.swift
//  AriaLite
//
//  Created by Giovanni Michele on 15/10/26.
//
//  L'esecuzione di un lavoro Aria passo per passo, col disegno della manutenzione: un passo alla volta,
//  pallini di avanzamento, schede Note e Foto, "Ask AriA" sullo step corrente.
//
//  • "Done" / "Not done" mettono il risultato sul server (PUT …/steps/{id}); "Not done" vuole il motivo.
//    "Undo" lo toglie, insieme alle foto.
//  • La nota di un passo ancora senza risultato è una bozza: parte col risultato.
//  • Le foto vogliono un risultato già messo: finché non c'è restano sul telefono e partono subito dopo.
//  • Tutto si salva prima sul telefono (AriaWorkOrderStore, local-first): si lavora anche offline e
//    il lotto parte quando si esce dall'esecuzione o si chiude il task.
//  • Un ordine chiuso è in sola lettura.
//

import PhotosUI
import SwiftUI

struct AriaStepRunnerView: View {
    @Binding var order: AriaWorkOrder
    let store: AriaWorkOrderStore

    @State private var currentId: String
    @State private var isBusy = false
    @State private var errorMessage: String?
    @State private var noteMode: NoteMode?
    @State private var draftNotes: [String: String] = [:]
    @State private var draftPhotos: [String: [Data]] = [:]
    @State private var pickerItems: [PhotosPickerItem] = []
    @State private var showPhotoSource = false
    @State private var showCamera = false
    @State private var previewPhoto: AriaPhotoPreviewItem?
    @State private var showAIHelp = false
    /// La chat di "Ask AriA" vive qui, non nel foglio: chiuderlo la minimizza, e col passo nuovo si azzera.
    @State private var help = AriaHelpChatSlot()
    @State private var helpDetent: PresentationDetent = .large
    @State private var showComplete = false
    @State private var showSafety = false
    @Namespace private var glassNamespace
    @Environment(\.dismiss) private var dismiss
    @Environment(\.verticalSizeClass) private var verticalSizeClass
    @Environment(AppViewModel.self) private var viewModel
    /// Misure pensate per il testo "Large": crescono col Dynamic Type così le icone non tagliano il testo.
    @ScaledMetric(relativeTo: .callout) private var iconBadgeSide: CGFloat = 38
    @ScaledMetric(relativeTo: .body) private var orbSide: CGFloat = 40
    @ScaledMetric(relativeTo: .footnote) private var chevronSide: CGFloat = 32

    private enum NoteMode: Identifiable {
        /// Aggiungere o cambiare la nota del passo.
        case note
        /// Il passo non è stato fatto: serve il motivo.
        case notDone
        var id: Self { self }
    }

    private static let maxPhotos = 3
    private static let askAriaSource = "ask-aria"

    /// Chat nuova col contesto del passo corrente; quella vecchia smette di rispondere.
    private func resetHelpChat() {
        help.chat?.stop()
        help.chat = current.map {
            AriaAgentChat(backend: viewModel.backend, context: "[Work order context]\n\(order.chatContext(step: $0))")
        }
    }

    init(order: Binding<AriaWorkOrder>, store: AriaWorkOrderStore, startingAt stepId: String) {
        _order = order
        self.store = store
        _currentId = State(initialValue: stepId)
    }

    // MARK: Stato derivato

    private var steps: [AriaProcedureStep] { order.procedure?.steps ?? [] }
    private var index: Int { steps.firstIndex { $0.id == currentId } ?? 0 }
    private var current: AriaProcedureStep? { steps.indices.contains(index) ? steps[index] : nil }
    private var reportedCount: Int { steps.filter { $0.report != nil }.count }
    private var isReadOnly: Bool { order.isClosed }
    private var safetyWarnings: [String] { order.procedure?.safetyWarnings ?? [] }

    /// Dove porta "Next": il passo dopo, altrimenti il primo ancora senza risultato; `nil` = è tutto fatto.
    private var nextTarget: AriaProcedureStep? {
        if index + 1 < steps.count { return steps[index + 1] }
        return steps.first { $0.report == nil && $0.id != current?.id }
    }

    private func note(of step: AriaProcedureStep) -> String? {
        let text = step.report?.note ?? draftNotes[step.id]
        return text.flatMap { $0.isEmpty ? nil : $0 }
    }

    private func photoCount(of step: AriaProcedureStep) -> Int {
        (step.report?.photos.count ?? 0) + queuedPhotos(of: step).count + (draftPhotos[step.id]?.count ?? 0)
    }

    /// Foto già in coda verso il server (scattate col passo segnato, anche offline).
    private func queuedPhotos(of step: AriaProcedureStep) -> [(localId: String, jpeg: Data)] {
        // Letto qui perché la coda non è osservabile: quando cambia, cambia il conteggio.
        _ = store.pendingCount
        return store.pendingPhotos(step: step.id, of: order.id)
    }

    // MARK: Corpo

    /// Altezza della sfumatura in fondo allo scroll (e dello spazio che la lascia vuota a fine pagina).
    private static let scrollFade: CGFloat = 24

    var body: some View {
        NavigationStack {
            Group {
                if let step = current {
                    ZStack {
                        LinearGradient(colors: [Color.liteBackground, Color.liteAccent.opacity(0.12)],
                                       startPoint: .topLeading, endPoint: .bottomTrailing)
                            .ignoresSafeArea()
                        VStack(spacing: 0) {
                            ScrollView {
                                VStack(spacing: 14) {
                                    AriaSyncStatusView(store: store)
                                    if !safetyWarnings.isEmpty { safetyCard }
                                    stepCard(step)
                                    if !isReadOnly || note(of: step) != nil || photoCount(of: step) > 0 {
                                        HStack(spacing: 12) {
                                            noteCard(step)
                                            photoCard(step)
                                        }
                                    }
                                    photoStrip(step)
                                }
                                .ariaReadableWidth()
                                .padding(.horizontal, 16)
                                .padding(.top, 12)
                                .padding(.bottom, Self.scrollFade)
                            }
                            .scrollBounceBehavior(.basedOnSize)
                            // Il contenuto sfuma sopra la barra invece di tagliarsi netto: si capisce che continua.
                            .mask {
                                VStack(spacing: 0) {
                                    Color.black
                                    LinearGradient(colors: [.black, .clear], startPoint: .top, endPoint: .bottom)
                                        .frame(height: Self.scrollFade)
                                }
                            }

                            // Sotto lo scroll, non sopra: lo scroll finisce dove comincia la barra, quindi uno step
                            // lungo con le foto non passa dietro "Ask AriA" (la barra è di vetro: si vedeva attraverso).
                            // Dietro c'è solo il gradiente della pagina, fino sotto l'indicatore home.
                            bottomBar(step)
                                // +40: i 20 di padding per lato della barra, così i pulsanti si allineano alle schede.
                                .ariaReadableWidth(AriaLayout.readableWidth + 40)
                        }
                    }
                } else {
                    ContentUnavailableView("No steps available", systemImage: "list.bullet.clipboard",
                                           description: Text("This task has no checklist items."))
                }
            }
            .navigationTitle("Procedure")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    if #available(iOS 26.0, *) {
                        Button(role: .close) { dismiss() }
                    } else {
                        Button { dismiss() } label: {
                            Image(systemName: "xmark.circle.fill").foregroundStyle(.secondary)
                        }
                    }
                }
            }
            .onAppear { showSafety = reportedCount == 0 && !safetyWarnings.isEmpty }
            .sheet(item: $noteMode) { mode in noteSheet(mode) }
            .sheet(isPresented: $showAIHelp) {
                AIHelpSheet(slot: help, detent: $helpDetent)
                    // Si richiude "dentro" il bottone Ask AriA da cui è uscito.
                    .navigationTransition(.zoom(sourceID: Self.askAriaSource, in: glassNamespace))
            }
            // Nuovo passo, nuova conversazione: il contesto è quello del passo (anche a foglio aperto).
            .onChange(of: currentId) { _, _ in resetHelpChat() }
            .sheet(isPresented: $showComplete) {
                AriaCompleteSheet(unreportedCount: steps.count - reportedCount) { notes in
                    switch await store.complete(order.id, resolutionNotes: notes) {
                    case .updated(let closed):
                        order = closed
                        dismiss()
                        return nil
                    case .gone:
                        dismiss()
                        return nil
                    case .failed(let message):
                        return message
                    }
                }
            }
            .sheet(isPresented: $showPhotoSource) {
                PhotoSourceSheet(selectedPhotoItems: $pickerItems) { showCamera = true }
            }
            .fullScreenCover(item: $previewPhoto) { AriaPhotoPreview(item: $0) }
            .fullScreenCover(isPresented: $showCamera) {
                CameraPicker { image in
                    if let jpeg = AriaPhoto.jpeg(from: image) { Task { await addPhoto(jpeg) } }
                }
                .ignoresSafeArea()
            }
            .onChange(of: pickerItems) { _, items in
                guard !items.isEmpty else { return }
                Task {
                    for item in items {
                        if let data = try? await item.loadTransferable(type: Data.self),
                           let jpeg = AriaPhoto.jpeg(from: data) { await addPhoto(jpeg) }
                    }
                    pickerItems = []
                }
            }
            .alert("Something went wrong", isPresented: Binding(get: { errorMessage != nil },
                                                                 set: { if !$0 { errorMessage = nil } })) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(errorMessage ?? "")
            }
        }
    }

    // MARK: Sicurezza

    private var safetyCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            Button {
                withAnimation(.snappy) { showSafety.toggle() }
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: "exclamationmark.shield.fill")
                    Text("Safety warnings")
                        .font(.subheadline.weight(.semibold))
                    Spacer()
                    Image(systemName: "chevron.down")
                        .font(.caption.weight(.semibold))
                        .rotationEffect(.degrees(showSafety ? 180 : 0))
                }
                .foregroundStyle(.orange)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            if showSafety {
                ForEach(Array(safetyWarnings.enumerated()), id: \.offset) { _, warning in
                    Label {
                        Text(warning).font(.subheadline).foregroundStyle(Color.liteText.opacity(0.8))
                    } icon: {
                        Image(systemName: "exclamationmark.triangle.fill").foregroundStyle(.orange)
                    }
                    .labelStyle(.titleAndIcon)
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
        }
        .padding(14)
        .background(Color.orange.opacity(0.1), in: RoundedRectangle(cornerRadius: 16))
        .overlay(RoundedRectangle(cornerRadius: 16).strokeBorder(Color.orange.opacity(0.3), lineWidth: 1))
    }

    // MARK: Passo

    /// Azione in evidenza, elenco puntato e indicazioni in corpo normale (AriaStepText).
    private func stepText(_ text: AriaStepText) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            if let tag = text.tag {
                Label(tag.capitalized, systemImage: text.isSafetyTag ? "exclamationmark.shield.fill" : "info.circle.fill")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(text.isSafetyTag ? Color.orange : Color.liteAccent)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 5)
                    .background((text.isSafetyTag ? Color.orange : Color.liteAccent).opacity(0.12), in: Capsule())
            }

            Text(text.headline)
                .font(.title3.weight(.semibold))
                .foregroundStyle(Color.liteText)
                .lineSpacing(2)

            if !text.items.isEmpty {
                VStack(alignment: .leading, spacing: 6) {
                    ForEach(Array(text.items.enumerated()), id: \.offset) { _, item in
                        HStack(alignment: .firstTextBaseline, spacing: 10) {
                            Circle()
                                .fill(Color.liteAccent.opacity(0.55))
                                .frame(width: 5, height: 5)
                                // A metà dell'altezza delle minuscole, non sulla linea di base.
                                .alignmentGuide(.firstTextBaseline) { $0[.bottom] + 4 }
                            Text(item)
                        }
                    }
                }
                .font(.callout)
                .foregroundStyle(Color.liteText.opacity(0.85))
                .padding(.leading, 2)
            }

            ForEach(Array(text.notes.enumerated()), id: \.offset) { _, note in
                Text(note)
                    .font(.callout)
                    .foregroundStyle(Color.liteText.opacity(0.8))
                    .lineSpacing(2)
            }
        }
        .fixedSize(horizontal: false, vertical: true)
        .textSelection(.enabled)
    }

    private func stepCard(_ step: AriaProcedureStep) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("Step \(index + 1) of \(steps.count)")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(Color.liteAccent)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 4)
                    .background(Color.liteAccent.opacity(0.1), in: Capsule())
                Spacer()
                statusBadge(step)
            }

            stepText(AriaStepText(step.displayText))

            if let report = step.report, report.reportedAt == nil, report.note == nil, report.photos.isEmpty {
                Label("Marked done from the desktop", systemImage: "desktopcomputer")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            VStack(spacing: 6) {
                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        Capsule().fill(Color.liteAccent.opacity(0.12)).frame(height: 4)
                        Capsule().fill(Color.liteAccent)
                            .frame(width: geo.size.width * CGFloat(reportedCount) / CGFloat(max(steps.count, 1)), height: 4)
                            .animation(.spring(duration: 0.4), value: reportedCount)
                    }
                }
                .frame(height: 4)
            }
            .padding(.top, 4)
        }
        .padding(20)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.liteAccent.opacity(0.04), in: RoundedRectangle(cornerRadius: 20))
        .overlay(RoundedRectangle(cornerRadius: 20).strokeBorder(Color.liteAccent.opacity(0.12), lineWidth: 1))
        .overlay(alignment: .top) { if isBusy { ProgressView().padding(.top, 10) } }
    }

    private func statusBadge(_ step: AriaProcedureStep) -> some View {
        let (icon, label, color): (String, String, Color) = switch step.report?.status {
        case "done": ("checkmark.circle.fill", String(localized: "Done"), .green)
        case "not_done": ("xmark.circle.fill", String(localized: "Not done"), .red)
        default: ("circle", String(localized: "To do"), Color.liteText.opacity(0.4))
        }
        return HStack(spacing: 5) {
            Image(systemName: icon).font(.footnote).contentTransition(.symbolEffect(.replace))
            Text(label).font(.caption.weight(.medium))
        }
        .foregroundStyle(color)
    }

    // MARK: Note e foto

    private func noteCard(_ step: AriaProcedureStep) -> some View {
        let text = note(of: step)
        return Button {
            noteMode = .note
        } label: {
            VStack(alignment: .leading, spacing: 10) {
                iconBadge(text == nil ? "square.and.pencil" : "note.text")
                Spacer()
                VStack(alignment: .leading, spacing: 3) {
                    Text(text == nil ? "Add Notes" : "Technical Notes")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(Color.liteText)
                    if let text {
                        Text(text)
                            .font(.caption)
                            .foregroundStyle(Color.liteText.opacity(0.6))
                            .lineLimit(3)
                            .multilineTextAlignment(.leading)
                    } else {
                        Text("No notes")
                            .font(.caption)
                            .foregroundStyle(Color.liteText.opacity(0.35))
                    }
                }
            }
            .padding(16)
            .frame(maxWidth: .infinity, minHeight: 130, alignment: .topLeading)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .disabled(isReadOnly || isBusy)
        .ariaGlass(in: RoundedRectangle(cornerRadius: 16), interactive: !isReadOnly)
    }

    private func photoCard(_ step: AriaProcedureStep) -> some View {
        let count = photoCount(of: step)
        let isFull = count >= Self.maxPhotos
        return Button {
            showPhotoSource = true
        } label: {
            VStack(alignment: .leading, spacing: 10) {
                iconBadge(count == 0 ? "camera" : "photo.stack")
                Spacer()
                VStack(alignment: .leading, spacing: 3) {
                    Text("Photos")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(Color.liteText)
                    Text(count == 0 ? String(localized: "No photos")
                         : isFull ? String(localized: "\(count) attached · maximum")
                         : String(localized: "\(count) attached"))
                        .font(.caption)
                        .foregroundStyle(Color.liteText.opacity(count == 0 ? 0.35 : 0.6))
                }
            }
            .padding(16)
            .frame(maxWidth: .infinity, minHeight: 130, alignment: .topLeading)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .disabled(isReadOnly || isBusy || isFull)
        .ariaGlass(in: RoundedRectangle(cornerRadius: 16), interactive: !isReadOnly && !isFull)
    }

    private func iconBadge(_ symbol: String) -> some View {
        ZStack {
            Circle().fill(Color.liteAccent.opacity(0.1)).frame(width: iconBadgeSide, height: iconBadgeSide)
            Image(systemName: symbol)
                .font(.callout)
                .foregroundStyle(Color.liteAccent)
                .contentTransition(.symbolEffect(.replace))
        }
    }

    /// Le foto del passo: quelle sul server (l'URL scade, per questo si ricarica l'ordine) e quelle ancora sul telefono.
    @ViewBuilder
    private func photoStrip(_ step: AriaProcedureStep) -> some View {
        let uploaded = step.report?.photos ?? []
        let queued = queuedPhotos(of: step)
        let drafts = draftPhotos[step.id] ?? []
        if !uploaded.isEmpty || !queued.isEmpty || !drafts.isEmpty {
            VStack(alignment: .leading, spacing: 8) {
                HStack(spacing: 10) {
                    ForEach(uploaded) { photo in
                        thumbnail {
                            // Solo https: un URL diverso non si scarica e resta il segnaposto.
                            if let url = photo.url.flatMap(AriaURLPolicy.image) {
                                AsyncImage(url: url) { phase in
                                    if let image = phase.image { image.resizable().scaledToFill() }
                                    else if phase.error != nil { Image(systemName: "photo").foregroundStyle(.secondary) }
                                    else { ProgressView() }
                                }
                            } else {
                                Image(systemName: "photo").foregroundStyle(.secondary)
                            }
                        } open: {
                            previewPhoto = .remote(id: photo.id, url: photo.url)
                        } remove: {
                            Task { await removeUploaded(photo, from: step) }
                        }
                    }
                    ForEach(queued, id: \.localId) { photo in
                        thumbnail {
                            if let image = UIImage(data: photo.jpeg) { Image(uiImage: image).resizable().scaledToFill() }
                        } open: {
                            previewPhoto = .local(id: photo.localId, jpeg: photo.jpeg)
                        } remove: {
                            Task { await removeQueued(photo.localId, from: step) }
                        }
                        .overlay(alignment: .bottom) { uploadBadge }
                    }
                    ForEach(Array(drafts.enumerated()), id: \.offset) { i, data in
                        thumbnail {
                            if let image = UIImage(data: data) { Image(uiImage: image).resizable().scaledToFill() }
                        } open: {
                            previewPhoto = .local(id: "draft-\(step.id)-\(i)", jpeg: data)
                        } remove: {
                            draftPhotos[step.id]?.remove(at: i)
                        }
                        .overlay(alignment: .bottom) { uploadBadge }
                    }
                    Spacer(minLength: 0)
                }
                if !drafts.isEmpty {
                    Text("Photos upload when you mark the step.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                } else if !queued.isEmpty {
                    Text("Photos upload with the next sync.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private var uploadBadge: some View {
        Image(systemName: "icloud.and.arrow.up")
            .font(.caption2.weight(.semibold))
            .foregroundStyle(.white)
            .padding(4)
            .background(.black.opacity(0.45), in: Capsule())
            .padding(4)
    }

    private func thumbnail<Content: View>(@ViewBuilder _ content: () -> Content,
                                          open: @escaping () -> Void,
                                          remove: @escaping () -> Void) -> some View {
        ZStack {
            Color(.tertiarySystemFill)
            content()
        }
        .frame(width: 84, height: 84)
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .contentShape(RoundedRectangle(cornerRadius: 12))
        .onTapGesture(perform: open)
        .accessibilityAddTraits(.isButton)
        .accessibilityLabel(Text("Photo"))
        .overlay(alignment: .topTrailing) {
            if !isReadOnly {
                Button(action: remove) {
                    Image(systemName: "xmark.circle.fill")
                        .font(.title3)
                        .symbolRenderingMode(.palette)
                        .foregroundStyle(.white, .black.opacity(0.55))
                }
                .buttonStyle(.plain)
                .disabled(isBusy)
                .padding(3)
                .accessibilityLabel(Text("Remove photo"))
            }
        }
    }

    // MARK: Barra in basso

    private func bottomBar(_ step: AriaProcedureStep) -> some View {
        AriaGlassEffectContainer(spacing: 12) {
            if verticalSizeClass == .compact {
                // iPhone in orizzontale: una riga sola, altrimenti la barra si prende metà dello schermo.
                HStack(spacing: 10) {
                    askAriaButton(compact: true)
                    controls(step)
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 8)
            } else {
                VStack(spacing: 0) {
                    askAriaButton(compact: false)
                        .padding(.horizontal, 20)
                        .padding(.top, 14)
                        .padding(.bottom, 10)

                    controls(step)
                        .padding(.horizontal, 20)
                        .padding(.vertical, 14)
                        .padding(.bottom, 8)
                }
            }
        }
    }

    /// Pillola di vetro con la sfera di Aria: il bordo iridescente riprende i colori della sfera.
    /// `compact`: solo la sfera, in un cerchio alto quanto i pulsanti accanto.
    private func askAriaButton(compact: Bool) -> some View {
        Button {
            if help.chat == nil { resetHelpChat() }
            showAIHelp = true
        } label: {
            if compact {
                AriaOrb(isAnimating: false, radius: 0.9)
                    .frame(width: 34, height: 34)
                    .frame(width: 46, height: 46)
                    .contentShape(Circle())
                    .ariaGlass(in: Circle())
            } else {
                askAriaPill
            }
        }
        .buttonStyle(AriaPressScaleStyle())
        .matchedTransitionSource(id: Self.askAriaSource, in: glassNamespace)
        .accessibilityLabel(Text("Ask AriA"))
        .accessibilityHint(Text("Get help with this step"))
    }

    private var askAriaPill: some View {
        HStack(spacing: 12) {
            AriaOrb(isAnimating: false, radius: 0.9)
                .frame(width: orbSide, height: orbSide)
                .shadow(color: Color(red: 0.89, green: 0.55, blue: 1).opacity(0.55), radius: 8)
            VStack(alignment: .leading, spacing: 1) {
                Text("Ask AriA")
                    .font(.system(.body, design: .rounded, weight: .semibold))
                    .foregroundStyle(Color.liteAccent)
                Text("Get help with this step")
                    .font(.caption)
                    .foregroundStyle(Color.liteAccent.opacity(0.6))
            }
            Spacer(minLength: 8)
            // La sfera a sinistra dice già che è Aria: a destra, dove porta il tocco.
            Image(systemName: "chevron.right")
                .font(.footnote.weight(.semibold))
                .foregroundStyle(Color.liteAccent)
                .frame(width: chevronSide, height: chevronSide)
                .background(Color.liteAccent.opacity(0.08), in: Circle())
        }
        .padding(.leading, 10)
        .padding(.trailing, 14)
        .padding(.vertical, 9)
        .frame(maxWidth: .infinity)
        .contentShape(Capsule())
        .ariaGlass(in: Capsule())
        .overlay {
            Capsule().strokeBorder(
                AngularGradient(colors: [Color(red: 0.89, green: 0.55, blue: 1), Color(red: 0.93, green: 0.76, blue: 0.93),
                                         Color(red: 0.70, green: 0.21, blue: 0.99), Color(red: 0.89, green: 0.55, blue: 1)],
                                center: .center),
                lineWidth: 1)
            .opacity(0.45)
        }
    }

    private func controls(_ step: AriaProcedureStep) -> some View {
        HStack(spacing: 10) {
            Button {
                if index > 0 { go(to: steps[index - 1]) }
            } label: {
                Image(systemName: "chevron.left")
                    .font(.subheadline.weight(.semibold))
                    // 46pt a testo "Large"; coi testi grandi cresce quanto il glifo.
                    .frame(minWidth: 46, minHeight: 46)
            }
            .ariaGlassButtonStyle()
            .disabled(index == 0 || isBusy)
            .accessibilityLabel(Text("Previous"))
            .ariaGlassEffectID("prev", in: glassNamespace)

            if isReadOnly {
                Spacer()
                if let next = nextTarget { nextButton(next) }
            } else if step.report == nil {
                Button { noteMode = .notDone } label: {
                    actionLabel("Not done", systemImage: "xmark")
                        .foregroundStyle(.red)
                        .frame(maxWidth: .infinity, minHeight: 46)
                }
                .ariaGlassButtonStyle()
                .disabled(isBusy)

                Button {
                    Task { await report(.done(note: draftNotes[step.id]), step: step) }
                } label: {
                    actionLabel("Done", systemImage: "checkmark")
                        .frame(maxWidth: .infinity, minHeight: 46)
                }
                .ariaAccentGlassButtonStyle()
                .disabled(isBusy)
                .ariaGlassEffectID("main-action", in: glassNamespace)
            } else {
                Button { Task { await undo(step) } } label: {
                    actionLabel("Undo", systemImage: "arrow.uturn.backward")
                        .frame(maxWidth: .infinity, minHeight: 46)
                }
                .ariaGlassButtonStyle()
                .disabled(isBusy)

                if let next = nextTarget {
                    nextButton(next)
                } else {
                    Button { showComplete = true } label: {
                        actionLabel("Complete task", systemImage: "checkmark.seal.fill")
                            .frame(maxWidth: .infinity, minHeight: 46)
                    }
                    .ariaProminentGlassButtonStyle(tint: .green)
                    .disabled(isBusy)
                    .ariaGlassEffectID("main-action", in: glassNamespace)
                }
            }
        }
        .animation(.spring(duration: 0.4), value: step.report?.status)
    }

    /// Etichetta di un pulsante della barra. Da iOS 26 il vetro aggiunge il suo padding e su un iPhone
    /// stretto "Complete task" andava a capo: se non ci sta, via l'icona e il testo si stringe un po'.
    private func actionLabel(_ title: LocalizedStringKey, systemImage: String) -> some View {
        ViewThatFits(in: .horizontal) {
            Label(title, systemImage: systemImage)
            Text(title)
                .lineLimit(1)
                .minimumScaleFactor(0.65)
        }
        .font(.subheadline.weight(.semibold))
    }

    private func nextButton(_ target: AriaProcedureStep) -> some View {
        Button { go(to: target) } label: {
            HStack(spacing: 6) {
                Text("Next").font(.subheadline.weight(.semibold))
                Image(systemName: "chevron.right").font(.footnote.weight(.semibold))
            }
            .frame(maxWidth: .infinity, minHeight: 46)
        }
        .ariaAccentGlassButtonStyle()
        .disabled(isBusy)
        .ariaGlassEffectID("main-action", in: glassNamespace)
    }

    // MARK: Nota

    @ViewBuilder
    private func noteSheet(_ mode: NoteMode) -> some View {
        if let step = current {
            switch mode {
            case .notDone:
                AriaStepNoteSheet(title: "Not done",
                                  prompt: "Why couldn't this step be done? The planner will see your note.",
                                  text: draftNotes[step.id] ?? "", isRequired: true, saveLabel: "Send") { text in
                    Task { await report(.notDone(note: text), step: step) }
                }
            case .note:
                AriaStepNoteSheet(title: "Note", text: note(of: step) ?? "", isRequired: step.report?.status == "not_done") { text in
                    saveNote(text, for: step)
                }
            }
        }
    }

    /// Passo già con un risultato: la nota si manda subito, rimettendo lo stesso risultato. Altrimenti è una bozza.
    private func saveNote(_ text: String, for step: AriaProcedureStep) {
        guard let report = step.report else {
            draftNotes[step.id] = text.isEmpty ? nil : text
            return
        }
        Task { await self.report(report.isDone ? .done(note: text) : .notDone(note: text), step: step, advance: false) }
    }

    // MARK: Azioni

    private func go(to step: AriaProcedureStep) {
        withAnimation(.spring(duration: 0.3)) { currentId = step.id }
    }

    /// Esito di una modifica: aggiorna l'ordine, oppure mostra l'errore. `false` = non è andata.
    private func apply(_ change: AriaWorkOrderStore.Change) -> Bool {
        switch change {
        case .updated(let fresh):
            order = fresh
            return true
        case .gone:
            // L'ordine non è più dell'operatore: si torna alla lista senza messaggi.
            dismiss()
            return false
        case .failed(let message):
            if !message.isEmpty { errorMessage = message }
            return false
        }
    }

    private func report(_ result: AriaStepResult, step: AriaProcedureStep, advance: Bool = true) async {
        guard !isBusy else { return }
        isBusy = true
        defer { isBusy = false }
        guard apply(await store.report(result, step: step.id, of: order.id)) else { return }
        draftNotes[step.id] = nil
        await uploadDrafts(for: step.id)
        if advance, let target = steps.indices.contains(index + 1) ? steps[index + 1] : nextTarget { go(to: target) }
    }

    private func undo(_ step: AriaProcedureStep) async {
        guard !isBusy else { return }
        isBusy = true
        defer { isBusy = false }
        _ = apply(await store.clearReport(step: step.id, of: order.id))
    }

    /// Foto scelta o scattata: con un risultato già messo parte subito, altrimenti aspetta sul telefono.
    private func addPhoto(_ jpeg: Data) async {
        guard let step = current, photoCount(of: step) < Self.maxPhotos else { return }
        guard step.report != nil else {
            draftPhotos[step.id, default: []].append(jpeg)
            return
        }
        guard !isBusy else { return }
        isBusy = true
        defer { isBusy = false }
        _ = apply(await store.addPhoto(jpeg: jpeg, step: step.id, of: order.id))
    }

    /// Dopo il risultato, le foto messe da parte. Se una fallisce le altre restano in attesa.
    private func uploadDrafts(for stepId: String) async {
        while let jpeg = draftPhotos[stepId]?.first {
            guard apply(await store.addPhoto(jpeg: jpeg, step: stepId, of: order.id)) else { return }
            draftPhotos[stepId]?.removeFirst()
        }
        draftPhotos[stepId] = nil
    }

    private func removeQueued(_ localId: String, from step: AriaProcedureStep) async {
        _ = apply(await store.removePhoto(localId, step: step.id, of: order.id))
    }

    private func removeUploaded(_ photo: AriaStepPhoto, from step: AriaProcedureStep) async {
        guard !isBusy else { return }
        isBusy = true
        defer { isBusy = false }
        _ = apply(await store.removePhoto(photo.id, step: step.id, of: order.id))
    }
}

/// Si abbassa appena al tocco, senza cambiare colore.
private struct AriaPressScaleStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.97 : 1)
            .animation(.spring(response: 0.25, dampingFraction: 0.7), value: configuration.isPressed)
    }
}
