//
//  AdminCategoriesViewModel+Actions.swift
//  AriaLite
//
//  Created by Giovanni Michele on 22/10/26.
//
//  Le azioni della sezione Categories: nuova, modifica, eliminazione (dopo conferma) e gli aggiornamenti
//  dell'elenco dopo un salvataggio.
//

import Foundation

extension AdminCategoriesViewModel {
    /// Senza queste azioni il ruolo guarda soltanto l'elenco: niente "+", modifica ed elimina.
    var canCreate: Bool { backend.rights.can(.create, in: .categories) }
    var canEdit: Bool { backend.rights.can(.edit, in: .categories) }
    var canDelete: Bool { backend.rights.can(.delete, in: .categories) }

    func startCreating() {
        guard canCreate else { return }
        form = AdminCategoryFormViewModel(mode: .create, owner: self)
    }

    func startEditing(_ category: AdminCategory) {
        guard canEdit else { return }
        form = AdminCategoryFormViewModel(mode: .edit(category), owner: self)
    }

    func askDelete(_ category: AdminCategory) {
        guard canDelete else { return }
        pendingDelete = category
    }

    /// Elimina dopo la conferma. Un 404 vuol dire che non c'era già più: si toglie comunque dall'elenco.
    func confirmDelete() async {
        guard canDelete, let category = pendingDelete, !isDeleting else { return }
        pendingDelete = nil
        isDeleting = true
        defer { isDeleting = false }
        do {
            try await AdminCategoriesAPI(api: backend.api).delete(id: category.id)
        } catch {
            guard let failure = AdminCategoriesFailure.from(error, action: .write, backend: backend) else { return }
            guard failure.isNotFound else {
                deleteError = failure.message
                return
            }
        }
        didDelete(id: category.id)
    }

    /// Una categoria creata entra nell'elenco.
    func didCreate(_ category: AdminCategory) {
        categories.append(category)
    }

    /// Una categoria modificata o riletta si aggiorna dov'è.
    func didSave(_ category: AdminCategory) {
        if let index = categories.firstIndex(where: { $0.id == category.id }) {
            categories[index] = category
        } else {
            categories.append(category)
        }
    }

    func didDelete(id: String) {
        categories.removeAll { $0.id == id }
        // L'ultimo del suo tipo se n'è andato: il filtro non ha più niente da mostrare.
        if let entityFilter, !categories.contains(where: { $0.entityType == entityFilter }) {
            self.entityFilter = nil
        }
    }
}
