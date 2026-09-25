//
//  AriaShellView.swift
//  AriaLite
//
//  Navigazione come Claude mobile: la chat è la schermata principale e tutte le
//  sezioni (Chat, Panoramica, Task, conversazioni fissate e recenti)
//  stanno in una sidebar che si apre dal pulsante ☰ o trascinando dal bordo sinistro.
//  Il pannello principale scivola a destra con gli angoli arrotondati.
//

import SwiftUI

enum AriaDestination: Hashable {
    case chat
    case chats
    case overview
    case tasks
}

extension EnvironmentValues {
    /// Apre la sidebar: il pulsante ☰ di ogni sezione lo legge da qui.
    @Entry var openSidebar: () -> Void = {}
}

/// Pulsante ☰ da mettere in alto a sinistra nella toolbar di ogni sezione.
struct AriaSidebarButton: View {
    @Environment(\.openSidebar) private var openSidebar

    var body: some View {
        Button("Menu", systemImage: "line.3.horizontal", action: openSidebar)
    }
}

struct AriaShellView: View {
    let user: User
    @Environment(AppViewModel.self) private var viewModel

    @State private var destination: AriaDestination = .chat
    @State private var isOpen = false
    @GestureState(resetTransaction: Transaction(animation: .snappy(duration: 0.3)))
    private var dragX: CGFloat = 0
    /// Cambia a ogni "Nuova chat" dalla sidebar: la chat riparte da capo (fonte, bozza, scroll).
    @State private var chatID = UUID()
    @State private var showSettings = false
    @State private var showConnection = false

    /// Da quanto vicino al bordo sinistro parte il trascinamento che apre la sidebar.
    private let edgeWidth: CGFloat = 30

    private var chat: AriaAgentChat { viewModel.mainChat }
    private var store: AriaSessionStore { viewModel.sessions }

    var body: some View {
        GeometryReader { geo in
            let width = min(geo.size.width * 0.82, 360)
            let offset = min(max((isOpen ? width : 0) + dragX, 0), width)
            let progress = offset / width

            ZStack(alignment: .leading) {
                AriaSidebar(
                    user: user,
                    destination: destination,
                    select: select,
                    openSession: openSession,
                    newChat: newChat,
                    showSettings: { showSettings = true },
                    showConnection: { showConnection = true }
                )
                .frame(width: width)
                .offset(x: (progress - 1) * 60)
                .opacity(0.3 + 0.7 * progress)

                main(progress: progress)
                    .offset(x: offset)
            }
            .simultaneousGesture(dragGesture(width: width))
        }
        .background(Color.liteSidebar.ignoresSafeArea())
        .environment(\.openSidebar) { setOpen(true) }
        .sensoryFeedback(.impact(weight: .light), trigger: isOpen)
        .task(id: viewModel.backend.isReady) { await store.load() }
        .onChange(of: isOpen) { _, open in
            // Le recenti si aggiornano a ogni apertura: una chat appena iniziata prende il suo titolo.
            if open { Task { await store.load() } }
        }
        .sheet(isPresented: $showSettings) {
            SettingsSheet(user: user, viewModel: viewModel)
        }
        .sheet(isPresented: $showConnection) {
            AriaConnectionSheet(backend: viewModel.backend)
        }
    }

    // MARK: - Pannello principale

    private func main(progress: CGFloat) -> some View {
        let shape = RoundedRectangle(cornerRadius: 44 * progress, style: .continuous)
        return content
            .overlay {
                Color.liteSurface
                    .opacity(0.45 * progress)
                    .ignoresSafeArea()
                    .allowsHitTesting(false)
            }
            // Maschera e ombra fin sotto la status bar: il pannello è tutto lo schermo.
            .mask { shape.ignoresSafeArea() }
            .background {
                shape
                    .fill(Color.liteBackground)
                    .shadow(color: .black.opacity(0.12 * progress), radius: 24, x: -4)
                    .ignoresSafeArea()
            }
            .overlay {
                // Aperta la sidebar, il pannello non si usa: un tocco lo richiude.
                if isOpen {
                    Color.clear
                        .contentShape(Rectangle())
                        .ignoresSafeArea()
                        .onTapGesture { setOpen(false) }
                }
            }
    }

    @ViewBuilder
    private var content: some View {
        switch destination {
        case .chat:
            AIChatView()
                .id(chatID)
        case .chats:
            AriaChatHistoryView(chat: chat, store: store, backend: viewModel.backend,
                                onOpen: openSession, onNewChat: newChat,
                                onConnect: { showConnection = true })
        case .overview:
            OverviewView()
        case .tasks:
            WorkOrderListView(viewModel: viewModel)
        }
    }

    // MARK: - Trascinamento

    private func dragGesture(width: CGFloat) -> some Gesture {
        DragGesture(minimumDistance: 14)
            .updating($dragX) { value, state, _ in
                guard isSidebarDrag(value) else { return }
                state = value.translation.width
            }
            .onEnded { value in
                guard isSidebarDrag(value) else { return }
                let landing = (isOpen ? width : 0) + value.predictedEndTranslation.width
                setOpen(landing > width / 2)
            }
    }

    /// Orizzontale, e — a sidebar chiusa — partito dal bordo sinistro (lo scroll resta dei contenuti).
    private func isSidebarDrag(_ value: DragGesture.Value) -> Bool {
        guard abs(value.translation.width) > abs(value.translation.height) else { return false }
        return isOpen || value.startLocation.x < edgeWidth
    }

    // MARK: - Azioni

    private func setOpen(_ open: Bool) {
        if open {
            UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
        }
        withAnimation(.snappy(duration: 0.3)) { isOpen = open }
    }

    private func select(_ target: AriaDestination) {
        destination = target
        setOpen(false)
    }

    private func openSession(_ session: AriaSessionSummary) {
        destination = .chat
        setOpen(false)
        guard session.sessionId != chat.sessionId || chat.messages.isEmpty else { return }
        Task { await chat.open(sessionId: session.sessionId) }
    }

    private func newChat() {
        chat.newConversation()
        chatID = UUID()
        destination = .chat
        setOpen(false)
    }
}

#Preview {
    AriaShellView(user: mockUsers[0])
        .environment(AppViewModel())
}
