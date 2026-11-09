//
//  AdminMobileUserStepReportsViewModel.swift
//  AriaLite
//
//  Created by Giovanni Michele on 22/10/26.
//
//  Sola lettura dei passi di un ordine di lavoro dell'operatore: per ogni passo il testo (dalla procedura),
//  il risultato, la nota, le foto e chi l'ha segnato. Report e procedura si chiedono insieme; senza la
//  procedura i passi restano con il solo numero d'ordine.
//

import Foundation
import Observation

@MainActor
@Observable
final class AdminMobileUserStepReportsViewModel {
    let backend: AriaBackend
    let order: AdminMobileUserWorkOrder

    private(set) var rows: [AdminMobileUserStepRowData] = []
    private(set) var isLoading = false
    private(set) var hasLoaded = false
    private(set) var errorMessage: String?

    init(backend: AriaBackend, order: AdminMobileUserWorkOrder) {
        self.backend = backend
        self.order = order
    }

    var progressText: String? {
        guard let progress = order.stepProgress, progress.total > 0 else { return nil }
        return String(localized: "\(progress.done) of \(progress.total) steps done")
    }

    func load() async {
        isLoading = true
        defer { isLoading = false }
        async let procedure = try? backend.api.call(AdminMobileUsersAPI.procedure(workOrderId: order.id)).steps
        do {
            let reports = try await backend.api.call(AdminMobileUsersAPI.stepReports(workOrderId: order.id)).items
            rows = Self.merge(steps: await procedure ?? [], reports: reports)
            hasLoaded = true
            errorMessage = nil
        } catch {
            _ = await procedure
            if let message = AdminMobileUserFailure.message(for: error, backend: backend) { errorMessage = message }
        }
    }

    /// I passi nell'ordine della procedura; i report di passi non più in procedura vanno in fondo.
    nonisolated static func merge(steps: [AdminMobileUserProcedureOrder.Step],
                                  reports: [AdminMobileUserStepReport]) -> [AdminMobileUserStepRowData] {
        let byStep = Dictionary(reports.map { ($0.stepId, $0) }, uniquingKeysWith: { first, _ in first })
        var out = steps.sorted { $0.number < $1.number }.map {
            AdminMobileUserStepRowData(id: $0.id, number: $0.number, text: $0.text, report: byStep[$0.id])
        }
        let known = Set(steps.map(\.id))
        out += reports.filter { !known.contains($0.stepId) }.map {
            AdminMobileUserStepRowData(id: $0.stepId, number: nil, text: nil, report: $0)
        }
        return out
    }
}
