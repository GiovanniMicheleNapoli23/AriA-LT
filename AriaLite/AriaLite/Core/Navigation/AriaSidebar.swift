//
//  AriaSidebar.swift
//  AriaLite
//
//  Created by Giovanni Michele on 26/09/26.
//
//  La sidebar di AriaPLT Mobile: sezioni in alto, conversazioni fissate e recenti,
//  profilo e "Nuova chat" in fondo. L'operatore ha Task e Calendario; un account della piattaforma
//  le sezioni della web, raggruppate come nella sidebar della web.
//

import SwiftUI

struct AriaSidebar: View {
    let user: User
    let destination: AriaDestination
    let select: (AriaDestination) -> Void
    let openSession: (AriaSessionSummary) -> Void
    let newChat: () -> Void
    let showSettings: () -> Void
    let showConnection: () -> Void

    @Environment(AppViewModel.self) private var viewModel
    @State private var renaming: AriaSessionSummary?
    /// L'avatar (52pt a testo "Large") cresce con l'iniziale.
    @ScaledMetric(relativeTo: .title3) private var avatarSide: CGFloat = 52

    private var store: AriaSessionStore { viewModel.sessions }
    private var chat: AriaAgentChat { viewModel.mainChat }

    /// Quantità di recenti in sidebar: il resto sta nella schermata Chat.
    private static let recentsLimit = 20

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 2) {
                AriaWordmark(size: 28)
                    .padding(.horizontal, 12)
                    .padding(.top, 8)
                    .padding(.bottom, 22)

                navRow("Chats", icon: "bubble.left.and.bubble.right", target: .chats)
                switch viewModel.accountKind {
                case .operator:
                    navRow("Tasks", icon: "checklist", target: .tasks)
                    navRow("Calendar", icon: "calendar", target: .calendar)
                case .admin:
                    sectionTitle("Operations")
                    navRow("Work Orders", icon: "wrench.and.screwdriver", target: .adminWorkOrders)
                    sectionTitle("Resources")
                    navRow("Assets", icon: "gearshape.2", target: .assets)
                    navRow("Spare Parts", icon: "shippingbox", target: .spareParts)
                }

                if !store.pinned.isEmpty {
                    sectionTitle("Pinned")
                    ForEach(store.pinned) { sessionRow($0) }
                }

                sectionTitle("Recents")
                recents
            }
            .padding(.horizontal, 12)
            // Spazio per la barra in fondo (profilo + Nuova chat).
            .padding(.bottom, 96)
        }
        .scrollIndicators(.hidden)
        .overlay(alignment: .bottom) { bottomBar }
        .modifier(AriaRenameSessionAlert(session: $renaming, store: store))
    }

    // MARK: - Sezioni

    private func navRow(_ title: LocalizedStringKey, icon: String, target: AriaDestination) -> some View {
        Button { select(target) } label: {
            SidebarRowLabel(title: Text(title), icon: icon, isSelected: destination == target, prominent: true)
        }
        .buttonStyle(.plain)
    }

    private func sectionTitle(_ title: LocalizedStringKey) -> some View {
        Text(title)
            .font(.subheadline.weight(.medium))
            .foregroundStyle(.secondary)
            .padding(.horizontal, 16)
            .padding(.top, 22)
            .padding(.bottom, 6)
    }

    // MARK: - Conversazioni

    @ViewBuilder
    private var recents: some View {
        if !viewModel.backend.isReady {
            Button(action: showConnection) {
                SidebarRowLabel(title: Text("Connect to Aria server"), icon: "bolt.horizontal.circle")
            }
            .buttonStyle(.plain)
        } else if store.isLoading && store.visible.isEmpty {
            ProgressView()
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
        } else if store.recents.isEmpty {
            Text(store.error ?? String(localized: "No conversations"))
                .font(.subheadline)
                .foregroundStyle(.tertiary)
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
        } else {
            ForEach(store.recents.prefix(Self.recentsLimit)) { sessionRow($0) }
            if store.recents.count > Self.recentsLimit {
                Button { select(.chats) } label: {
                    Text("All chats")
                        .font(.subheadline.weight(.medium))
                        .foregroundStyle(Color.liteAccent)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 10)
                }
                .buttonStyle(.plain)
            }
        }
    }

    private func sessionRow(_ session: AriaSessionSummary) -> some View {
        let isCurrent = destination == .chat && session.sessionId == chat.sessionId && !chat.messages.isEmpty
        return Button { openSession(session) } label: {
            SidebarRowLabel(title: Text(session.displayTitle), icon: "bubble.left", isSelected: isCurrent,
                            showsActivity: isCurrent && chat.isStreaming)
        }
        .buttonStyle(.plain)
        .ariaSessionMenu(session, store: store, chat: chat) { renaming = session }
    }

    // MARK: - Profilo + Nuova chat

    private var bottomBar: some View {
        HStack(spacing: 12) {
            Button(action: showSettings) {
                Text(user.name.prefix(1))
                    .font(.system(.title3, design: .rounded, weight: .semibold))
                    .foregroundStyle(Color.liteAccent)
                    .frame(width: avatarSide, height: avatarSide)
                    .ariaGlass(in: Circle(), interactive: true)
            }
            .buttonStyle(.plain)
            .accessibilityLabel(Text("Settings"))

            Spacer()

            Button(action: newChat) {
                // Coi testi grandi la sidebar non ha posto per l'etichetta: resta il "+".
                ViewThatFits(in: .horizontal) {
                    Label("New chat", systemImage: "plus")
                    Label("New chat", systemImage: "plus").labelStyle(.iconOnly)
                }
                .font(.headline)
                .foregroundStyle(.white)
                .padding(.horizontal, 22)
                .padding(.vertical, 8)
                .frame(minHeight: 52)
                .background(Color.liteAccent, in: Capsule())
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 20)
        .padding(.top, 24)
        .padding(.bottom, 8)
        .background {
            // Le righe sfumano sotto la barra invece di tagliarsi di netto.
            LinearGradient(colors: [Color.liteSidebar.opacity(0), Color.liteSidebar], startPoint: .top, endPoint: .center)
                .ignoresSafeArea()
                .allowsHitTesting(false)
        }
    }
}

