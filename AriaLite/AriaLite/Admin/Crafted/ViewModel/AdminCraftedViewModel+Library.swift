//
//  AdminCraftedViewModel+Library.swift
//  AriaLite
//
//  Created by Giovanni Michele on 23/10/26.
//
//  La lista di Crafted: rapporti e artifact insieme, ricerca, categorie presenti con i conteggi, ordine per
//  data o per nome, gruppi per mese e come si presenta ogni riga (crafted-view.tsx della web).
//

import Foundation

extension AdminCraftedViewModel {
    private var query: String { searchText.trimmingCharacters(in: .whitespacesAndNewlines) }

    var isSearching: Bool { !query.isEmpty }

    /// Tutto quello che c'è, senza filtri: gli artifact del dispositivo e i rapporti del server.
    var items: [AdminCraftedItem] {
        (store?.list ?? []).map(AdminCraftedItem.artifact) + reviews.map(AdminCraftedItem.report)
    }

    /// Per la ricerca contano il titolo e, quando c'è, il codice allarme o la richiesta fatta ad Aria.
    private func matches(_ item: AdminCraftedItem, _ needle: String) -> Bool {
        let fields: [String] = switch item {
        case .report(let review): [review.displayTitle, review.alarmCode ?? ""]
        case .artifact(let artifact): [artifact.title, artifact.request]
        }
        return fields.contains { $0.localizedStandardContains(needle) }
    }

    /// La lista pronta per la vista. I chip sono solo le categorie in cui sta qualcosa — un filtro che può solo
    /// svuotare la lista è rumore — contate sulla ricerca, così dicono dove sono i risultati.
    var library: AdminCraftedLibrary {
        let all = items
        let needle = query
        let searched = needle.isEmpty ? all : all.filter { matches($0, needle) }
        let present = Set(all.map(\.category))
        let chips = AdminCraftedCategory.allCases.filter { present.contains($0) }.map { category in
            AdminCraftedCategoryChip(category: category, count: searched.filter { $0.category == category }.count)
        }
        // Una categoria svuotata (l'ultimo "non pronto" è tornato) ricade su tutto: niente filtro senza chip per toglierlo.
        let selected = chips.contains { $0.category == category } ? category : nil
        let matched = selected.map { selected in searched.filter { $0.category == selected } } ?? searched
        let sorted = sort == .name
            ? matched.sorted { $0.title.localizedStandardCompare($1.title) == .orderedAscending }
            : matched.sorted { $0.sortDate > $1.sortDate }

        var library = AdminCraftedLibrary(chips: chips, searchedCount: searched.count, selectedCategory: selected,
                                          groups: groups(of: sorted), visibleCount: sorted.count)
        library.note = sorted.isEmpty ? nil : reviewsNote
        if sorted.isEmpty { library.emptyState = emptyState(hasItems: !all.isEmpty, selected: selected) }
        return library
    }

    /// Le fasce per mese solo ordinando per data: raggruppare per mese un elenco alfabetico lo spezzerebbe.
    private func groups(of items: [AdminCraftedItem]) -> [AdminCraftedGroup] {
        guard sort == .recent else {
            return items.isEmpty ? [] : [AdminCraftedGroup(id: "all", label: nil, items: items)]
        }
        var groups: [AdminCraftedGroup] = []
        for item in items {
            let label = Self.monthLabel(item.date)
            if groups.last?.label == label {
                groups[groups.count - 1].items.append(item)
            } else {
                groups.append(AdminCraftedGroup(id: "\(groups.count)-\(label)", label: label, items: [item]))
            }
        }
        return groups
    }

    /// "ottobre 2026"; senza data "—".
    nonisolated static func monthLabel(_ date: Date?) -> String {
        date?.formatted(.dateTime.month(.wide).year()) ?? "—"
    }

    private func emptyState(hasItems: Bool, selected: AdminCraftedCategory?) -> AdminCraftedEmptyState {
        // I rapporti ancora in arrivo: non si dice "niente" a chi ne ha cinquanta.
        if backend.activeCompanyId != nil, !reviewsLoaded, reviewsNote == nil { return .loading }
        if isSearching, hasItems { return .noMatch(query: query, category: selected?.label) }
        switch reviewsNote {
        case .restricted?: return .restricted
        case .failed(let message)?: return .failed(message)
        case nil: return .empty
        }
    }

    // MARK: Righe

    /// Il rapporto o l'artifact nel suo stato di adesso.
    func rowInfo(for item: AdminCraftedItem) -> AdminCraftedRowInfo {
        let date = item.date?.formatted(date: .abbreviated, time: .omitted) ?? "—"
        switch item {
        case .report(let review):
            let verdict = review.verdict?.lowercased()
            let hasVerdict = !(verdict ?? "").isEmpty
            return AdminCraftedRowInfo(
                systemImage: AdminCraftedKind.systemImage("report"), dateText: date,
                detail: hasVerdict ? AdminCraftedVerdict.label(verdict) : nil,
                detailTint: hasVerdict ? AdminCraftedVerdict.tint(verdict) : nil, showsVerdictDot: hasVerdict,
                edited: Self.editedText(reportVersion(of: review)))
        case .artifact(let artifact):
            let generating = generator?.isGenerating(artifact.id) == true || artifact.status == .generating
            var info = AdminCraftedRowInfo(systemImage: Self.systemImage(of: artifact), isGenerating: generating, dateText: date)
            if generating {
                info.detail = String(localized: "Being made…")
            } else {
                switch artifact.status {
                case .generating: break
                case .ready: info.detail = AdminCraftedKind.label(artifact.artifacts.first?.kind ?? "document")
                case .needsChat: info.detail = String(localized: "Needs the chat")
                case .failed:
                    info.detail = String(localized: "Failed")
                    info.isError = true
                }
                info.edited = Self.editedText(artifact.versions?.last?.number)
            }
            return info
        }
    }

    private static func systemImage(of artifact: AdminCraftedArtifact) -> String {
        if let first = artifact.artifacts.first { return AdminCraftedKind.systemImage(first.kind) }
        return artifact.status == .ready ? AdminCraftedKind.systemImage("document") : "sparkles"
    }

    /// L'ultima versione di un rapporto in una lingua qualsiasi; nil se non è mai stato modificato.
    private func reportVersion(of review: AdminCraftedSessionReview) -> Int? {
        let prefix = "\(review.sessionId):\(review.episode ?? 1):"
        return reportVersions?.versionsByKey
            .filter { $0.key.hasPrefix(prefix) }
            .compactMap { $0.value.last?.number }
            .max()
    }

    private static func editedText(_ version: Int?) -> String? {
        version.map { String(localized: "Edited") + " · v\($0)" }
    }

    var storageWarning: String? {
        guard store?.saveFailed == true || reportVersions?.saveFailed == true else { return nil }
        return String(localized: "It could not be saved on this device.")
    }
}
