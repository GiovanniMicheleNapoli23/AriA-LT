//
//  AdminWorkOrderDetailHeader.swift
//  AriaLite
//
//  Created by Giovanni Michele on 22/10/26.
//
//  L'intestazione del dettaglio: il titolo; stato (menu con gli stati possibili), priorità e tipo come
//  pillole della stessa misura; i fatti principali (asset, assegnatario, scadenza, passi) in una griglia
//  a due colonne, leggibili a colpo d'occhio. L'assistente AI sta nella toolbar.
//

import SwiftUI

struct AdminWorkOrderDetailHeader: View {
    let viewModel: AdminWorkOrderDetailViewModel

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text(viewModel.order.title)
                .font(.title2.weight(.bold))
                .fixedSize(horizontal: false, vertical: true)
                .textSelection(.enabled)
            pills
            if !facts.isEmpty { factsGrid }
        }
    }

    // MARK: Pillole

    private var pills: some View {
        ViewThatFits(in: .horizontal) {
            HStack(spacing: 8) { pillContent }
            VStack(alignment: .leading, spacing: 8) {
                statusButton
                HStack(spacing: 8) { otherPills }
            }
        }
    }

    @ViewBuilder
    private var pillContent: some View {
        statusButton
        otherPills
        Spacer(minLength: 0)
        if viewModel.isLoading || viewModel.isDeleting { ProgressView().controlSize(.small) }
    }

    @ViewBuilder
    private var otherPills: some View {
        if let priority = viewModel.priority {
            AdminWorkOrderHeaderPill(title: priority.localized, systemImage: "flag.fill",
                                     foreground: priority.tint, background: priority.tint.opacity(0.14))
        }
        if let type = viewModel.typeLabel {
            AdminWorkOrderHeaderPill(title: type, systemImage: nil,
                                     foreground: .primary, background: Color.primary.opacity(0.06))
        }
    }

    /// Il pulsante in evidenza: colore dello stato, tocco = menu dei cambi di stato.
    private var statusButton: some View {
        let status = viewModel.status ?? .unknown
        let tint = status == .planned ? Color.gray : status.tint
        return Menu {
            Section("Change status") {
                AdminWorkOrderStatusMenuItems(choices: viewModel.statusChoices, onSelect: viewModel.changeStatus)
            }
        } label: {
            HStack(spacing: 6) {
                if viewModel.isChangingStatus {
                    ProgressView().controlSize(.small).tint(.white)
                } else {
                    Image(systemName: status.systemImage)
                }
                Text(status.localized)
                Image(systemName: "chevron.down").font(.caption.weight(.bold))
            }
            .font(.subheadline.weight(.semibold))
            .foregroundStyle(.white)
            .padding(.horizontal, 14)
            .frame(minHeight: 34)
            .background(tint, in: Capsule())
            .fixedSize()
        }
        .menuIndicator(.hidden)
        .buttonStyle(.plain)
        .disabled(viewModel.isChangingStatus)
        .accessibilityLabel(Text("Status: \(status.localized)"))
        .accessibilityHint(Text("Changes the status"))
    }

    // MARK: Fatti

    private struct Fact: Identifiable {
        let id: String
        let label: String
        let value: String
        let icon: String
        var isAlert = false
    }

    private var facts: [Fact] {
        var facts: [Fact] = []
        if !viewModel.place.isEmpty {
            facts.append(Fact(id: "asset", label: String(localized: "Asset"), value: viewModel.place, icon: "gearshape.2"))
        }
        facts.append(Fact(id: "assignee", label: String(localized: "Assignee"),
                          value: viewModel.assigneeName ?? String(localized: "Unassigned"), icon: "person"))
        if let due = viewModel.dueLabel {
            facts.append(Fact(id: "due", label: String(localized: "Due"), value: due,
                              icon: viewModel.isOverdue ? "exclamationmark.clock.fill" : "clock",
                              isAlert: viewModel.isOverdue))
        }
        if let progress = viewModel.progressShort {
            facts.append(Fact(id: "steps", label: String(localized: "Steps"), value: progress, icon: "list.bullet"))
        }
        return facts
    }

    private var factsGrid: some View {
        LazyVGrid(columns: [GridItem(.flexible(), spacing: 12, alignment: .topLeading),
                            GridItem(.flexible(), spacing: 12, alignment: .topLeading)],
                  alignment: .leading, spacing: 14) {
            ForEach(facts) { fact in
                AdminWorkOrderHeaderFact(label: fact.label, value: fact.value, icon: fact.icon, isAlert: fact.isAlert)
            }
        }
        .padding(14)
        .adminWorkOrderCard()
    }
}

/// Una pillola dell'intestazione: stessa altezza del pulsante di stato.
private struct AdminWorkOrderHeaderPill: View {
    let title: String
    let systemImage: String?
    let foreground: Color
    let background: Color

    var body: some View {
        HStack(spacing: 5) {
            if let systemImage { Image(systemName: systemImage).font(.caption) }
            Text(title)
        }
        .font(.subheadline.weight(.semibold))
        .foregroundStyle(foreground)
        .padding(.horizontal, 12)
        .frame(minHeight: 34)
        .background(background, in: Capsule())
        .fixedSize()
    }
}

/// Un fatto dell'intestazione: icona in un riquadro, etichetta piccola e valore leggibile.
private struct AdminWorkOrderHeaderFact: View {
    let label: String
    let value: String
    let icon: String
    let isAlert: Bool

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: icon)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(isAlert ? Color.red : Color.liteAccent)
                .frame(width: 32, height: 32)
                .background((isAlert ? Color.red : Color.liteAccent).opacity(0.1),
                            in: RoundedRectangle(cornerRadius: 9, style: .continuous))
            VStack(alignment: .leading, spacing: 2) {
                Text(label)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Text(value)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(isAlert ? Color.red : Color.primary)
                    .lineLimit(2)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 0)
        }
        .accessibilityElement(children: .combine)
    }
}
