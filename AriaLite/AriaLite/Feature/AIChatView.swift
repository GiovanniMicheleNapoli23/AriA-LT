//
//  AIChatView.swift
//  AriaLite
//
//  Created by Giovanni Michele on 31/03/26.
//

import SwiftUI

// Da cosa è stata prodotta l'ultima risposta dell'assistente.
enum AriaResponseSource: Equatable {
    case none               // nessuna risposta ancora → nessun pallino
    case local              // knowledge base / fallback locale → pallino blu
    case appleIntelligence  // generata on-device da Apple Intelligence → pallino viola
    case server             // backend Aria → pallino verde
}

// Pallino di stato accanto a "Aria Engine".
struct AriaSourceDot: View {
    let source: AriaResponseSource

    var body: some View {
        switch source {
        case .none:
            EmptyView()
        case .local:
            dot(.blue)
        case .appleIntelligence:
            dot(.purple)
        case .server:
            dot(.green)
        }
    }

    private func dot(_ color: Color) -> some View {
        Circle()
            .fill(color)
            .frame(width: 7, height: 7)
            .shadow(color: color.opacity(0.6), radius: 3)
            .transition(.scale.combined(with: .opacity))
    }
}

// MARK: - AIChatView (schermata principale)
struct AIChatView: View {
    @Environment(AppViewModel.self) private var viewModel
    @State private var closeout: AriaCloseoutChoice?
    @State private var showingOptions = false
    /// La chiusura intervento scelta dal menu "···": parte quando il menu si è chiuso (un foglio alla volta).
    @State private var closeOutAfterOptions = false

    private var backend: AriaBackend { viewModel.backend }
    private var chat: AriaAgentChat { viewModel.mainChat }

    /// Il titolo che il backend dà alla sessione; finché non arriva, la prima domanda dell'operatore.
    private var title: String {
        guard backend.isReady, let first = chat.messages.first(where: { $0.role == .user })?.text else {
            return String(localized: "New chat")
        }
        if let saved = viewModel.sessions.sessions.first(where: { $0.sessionId == chat.sessionId })?.title,
           !saved.isEmpty {
            return saved
        }
        return first
    }

    var body: some View {
        NavigationStack {
            AriaConversation(agentChat: chat, showsEmptyState: true)
                .navigationTitle(title)
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .topBarLeading) { AriaSidebarButton() }
                    // Solo il titolo: server e stabilimento si gestiscono nel profilo (Impostazioni).
                    ToolbarItem(placement: .principal) {
                        Text(title)
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundStyle(.primary)
                            .lineLimit(1)
                            .frame(maxWidth: 240)
                            .contentTransition(.opacity)
                            .animation(.easeInOut(duration: 0.25), value: title)
                    }
                    // La nuova chat sta nella barra laterale; qui lo storico della procedura,
                    // il microfono e la chiusura intervento.
                    ToolbarItem(placement: .topBarTrailing) {
                        Button("More", systemImage: "ellipsis") { showingOptions = true }
                    }
                }
                .sheet(isPresented: $showingOptions, onDismiss: {
                    guard closeOutAfterOptions else { return }
                    closeOutAfterOptions = false
                    closeout = AriaCloseoutChoice(workOrder: true, report: false)
                }) {
                    AriaChatOptionsSheet(chat: chat, onCloseOut: backend.isReady ? { closeOutAfterOptions = true } : nil)
                }
                .sheet(item: $closeout) { choice in
                    AriaCloseoutSheet(chat: chat, choice: choice)
                }
                // A turno finito il backend ha (ri)generato il titolo: si ricaricano le sessioni.
                .onChange(of: chat.isStreaming) { _, streaming in
                    if !streaming, backend.isReady { Task { await viewModel.sessions.load() } }
                }
        }
    }
}

// MARK: - Reusable conversation (chat + input)
// Usata dalla tab Assistant (showsEmptyState) e dall'assistente in manutenzione (seedsStepIntro).
// Con il backend Aria collegato (AriaBackend.isReady) è la chat della web app (AriaAgentChatView);
// altrimenti risponde il motore locale (knowledge base + Apple Intelligence).
struct AriaConversation: View {
    @Environment(AppViewModel.self) private var viewModel

    /// Chat del chiamante (la tab tiene quella principale); nil = una chat propria con il contesto dello step.
    var agentChat: AriaAgentChat? = nil
    var workOrder: WorkOrder? = nil
    var step: ChecklistItem? = nil
    var showsEmptyState: Bool = true
    var seedsStepIntro: Bool = false
    var source: Binding<AriaResponseSource> = .constant(.none)

