//
//  AdminAgentStudioNotificationsView.swift
//  AriaLite
//
//  Created by Giovanni Michele on 22/10/26.
//
//  Le notifiche di Agent Studio in un foglio: tutte o solo non lette, "segna come letta" (tocco o swipe)
//  e "segna tutte". Toccarne una che porta a un'approvazione o a un run la apre.
//

import SwiftUI

struct AdminAgentStudioNotificationsView: View {
    @Bindable var viewModel: AdminAgentStudioViewModel
    let onOpen: (AdminAgentStudioRoute) -> Void

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            content
                .navigationTitle("Notifications")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("Done") { dismiss() }
                    }
                    ToolbarItem(placement: .topBarTrailing) {
                        Menu("Options", systemImage: "ellipsis.circle") {
                            Toggle("Unread only", isOn: $viewModel.showsUnreadOnly)
                            Button("Mark all as read", systemImage: "checkmark.circle") {
                                Task { await viewModel.markAllRead() }
                            }
                            .disabled(viewModel.unreadCount == 0)
                        }
                    }
                }
                .refreshable { await viewModel.load() }
                .alert("Agent Studio", isPresented: $viewModel.showsActionError) {
                    Button("OK") {}
                } message: {
                    Text(viewModel.actionError ?? "")
                }
        }
    }

    @ViewBuilder
    private var content: some View {
        if viewModel.visibleNotifications.isEmpty {
            if let message = viewModel.notificationsError {
                ContentUnavailableView("Can't load notifications", systemImage: "exclamationmark.triangle",
                                       description: Text(message))
            } else if !viewModel.hasLoaded {
                ProgressView()
            } else {
                if viewModel.showsUnreadOnly {
                    ContentUnavailableView("All caught up", systemImage: "bell.slash",
                                           description: Text("Run results and approval requests show up here."))
                } else {
                    ContentUnavailableView("No notifications", systemImage: "bell.slash",
                                           description: Text("Run results and approval requests show up here."))
                }
            }
        } else {
            List(viewModel.visibleNotifications) { notification in
                Button {
                    Task { await viewModel.markRead(notification) }
                    if let route = viewModel.route(for: notification) { onOpen(route) }
                } label: {
                    AdminAgentStudioNotificationRow(notification: notification)
                }
                .buttonStyle(.plain)
                .swipeActions(edge: .trailing) {
                    if !notification.isRead {
                        Button("Mark as read", systemImage: "envelope.open") {
                            Task { await viewModel.markRead(notification) }
                        }
                        .tint(Color.liteAccent)
                    }
                }
            }
            .listStyle(.plain)
        }
    }
}
