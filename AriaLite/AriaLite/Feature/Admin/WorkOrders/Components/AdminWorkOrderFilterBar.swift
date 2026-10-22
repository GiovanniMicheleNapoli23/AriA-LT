//
//  AdminWorkOrderFilterBar.swift
//  AriaLite
//
//  Created by Giovanni Michele on 22/10/26.
//
//  La barra della lista: aperti / chiusi / tutti in un selettore a tutta larghezza; sotto "Mine" (assegnati
//  all'account collegato), il menu dei filtri (stato, priorità, tipo, assegnatario) col numero di quelli
//  attivi e il menu dell'ordinamento. Se c'è spazio (iPad, orizzontale) tutto sta su una riga; i pulsanti
//  crescono col testo dinamico e, se non ci stanno, scorrono. Tutto in Liquid Glass nativo (iOS 26):
//  segmented control di sistema e pulsanti `.glass` / `.glassProminent` in un GlassEffectContainer.
//

import SwiftUI

struct AdminWorkOrderFilterBar: View {
    let viewModel: AdminWorkOrdersViewModel

    private var filters: AdminWorkOrderFilters { viewModel.filters }

    var body: some View {
        ViewThatFits(in: .horizontal) {
            HStack(spacing: 10) {
                groupPicker.frame(maxWidth: 360)
                Spacer(minLength: 0)
                HStack(spacing: 8) { chips }
            }
            VStack(alignment: .leading, spacing: 10) {
                groupPicker
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) { chips }
                        .padding(.vertical, 1)
                }
                .scrollClipDisabled()
            }
        }
        .padding(.horizontal, 16)
    }

    // MARK: Aperti / chiusi / tutti

    /// Il segmented control di sistema. Con uno stato preciso scelto nei filtri non è selezionato nessun gruppo.
    private var groupPicker: some View {
        Picker("Show", selection: Binding<AdminWorkOrderStatusGroup?>(
            get: { filters.status == nil ? filters.statusGroup : nil },
            set: { if let group = $0 { viewModel.select(group) } }
        )) {
            ForEach(AdminWorkOrderStatusGroup.allCases, id: \.self) { group in
                Text(group.localized).tag(Optional(group))
            }
        }
        .pickerStyle(.segmented)
        .controlSize(.large)
    }

    // MARK: Pulsanti

    @ViewBuilder
    private var chips: some View {
        AriaGlassEffectContainer(spacing: 8) {
            HStack(spacing: 8) {
                if viewModel.myUserId != nil {
                    let isOn = filters.assignee == .me
                    Button { viewModel.toggleMine() } label: {
                        AdminWorkOrderChip(title: String(localized: "Mine"), icon: "person.fill", isOn: isOn)
                    }
                    .adminWorkOrderChipStyle(isOn: isOn)
                    .accessibilityAddTraits(isOn ? .isSelected : [])
                }
                filtersMenu
                sortMenu
            }
        }
    }

    // MARK: Filtri

    private var filtersTitle: String {
        filters.extraCount == 0 ? String(localized: "Filters") : String(localized: "Filters · \(filters.extraCount)")
    }

    private var filtersMenu: some View {
        Menu {
            Picker(selection: binding(\.status)) {
                Text("Any status").tag(AdminWorkOrderStatus?.none)
                ForEach(AdminWorkOrderStatus.known, id: \.self) { status in
                    Label(status.localized, systemImage: status.systemImage).tag(Optional(status))
                }
            } label: {
                Label("Status", systemImage: "circle.dashed")
            }
            .pickerStyle(.menu)
            Picker(selection: binding(\.priority)) {
                Text("Any priority").tag(AdminWorkOrderPriority?.none)
                ForEach(AdminWorkOrderPriority.known, id: \.self) { Text($0.localized).tag(Optional($0)) }
            } label: {
                Label("Priority", systemImage: "flag")
            }
            .pickerStyle(.menu)
            Picker(selection: binding(\.type)) {
                Text("Any type").tag(AdminWorkOrderType?.none)
                ForEach(AdminWorkOrderType.known, id: \.self) { Text($0.localized).tag(Optional($0)) }
            } label: {
                Label("Type", systemImage: "wrench.and.screwdriver")
            }
            .pickerStyle(.menu)
            Picker(selection: binding(\.assignee)) {
                Text("Anyone").tag(AdminWorkOrderAssigneeFilter.anyone)
                if viewModel.myUserId != nil {
                    Text("Assigned to me").tag(AdminWorkOrderAssigneeFilter.me)
                }
                ForEach(viewModel.assigneeChoices) { user in
                    Text(user.displayName).tag(AdminWorkOrderAssigneeFilter.user(user.id))
                }
            } label: {
                Label("Assignee", systemImage: "person")
            }
            .pickerStyle(.menu)
            if filters.extraCount > 0 {
                Divider()
                Button("Clear filters", systemImage: "xmark.circle", role: .destructive) { viewModel.clearFilters() }
            }
        } label: {
            AdminWorkOrderChip(title: filtersTitle, icon: "line.3.horizontal.decrease", isOn: filters.extraCount > 0,
                               showsChevron: true)
        }
        .menuIndicator(.hidden)
        .adminWorkOrderChipStyle(isOn: filters.extraCount > 0)
        .accessibilityLabel(Text(filtersTitle))
    }

    /// Un campo dei filtri: cambiarlo ricarica la lista.
    private func binding<T>(_ keyPath: WritableKeyPath<AdminWorkOrderFilters, T>) -> Binding<T> {
        Binding(
            get: { viewModel.filters[keyPath: keyPath] },
            set: { value in
                var next = viewModel.filters
                next[keyPath: keyPath] = value
                viewModel.apply(next)
            }
        )
    }

    // MARK: Ordinamento

    private var sortMenu: some View {
        Menu {
            Picker(selection: Binding(get: { viewModel.sort }, set: { viewModel.sort = $0 })) {
                ForEach(AdminWorkOrderSort.allCases) { Label($0.title, systemImage: $0.systemImage).tag($0) }
            } label: {
                Text("Sort by")
            }
            .pickerStyle(.inline)
        } label: {
            AdminWorkOrderChip(title: viewModel.sort.title, icon: "arrow.up.arrow.down", isOn: viewModel.sort != .newest,
                               showsChevron: true)
        }
        .menuIndicator(.hidden)
        .adminWorkOrderChipStyle(isOn: viewModel.sort != .newest)
        .accessibilityLabel(Text("Sort by \(viewModel.sort.title)"))
    }
}

/// L'etichetta di un pulsante della barra (e delle schede del dettaglio). Il vetro lo mette lo stile del
/// pulsante: `adminWorkOrderChipStyle(isOn:)`.
struct AdminWorkOrderChip: View {
    let title: String
    var icon: String?
    let isOn: Bool
    var showsChevron = false

    var body: some View {
        HStack(spacing: 6) {
            if let icon { Image(systemName: icon).font(.footnote.weight(.semibold)) }
            Text(title).lineLimit(1)
            if showsChevron { Image(systemName: "chevron.down").font(.caption.weight(.bold)) }
        }
        .font(.subheadline.weight(isOn ? .semibold : .medium))
        .padding(.horizontal, 4)
        .padding(.vertical, 2)
        .fixedSize()
    }
}

extension View {
    /// Vetro nativo: in evidenza (`.glassProminent` col colore dell'app) se attivo, `.glass` se no.
    /// Prima di iOS 26 il material degli helper di AriaGlass.
    @ViewBuilder
    func adminWorkOrderChipStyle(isOn: Bool) -> some View {
        if isOn {
            ariaProminentGlassButtonStyle(tint: .liteAccent)
        } else {
            ariaGlassButtonStyle().foregroundStyle(Color.liteText)
        }
    }
}
