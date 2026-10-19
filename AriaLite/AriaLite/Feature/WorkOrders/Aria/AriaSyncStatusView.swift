//
//  AriaSyncStatusView.swift
//  AriaLite
//
//  Created by Giovanni Michele on 19/10/26.
//
//  La pillola che dice come stanno i dati dei lavori rispetto al server: offline (e quante modifiche
//  aspettano), invio in corso, modifiche in attesa (con "Invia ora"), modifiche rifiutate dal server.
//  Quando è tutto a posto non si vede.
//

import SwiftUI

struct AriaSyncStatusView: View {
    let store: AriaWorkOrderStore

    @State private var showIssues = false

    private enum Phase: Equatable {
        case hidden, issues(Int), offline(Int), syncing(Int), waiting(Int)
    }

    private var phase: Phase {
        if !store.syncIssues.isEmpty { return .issues(store.syncIssues.count) }
        if store.isOffline { return .offline(store.pendingCount) }
        if store.isSyncingChanges { return .syncing(store.pendingCount) }
        if store.pendingCount > 0 { return .waiting(store.pendingCount) }
        return .hidden
    }

    var body: some View {
        Group {
            switch phase {
            case .hidden:
                EmptyView()
            case .issues(let count):
                pill(tint: .red) {
                    Image(systemName: "exclamationmark.arrow.triangle.2.circlepath")
                } text: {
                    Text("\(count) changes couldn't be synced")
                } action: {
                    Button("Review") { showIssues = true }
                }
            case .offline(let count):
                pill(tint: .orange) {
                    Image(systemName: "wifi.slash")
                } text: {
                    if count > 0 {
                        Text("\(count) changes will sync when you're back online")
                    } else {
                        Text("Offline · showing tasks saved on this phone")
                    }
                }
            case .syncing(let count):
                pill(tint: .accentColor) {
                    ProgressView().controlSize(.mini)
                } text: {
                    Text("Syncing \(count) changes…")
                }
            case .waiting(let count):
                pill(tint: .accentColor) {
                    Image(systemName: "arrow.triangle.2.circlepath")
                } text: {
                    Text("\(count) changes waiting to sync")
                } action: {
                    Button("Sync now") { Task { await store.flush() } }
                }
            }
        }
        .animation(.snappy(duration: 0.25), value: phase)
        .sheet(isPresented: $showIssues, onDismiss: { store.dismissSyncIssues() }) {
            AriaSyncIssuesSheet(issues: store.syncIssues)
        }
    }

    private func pill<Icon: View, Label: View>(tint: Color, @ViewBuilder icon: () -> Icon, @ViewBuilder text: () -> Label,
                                               @ViewBuilder action: () -> some View = { EmptyView() }) -> some View {
        HStack(spacing: 8) {
            icon()
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(tint)
            text()
                .font(.footnote)
                .foregroundStyle(.primary.opacity(0.8))
                .lineLimit(2)
                .fixedSize(horizontal: false, vertical: true)
            action()
                .font(.footnote.weight(.semibold))
                .tint(tint)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 8)
        .ariaGlass(in: Capsule(), tint: tint.opacity(0.1))
        .frame(maxWidth: .infinity)
        .transition(.move(edge: .top).combined(with: .opacity))
        .accessibilityElement(children: .combine)
    }
}

/// Le modifiche che il server non ha accettato: cosa era stato fatto, su quale task e perché.
private struct AriaSyncIssuesSheet: View {
    let issues: [AriaWorkOrderStore.SyncIssue]
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            List {
                Section {
                    ForEach(issues) { issue in
                        VStack(alignment: .leading, spacing: 4) {
                            Text(issue.orderTitle ?? issue.orderId)
                                .font(.subheadline.weight(.semibold))
                            Text(issue.change)
                                .font(.footnote)
                                .foregroundStyle(.secondary)
                            Label(issue.message, systemImage: issue.kind == .gone ? "person.crop.circle.badge.xmark" : "xmark.octagon")
                                .font(.footnote)
                                .foregroundStyle(.red)
                                .padding(.top, 2)
                        }
                        .padding(.vertical, 2)
                    }
                } footer: {
                    Text("The server didn't accept these changes. Each task now shows what is on the server.")
                }
            }
            .navigationTitle("Not synced")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
        .presentationDetents([.medium, .large])
    }
}