    @State private var ownAgentChat: AriaAgentChat?
    @State private var voice = AriaVoiceViewModel()

    // FAKE: motore di chat simulato (vedi FakeAriaEngine).
    private var engine: FakeAriaEngine {
        FakeAriaEngine(viewModel: viewModel, workOrder: workOrder, step: step)
    }

    var body: some View {
        if viewModel.backend.isReady {
            if let chat = agentChat ?? ownAgentChat {
                AriaAgentChatView(chat: chat, backend: viewModel.backend, showsEmptyState: showsEmptyState, voice: voice)
                    .onChange(of: chat.isStreaming) { _, streaming in
                        guard !streaming, let last = chat.messages.last, last.role == .assistant, last.error == nil else { return }
                        source.wrappedValue = .server
                    }
                    .onChange(of: chat.messages.isEmpty) { _, empty in
                        if empty { source.wrappedValue = .none }
                    }
            } else {
                Color(.systemGroupedBackground).onAppear {
                    // Contesto dello step in manutenzione: viaggia col primo messaggio (modo A della guida).
                    let context = engine.llmContext().map { "[Work order context]\n\($0)" }
                    ownAgentChat = AriaAgentChat(backend: viewModel.backend, context: context)
                }
            }
        } else {
            AriaLocalConversation(workOrder: workOrder, step: step, showsEmptyState: showsEmptyState,
                                  seedsStepIntro: seedsStepIntro, source: source, voice: voice)
        }
    }
}

// MARK: - Local conversation (motore simulato)
struct AriaLocalConversation: View {
    @Environment(AppViewModel.self) private var viewModel

    var workOrder: WorkOrder? = nil
    var step: ChecklistItem? = nil
    var showsEmptyState: Bool = true
    var seedsStepIntro: Bool = false
    var source: Binding<AriaResponseSource> = .constant(.none)
    var voice: AriaVoiceViewModel

    @State private var message = ""
    @State private var messages: [ChatMessage] = []
    @State private var isTyping = false
    @State private var animateBlob = false
    @State private var didSeed = false
    @State private var showConnection = false
    @State private var llm = AriaLanguageModel()
    @FocusState private var isInputFocused: Bool

    // FAKE: motore di chat simulato (vedi FakeAriaEngine).
    private var engine: FakeAriaEngine {
        FakeAriaEngine(viewModel: viewModel, workOrder: workOrder, step: step)
    }

    private var hasText: Bool {
        !message.trimmingCharacters(in: .whitespaces).isEmpty
    }

