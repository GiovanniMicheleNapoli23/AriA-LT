//
//  AdminMarketplaceCatalog.swift
//  AriaLite
//
//  Created by Giovanni Michele on 23/10/26.
//
//  Il catalogo del Marketplace dal bundle. Esiste solo nel frontend della web (il backend ha solo i
//  connettori): scripts/export-marketplace-catalog.mjs lo esporta in MarketplaceCatalog.json, in inglese.
//  In italiano ogni testo passa da MarketplaceCatalog.it.json (inglese → italiano) prima della decodifica;
//  un testo senza traduzione resta in inglese. Id, codici e icone non si traducono, come nell'export.
//

import Foundation

nonisolated enum AdminMarketplaceCatalog {
    /// Le chiavi i cui valori non sono testo da leggere: devono restare uguali allo `SKIP` dell'export.
    private static let untranslated: Set<String> = [
        "id", "sourceId", "kind", "area", "icon", "needs", "components", "skills", "code", "connectorId",
        "frequency", "agent", "source", "custom", "preview",
    ]

    /// Il catalogo nella lingua dell'app, letto una volta.
    static let items: [AdminMarketplaceItem] = load()

    static func load(bundle: Bundle = .main, language: String? = nil) -> [AdminMarketplaceItem] {
        guard let url = bundle.url(forResource: "MarketplaceCatalog", withExtension: "json"),
              let data = try? Data(contentsOf: url),
              var root = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else { return [] }

        // L'app ha solo en e it: la lingua scelta da iOS fra quelle del bundle, non Locale.current.
        let language = language ?? bundle.preferredLocalizations.first ?? "en"
        if language.hasPrefix("it"), let map = translations(bundle: bundle, name: "MarketplaceCatalog.it") {
            root["items"] = translate(root["items"] as Any, key: nil, map: map)
        }

        guard let items = root["items"],
              let translated = try? JSONSerialization.data(withJSONObject: ["items": items]),
              let decoded = try? JSONDecoder().decode(Payload.self, from: translated) else { return [] }
        return decoded.items.items
    }

    private static func translations(bundle: Bundle, name: String) -> [String: String]? {
        guard let url = bundle.url(forResource: name, withExtension: "json"),
              let data = try? Data(contentsOf: url) else { return nil }
        return try? JSONDecoder().decode([String: String].self, from: data)
    }

    private static func translate(_ value: Any, key: String?, map: [String: String]) -> Any {
        if let key, untranslated.contains(key) { return value }
        switch value {
        case let text as String:
            return map[text] ?? text
        case let list as [Any]:
            return list.map { translate($0, key: key, map: map) }
        case let object as [String: Any]:
            return object.reduce(into: [String: Any]()) { result, entry in
                result[entry.key] = translate(entry.value, key: entry.key, map: map)
            }
        default:
            return value
        }
    }

    /// Un elemento che non si decodifica (un tipo nuovo della web) si salta, non svuota il catalogo.
    nonisolated private struct Payload: Decodable {
        let items: AriaLossyArray<AdminMarketplaceItem>
    }
}
