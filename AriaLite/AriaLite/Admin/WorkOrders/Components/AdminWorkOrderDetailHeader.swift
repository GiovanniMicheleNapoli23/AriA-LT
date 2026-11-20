//
//  AdminWorkOrderDetailHeader.swift
//  AriaLite
//
//  Created by Giovanni Michele on 22/10/26.
//
//  L'intestazione del dettaglio: il titolo; stato (menu con gli stati possibili), priorità e tipo come
//  pillole della stessa misura; i fatti principali (asset, assegnatario, scadenza, passi) leggibili a colpo
//  d'occhio: in una riga sola se ci stanno (iPad), altrimenti in una griglia che si adatta alla larghezza e al
//  testo (due colonne su iPhone, una con il testo molto grande). L'assistente AI sta nella toolbar.
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
            if !viewModel.headerFacts.isEmpty { factsCard }
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
            // Testo molto grande: una pillola per riga.
            VStack(alignment: .leading, spacing: 8) {
                statusButton
                otherPills
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

    /// Il pulsante in evidenza: colore dello stato, tocco = menu dei cambi di stato. Se il ruolo non ne ha nessuno
    /// resta la sola pillola, senza menu.
    @ViewBuilder
    private var statusButton: some View {
        let status = viewModel.status ?? .unknown
        let tint = status == .planned ? Color.gray : status.tint
        if viewModel.canChangeStatus {
            Menu {
                Section("Change status") {
                    AdminWorkOrderStatusMenuItems(choices: viewModel.statusChoices, onSelect: viewModel.changeStatus)
                }
            } label: {
                statusPill(status, tint: tint, showsChevron: true)
            }
            .menuIndicator(.hidden)
            .buttonStyle(.plain)
            .disabled(viewModel.isChangingStatus)
            .accessibilityLabel(Text("Status: \(status.localized)"))
            .accessibilityHint(Text("Changes the status"))
        } else {
            statusPill(status, tint: tint, showsChevron: false)
                .accessibilityElement(children: .combine)
                .accessibilityLabel(Text("Status: \(status.localized)"))
        }
    }

    private func statusPill(_ status: AdminWorkOrderStatus, tint: Color, showsChevron: Bool) -> some View {
        HStack(spacing: 6) {
            if viewModel.isChangingStatus {
                ProgressView().controlSize(.small).tint(.white)
            } else {
                Image(systemName: status.systemImage)
            }
            Text(status.localized)
            if showsChevron { Image(systemName: "chevron.down").font(.caption.weight(.bold)) }
        }
        .font(.subheadline.weight(.semibold))
        .foregroundStyle(.white)
        .padding(.horizontal, 14)
        .frame(minHeight: 34)
        .background(tint, in: Capsule())
        .fixedSize()
    }

    // MARK: Fatti

    /// Larghezza minima di una colonna della griglia: cresce con il testo, così con il testo grande le colonne
    /// diventano una.
    @ScaledMetric(relativeTo: .subheadline) private var factMinWidth: CGFloat = 120

    private var factsCard: some View {
        let facts = viewModel.headerFacts
        return ViewThatFits(in: .horizontal) {
            // iPad o iPhone in orizzontale: tutti i fatti su una riga.
            HStack(alignment: .top, spacing: 16) {
                ForEach(facts) { AdminWorkOrderHeaderFactView(fact: $0).frame(maxWidth: .infinity, alignment: .leading) }
            }
            LazyVGrid(columns: [GridItem(.adaptive(minimum: factMinWidth), spacing: 12, alignment: .topLeading)],
                      alignment: .leading, spacing: 14) {
                ForEach(facts) { AdminWorkOrderHeaderFactView(fact: $0) }
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

/// Un fatto dell'intestazione: icona in un riquadro, etichetta piccola e valore leggibile. Con il testo molto
/// grande l'icona si toglie e lascia tutta la larghezza al testo.
private struct AdminWorkOrderHeaderFactView: View {
    let fact: AdminWorkOrderHeaderFact

    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @ScaledMetric(relativeTo: .subheadline) private var iconSide: CGFloat = 32

    private var tint: Color { fact.isAlert ? .red : .liteAccent }

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            if !dynamicTypeSize.isAccessibilitySize {
                Image(systemName: fact.icon)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(fact.isPlaceholder ? Color.secondary : tint)
                    .frame(width: iconSide, height: iconSide)
                    .background((fact.isPlaceholder ? Color.secondary : tint).opacity(0.1),
                                in: RoundedRectangle(cornerRadius: 9, style: .continuous))
            }
            VStack(alignment: .leading, spacing: 2) {
                Text(fact.label)
                    .font(.caption.weight(fact.isAlert ? .semibold : .regular))
                    .foregroundStyle(fact.isAlert ? Color.red : Color.secondary)
                Text(fact.value)
                    .font(.subheadline.weight(fact.isPlaceholder ? .regular : .semibold))
                    .foregroundStyle(fact.isAlert ? Color.red : fact.isPlaceholder ? Color.secondary : Color.primary)
                    .lineLimit(dynamicTypeSize.isAccessibilitySize ? nil : 2)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 0)
        }
        .accessibilityElement(children: .combine)
    }
}