    var body: some View {
        VStack(spacing: 0) {
            messagesArea

            // Voce: pannello stato sessione (visibile solo quando attiva)
            if voice.isConnected || voice.isConnecting || voice.error != nil {
                VoiceSessionOverlay(voice: voice)
                    .padding(.horizontal, 16)
                    .padding(.top, 8)
                    .transition(.opacity.combined(with: .move(edge: .bottom)))
            }

            inputBar
        }
        .background(Color(.systemGroupedBackground))
        .animation(.easeInOut(duration: 0.25), value: voice.isConnected)
        .animation(.easeInOut(duration: 0.25), value: voice.isConnecting)
        .sheet(isPresented: $showConnection) {
            AriaConnectionSheet(backend: viewModel.backend)
        }
        .onAppear {
            guard seedsStepIntro, !didSeed else { return }
            didSeed = true
            isTyping = true
            // FAKE: ritardo simulato per il messaggio iniziale sullo step.
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) {
                withAnimation(.spring(response: 0.4)) {
                    isTyping = false
                    messages.append(ChatMessage(engine.stepIntro()))
                    source.wrappedValue = .local
                }
            }
        }
    }

    // MARK: - Messages
    private var messagesArea: some View {
        ScrollViewReader { proxy in
            ScrollView {
                if messages.isEmpty && !isTyping && showsEmptyState {
                    emptyState
                        .frame(maxWidth: .infinity)
                        .containerRelativeFrame(.vertical, alignment: .center)
                } else {
                    LazyVStack(alignment: .leading, spacing: 10) {
                        ForEach(messages) { msg in
                            AriaMessageBubble(message: msg) { followUp in
                                send(followUp)
                            }
                            .transition(.asymmetric(
                                insertion: .move(edge: msg.isUser ? .trailing : .leading)
                                    .combined(with: .opacity),
                                removal: .opacity
                            ))
                        }

                        if isTyping {
                            AriaTypingIndicator()
                                .transition(.move(edge: .leading).combined(with: .opacity))
                        }

                        Color.clear.frame(height: 1).id("bottom")
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 14)
                }
            }
            .scrollDismissesKeyboard(.interactively)
            .onChange(of: messages.count) {
                withAnimation(.spring(response: 0.4)) { proxy.scrollTo("bottom") }
            }
            .onChange(of: isTyping) {
                withAnimation(.spring(response: 0.4)) { proxy.scrollTo("bottom") }
            }
        }
    }

    // MARK: - Input Bar
    private var inputBar: some View {
        HStack(alignment: .bottom, spacing: 10) {
            ZStack(alignment: .leading) {
                if message.isEmpty {
                    Text("Ask Aria anything...")
                        .font(.system(size: 16))
                        .foregroundStyle(.tertiary)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 12)
                }
                TextField("", text: $message, axis: .vertical)
                    .font(.system(size: 16))
                    .lineLimit(1...5)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 12)
                    .focused($isInputFocused)
                    .onSubmit { sendMessage() }
            }
            .background(Color(.secondarySystemGroupedBackground))
            .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 22, style: .continuous)
                    .stroke(
                        isInputFocused ? Color.accentColor.opacity(0.5) : Color.clear,
                        lineWidth: 1.5
                    )
            )
            .animation(.easeInOut(duration: 0.2), value: isInputFocused)

            // Testo → invia · vuoto → microfono (parla ad Aria) · in chiamata → stop
            Button {
                if hasText {
                    sendMessage()
                } else {
                    voice.toggleConnection()
                }
            } label: {
                ZStack {
                    Circle()
                        .fill(voice.isConnected && !hasText ? Color.red : Color.accentColor)
                        .frame(width: 44, height: 44)
                        .shadow(
                            color: (voice.isConnected && !hasText ? Color.red : Color.accentColor).opacity(0.35),
                            radius: 8, x: 0, y: 4
                        )

                    if voice.isConnecting && !hasText {
                        ProgressView().tint(.white)
                    } else {
                        Image(systemName: hasText ? "arrow.up" : (voice.isConnected ? "stop.fill" : "mic.fill"))
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundStyle(.white)
                            .contentTransition(.symbolEffect(.replace))
                    }
                }
                .animation(.spring(response: 0.3, dampingFraction: 0.65), value: hasText)
                .animation(.easeInOut(duration: 0.2), value: voice.isConnected)
            }
            .buttonStyle(.plain)
            .disabled(hasText && isTyping)
        }
        .padding(.horizontal, 16)
        .padding(.top, 10)
        .padding(.bottom, 10)
        .background(
            Color(.systemGroupedBackground)
                .overlay(alignment: .top) { Divider().opacity(0.6) }
                .ignoresSafeArea()
        )
    }

    // MARK: - Empty State
    private var emptyState: some View {
        VStack(spacing: 24) {
            ZStack {
                Circle()
                    .fill(Color.accentColor.opacity(0.12))
                    .frame(width: 132, height: 132)
                    .blur(radius: 10)
                    .scaleEffect(animateBlob ? 1.08 : 0.92)

                AriaOrb(radius: 0.8)
                    .frame(width: 108, height: 108)
                    .shadow(color: Color.accentColor.opacity(0.28), radius: 18, x: 0, y: 8)
                    .scaleEffect(animateBlob ? 1.03 : 0.97)
            }
            .animation(.easeInOut(duration: 2.6).repeatForever(autoreverses: true), value: animateBlob)
            .onAppear { animateBlob = true }

            VStack(spacing: 8) {
                Text("Hi, I'm Aria")
                    .font(.system(size: 24, weight: .bold, design: .rounded))
                    .foregroundStyle(.primary)

                Text("Your AI assistant for work orders. Ask a question or pick a suggestion to start.")
                    .font(.system(size: 15))
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .lineSpacing(3)
                    .padding(.horizontal, 32)

                Button { showConnection = true } label: {
                    Label("Connect to the Aria server", systemImage: "bolt.horizontal.circle")
                        .font(.system(size: 13, weight: .semibold))
                }
                .buttonStyle(.plain)
                .foregroundStyle(Color.accentColor)
                .padding(.top, 4)
            }

            VStack(spacing: 10) {
                Text("Try asking")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.tertiary)
                    .textCase(.uppercase)
                    .tracking(0.6)

                ForEach(engine.quickSuggestions) { suggestion in
                    Button {
                        send(suggestion)
                    } label: {
                        HStack(spacing: 10) {
                            Image(systemName: "sparkle")
                                .font(.system(size: 12, weight: .semibold))
                                .foregroundStyle(Color.accentColor)
                            Text(suggestion.text)
                                .font(.system(size: 14, weight: .medium))
                                .foregroundStyle(.primary)
                            Spacer(minLength: 0)
                            Image(systemName: "arrow.up.right")
                                .font(.system(size: 11, weight: .semibold))
                                .foregroundStyle(.tertiary)
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 13)
                        .background(Color(.secondarySystemGroupedBackground))
                        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                        .overlay(
                            RoundedRectangle(cornerRadius: 16, style: .continuous)
                                .strokeBorder(Color.accentColor.opacity(0.12), lineWidth: 1)
                        )
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 20)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 24)
    }

    // MARK: - Send

    private func sendMessage() {
        let trimmed = message.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return }
        appendUser(trimmed)
        if let known = engine.knownResponse(to: trimmed) {
            // Procedure note / work order: risposta deterministica immediata.
            scheduleReply { known }
        } else {
            // Tutto il resto → Apple Intelligence on-device.
            respondWithModel(to: trimmed)
        }
    }

    // Genera la risposta col modello on-device (FoundationModels); fallback locale se non disponibile.
    private func respondWithModel(to text: String) {
        let context = engine.llmContext()
        Task { @MainActor in
            let answer = await llm.reply(to: text, context: context)
            withAnimation(.spring(response: 0.4)) {
                isTyping = false
                if let answer, !answer.isEmpty {
                    messages.append(ChatMessage(text: answer, isUser: false))
                    source.wrappedValue = .appleIntelligence
                } else {
                    messages.append(ChatMessage(engine.reply(to: text)))
                    source.wrappedValue = .local
                }
            }
        }
    }

    // Invio di un suggerimento / follow-up (può portare una risposta diretta dalla knowledge base).
    private func send(_ suggestion: AriaSuggestion) {
        appendUser(suggestion.text)
        scheduleReply {
            if let answer = suggestion.answer {
                return AriaResponse(text: answer, followUps: suggestion.followUps)
            }
            return engine.response(for: suggestion.intent)
        }
    }

    private func appendUser(_ text: String) {
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
        withAnimation(.spring(response: 0.35, dampingFraction: 0.75)) {
            messages.append(ChatMessage(text: text, isUser: true))
        }
        message = ""
        isInputFocused = false
        isTyping = true
    }

    // FAKE: ritardo di digitazione simulato + risposta del motore locale.
    private func scheduleReply(_ make: @escaping () -> AriaResponse) {
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            withAnimation(.spring(response: 0.4)) {
                isTyping = false
                messages.append(ChatMessage(make()))
                source.wrappedValue = .local
            }
        }
    }
}