// MARK: - Riga

private struct SidebarRowLabel: View {
    let title: Text
    let icon: String
    var isSelected = false
    var prominent = false
    var showsActivity = false
    @ScaledMetric(relativeTo: .body) private var iconWidth: CGFloat = 28

    var body: some View {
        HStack(spacing: 16) {
            Image(systemName: icon)
                .font(prominent ? .title3 : .body)
                .frame(width: iconWidth)
            title
                .font(.body)
                .lineLimit(1)
            Spacer(minLength: 8)
            if showsActivity {
                ProgressView().controlSize(.small)
            }
        }
        .foregroundStyle(Color.liteText)
        .padding(.horizontal, 16)
        // 54/48pt a testo "Large"; coi testi grandi la riga cresce quanto il titolo.
        .padding(.vertical, 8)
        .frame(minHeight: prominent ? 54 : 48)
        .background {
            if isSelected {
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(Color.liteAccent.opacity(0.07))
            }
        }
        .contentShape(Rectangle())
    }
}

// MARK: - Azioni su una conversazione (sidebar e schermata Chat)

extension AriaSessionSummary {
    var displayTitle: String {
        title?.isEmpty == false ? title! : String(localized: "Untitled conversation")
    }
}

extension View {
    /// Fissa / Rinomina / Elimina, a pressione lunga.
    func ariaSessionMenu(_ session: AriaSessionSummary, store: AriaSessionStore, chat: AriaAgentChat,
                         rename: @escaping () -> Void) -> some View {
        contextMenu {
            Button(store.isPinned(session) ? "Unpin" : "Pin",
                   systemImage: store.isPinned(session) ? "pin.slash" : "pin") {
                store.togglePin(session)
            }
            Button("Rename", systemImage: "pencil", action: rename)
            Button("Delete", systemImage: "trash", role: .destructive) {
                Task { await store.delete(session, closing: chat) }
            }
        }
    }
}

struct AriaRenameSessionAlert: ViewModifier {
    @Binding var session: AriaSessionSummary?
    let store: AriaSessionStore
    @State private var title = ""

    func body(content: Content) -> some View {
        content
            .alert("Rename conversation", isPresented: Binding(get: { session != nil }, set: { if !$0 { session = nil } })) {
                TextField("Title", text: $title)
                Button("Cancel", role: .cancel) {}
                Button("Save") {
                    if let session { Task { await store.rename(session, to: title) } }
                }
            }
            .onChange(of: session) { title = session?.title ?? "" }
    }
}
