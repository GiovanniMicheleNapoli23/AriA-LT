//
//  AdminCraftedWidgetDetailViewModel.swift
//  AriaLite
//
//  Created by Giovanni Michele on 22/10/26.
//
//  Il dettaglio di un widget salvato: riesegue il suo tool (render) per lo stabilimento attivo e
//  decide come mostrarlo (card della chat o contenuto strutturato). La ricetta resta sempre visibile.
//

import Foundation
import Observation

@MainActor
@Observable
final class AdminCraftedWidgetDetailViewModel {
    let backend: AriaBackend
    let widget: AdminCraftedWidget

    private(set) var render: AdminCraftedRender?
    private(set) var isLoading = false
    private(set) var errorMessage: String?
    private(set) var renderedAt: Date?

    init(backend: AriaBackend, widget: AdminCraftedWidget) {
        self.backend = backend
        self.widget = widget
    }

    var kindLabel: String { AdminCraftedKind.label(widget.kind) }
    var systemImage: String { AdminCraftedKind.systemImage(widget.kind) }
    var argumentFields: [AdminAssetField] { widget.argumentFields }
    var plantName: String? { backend.activePlantName }

    /// Le righe "chiave: valore" del contenuto strutturato (valori scalari in cima).
    func fields(of json: AriaJSON) -> [AdminAssetField] {
        guard let object = json.objectValue else { return [] }
        return object.sorted { $0.key < $1.key }.compactMap { key, value in
            switch value {
            case .object, .array, .null: nil
            default: AdminAssetField(title: key.replacingOccurrences(of: "_", with: " "), value: value.stringValue ?? "")
            }
        }
    }

    /// Le liste di oggetti del contenuto strutturato, ognuna come tabella semplice.
    func tables(of json: AriaJSON) -> [AdminCraftedTable] {
        switch json {
        case .array(let items):
            AdminCraftedTable(title: nil, items: items).map { [$0] } ?? []
        case .object(let object):
            object.sorted { $0.key < $1.key }.compactMap { key, value in
                AdminCraftedTable(title: key.replacingOccurrences(of: "_", with: " "), items: value.arrayValue)
            }
        default:
            []
        }
    }

    /// Gli oggetti annidati che non sono liste: si mostrano come JSON compatto.
    func nested(of json: AriaJSON) -> [AdminAssetField] {
        guard let object = json.objectValue else { return [] }
        return object.sorted { $0.key < $1.key }.compactMap { key, value in
            guard case .object = value else { return nil }
            return AdminAssetField(title: key.replacingOccurrences(of: "_", with: " "), value: value.compactDescription)
        }
    }

    /// Un percorso della web (es. /work-orders/12) dalle card: si apre nel browser, sempre filtrato.
    func webURL(for target: String) -> URL? {
        let url = URL(string: target).flatMap { $0.scheme == nil ? URL(string: target, relativeTo: backend.webURL)?.absoluteURL : $0 }
        return url.flatMap(AriaURLPolicy.external)
    }

    func load() async {
        guard let id = widget.serverId else {
            errorMessage = String(localized: "This widget has no identifier, so it can't be refreshed.")
            return
        }
        isLoading = true
        defer { isLoading = false }
        do {
            let json = try await backend.api.call(AdminCraftedAPI.render(widgetId: id, plantId: backend.activePlantId))
            guard !Task.isCancelled else { return }
            render = AdminCraftedRender.read(json, widget: widget)
            renderedAt = .now
            errorMessage = nil
        } catch {
            guard let message = AdminCraftedFailure.message(for: error, backend: backend) else { return }
            errorMessage = message
        }
    }
}

/// Una lista di oggetti da mostrare come tabella: colonne = chiavi scalari della prima riga.
struct AdminCraftedTable: Identifiable, Hashable {
    let title: String?
    let columns: [String]
    let rows: [[String]]

    var id: String { title ?? "-" }

    init?(title: String?, items: [AriaJSON]) {
        let objects = items.compactMap(\.objectValue)
        guard !objects.isEmpty else { return nil }
        let columns = objects[0].keys.sorted().filter { key in
            switch objects[0][key] {
            case .object?, .array?: false
            default: true
            }
        }
        guard !columns.isEmpty else { return nil }
        self.title = title
        self.columns = columns
        self.rows = objects.prefix(100).map { row in columns.map { row[$0]?.stringValue ?? "—" } }
    }
}