// MARK: - ChatMessage
struct ChatMessage: Identifiable {
    let id = UUID()
    let text: String
    let isUser: Bool
    var workOrders: [WorkOrder] = []
    var followUps: [AriaSuggestion] = []

    init(text: String, isUser: Bool, workOrders: [WorkOrder] = [], followUps: [AriaSuggestion] = []) {
        self.text = text
        self.isUser = isUser
        self.workOrders = workOrders
        self.followUps = followUps
    }

    // Costruisce un messaggio dell'assistente da una risposta del motore.
    init(_ response: AriaResponse) {
        self.text = response.text
        self.isUser = false
        self.workOrders = response.workOrders
        self.followUps = response.followUps
    }
}

// MARK: - Message Bubble
struct AriaMessageBubble: View {
    let message: ChatMessage
    var onFollowUp: (AriaSuggestion) -> Void = { _ in }

    private var isCompact: Bool {
        message.workOrders.isEmpty && message.followUps.isEmpty
    }


    var body: some View {
        HStack(alignment: isCompact ? .bottom : .top, spacing: 8) {
            if message.isUser {
                Spacer(minLength: 55)
            } else {
                AriaOrb(isAnimating: false)
                    .frame(width: 28, height: 28)
                    .shadow(color: Color.accentColor.opacity(0.2), radius: 3)
            }

            VStack(alignment: message.isUser ? .trailing : .leading, spacing: 8) {
                if !message.text.isEmpty {
                    if message.isUser {
                        Text(message.text)
                            .font(.system(size: 16))
                            .foregroundStyle(.white)
                            .padding(.horizontal, 15)
                            .padding(.vertical, 11)
                            .background(Color.accentColor, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
                            .shadow(color: Color.accentColor.opacity(0.25), radius: 8, x: 0, y: 2)
                            .textSelection(.enabled)
                    } else {
                        // Le risposte di Aria senza bolla, come nella chat col backend.
                        Text(message.text)
                            .font(.system(size: 16))
                            .foregroundStyle(.primary)
                            .padding(.top, 4)
                            .textSelection(.enabled)
                    }
                }

                ForEach(message.workOrders) { workOrder in
                    NavigationLink {
                        AssistantWorkOrderDetail(workOrder: workOrder)
                    } label: {
                        AriaWorkOrderCard(workOrder: workOrder)
                    }
                    .buttonStyle(.plain)
                }

                // Follow-up question chips
                ForEach(message.followUps) { followUp in
                    Button {
                        onFollowUp(followUp)
                    } label: {
                        HStack(spacing: 7) {
                            Image(systemName: "arrow.turn.down.right")
                                .font(.system(size: 10, weight: .semibold))
                            Text(followUp.text)
                                .font(.system(size: 13, weight: .medium))
                                .multilineTextAlignment(.leading)
                        }
                        .foregroundStyle(Color.accentColor)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                        .background(Color.accentColor.opacity(0.08), in: Capsule())
                        .overlay(Capsule().strokeBorder(Color.accentColor.opacity(0.2), lineWidth: 1))
                    }
                    .buttonStyle(.plain)
                }
            }

            if !message.isUser {
                Spacer(minLength: isCompact ? 55 : 12)
            }
        }
    }
}

// MARK: - Work Order Card (in chat)
struct AriaWorkOrderCard: View {
    let workOrder: WorkOrder
    @Environment(AppViewModel.self) private var viewModel

