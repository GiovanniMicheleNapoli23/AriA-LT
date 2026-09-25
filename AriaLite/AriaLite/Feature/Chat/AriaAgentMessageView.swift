//
//  AriaAgentMessageView.swift
//  AriaLite
//
//  Un messaggio della chat, nello stesso ordine della web (agent-message-body):
//  strumenti, fonti, ragionamento, testo, conoscenza usata, card, immagini,
//  eventi CMMS, checklist, azioni, proposte di memoria, approvazione, errore,
//  barra (copia, leggi, voto, rigenera) e chip di follow-up.
//

import AVFoundation
import SwiftUI

struct AriaAgentMessageView: View {
    let message: AriaAgentMessage
    let chat: AriaAgentChat
    let webBase: URL
    var isLast: Bool

    @Environment(\.openURL) private var openURL
    @State private var showReasoning = false
    @State private var showSources = false
    @State private var showFacts = false
    @State private var copied = false
    @State private var downNote = ""
    @State private var askingDownNote = false

    private var actions: AriaArtifactActions {
        AriaArtifactActions(
            ask: { chat.send($0) },
            quick: { chat.sendQuick(label: $0, tool: $1, args: $2) },
            open: { path in open(path) }
        )
    }

    var body: some View {
        if message.role == .user {
            userBubble
        } else {
            assistant
        }
    }

    // MARK: Utente

