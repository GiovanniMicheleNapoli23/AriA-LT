//
//  AriaWorkOrdersView.swift
//  AriaLite
//
//  Created by Giovanni Michele on 08/10/26.
//
//  Task dell'account Aria: gli ordini di lavoro assegnati all'operatore
//  (il dettaglio e l'esecuzione dei passi sono in AriaWorkOrderDetailView).
//  "Today" (aperti da fare oggi o in ritardo),
//  "Upcoming" (aperti con scadenza futura) e "Past" (chiusi, raggruppati per giorno).
//

import SwiftUI
import UIKit

struct AriaWorkOrdersView: View {
    let store: AriaWorkOrderStore

    @State private var viewModel: AriaWorkOrdersViewModel
    @State private var path: [AriaWorkOrder] = []

    init(store: AriaWorkOrderStore) {
        self.store = store
        _viewModel = State(initialValue: AriaWorkOrdersViewModel(store: store))
    }

    var body: some View {
        NavigationStack(path: $path) {
            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    AriaSyncStatusView(store: store)
                        .padding(.top, 8)
                        .padding(.horizontal, 16)
                    errorPill
                    content
                }
                .ariaReadableWidth()
            }
            .refreshable { await store.refresh() }
            .liteBackground()
            .navigationTitle("Tasks")
            .navigationDestination(for: AriaWorkOrder.self) { order in
                AriaWorkOrderDetailView(order: order, store: store)
            }
            .toolbar {
                ToolbarItem(placement: .topBarLeading) { AriaSidebarButton() }
            }
            .searchable(text: $viewModel.searchText, prompt: Text("Search tasks..."))
        }
        .task(id: store.openRequest) { await openRequested() }
        // La copia locale si legge al primo uso: qui, se non l'ha già chiesta la sincronizzazione.
        .onAppear {
            store.restoreIfNeeded()
            viewModel.rebuildSections()
        }
        .onChange(of: store.listRevision) { _, _ in viewModel.rebuildSections() }
        // Passata la mezzanotte, "oggi" è un altro giorno.
        .onReceive(NotificationCenter.default.publisher(for: UIApplication.significantTimeChangeNotification)) { _ in
            viewModel.rebuildSections()
        }
    }

    /// Lavoro toccato in una notifica: si apre il dettaglio aggiornato. Se l'ordine non è più
    /// dell'operatore (`gone`) o la rete manca, resta la lista.
    private func openRequested() async {
        guard let id = store.openRequest else { return }
        store.openRequest = nil
        guard path.last?.id != id else { return }
        guard case .found(let order)? = await store.detail(of: id) else { return }
        path = [order]
    }

    // MARK: Contenuto

    @ViewBuilder
    private var content: some View {
        if !store.hasLoaded {
            if store.isOffline {
                // Mai scaricata e senza rete: non c'è una copia da mostrare.
                ContentUnavailableView("You're offline", systemImage: "wifi.slash",
                                       description: Text("Tasks appear here once the phone has been online at least once."))
                    .padding(.top, 40)
            } else if store.isLoading {
                ProgressView()
                    .frame(maxWidth: .infinity)
                    .padding(.top, 60)
            } else if let message = store.errorMessage {
                // Mai arrivata la lista: non si dice "nessun task", si dice che non si è riusciti a caricarla.
                VStack(spacing: 14) {
                    ContentUnavailableView("Can't load tasks", systemImage: "wifi.exclamationmark",
                                           description: Text(message))
                    Button {
                        Task { await store.refresh() }
                    } label: {
                        Label("Retry", systemImage: "arrow.clockwise")
                    }
                    .ariaGlassButtonStyle()
                }
                .padding(.top, 40)
            }
        } else if viewModel.hasNoSearchResults {
            ContentUnavailableView.search(text: viewModel.appliedText)
        } else {
            scheduled
        }
    }

    private var scheduled: some View {
        let sections = viewModel.sections
        return VStack(alignment: .leading, spacing: 0) {

            // MARK: - Today
            sectionHeader(
                title: String(localized: "Today"),
                subtitle: countSubtitle(sections.today.count),
                icon: "calendar",
                color: Color.liteAccent
            )
            .padding(.top, 12)

            if sections.today.isEmpty {
                emptyState(icon: "tray", message: String(localized: "No tasks for today"))
            } else {
                rows(sections.today)
                    .padding(.bottom, 8)
            }

            // MARK: - Upcoming
            if !sections.upcoming.isEmpty {
                sectionHeader(
                    title: String(localized: "Upcoming"),
                    subtitle: countSubtitle(sections.upcoming.count),
                    icon: "calendar.badge.clock",
                    color: .secondary
                )
                .padding(.top, 12)
                rows(sections.upcoming)
                    .padding(.bottom, 8)
            }

            // MARK: - Past
            if !sections.pastByDay.isEmpty {
                sectionHeader(
                    title: String(localized: "Past"),
                    subtitle: String(localized: "\(sections.closedCount) archived tasks"),
                    icon: "clock.arrow.circlepath",
                    color: .secondary
                )
                .padding(.top, 12)

                // Fino a 200 chiusi: le righe si costruiscono mentre scorrono.
                LazyVStack(alignment: .leading, spacing: 0) {
                    ForEach(sections.pastByDay) { item in
                        VStack(alignment: .leading, spacing: 0) {
                            Text(item.day.formatted(date: .abbreviated, time: .omitted))
                                .font(.caption)
                                .fontWeight(.semibold)
                                .foregroundStyle(.secondary)
                                .textCase(.uppercase)
                                .padding(.horizontal, 20)
                                .padding(.top, 16)
                                .padding(.bottom, 6)
                            rows(item.orders, isPast: true)
                        }
                    }
                }
                .padding(.bottom, 24)
            }

            if let updated = store.lastUpdated {
                Text("Updated \(updated.formatted(date: .omitted, time: .shortened))")
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
                    .frame(maxWidth: .infinity)
                    .padding(.bottom, 24)
            }
        }
    }

    /// I chiusi (fino a 200) in uno stack pigro; oggi e in arrivo sono pochi e restano in uno normale.
    @ViewBuilder
    private func rows(_ orders: [AriaWorkOrder], isPast: Bool = false) -> some View {
        if isPast {
            LazyVStack(spacing: 8) { rowLinks(orders, isPast: true) }
        } else {
            VStack(spacing: 8) { rowLinks(orders, isPast: false) }
        }
    }

    private func rowLinks(_ orders: [AriaWorkOrder], isPast: Bool) -> some View {
        ForEach(orders) { order in
            NavigationLink(value: order) {
                AriaWorkOrderRow(order: order)
                    .opacity(isPast ? 0.6 : 1)
            }
            .buttonStyle(.plain)
            .padding(.horizontal, 20)
        }
    }

    // MARK: Helpers

    private func countSubtitle(_ count: Int) -> String {
        count == 0 ? String(localized: "No scheduled tasks") : String(localized: "\(count) scheduled tasks")
    }

    @ViewBuilder
    private func sectionHeader(title: String, subtitle: String, icon: String, color: Color) -> some View {
        HStack(spacing: 10) {
            Image(systemName: icon)
                .font(.subheadline.bold())
                .foregroundStyle(color)

            VStack(alignment: .leading, spacing: 1) {
                Text(title)
                    .font(.headline)

                Text(subtitle)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()
        }
        .padding(.horizontal, 20)
        .padding(.bottom, 10)
    }

    @ViewBuilder
    private func emptyState(icon: String, message: String) -> some View {
        HStack(spacing: 10) {
            Image(systemName: icon)
                .foregroundStyle(.tertiary)

            Text(message)
                .font(.subheadline)
                .foregroundStyle(.tertiary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 20)
        .padding(.vertical, 12)
        .padding(.bottom, 8)
    }

    /// Lista già a schermo ma l'ultimo aggiornamento è fallito: una riga sottile, senza il testo dell'errore.
    @ViewBuilder
    private var errorPill: some View {
        if store.hasLoaded, store.errorMessage != nil, !store.isOffline {
            HStack(spacing: 8) {
                Image(systemName: "wifi.exclamationmark").foregroundStyle(.orange)
                Text("Couldn't refresh")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                Button("Retry") { Task { await store.refresh() } }
                    .font(.footnote.weight(.semibold))
                    .disabled(store.isLoading)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 8)
            .ariaGlass(in: Capsule())
            .frame(maxWidth: .infinity)
            .padding(.top, 8)
        }
    }
}

// MARK: - Riga

/// Scheda della task: titolo, riga di dettaglio, valore a destra e barra in fondo.
/// Qui il valore è la priorità e la barra è l'avanzamento dei passi (quelli con un risultato su quelli totali).
struct AriaWorkOrderRow: View {
    let order: AriaWorkOrder

    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    private var progress: Double {
        if ["completed", "verified"].contains(order.status) { return 1 }
        if let steps = order.progress, steps.total > 0 { return steps.fraction }
        return order.status == "in_progress" ? 0.5 : 0
    }

    private var priorityColor: Color {
        switch order.priorityLevel {
        case .high: .red
        case .medium: .orange
        case .low: .green
        case nil: .secondary
        }
    }

    private var detailLine: String {
        ([order.statusLabel, order.assetTag, order.zone].compactMap { $0 }.filter { !$0.isEmpty }).joined(separator: " · ")
    }

    var body: some View {
        // Testo molto grande: priorità e scadenza vanno sotto il titolo, che altrimenti si spezza a metà parola.
        let isAX = dynamicTypeSize.isAccessibilitySize
        let header = isAX
            ? AnyLayout(VStackLayout(alignment: .leading, spacing: 6))
            : AnyLayout(HStackLayout(alignment: .top))
        VStack(alignment: .leading, spacing: 10) {
            header {
                VStack(alignment: .leading, spacing: 4) {
                    Text(order.title)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.primary)
                        .multilineTextAlignment(.leading)
                    Text(detailLine)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(isAX ? 3 : 1)
                }
                if !isAX { Spacer() }
                VStack(alignment: isAX ? .leading : .trailing, spacing: 3) {
                    if let level = order.priorityLevel {
                        Text(level.localized)
                            .font(.caption.weight(.bold))
                            .foregroundStyle(priorityColor)
                    }
                    if let due = order.dueDate, !order.isClosed {
                        Text(due.formatted(.dateTime.month(.abbreviated).day().hour().minute()))
                            .font(.caption2)
                            .foregroundStyle(order.isOverdue ? Color.red : Color.secondary)
                    }
                }
            }

            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule()
                        .fill(Color.liteAccent.opacity(0.12))
                        .frame(height: 4)
                    Capsule()
                        .fill(progress >= 1 ? Color.green : Color.liteAccent)
                        .frame(width: geo.size.width * progress, height: 4)
                }
            }
            .frame(height: 4)
        }
        .padding(.vertical, 14)
        .padding(.horizontal, 16)
        .ariaGlass(in: RoundedRectangle(cornerRadius: 16))
    }
}

struct AriaPriorityBadge: View {
    let level: AriaWorkOrderPriority

    private var color: Color {
        switch level {
        case .high: .red
        case .medium: .orange
        case .low: .green
        }
    }

    var body: some View {
        Text(level.localized)
            .font(.caption2.weight(.bold))
            .foregroundStyle(color)
            .padding(.horizontal, 8)
            .padding(.vertical, 3)
            .background(color.opacity(0.14), in: Capsule())
    }
}