    private var completed: Int {
        workOrder.checklist.filter { viewModel.isItemCompleted($0, in: workOrder.id) }.count
    }
    private var total: Int { workOrder.checklist.count }
    private var progress: Double { total == 0 ? 0 : Double(completed) / Double(total) }
    private var isSubmitted: Bool { viewModel.submittedWorkOrders.contains(workOrder.id) }

    private var statusText: String {
        if isSubmitted { return String(localized: "Submitted") }
        if completed == 0 { return String(localized: "Not started") }
        return String(localized: "In progress")
    }
    private var statusColor: Color {
        if isSubmitted { return .green }
        if completed == 0 { return .secondary }
        return Color.liteAccent
    }

    var body: some View {
        HStack(spacing: 12) {
            ZStack {
                Circle()
                    .fill(Color.liteAccent.opacity(0.12))
                    .frame(width: 36, height: 36)
                Image(systemName: isSubmitted ? "checkmark.circle.fill" : "wrench.and.screwdriver.fill")
                    .font(.system(size: 14))
                    .foregroundStyle(isSubmitted ? .green : Color.liteAccent)
            }

            VStack(alignment: .leading, spacing: 5) {
                Text(workOrder.title)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(.primary)
                    .lineLimit(1)

                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        Capsule()
                            .fill(Color.liteAccent.opacity(0.12))
                            .frame(height: 4)
                        Capsule()
                            .fill(isSubmitted ? Color.green : Color.liteAccent)
                            .frame(width: geo.size.width * progress, height: 4)
                    }
                }
                .frame(height: 4)

                HStack(spacing: 6) {
                    Text("\(completed)/\(total) steps")
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary)
                    Text("•")
                        .font(.system(size: 11))
                        .foregroundStyle(.tertiary)
                    Text(statusText)
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(statusColor)
                }
            }

            Spacer(minLength: 0)

            Image(systemName: "chevron.right")
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(.tertiary)
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .strokeBorder(Color.liteAccent.opacity(0.10), lineWidth: 1)
        )
    }
}

// MARK: - Work Order Detail (pushed from chat)
struct AssistantWorkOrderDetail: View {
    let workOrder: WorkOrder
    @Environment(AppViewModel.self) private var viewModel

    private var completed: Int {
        workOrder.checklist.filter { viewModel.isItemCompleted($0, in: workOrder.id) }.count
    }
    private var total: Int { workOrder.checklist.count }
    private var progress: Double { total == 0 ? 0 : Double(completed) / Double(total) }
    private var isSubmitted: Bool { viewModel.submittedWorkOrders.contains(workOrder.id) }