    private var userBubble: some View {
        HStack {
            Spacer(minLength: 55)
            Text(message.text)
                .font(.system(size: 16))
                .foregroundStyle(.white)
                .padding(.horizontal, 15)
                .padding(.vertical, 11)
                .background(Color.accentColor, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
                .textSelection(.enabled)
        }
    }

    // MARK: Assistente

    private var assistant: some View {
        HStack(alignment: .top, spacing: 8) {
            Image("AriaBlobIcon")
                .resizable()
                .scaledToFit()
                .frame(width: 28, height: 28)
                .shadow(color: Color.accentColor.opacity(0.2), radius: 3)

            VStack(alignment: .leading, spacing: 10) {
                if !message.toolCalls.isEmpty { activityStrip }
                if !message.sources.isEmpty { sources }
                if !message.reasoning.isEmpty { reasoning }

                if !message.displayText.isEmpty {
                    AriaMarkdownView(text: message.displayText)
                        .padding(.horizontal, 15)
                        .padding(.vertical, 11)
                        .background(Color(.secondarySystemGroupedBackground),
                                    in: RoundedRectangle(cornerRadius: 20, style: .continuous))
                } else if !message.finished {
                    AriaTypingDots()
                }

                if !message.memoryFactsUsed.isEmpty { factsUsed }

                ForEach(message.artifacts.filter(\.isDeliverable)) { AriaArtifactView(artifact: $0, actions: actions) }
                ForEach(message.artifacts.filter { !$0.isDeliverable }) { AriaArtifactView(artifact: $0, actions: actions) }

                if !message.images.isEmpty { images }
                cmmsNotices

                if let list = message.taskList {
                    AriaTaskChecklistCard(list: list, messageId: message.id, chat: chat,
                                          isLatest: chat.latestTaskList?.messageId == message.id)
                }

                if !message.uiActions.isEmpty { actionBar }

                if message.finished, !message.memoryLearned.isEmpty {
                    Label(String(localized: "Aria learned \(message.memoryLearned.count) new facts"), systemImage: "brain")
                        .font(.system(size: 12)).foregroundStyle(.secondary)
                }
                ForEach(message.memoryProposals) { memoryProposal($0) }

                if let interrupt = message.interrupt, interrupt.kind != .loto, !chat.isStreaming {
                    AriaApprovalCard(interrupt: interrupt) { chat.resume($0) }
                } else if let outcome = message.interruptOutcome {
                    AriaInterruptOutcomeLine(outcome: outcome)
                }

                if let error = message.error {
                    Label(error, systemImage: "exclamationmark.triangle.fill")
                        .font(.system(size: 12))
                        .foregroundStyle(.red)
                }

                if message.finished, !message.displayText.isEmpty || !message.artifacts.isEmpty {
                    toolbar
                }
                if isLast, message.finished, message.interrupt == nil, chat.activeElicitation == nil {
                    followUps
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .ariaLinks(webBase)
        .alert("What was wrong?", isPresented: $askingDownNote) {
            TextField("Optional note", text: $downNote)
            Button("Cancel", role: .cancel) { downNote = "" }
            Button("Send") {
                let note = downNote.trimmingCharacters(in: .whitespacesAndNewlines)
                chat.vote(message.id, .down, note: note.isEmpty ? nil : note)
                downNote = ""
            }
        }
    }

    // MARK: Parti

    private var activityStrip: some View {
        VStack(alignment: .leading, spacing: 4) {
            ForEach(message.toolCalls) { call in
                HStack(spacing: 6) {
                    switch call.status {
                    case .running: ProgressView().controlSize(.mini)
                    case .ok: Image(systemName: "checkmark.circle.fill").foregroundStyle(.green)
                    case .error: Image(systemName: "xmark.circle.fill").foregroundStyle(.red)
                    case .proposed: Image(systemName: "hand.raised.fill").foregroundStyle(.orange)
                    case .rejected: Image(systemName: "nosign").foregroundStyle(.red)
                    case .unknown: Image(systemName: "gearshape").foregroundStyle(.secondary)
                    }
                    Text(AriaChatCopy.toolLabel(call.name))
                        .foregroundStyle(.secondary)
                    if let error = call.error, call.status == .error {
                        Text(error).foregroundStyle(.red).lineLimit(1)
                    }
                }
                .font(.system(size: 12, weight: .medium))
            }
        }
    }

    private var sources: some View {
        DisclosureGroup(isExpanded: $showSources) {
            VStack(alignment: .leading, spacing: 4) {
                ForEach(message.sources, id: \.self) { source in
                    if let raw = source.url, let url = URL(string: raw) {
                        Link(destination: url) { Label(source.title, systemImage: "link") }
                    } else {
                        Label(source.title, systemImage: "doc.text")
                    }
                }
            }
            .font(.system(size: 12))
            .padding(.top, 4)
        } label: {
            Text("\(message.sources.count) sources").font(.system(size: 12, weight: .medium)).foregroundStyle(.secondary)
        }
    }

    private var reasoning: some View {
        DisclosureGroup(isExpanded: $showReasoning) {
            Text(message.reasoning)
                .font(.system(size: 12))
                .foregroundStyle(.secondary)
                .padding(.top, 4)
        } label: {
            Label("Reasoning", systemImage: "brain.head.profile")
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(.secondary)
        }
    }

    private var factsUsed: some View {
        DisclosureGroup(isExpanded: $showFacts) {
            VStack(alignment: .leading, spacing: 4) {
                ForEach(message.memoryFactsUsed, id: \.self) { Text("• \($0)") }
            }
            .font(.system(size: 12))
            .foregroundStyle(.secondary)
        } label: {
            Label("Learned knowledge used · \(message.memoryFactsUsed.count)", systemImage: "books.vertical")
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(.secondary)
        }
    }

    private var images: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(message.images) { image in
                    if let url = URL(string: image.url) {
                        Link(destination: url) {
                            VStack(alignment: .leading, spacing: 4) {
                                AsyncImage(url: url) { phase in
                                    if let picture = phase.image {
                                        picture.resizable().scaledToFill()
                                    } else {
                                        Color(.tertiarySystemFill)
                                    }
                                }
                                .frame(width: 150, height: 110)
                                .clipShape(RoundedRectangle(cornerRadius: 10))
                                if let caption = image.caption {
                                    Text(caption).font(.system(size: 11)).foregroundStyle(.secondary).lineLimit(2)
                                }
                            }
                            .frame(width: 150)
                        }
                    }
                }
            }
        }
    }

    /// Eventi CMMS della pipeline: WO suggerito e scritture su sistemi esterni (MaintainX).
    @ViewBuilder
    private var cmmsNotices: some View {
        ForEach(message.pipeline) { entry in
            switch entry.name {
            case "aria.cmms_work_order_created" where entry.data["detected"]?.boolValue == true:
                AriaCard(tint: .blue) {
                    HStack {
                        Label("Work order suggested", systemImage: "wand.and.stars").font(.system(size: 13, weight: .semibold))
                        Spacer()
                        AriaBadge(text: String(localized: "auto-detected"), tint: .blue)
                    }
                    if let title = entry.data["title"]?.nonEmptyString { Text(title).font(.system(size: 14, weight: .medium)) }
                    if let suggestion = entry.data["suggestion"]?.nonEmptyString {
                        Text(suggestion).font(.system(size: 12)).foregroundStyle(.secondary)
                    }
                }
            case "aria.external_action":
                let ok = entry.data["status"]?.stringValue == "ok"
                Label("\(entry.data["system"]?.stringValue ?? "CMMS"): \(entry.data["summary"]?.stringValue ?? entry.data["tool"]?.stringValue ?? "")",
                      systemImage: ok ? "arrow.up.forward.app.fill" : "exclamationmark.triangle")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(ok ? .green : .orange)
            case "aria.cmms_entity_referenced":
                if let type = entry.data["entity_type"]?.stringValue, let id = entry.data["entity_id"]?.stringValue {
                    Button(entry.data["entity_label"]?.stringValue ?? "\(type) \(id)", systemImage: "link") {
                        open("/\(type.replacingOccurrences(of: "_", with: "-"))s/\(id)")
                    }
                    .font(.system(size: 12, weight: .medium))
                    .buttonStyle(.borderless)
                }
            default:
                EmptyView()
            }
        }
    }

    /// ui-action-bar della web: nessuna navigazione automatica, solo pulsanti.
    private var actionBar: some View {
        let unique = message.uiActions.reduce(into: [AriaUIAction]()) { list, action in
            if !list.contains(where: { $0.to == action.to }) { list.append(action) }
        }
        return ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(unique) { action in
                    if let to = action.to, action.action == "navigate" || action.action == "open-external" {
                        Button(AriaChatCopy.actionLabel(for: action)) { open(to) }
                            .buttonStyle(.bordered)
                            .controlSize(.small)
                    }
                }
            }
        }
    }

    private func memoryProposal(_ proposal: AriaMemoryProposal) -> some View {
        AriaCard(tint: .purple) {
            Label("Should Aria remember this?", systemImage: "brain")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(.purple)
            Text(proposal.content).font(.system(size: 13))
            if let reason = proposal.reason, !reason.isEmpty {
                Text(reason).font(.system(size: 12)).foregroundStyle(.secondary)
            }
            HStack {
                Button("Discard") { chat.confirmMemory(proposal, in: message.id, accept: false) }
                    .buttonStyle(.bordered)
                Spacer()
                Button("Keep") { chat.confirmMemory(proposal, in: message.id, accept: true) }
                    .buttonStyle(.borderedProminent)
            }
            .controlSize(.small)
        }
    }

    private var toolbar: some View {
        HStack(spacing: 16) {
            Button {
                UIPasteboard.general.string = message.displayText
                copied = true
                Task { try? await Task.sleep(for: .seconds(1.5)); copied = false }
            } label: {
                Image(systemName: copied ? "checkmark" : "doc.on.doc")
            }
            .accessibilityLabel("Copy")
            Button {
                AriaSpeech.shared.toggle(message.displayText)
            } label: {
                Image(systemName: "speaker.wave.2")
            }
            .accessibilityLabel("Read aloud")
            Button {
                chat.vote(message.id, .up)
            } label: {
                Image(systemName: message.vote == .up ? "hand.thumbsup.fill" : "hand.thumbsup")
            }
            .accessibilityLabel("Good answer")
            Button {
                if message.vote == .down { chat.vote(message.id, .down) } else { askingDownNote = true }
            } label: {
                Image(systemName: message.vote == .down ? "hand.thumbsdown.fill" : "hand.thumbsdown")
            }
            .accessibilityLabel("Bad answer")
            Button {
                chat.regenerate(message.id)
            } label: {
                Image(systemName: "arrow.clockwise")
            }
            .accessibilityLabel("Regenerate")
            .disabled(chat.isStreaming || chat.pendingInterrupt != nil)
            Spacer()
            if let usage = message.usage, let input = usage.inputTokens, let output = usage.outputTokens {
                Text(verbatim: "↑\(input) ↓\(output)")
                    .font(.system(size: 10).monospacedDigit())
                    .foregroundStyle(.tertiary)
            }
        }
        .font(.system(size: 13))
        .foregroundStyle(.secondary)
        .buttonStyle(.plain)
        .padding(.horizontal, 4)
    }

    private var followUps: some View {
        let chips = AriaChatCopy.followUps(for: message)
        return ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(chips, id: \.self) { chip in
                    Button {
                        chat.send(chip.prompt)
                    } label: {
                        HStack(spacing: 6) {
                            Image(systemName: "arrow.turn.down.right").font(.system(size: 10, weight: .semibold))
                            Text(chip.label).font(.system(size: 13, weight: .medium))
                        }
                        .foregroundStyle(Color.accentColor)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                        .background(Color.accentColor.opacity(0.08), in: Capsule())
                        .overlay(Capsule().strokeBorder(Color.accentColor.opacity(0.2), lineWidth: 1))
                    }
                    .buttonStyle(.plain)
                    .disabled(chat.isStreaming)
                }
            }
        }
    }

    private func open(_ target: String) {
        if let url = URL(string: target), url.scheme != nil {
            openURL(url)
        } else if let url = URL(string: target, relativeTo: webBase)?.absoluteURL {
            openURL(url)
        }
    }
}

