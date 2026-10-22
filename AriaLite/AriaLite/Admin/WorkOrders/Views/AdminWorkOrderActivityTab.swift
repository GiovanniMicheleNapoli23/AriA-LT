//
//  AdminWorkOrderActivityTab.swift
//  AriaLite
//
//  Created by Giovanni Michele on 22/10/26.
//
//  Attività di un ordine: messaggi (GET/POST /messages) e storico delle modifiche (GET /v1/audit-log).
//  Sta dentro lo ScrollView del dettaglio: niente List, il compositore è l'ultimo elemento della scheda.
//

import SwiftUI

struct AdminWorkOrderActivityTab: View {
    let viewModel: AdminWorkOrderActivityViewModel

    var body: some View {
        @Bindable var viewModel = viewModel
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 8) {
                Picker("Activity", selection: $viewModel.section) {
                    ForEach(AdminWorkOrderActivitySection.allCases) { Text($0.title).tag($0) }
                }
                .pickerStyle(.segmented)
                AdminWorkOrderActivityRefreshButton(isLoading: viewModel.isLoading) {
                    Task { await viewModel.load() }
                }
            }
            if let message = viewModel.errorMessage { AdminWorkOrderActivityError(message: message) }
            switch viewModel.section {
            case .messages:
                AdminWorkOrderMessageThread(rows: viewModel.messageRows, isLoading: !viewModel.hasLoaded)
                AdminWorkOrderMessageComposer(text: $viewModel.draft, isSending: viewModel.isSending,
                                              canSend: viewModel.canSend) {
                    Task { await viewModel.send() }
                }
            case .history:
                AdminWorkOrderAuditTimeline(rows: viewModel.historyRows, isLoading: !viewModel.hasLoaded,
                                            hasMore: viewModel.hasMoreHistory, isLoadingMore: viewModel.isLoadingMore) {
                    Task { await viewModel.loadMoreHistory() }
                }
            }
        }
        .task { await viewModel.load() }
    }
}

// MARK: Messaggi

struct AdminWorkOrderMessageThread: View {
    let rows: [AdminWorkOrderMessageRowItem]
    let isLoading: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            if rows.isEmpty {
                if isLoading {
                    ProgressView().frame(maxWidth: .infinity).padding(.vertical, 12)
                } else {
                    Label("No messages yet.", systemImage: "bubble.left.and.bubble.right")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
            }
            ForEach(rows) { AdminWorkOrderMessageBubble(row: $0) }
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .ariaGlass(in: RoundedRectangle(cornerRadius: 16))
    }
}

struct AdminWorkOrderMessageBubble: View {
    let row: AdminWorkOrderMessageRowItem

    var body: some View {
        VStack(alignment: row.isMine ? .trailing : .leading, spacing: 3) {
            HStack(spacing: 6) {
                Text(row.author).font(.caption.weight(.semibold))
                if let time = row.time { Text(time).font(.caption2).foregroundStyle(.secondary) }
            }
            Text(row.text)
                .font(.subheadline)
                .fixedSize(horizontal: false, vertical: true)
                .textSelection(.enabled)
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(row.isMine ? Color.accentColor.opacity(0.18) : Color.secondary.opacity(0.12),
                            in: RoundedRectangle(cornerRadius: 14))
        }
        .frame(maxWidth: .infinity, alignment: row.isMine ? .trailing : .leading)
        .padding(row.isMine ? .leading : .trailing, 32)
        .accessibilityElement(children: .combine)
    }
}

struct AdminWorkOrderMessageComposer: View {
    @Binding var text: String
    let isSending: Bool
    let canSend: Bool
    let send: () -> Void

    var body: some View {
        HStack(alignment: .bottom, spacing: 8) {
            TextField("Write a message…", text: $text, axis: .vertical)
                .lineLimit(1...5)
                .font(.subheadline)
                .padding(.horizontal, 12)
                .padding(.vertical, 9)
                .ariaGlass(in: RoundedRectangle(cornerRadius: 18))
            Button(action: send) {
                if isSending {
                    ProgressView().frame(width: 32, height: 32)
                } else {
                    Image(systemName: "arrow.up.circle.fill")
                        .font(.title)
                        .foregroundStyle(canSend ? Color.accentColor : Color.secondary.opacity(0.5))
                }
            }
            .disabled(!canSend)
            .accessibilityLabel("Send")
        }
    }
}

