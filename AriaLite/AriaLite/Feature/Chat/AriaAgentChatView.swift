//
//  AriaAgentChatView.swift
//  AriaLite
//
//  La chat con il backend Aria, come quella della web: messaggi in streaming,
//  suggerimenti iniziali, scelta dello stabilimento, domande guidate,
//  conferma LOTO, composer con stile di risposta, ricerca web e stop.
//

import SwiftUI

struct AriaAgentChatView: View {
    let chat: AriaAgentChat
    let backend: AriaBackend
    var showsEmptyState = true
    /// Microfono della chat vocale esistente (quando il campo è vuoto).
    var voice: AriaVoiceViewModel? = nil

    @State private var draft = ""
    @State private var greeting = AriaChatCopy.greeting()
    @FocusState private var inputFocused: Bool

    private var lotoInterrupt: AriaInterrupt? {
        guard let pause = chat.pendingInterrupt, pause.kind == .loto, !chat.isStreaming else { return nil }
        return pause
    }

    var body: some View {
        VStack(spacing: 0) {
            messagesArea

            VStack(spacing: 8) {
                if backend.activePlantId == nil { plantGuard }
                if let notice = chat.notice {
                    Label(notice, systemImage: "checkmark.circle.fill")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(.green)
                        .task { try? await Task.sleep(for: .seconds(3)); chat.notice = nil }
                }
                if let (_, question) = chat.activeElicitation {
                    AriaElicitationPanel(elicitation: question) { text, details in
                        chat.answer(question, text: text, details: details)
                    }
                    .transition(.move(edge: .bottom).combined(with: .opacity))
                }
                if let voice, voice.isConnected || voice.isConnecting {
                    VoiceSessionOverlay(voice: voice)
                }
            }
            .padding(.horizontal, 16)
            .padding(.top, 6)

            composer
        }
        .background(Color(.systemGroupedBackground))
        .animation(.easeInOut(duration: 0.25), value: chat.activeElicitation?.elicitation.id)
        .ariaLinks(backend.webURL)
        .task { await chat.restoreIfNeeded() }
        .task(id: backend.activePlantId) {
            if showsEmptyState { await chat.loadSuggestions() }
        }
        .sheet(item: Binding(get: { lotoInterrupt.map(LotoItem.init) }, set: { _ in })) { item in
            AriaLotoSheet(interrupt: item.interrupt) { chat.resume($0) }
        }
        .sheet(item: Binding(get: { chat.pendingCloseout }, set: { chat.pendingCloseout = $0 })) { choice in
            AriaCloseoutSheet(chat: chat, choice: choice)
        }
    }

    private struct LotoItem: Identifiable {
        let interrupt: AriaInterrupt
        var id: String { interrupt.interruptId }
    }

    // MARK: Messaggi

    private var messagesArea: some View {
        ScrollViewReader { proxy in
            ScrollView {
                if chat.isLoadingHistory {
                    ProgressView().padding(.top, 60)
                } else if chat.messages.isEmpty && showsEmptyState {
                    emptyState
                        .frame(maxWidth: .infinity)
                        .containerRelativeFrame(.vertical, alignment: .center)
                } else {
                    LazyVStack(alignment: .leading, spacing: 14) {
                        ForEach(chat.messages) { message in
                            AriaAgentMessageView(message: message, chat: chat, webBase: backend.webURL,
                                                 isLast: message.id == chat.messages.last?.id)
                                .id(message.id)
                        }
                        Color.clear.frame(height: 1).id("bottom")
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 14)
                }
            }
            .scrollDismissesKeyboard(.interactively)
            .defaultScrollAnchor(.bottom)
            .onChange(of: chat.messages.count) {
                withAnimation(.spring(response: 0.4)) { proxy.scrollTo("bottom") }
            }
            .onChange(of: chat.messages.last?.text) {
                proxy.scrollTo("bottom")
            }
        }
    }