// MARK: - Indicatore di digitazione

struct AriaTypingDots: View {
    @State private var animating = false

    var body: some View {
        HStack(spacing: 5) {
            ForEach(0..<3, id: \.self) { i in
                Circle()
                    .fill(Color.accentColor.opacity(0.5))
                    .frame(width: 7, height: 7)
                    .scaleEffect(animating ? 1.2 : 0.8)
                    .opacity(animating ? 1.0 : 0.4)
                    .animation(.easeInOut(duration: 0.48).repeatForever(autoreverses: true).delay(Double(i) * 0.16),
                               value: animating)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
        .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 20, style: .continuous))
        .onAppear { animating = true }
    }
}

// MARK: - Lettura ad alta voce

@MainActor
final class AriaSpeech {
    static let shared = AriaSpeech()
    private let synthesizer = AVSpeechSynthesizer()

    func toggle(_ text: String) {
        if synthesizer.isSpeaking {
            synthesizer.stopSpeaking(at: .immediate)
            return
        }
        // Senza markdown: si legge il testo, non i simboli.
        let plain = String(AriaMarkdown.inline(text).characters)
            .replacingOccurrences(of: #"[#>|*`_]"#, with: "", options: .regularExpression)
        let utterance = AVSpeechUtterance(string: plain)
        utterance.voice = AVSpeechSynthesisVoice(language: Locale.current.language.languageCode?.identifier == "it" ? "it-IT" : "en-US")
        synthesizer.speak(utterance)
    }
}
