//
//  AdminPurchaseOrderLineParts.swift
//  AriaLite
//
//  Created by Giovanni Michele on 22/10/26.
//
//  I ricambi dello stabilimento dell'ordine (GET /v1/spare-parts): servono a scrivere il nome di un ricambio
//  accanto al codice nelle righe e al selettore del modulo di una riga. Si caricano una volta; se non
//  arrivano, le righe restano con il codice e il selettore con il codice libero.
//

import Foundation
import Observation

@MainActor
@Observable
final class AdminPurchaseOrderLineParts {
    private let backend: AriaBackend

    private(set) var parts: [AdminSparePart] = []
    private(set) var isLoading = false
    private(set) var hasLoaded = false
    private(set) var failureMessage: String?

    init(backend: AriaBackend) {
        self.backend = backend
    }

    func loadIfNeeded(plantId: String?) async {
        guard !hasLoaded, !isLoading else { return }
        await reload(plantId: plantId)
    }

    func reload(plantId: String?) async {
        isLoading = true
        defer { isLoading = false }
        do {
            parts = try await AdminSparePartsAPI(api: backend.api).list(plantId: plantId)
            hasLoaded = true
            failureMessage = nil
        } catch {
            if let failure = AdminPurchaseOrdersFailure.from(error, action: .read, backend: backend) {
                failureMessage = failure.message
            }
        }
    }

    /// Il ricambio di una riga: per id, altrimenti per codice (senza badare alle maiuscole).
    func part(id: String?, code: String?) -> AdminSparePart? {
        if let id, let found = parts.first(where: { $0.id == id }) { return found }
        guard let code = code?.trimmingCharacters(in: .whitespaces), !code.isEmpty else { return nil }
        return parts.first { $0.code.caseInsensitiveCompare(code) == .orderedSame }
    }

    /// I ricambi che contengono il testo nel codice, nel nome o nel codice produttore; senza testo, tutti.
    func matching(_ query: String) -> [AdminSparePart] {
        let text = query.trimmingCharacters(in: .whitespaces)
        guard !text.isEmpty else { return parts }
        return parts.filter { part in
            [part.code, part.name, part.partNumber ?? "", part.manufacturer ?? ""]
                .contains { $0.localizedStandardContains(text) }
        }
    }
}
