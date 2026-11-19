//
//  AdminUsageBillingViewModel+SpendCap.swift
//  AriaLite
//
//  Created by Giovanni Michele on 18/11/26.
//
//  La scheda del limite di spesa (contratto 5.1): lettura, campo, conferma di "Lower limit", salvataggio e rimozione. Dopo
//  un salvataggio si rileggono saldo, cruscotto e storico, e per qualche secondo compare "Spending limit saved" o "…removed".
//

import Foundation

extension AdminUsageBillingViewModel {
    // MARK: Cosa mostra la scheda

    /// La scheda del limite; `nil` mentre i fatti della pagina non ci sono.
    var spendCapCard: AdminUsageSpendCapCard? {
        page.facts.map { AdminUsageSpendCapBuilder.card($0, cap: cap, phase: capPhase, saveFailed: capSaveFailed && !isFormShown) }
    }

    /// Il campo si vede: senza limite, o dopo "Change". Mai nella prova.
    var isFormShown: Bool {
        guard let cap else { return false }
        return AdminUsageSpendCapFormBuilder.isShown(cap: cap, editing: capEditing)
    }

    var spendCapForm: AdminUsageSpendCapForm? {
        guard let cap, isFormShown, let facts = page.facts else { return nil }
        let input = AdminUsageSpendCapFormInput(
            draft: capDraft, editing: capEditing, invalid: capInvalid, allowance: page.allowancePhase,
            saving: capSaving, saveFailed: capSaveFailed)
        return AdminUsageSpendCapFormBuilder.form(facts, cap: cap, input: input)
    }

    // MARK: Lettura

    func loadSpendCap() async {
        let stamp = currentStamp()
        // Con un limite in mano la rilettura è silenziosa: la scheda non torna al segnaposto.
        if cap == nil { capPhase = .loading }
        do {
            let fresh = try await api.spendCap()
            guard isCurrent(stamp) else { return }
            cap = fresh
            capPhase = .loaded
        } catch {
            guard isCurrent(stamp) else { return }
            if handle(error) {
                if cap == nil { capPhase = .failed }
            } else if cap == nil {
                capPhase = .idle
            }
        }
    }

    func retrySpendCap() async {
        capPhase = .loading
        await loadSpendCap()
    }

    /// "Retry" della frase "What this cycle has used could not be loaded…": rilegge il saldo.
    func retryAllowance() async {
        await page.retryAllowance()
    }

    // MARK: Campo

    func startEditing() {
        guard let amount = cap?.amount else { return }
        capSaveFailed = false
        capInvalid = false
        capEditing = true
        capDraft = AdminUsageSpendCapAmount.fieldText(amount)
    }

    func cancelEditing() {
        capEditing = false
        capDraft = nil
        capInvalid = false
        capSaveFailed = false
    }

    /// Si è scritto nel campo: l'errore di prima non vale più.
    func capDraftChanged(_ text: String) {
        capDraft = text
        capInvalid = false
    }

    /// "Set limit" / "Save": legge l'importo, controlla il minimo, chiede conferma se si scende sotto quanto già usato, poi manda.
    func submitSpendCap() {
        guard !capSaving, let cap, let facts = page.facts else { return }
        let text = capDraft ?? AdminUsageSpendCapFormBuilder.form(
            facts, cap: cap, input: AdminUsageSpendCapFormInput(editing: capEditing)).text
        switch AdminUsageSpendCapFormBuilder.submit(text, facts, cap: cap) {
        case .invalid:
            capInvalid = true
        case .confirm(let confirmation):
            capInvalid = false
            capConfirmation = confirmation
        case .save(let amount):
            capInvalid = false
            putSpendCap(amount)
        }
    }

    /// "Lower limit": l'utente ha confermato. Riceve la conferma dall'avviso, che la tiene finché il bottone agisce.
    func confirmLowering(_ confirmation: AdminUsageSpendCapConfirmation) {
        capConfirmation = nil
        putSpendCap(confirmation.amount)
    }

    func dismissConfirmation() {
        capConfirmation = nil
    }

    /// "Remove limit": si toglie subito, come la web (`{"amount": null}`).
    func removeSpendCap() {
        putSpendCap(nil)
    }

    // MARK: Scrittura

    /// PUT /v1/usage/spend-cap (`nil` toglie il limite). La risposta è la scheda nuova; poi si rilegge il resto.
    private func putSpendCap(_ amount: Decimal?) {
        guard !capSaving else { return }
        capSaving = true
        capSaveFailed = false
        let stamp = currentStamp()
        capTask = Task { [weak self] in
            guard let self else { return }
            do {
                let answer = try await api.saveSpendCap(amount)
                guard isCurrent(stamp) else { return }
                cap = answer
                capPhase = .loaded
                capSaving = false
                capEditing = false
                capDraft = nil
                capInvalid = false
                showToast(amount == nil
                    ? String(localized: "Spending limit removed")
                    : String(localized: "Spending limit saved"))
                await readAfterSaving()
            } catch {
                guard isCurrent(stamp) else { return }
                capSaving = false
                // I quattro rifiuti (prova, nessun piano, sempre attivo, sotto il minimo) dicono lo stesso: "The limit was not saved. Try again."
                if handle(error) { capSaveFailed = true }
            }
        }
    }

    /// Il limite sposta saldo, cruscotto e storico: si rileggono tutti e tre.
    private func readAfterSaving() async {
        async let everything: Void = page.refresh()
        async let log: Void = loadHistory()
        _ = await (everything, log)
    }

    // MARK: Messaggio

    /// Un messaggio passeggero: sta per qualche secondo e poi sparisce.
    func showToast(_ text: String) {
        toastTask?.cancel()
        toastCounter += 1
        toast = AdminUsageBillingToast(text: text, id: toastCounter)
        let id = toastCounter
        toastTask = Task { [weak self] in
            try? await Task.sleep(for: .seconds(4))
            guard !Task.isCancelled, let self, self.toast?.id == id else { return }
            self.toast = nil
        }
    }
}
