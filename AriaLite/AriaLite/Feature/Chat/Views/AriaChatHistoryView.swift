//
//  AriaChatHistoryView.swift
//  AriaLite
//
//  Created by Giovanni Michele on 25/09/26.
//
//  La sezione "Chat" della sidebar (chat-history-sheet della web): conversazioni
//  raggruppate per data, cerca per titolo, fissa, rinomina, elimina, apri.
//  La logica sta in AriaChatHistoryViewModel.
//

import SwiftUI

struct AriaChatHistoryView: View {
    let onOpen: (AriaSessionSummary) -> Void
    let onNewChat: () -> Void
    let onConnect: () -> Void

    @State private var model: AriaChatHistoryViewModel

    /// Chat, archivio e backend sono quelli dell'app (gli stessi per tutta la vita della schermata):
    /// il view model nasce una volta sola con loro.
    init(chat: AriaAgentChat, store: AriaSessionStore, backend: AriaBackend,
         onOpen: @escaping (AriaSessionSummary) -> Void, onNewChat: @escaping () -> Void, onConnect: @escaping () -> Void) {
        _model = State(initialValue: AriaChatHistoryViewModel(chat: chat, store: store, backend: backend))
        self.onOpen = onOpen
        self.onNewChat = onNewChat
        self.onConnect = onConnect
    }

    var body: some View {
        NavigationStack {
            List {
                ForEach(model.groups) { group in
                    Section(title(group.period)) {
                        ForEach(group.sessions) { session in
                            AriaChatHistoryRow(model: model, session: session) { onOpen(session) }
                        }
                    }
                }
                if model.canLoadMore {
                    Button("Load more") { Task { await model.loadMore() } }
                        .disabled(model.isLoading)
                }
            }
            .listStyle(.plain)
            .scrollContentBackground(.hidden)
            .liteBackground()
            .overlay { placeholder }
            .searchable(text: $model.query, prompt: "Search conversations")
            .refreshable { await model.load() }
            .navigationTitle("Chats")
            .toolbar {
                ToolbarItem(placement: .topBarLeading) { AriaSidebarButton() }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("New chat", systemImage: "square.and.pencil", action: onNewChat)
                }
            }
            .task { await model.load() }
            .modifier(AriaRenameSessionAlert(session: $model.renaming, store: model.store))
        }
    }

    private func title(_ period: AriaChatHistoryViewModel.Period) -> LocalizedStringKey {
        switch period {
        case .today: "Today"
        case .yesterday: "Yesterday"
        case .lastWeek: "Last week"
        case .older: "Older"
        }
    }

    @ViewBuilder
    private var placeholder: some View {
        switch model.placeholder {
        case .notConnected:
            ContentUnavailableView {
                Label("Not connected", systemImage: "bolt.horizontal.circle")
            } description: {
                Text("Connect to the Aria server to see your conversations.")
            } actions: {
                Button("Connect", action: onConnect)
                    .buttonStyle(.borderedProminent)
                    .tint(Color.liteAccent)
                    .foregroundStyle(Color.liteOnAccent)
            }
        case .loading:
            ProgressView()
        case .failed(let error):
            ContentUnavailableView("Couldn't load conversations", systemImage: "exclamationmark.triangle", description: Text(error))
        case .empty:
            ContentUnavailableView("No conversations", systemImage: "bubble.left.and.bubble.right")
        case .noResults(let query):
            ContentUnavailableView.search(text: query)
        case nil:
            EmptyView()
        }
    }
}

/// Una conversazione: tocco = apri, menu e scorrimento = fissa, rinomina, elimina.
private struct AriaChatHistoryRow: View {
    let model: AriaChatHistoryViewModel
    let session: AriaSessionSummary
    var onOpen: () -> Void
    /// La colonna dell'icona cresce con il testo (Dynamic Type).
    @ScaledMetric(relativeTo: .callout) private var iconWidth: CGFloat = 22

    var body: some View {
        Button(action: onOpen) {
            HStack(alignment: .firstTextBaseline, spacing: 14) {
                Image(systemName: model.isPinned(session) ? "pin" : "bubble.left")
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .frame(width: iconWidth)
                VStack(alignment: .leading, spacing: 3) {
                    Text(session.displayTitle)
                        .font(.callout.weight(model.isCurrent(session) ? .semibold : .regular))
                        .foregroundStyle(.primary)
                        .lineLimit(2)
                    if let date = session.lastActivity {
                        Text(date, format: .relative(presentation: .named))
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .padding(.vertical, 4)
        }
        .listRowBackground(Color.clear)
        .ariaSessionMenu(session, store: model.store, chat: model.chat) { model.rename(session) }
        .swipeActions {
            Button("Delete", systemImage: "trash", role: .destructive) {
                Task { await model.delete(session) }
            }
            Button("Rename", systemImage: "pencil") { model.rename(session) }
                .tint(.orange)
        }
    }
}
