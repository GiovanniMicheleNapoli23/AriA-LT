//
//  AriaAgentChatView.swift
//  AriaLite
//
//  La chat con il backend Aria, come quella della web: messaggi in streaming,
//  suggerimenti iniziali, scelta dello stabilimento, domande guidate (al posto
//  del composer), conferma LOTO, comandi rapidi, errori con "Riprova" e un
//  pulsante per tornare in fondo quando si sta rileggendo.
//

import SwiftUI

struct AriaAgentChatView: View {
    let chat: AriaAgentChat
    let backend: AriaBackend
    var showsEmptyState = true
    /// Microfono della chat vocale esistente (quando il campo è vuoto).
    var voice: AriaVoiceViewModel? = nil

    @State private var draft = ""
    @Namespace private var orbNamespace
    @State private var greeting = AriaChatCopy.greeting()
    @FocusState private var inputFocused: Bool
    /// La domanda guidata è stata ridotta a pillola (si legge o si scrive liberamente).
    @State private var questionCollapsed = false
    /// La domanda di Real-time Learning in fondo: compare quando l'avviso rientra nella Dynamic Island.
    @State private var learningShownId: String?
    @State private var learningCollapsed = false
    /// Il pannello mostrato in fondo: segue `wantedPanel` con un'animazione.
    @State private var panel: BottomPanel = .composer
    /// La chat segue l'ultimo messaggio. Smette solo quando è l'operatore a scorrere verso l'alto:
    /// il testo che cresce durante lo streaming non deve mai fargli perdere il "segui".
    @State private var followsBottom = true
    @State private var isNearBottom = true
    /// Scorrimento fatto con il dito (non da `scrollTo`).
    @State private var userScrolling = false
    @State private var viewportHeight: CGFloat = 700
    /// Parte visibile della lista (senza barre e pannello in basso) e altezza dell'ultima domanda:
    /// servono a tenere la domanda in cima mentre la risposta cresce sotto (come Claude).
    @State private var visibleHeight: CGFloat = 600
    @State private var turnQuestionHeight: CGFloat = 0

    private var lotoInterrupt: AriaInterrupt? {
        guard let pause = chat.pendingInterrupt, pause.kind == .loto, !chat.isStreaming else { return nil }
        return pause
    }

    /// L'ultimo turno è fallito: si può rimandare la stessa domanda.
    private var failedTurn: AriaAgentMessage? {
        guard !chat.isStreaming, let last = chat.messages.last, last.role == .assistant, last.error != nil,
              last.interrupt == nil else { return nil }
        return last
    }

    /// L'ultima domanda dell'operatore e la risposta che la segue (se è l'ultimo messaggio).
    private var turnQuestionID: String? {
        chat.messages.last(where: { $0.role == .user })?.id
    }

    private var turnReplyID: String? {
        guard let last = chat.messages.last, last.role == .assistant,
              let questionIndex = chat.messages.lastIndex(where: { $0.role == .user }),
              questionIndex == chat.messages.count - 2 else { return nil }
        return last.id
    }

    /// Altezza minima della risposta: con la lista in fondo, la domanda resta in cima allo schermo e
    /// la risposta (con la sfera sotto) scende man mano che si scrive; quando non ci sta più, si segue il fondo.
    private var replyMinHeight: CGFloat {
        // padding verticale della lista (14 + 14), spaziature (16 + 16) e il segnaposto "bottom" (1).
        max(0, visibleHeight - turnQuestionHeight - 61)
    }

    /// Altezza del contenuto e della finestra visibile: se cambia una delle due e si sta seguendo, si torna in fondo.
    private struct ScrollSizes: Equatable {
        var content: CGFloat
        var container: CGFloat
    }