    private var emptyState: some View {
        VStack(spacing: 22) {
            Image("AriaBlob")
                .resizable()
                .scaledToFit()
                .frame(width: 96, height: 96)
                .shadow(color: Color.accentColor.opacity(0.28), radius: 18, x: 0, y: 8)

            Text(greeting)
                .font(.system(size: 22, weight: .bold, design: .rounded))
                .multilineTextAlignment(.center)
                .padding(.horizontal, 24)

            LazyVGrid(columns: [GridItem(.flexible(), spacing: 10), GridItem(.flexible(), spacing: 10)], spacing: 10) {
                ForEach(chat.suggestions, id: \.self) { suggestion in
                    Button {
                        chat.send(suggestion)
                    } label: {
                        Text(suggestion)
                            .font(.system(size: 13, weight: .medium))
                            .foregroundStyle(.primary)
                            .multilineTextAlignment(.leading)
                            .frame(maxWidth: .infinity, minHeight: 58, alignment: .topLeading)
                            .padding(12)
                            .background(Color(.secondarySystemGroupedBackground),
                                        in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                            .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous)
                                .strokeBorder(Color.accentColor.opacity(0.12), lineWidth: 1))
                    }
                    .buttonStyle(.plain)
                    .disabled(backend.activePlantId == nil)
                }
            }
            .padding(.horizontal, 16)

            Text("AriA can make mistakes. Verify safety procedures before any intervention.")
                .font(.system(size: 11))
                .foregroundStyle(.tertiary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)
        }
        .padding(.vertical, 20)
    }

    /// PlantGuardBanner della web: senza stabilimento il backend non risponde.
    private var plantGuard: some View {
        HStack {
            Label("Select a plant before chatting.", systemImage: "building.2")
                .font(.system(size: 13, weight: .medium))
            Spacer()
            Menu {
                ForEach(backend.plants) { plant in
                    Button(plant.name) { Task { await backend.selectPlant(plant.id) } }
                }
            } label: {
                Text("Choose").font(.system(size: 13, weight: .semibold))
            }
            .disabled(backend.plants.isEmpty)
        }
        .padding(12)
        .background(Color.orange.opacity(0.1), in: RoundedRectangle(cornerRadius: 12))
        .task { await backend.bootstrapIfNeeded() }
    }

    // MARK: Composer

    private var hasText: Bool { !draft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
    private var isLocked: Bool { chat.pendingInterrupt != nil }

    private var composer: some View {
        HStack(alignment: .bottom, spacing: 8) {
            Menu {
                Picker("Response style", selection: Binding(get: { chat.style }, set: { chat.style = $0 })) {
                    Text("Auto").tag(AriaChatStyle.auto)
                    Text("Detailed").tag(AriaChatStyle.detailed)
                    Text("Compact (operator)").tag(AriaChatStyle.compact)
                }
                Toggle("Web search", isOn: Binding(get: { chat.webSearch }, set: { chat.webSearch = $0 }))
            } label: {
                Image(systemName: "slider.horizontal.3")
                    .font(.system(size: 16, weight: .medium))
                    .foregroundStyle(.secondary)
                    .frame(width: 36, height: 44)
            }

            TextField(isLocked ? "Waiting for your decision above" : "Ask Aria anything...",
                      text: $draft, axis: .vertical)
                .font(.system(size: 16))
                .lineLimit(1...5)
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
                .focused($inputFocused)
                .disabled(isLocked)
                .background(Color(.secondarySystemGroupedBackground),
                            in: RoundedRectangle(cornerRadius: 22, style: .continuous))
                .overlay(RoundedRectangle(cornerRadius: 22, style: .continuous)
                    .stroke(inputFocused ? Color.accentColor.opacity(0.5) : .clear, lineWidth: 1.5))

            Button(action: primaryAction) {
                ZStack {
                    Circle()
                        .fill(showsStop ? Color.red : Color.accentColor)
                        .frame(width: 44, height: 44)
                    if let voice, voice.isConnecting, !hasText, !chat.isStreaming {
                        ProgressView().tint(.white)
                    } else {
                        Image(systemName: symbol)
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundStyle(.white)
                            .contentTransition(.symbolEffect(.replace))
                    }
                }
            }
            .buttonStyle(.plain)
            .disabled(hasText ? (chat.isStreaming || isLocked || backend.activePlantId == nil) : (!chat.isStreaming && voice == nil))
            .accessibilityLabel(chat.isStreaming ? "Stop" : "Send")
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(
            Color(.systemGroupedBackground)
                .overlay(alignment: .top) { Divider().opacity(0.6) }
                .ignoresSafeArea()
        )
    }

    private var showsStop: Bool { !hasText && (chat.isStreaming || voice?.isConnected == true) }

    private var symbol: String {
        if hasText { return "arrow.up" }
        if showsStop { return "stop.fill" }
        return voice == nil ? "arrow.up" : "mic.fill"
    }

    private func primaryAction() {
        if hasText {
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
            chat.send(draft)
            draft = ""
            inputFocused = false
        } else if chat.isStreaming {
            chat.stop()
        } else {
            voice?.toggleConnection()
        }
    }
}