    private var statusText: String {
        if isSubmitted { return String(localized: "Submitted") }
        if completed == 0 { return String(localized: "Not started") }
        return String(localized: "In progress")
    }
    private var statusColor: Color {
        if isSubmitted { return .green }
        if completed == 0 { return .secondary }
        return Color.liteAccent
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                summaryCard
                checklistSection
                if !workOrder.documents.isEmpty { documentsSection }
            }
            .padding(20)
        }
        .liteBackground()
        .navigationTitle(workOrder.title)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .principal) {
                Text(workOrder.title)
                    .font(.system(size: 17, weight: .semibold))
                    .lineLimit(1)
                    .minimumScaleFactor(0.6)
            }
        }
    }

    private var summaryCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Label(statusText, systemImage: isSubmitted ? "checkmark.seal.fill" : "clock")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(statusColor)
                Spacer()
                Label(
                    workOrder.scheduledDate.formatted(date: .abbreviated, time: .omitted),
                    systemImage: "calendar"
                )
                .font(.system(size: 12))
                .foregroundStyle(.secondary)
            }

            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule().fill(Color.liteAccent.opacity(0.12)).frame(height: 6)
                    Capsule()
                        .fill(isSubmitted ? Color.green : Color.liteAccent)
                        .frame(width: geo.size.width * progress, height: 6)
                }
            }
            .frame(height: 6)

            Text("\(completed)/\(total) steps")
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(.secondary)
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 16))
    }

    private var checklistSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Checklist")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
                .textCase(.uppercase)
                .tracking(0.5)

            VStack(spacing: 8) {
                ForEach(workOrder.checklist) { item in
                    let done = viewModel.isItemCompleted(item, in: workOrder.id)
                    let hasNote = viewModel.fieldNotes[workOrder.id]?[item.id] != nil

                    HStack(alignment: .top, spacing: 10) {
                        Image(systemName: done ? "checkmark.circle.fill" : "circle")
                            .font(.system(size: 16))
                            .foregroundStyle(done ? .green : Color.liteAccent.opacity(0.4))

                        VStack(alignment: .leading, spacing: 2) {
                            Text(item.text)
                                .font(.system(size: 14, weight: .medium))
                                .foregroundStyle(.primary)
                            if let description = item.description, !description.isEmpty {
                                Text(description)
                                    .font(.system(size: 12))
                                    .foregroundStyle(.secondary)
                                    .lineLimit(2)
                            }
                        }

                        Spacer(minLength: 0)

                        if hasNote {
                            Image(systemName: "note.text")
                                .font(.system(size: 12))
                                .foregroundStyle(Color.liteAccent)
                        }
                    }
                    .padding(12)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 12))
                }
            }
        }
    }

    private var documentsSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Documents")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
                .textCase(.uppercase)
                .tracking(0.5)

            VStack(spacing: 8) {
                ForEach(workOrder.documents) { doc in
                    HStack(spacing: 10) {
                        Image(systemName: "doc.text.fill")
                            .font(.system(size: 14))
                            .foregroundStyle(Color.liteAccent)
                        Text(doc.title)
                            .font(.system(size: 14))
                            .foregroundStyle(.primary)
                        Spacer(minLength: 0)
                    }
                    .padding(12)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 12))
                }
            }
        }
    }
}

// MARK: - Typing Indicator
struct AriaTypingIndicator: View {
    @State private var animating = false

    var body: some View {
        HStack(alignment: .bottom, spacing: 8) {
            AriaOrb(mood: .thinking)
                .frame(width: 28, height: 28)
                .shadow(color: Color.accentColor.opacity(0.2), radius: 3)

            HStack(spacing: 5) {
                ForEach(0..<3, id: \.self) { i in
                    Circle()
                        .fill(Color.accentColor.opacity(0.5))
                        .frame(width: 7, height: 7)
                        .scaleEffect(animating ? 1.2 : 0.8)
                        .opacity(animating ? 1.0 : 0.4)
                        .animation(
                            .easeInOut(duration: 0.48)
                                .repeatForever(autoreverses: true)
                                .delay(Double(i) * 0.16),
                            value: animating
                        )
                }
            }
            .padding(.vertical, 10)

            Spacer(minLength: 55)
        }
        .onAppear { animating = true }
    }
}

// MARK: - Preview
#Preview {
    AIChatView()
        .environment(AppViewModel())
}
