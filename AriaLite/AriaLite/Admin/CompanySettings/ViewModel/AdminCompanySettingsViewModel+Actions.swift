//
//  AdminCompanySettingsViewModel+Actions.swift
//  AriaLite
//
//  Created by Giovanni Michele on 22/10/26.
//
//  Le azioni della Danger zone: si apre lo sheet di conferma, si cancella solo con il nome esatto e,
//  a cancellazione riuscita, si ricaricano gli stabilimenti.
//

import Foundation

extension AdminCompanySettingsViewModel {
    /// Apre la conferma per cancellare tutti i dati dell'azienda attiva.
    func requestCompanyDeletion() {
        guard canDeleteCompany, let id = backend.activeCompanyId, let name = companyName else { return }
        open(.company(id: id, name: name))
    }

    /// Apre la conferma per cancellare i dati di uno stabilimento.
    func requestPlantDeletion(_ plant: AriaPlant) {
        guard hasCompany else { return }
        open(.plant(id: plant.id, name: plant.name))
    }

    /// Lo sheet si è chiuso (anche dal gesto): si azzera tutto per la prossima apertura.
    func sheetDismissed() {
        target = nil
        typedName = ""
        phase = .confirming
    }

    /// Cancella davvero, solo se il nome corrisponde. Il server risponde con un riepilogo che non serve mostrare.
    func confirmDeletion() async {
        guard canConfirm, let target, let companyId = backend.activeCompanyId else { return }
        phase = .running
        let api = AdminCompanySettingsAPI(api: backend.api)
        do {
            switch target {
            case .company:
                try await api.deleteCompanyData(companyId: companyId)
            case .plant(let plantId, _):
                try await api.deletePlantData(companyId: companyId, plantId: plantId)
            }
            phase = .succeeded
            // Gli stabilimenti condivisi si richiedono al server: così l'app vede lo stato dopo la cancellazione.
            try? await backend.reloadPlants()
        } catch {
            guard let failure = AdminCompanySettingsFailure.from(error, backend: backend) else {
                phase = .confirming
                return
            }
            phase = .failed(failure.message)
        }
    }

    private func open(_ target: AdminCompanySettingsTarget) {
        self.target = target
        typedName = ""
        phase = .confirming
    }
}