    var body: some View {
        ScrollViewReader { proxy in
            messagesArea(proxy)
                // Primo invio: la sfera grande diventa quella piccola sotto la risposta.
                .animation(.spring(response: 0.55, dampingFraction: 0.82), value: chat.messages.isEmpty)
                .overlay(alignment: .bottom) { scrollToBottomButton(proxy) }
                // Il fondo sta sopra i messaggi, non sotto: con il vetro della barra si vedono scorrere dietro.
                .safeAreaInset(edge: .bottom, spacing: 0) { dock(proxy) }
        }
        .background(Color(.systemGroupedBackground))
        .onGeometryChange(for: CGFloat.self, of: \.size.height) { viewportHeight = $0 }
        .animation(.snappy(duration: 0.3), value: chat.activeElicitation?.elicitation.id)
        .animation(.snappy(duration: 0.3), value: questionCollapsed)
        .animation(.snappy(duration: 0.25), value: chat.notice)
        .animation(.snappy(duration: 0.25), value: chat.lastError)
        .animation(.snappy(duration: 0.3), value: chat.blockingTaskList == nil)
        .onChange(of: chat.activeElicitation?.elicitation.id) { questionCollapsed = false }
        .animation(.snappy(duration: 0.3), value: learningCollapsed)
        .onChange(of: chat.activeLearning?.messageId) { _, id in announceLearning(id) }
        .onChange(of: chat.learningReveal) {
            learningShownId = chat.activeLearning?.messageId
            learningCollapsed = false
        }
        // Tornando alla chat con una domanda già annunciata (o mai vista) la si mostra subito, senza avviso.
        .onAppear { learningShownId = chat.activeLearning?.messageId }
        .modifier(AriaChatHaptics(chat: chat))
        .ariaLinks(backend.webURL)
        .task { await chat.restoreIfNeeded() }
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

    /// Cronologia in caricamento e chat vuota stanno fuori dalla scroll view dei messaggi: una schermata
    /// alta quanto lo schermo (containerRelativeFrame) dentro una ScrollView ancorata in basso e osservata
    /// entrava in un ciclo di layout infinito — main thread al 100% e chat inutilizzabile.
    @ViewBuilder
    private func messagesArea(_ proxy: ScrollViewProxy) -> some View {
        if chat.isLoadingHistory {
            ProgressView()
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else if chat.messages.isEmpty && showsEmptyState {
            emptyState
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .contentShape(Rectangle())
                .onTapGesture { inputFocused = false }
        } else {
            messagesList(proxy)
        }
    }

    private func messagesList(_ proxy: ScrollViewProxy) -> some View {
        ScrollView {
            // VStack e non LazyVStack: con altezze stimate lo scroll in fondo saltella mentre il testo cresce.
            VStack(alignment: .leading, spacing: 16) {
                ForEach(chat.messages) { message in
                    AriaAgentMessageView(message: message, chat: chat, webBase: backend.webURL,
                                         isLast: message.id == chat.messages.last?.id,
                                         orbNamespace: showsEmptyState ? orbNamespace : nil)
                        .onGeometryChange(for: CGFloat.self, of: \.size.height) { height in
                            if message.id == turnQuestionID { turnQuestionHeight = height }
                        }
                        .frame(minHeight: message.id == turnReplyID ? replyMinHeight : nil, alignment: .top)
                        .id(message.id)
                }
                Color.clear.frame(height: 1).id("bottom")
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 14)
        }
        .scrollDismissesKeyboard(.interactively)
        .defaultScrollAnchor(.bottom)
        // Il riquadro della lista è già senza barra in alto e pannello in basso. onGeometryChange dà anche il valore iniziale.
        .onGeometryChange(for: CGFloat.self, of: \.size.height) { height in
            visibleHeight = height
        }
        .onScrollGeometryChange(for: Bool.self) { geometry in
            geometry.visibleRect.maxY >= geometry.contentSize.height - 80
        } action: { _, near in
            isNearBottom = near
        }
        // Testo in streaming, card, tastiera, pannello in basso: qualunque cambio di altezza, se si segue si resta in fondo.
        .onScrollGeometryChange(for: ScrollSizes.self) { geometry in
            ScrollSizes(content: geometry.contentSize.height, container: geometry.containerSize.height)
        } action: { _, sizes in
            // Solo se c'è davvero da scorrere: con un contenuto più corto dello schermo non serve.
            guard followsBottom, !userScrolling, sizes.content > sizes.container + 1 else { return }
            proxy.scrollTo("bottom", anchor: .bottom)
        }
        // Solo il dito decide se seguire: finito lo scorrimento, si segue se si è rimasti in fondo.
        .onScrollPhaseChange { _, phase in
            switch phase {
            case .tracking, .interacting:
                userScrolling = true
            case .idle:
                if userScrolling { followsBottom = isNearBottom }
                userScrolling = false
            default:
                break
            }
        }
        // Un messaggio nuovo (mandato o ricevuto) riporta sempre in fondo.
        .onChange(of: chat.messages.count) {
            followsBottom = true
            proxy.scrollTo("bottom", anchor: .bottom)
        }
    }

    @ViewBuilder
    private func scrollToBottomButton(_ proxy: ScrollViewProxy) -> some View {
        if !followsBottom, !isNearBottom, !chat.messages.isEmpty {
            Button {
                followsBottom = true
                withAnimation(.snappy) { proxy.scrollTo("bottom", anchor: .bottom) }
            } label: {
                Image(systemName: chat.isStreaming ? "arrow.down.circle.dotted" : "arrow.down")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(.primary)
                    .frame(width: 40, height: 40)
                    .ariaGlass(in: Circle(), interactive: true)
            }
            .buttonStyle(.plain)
            .padding(.bottom, 10)
            .accessibilityLabel("Scroll to the latest message")
            .transition(.scale(scale: 0.6).combined(with: .opacity))
        }
    }

    /// La sfera e il saluto: mentre l'operatore scrive la sfera "pensa", e all'invio vola al posto
    /// della sfera piccola sotto la risposta (stesso `matchedGeometryEffect`) mentre il saluto sparisce.
    private var emptyState: some View {
        VStack(spacing: 18) {
            AriaOrb(mood: isComposing ? .thinking : .idle, radius: 0.8)
                .ariaOrbHero(orbNamespace)
                .frame(width: 64, height: 64)
                .shadow(color: Color.accentColor.opacity(0.22), radius: 12, x: 0, y: 6)

            Text(greeting)
                .font(.system(size: 22, weight: .regular))
                .foregroundStyle(.primary.opacity(0.85))
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)
                .transition(.opacity)
        }
    }

    private var isComposing: Bool {
        !draft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    // MARK: In basso

    /// Avvisi, poi la domanda guidata (che prende il posto del composer) oppure il composer.
    private func dock(_ proxy: ScrollViewProxy) -> some View {
        VStack(spacing: 8) {
            VStack(spacing: 8) {
                if backend.activePlantId == nil { plantGuard }
                if let notice = chat.notice { noticeBanner(notice) }
                if let error = chat.lastError { errorBanner(error) }
                if let voice, voice.isConnected || voice.isConnecting || voice.error != nil {
                    VoiceSessionOverlay(voice: voice)
                }
                if let (messageId, request, _) = chat.activeLearning, learningShownId == messageId, learningCollapsed {
                    AriaElicitationPill(elicitation: request.elicitation(messageId: messageId), isLearning: true) {
                        inputFocused = false
                        learningCollapsed = false
                    }
                    .transition(.move(edge: .bottom).combined(with: .opacity))
                } else if let (_, question) = chat.activeElicitation, questionCollapsed, chat.blockingTaskList == nil {
                    AriaElicitationPill(elicitation: question) { expandQuestion() }
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                }
            }
            .padding(.horizontal, 12)

            switch panel {
            case .learned(let outcome):
                AriaLearningOutcomePanel(outcome: outcome, chat: chat)
                    .padding(.top, 4)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
            case .learning(let messageId, let request):
                // Stesso posto e stesso comportamento della domanda guidata, ma la risposta insegna ad Aria:
                // non diventa un turno di chat e la procedura in corso non si interrompe.
                AriaElicitationPanel(elicitation: request.elicitation(messageId: messageId),
                                     kind: .learning(reason: request.reasonText),
                                     maxOptionsHeight: max(200, viewportHeight * 0.6)) { text, _ in
                    chat.answerLearning(messageId: messageId, request: request, feedback: text)
                } onMinimize: {
                    learningCollapsed = true
                }
                .padding(.top, 4)
                .transition(.move(edge: .bottom).combined(with: .opacity))
            case .procedure(let messageId, let list):
                // Prima la checklist, poi la domanda: finché mancano task si risponde alla procedura.
                AriaProcedureDock(list: list, messageId: messageId, chat: chat)
                    .padding(.top, 4)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
            case .question(let question):
                AriaElicitationPanel(elicitation: question, maxOptionsHeight: max(200, viewportHeight * 0.7)) { text, details in
                    chat.answer(question, text: text, details: details)
                } onMinimize: {
                    questionCollapsed = true
                }
                .padding(.top, 4)
                .transition(.move(edge: .bottom).combined(with: .opacity))
            case .composer:
                AriaChatComposer(chat: chat, backend: backend, voice: voice, draft: $draft,
                                 inputFocused: $inputFocused) {
                    if let id = chat.messages.last(where: { $0.interrupt != nil })?.id {
                        withAnimation(.snappy) { proxy.scrollTo(id, anchor: .bottom) }
                    }
                }
                .transition(.opacity)
            }
        }
        .padding(.top, 6)
        // Il pannello segue la chat con un'animazione esplicita: cambia quando finisce lo stream,
        // e l'animazione implicita lì non partiva (il pannello compariva di colpo).
        .onChange(of: wantedPanel) { _, new in
            withAnimation(.spring(duration: 0.45, bounce: 0.12)) { panel = new }
        }
        .onAppear { panel = wantedPanel }
    }

    /// Cosa c'è in fondo: la procedura, la domanda guidata o il composer. I dati viaggiano con il caso,
    /// così il pannello che esce si disegna ancora mentre la chat è già passata oltre.
    private enum BottomPanel: Equatable {
        case composer
        case question(AriaElicitation)
        case procedure(messageId: String, list: AriaTaskList)
        case learning(messageId: String, request: AriaValidationRequest)
        case learned(AriaLearningOutcome)
    }

    /// Il Real-time Learning passa davanti: è appena stato annunciato dall'isola e non blocca niente
    /// (con "Non ora" si riduce a pillola e tornano la procedura, la domanda o il composer).
    private var wantedPanel: BottomPanel {
        if let outcome = chat.learningOutcome { return .learned(outcome) }
        if let (messageId, request, _) = chat.activeLearning, learningShownId == messageId, !learningCollapsed {
            return .learning(messageId: messageId, request: request)
        }
        if let (messageId, list) = chat.blockingTaskList { return .procedure(messageId: messageId, list: list) }
        if let (_, question) = chat.activeElicitation, !questionCollapsed { return .question(question) }
        return .composer
    }

    /// Una domanda di Real-time Learning nuova: l'avviso esce dalla Dynamic Island e, quando ci rientra,
    /// la domanda compare in fondo. Riaperta dal chip di un messaggio invece compare subito.
    private func announceLearning(_ messageId: String?) {
        guard let messageId, let (_, request, manual) = chat.activeLearning else { return }
        learningCollapsed = false
        if manual || learningShownId == messageId {
            learningShownId = messageId
            return
        }
        let alert = AriaIsland.Alert(title: String(localized: "Real-time Learning"),
                                     message: request.question,
                                     systemImage: AriaLearningStyle.symbol,
                                     tint: AriaLearningStyle.tint)
        AriaIsland.shared.present(alert) { [chat] in
            // Nel frattempo può essere partito un turno nuovo: la domanda allora non c'è più.
            guard chat.activeLearning?.messageId == messageId else { return }
            learningShownId = messageId
        }
    }

    private func expandQuestion() {
        inputFocused = false
        questionCollapsed = false
    }

    private func noticeBanner(_ notice: String) -> some View {
        Label(notice, systemImage: "checkmark.circle.fill")
            .font(.system(size: 13, weight: .medium))
            .foregroundStyle(.green)
            .padding(.horizontal, 14)
            .padding(.vertical, 8)
            .background(Color.green.opacity(0.1), in: Capsule())
            .transition(.move(edge: .bottom).combined(with: .opacity))
            .task(id: notice) {
                try? await Task.sleep(for: .seconds(3))
                chat.notice = nil
            }
    }

    private func errorBanner(_ error: String) -> some View {
        HStack(spacing: 10) {
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundStyle(.red)
            Text(error)
                .font(.system(size: 13))
                .lineLimit(2)
            Spacer(minLength: 4)
            if let failed = failedTurn {
                Button("Retry") { chat.regenerate(failed.id) }
                    .font(.system(size: 13, weight: .semibold))
                    .buttonStyle(.bordered)
                    .buttonBorderShape(.capsule)
                    .controlSize(.small)
            }
            Button {
                chat.lastError = nil
            } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundStyle(.secondary)
                    .frame(width: 26, height: 26)
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Dismiss")
        }
        .padding(.leading, 12)
        .padding(.trailing, 6)
        .padding(.vertical, 6)
        .background(Color.red.opacity(0.08), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        .transition(.move(edge: .bottom).combined(with: .opacity))
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
}

// MARK: - Haptic

/// Gli haptic della conversazione si leggono dallo stato della chat, così valgono da qualunque
/// punto parta l'azione (composer, suggerimenti, aiuto sui task, domande guidate, card).
private struct AriaChatHaptics: ViewModifier {
    let chat: AriaAgentChat

    /// Esito dell'ultima pausa decisa (approvazione o LOTO).
    private var outcome: AriaInterruptOutcome? {
        chat.messages.last(where: { $0.role == .assistant })?.interruptOutcome
    }

    func body(content: Content) -> some View {
        content
            // Turno nuovo: domanda e risposta in arrivo aggiunte insieme (lo storico caricato non conta).
            .sensoryFeedback(trigger: chat.messages.count) { old, new in
                new == old + 2 && chat.isStreaming ? .impact(weight: .light) : nil
            }
            // Aria ha finito e aspetta l'operatore: una decisione da prendere o una domanda.
            .sensoryFeedback(trigger: chat.isStreaming) { was, now in
                guard was, !now, chat.lastError == nil else { return nil }
                if chat.pendingInterrupt != nil { return .warning }
                if chat.activeElicitation != nil { return .impact(weight: .medium) }
                return nil
            }
            // La decisione sulla pausa: il LOTO confermato "pesa" più di un'approvazione.
            .sensoryFeedback(trigger: outcome) { _, new in
                guard chat.isStreaming, let new else { return nil }
                return switch new {
                case .approved, .edited: .success
                case .rejected: .impact(weight: .medium)
                case .lotoConfirmed: .impact(weight: .heavy)
                case .lotoDeclined: .warning
                }
            }
            .sensoryFeedback(.error, trigger: chat.lastError) { _, new in new != nil }
            .sensoryFeedback(.success, trigger: chat.notice) { _, new in new != nil }
    }
}