// MARK: Storico

struct AdminWorkOrderAuditTimeline: View {
    let rows: [AdminWorkOrderAuditRowItem]
    let isLoading: Bool
    let hasMore: Bool
    let isLoadingMore: Bool
    let loadMore: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            if rows.isEmpty {
                if isLoading {
                    ProgressView().frame(maxWidth: .infinity).padding(.vertical, 12)
                } else {
                    Label("No changes recorded yet.", systemImage: "clock.arrow.circlepath")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
            }
            ForEach(Array(rows.enumerated()), id: \.element.id) { index, row in
                AdminWorkOrderAuditRow(row: row, isLast: index == rows.count - 1 && !hasMore)
            }
            if hasMore {
                Button(action: loadMore) {
                    if isLoadingMore { ProgressView() } else { Text("Load more") }
                }
                .font(.subheadline.weight(.medium))
                .frame(maxWidth: .infinity)
                .padding(.top, 8)
                .disabled(isLoadingMore)
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .ariaGlass(in: RoundedRectangle(cornerRadius: 16))
    }
}

struct AdminWorkOrderAuditRow: View {
    let row: AdminWorkOrderAuditRowItem
    let isLast: Bool

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            // Il pallino con la linea verso la voce successiva.
            VStack(spacing: 2) {
                Image(systemName: row.icon)
                    .font(.body)
                    .foregroundStyle(Color.accentColor)
                if !isLast {
                    Rectangle().fill(Color.secondary.opacity(0.25)).frame(width: 1.5).frame(maxHeight: .infinity)
                }
            }
            VStack(alignment: .leading, spacing: 4) {
                HStack(alignment: .firstTextBaseline, spacing: 6) {
                    Text(row.title).font(.subheadline.weight(.semibold))
                    Text(row.who).font(.caption).foregroundStyle(.secondary).lineLimit(1)
                    Spacer(minLength: 4)
                    if let time = row.time { Text(time).font(.caption2).foregroundStyle(.secondary) }
                }
                ForEach(row.changes) { change in
                    AdminWorkOrderAuditChangeLine(change: change)
                }
                if let note = row.note {
                    Text(note).font(.caption).foregroundStyle(.secondary).lineLimit(4)
                }
            }
            .padding(.bottom, isLast ? 0 : 12)
        }
        .accessibilityElement(children: .combine)
    }
}

struct AdminWorkOrderAuditChangeLine: View {
    let change: AdminWorkOrderAuditChangeItem

    var body: some View {
        (Text(verbatim: "\(change.field): ").foregroundStyle(.secondary)
            + oldValue
            + Text(verbatim: change.new).foregroundStyle(.primary))
            .font(.caption)
            .lineLimit(3)
    }

    private var oldValue: Text {
        guard let old = change.old else { return Text(verbatim: "") }
        return Text(verbatim: old).strikethrough().foregroundStyle(.secondary) + Text(verbatim: " → ").foregroundStyle(.secondary)
    }
}

// MARK: Comuni

struct AdminWorkOrderActivityRefreshButton: View {
    let isLoading: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            if isLoading {
                ProgressView().controlSize(.small).frame(width: 28, height: 28)
            } else {
                Image(systemName: "arrow.clockwise").frame(width: 28, height: 28)
            }
        }
        .disabled(isLoading)
        .accessibilityLabel("Refresh")
    }
}

struct AdminWorkOrderActivityError: View {
    let message: String

    var body: some View {
        Label(message, systemImage: "exclamationmark.triangle.fill")
            .font(.subheadline)
            .foregroundStyle(.orange)
            .padding(12)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color.orange.opacity(0.1), in: RoundedRectangle(cornerRadius: 14))
    }
}
