//
//  AdminTaskboardPersonSection.swift
//  AriaLite
//
//  Created by Giovanni Michele on 27/10/26.
//
//  Le task di una persona (o di una squadra, o di nessuno): intestazione con avatar, nome e conteggi, poi le
//  card in una griglia adattiva (una colonna su telefono, più affiancate se c'è larghezza).
//

import SwiftUI

struct AdminTaskboardPersonSection<CardView: View>: View {
    let group: AdminTaskboardPersonGroup
    @ViewBuilder var card: (AdminWorkOrderRowItem) -> CardView

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            AdminTaskboardPersonHeader(group: group)
            LazyVGrid(columns: [GridItem(.adaptive(minimum: 300), spacing: 10, alignment: .top)],
                      alignment: .leading, spacing: 10) {
                ForEach(group.items) { item in card(item) }
            }
        }
    }
}

struct AdminTaskboardPersonHeader: View {
    let group: AdminTaskboardPersonGroup

    @ScaledMetric(relativeTo: .headline) private var side: CGFloat = 36

    var body: some View {
        HStack(spacing: 10) {
            avatar
            VStack(alignment: .leading, spacing: 1) {
                Text(group.name)
                    .font(.headline)
                    .foregroundStyle(group.kind == .unassigned ? Color.secondary : Color.liteText)
                    .lineLimit(1)
                counts
            }
            Spacer(minLength: 0)
        }
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(.isHeader)
    }

    @ViewBuilder
    private var avatar: some View {
        switch group.kind {
        case .person:
            AdminMemberAvatar(initials: group.initials)
        case .team:
            icon("person.3.fill")
        case .unassigned:
            icon("person.crop.circle.badge.questionmark")
        }
    }

    private func icon(_ systemImage: String) -> some View {
        Image(systemName: systemImage)
            .font(.subheadline.weight(.semibold))
            .foregroundStyle(group.kind == .unassigned ? Color.secondary : Color.liteAccent)
            .frame(width: side, height: side)
            .background(Color.liteAccent.opacity(group.kind == .unassigned ? 0.05 : 0.12), in: Circle())
            .accessibilityHidden(true)
    }

    private var counts: some View {
        HStack(spacing: 6) {
            Text("\(group.items.count) tasks")
            if group.overdueCount > 0 {
                Text(verbatim: "·")
                Label("\(group.overdueCount) overdue", systemImage: "exclamationmark.clock.fill")
                    .labelStyle(.titleAndIcon)
                    .foregroundStyle(.red)
            }
        }
        .font(.caption)
        .foregroundStyle(.secondary)
        .monospacedDigit()
        .lineLimit(1)
    }
}
