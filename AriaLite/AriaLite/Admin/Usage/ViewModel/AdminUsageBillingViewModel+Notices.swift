//
//  AdminUsageBillingViewModel+Notices.swift
//  AriaLite
//
//  Created by Giovanni Michele on 18/11/26.
//
//  La scheda "Notice settings" (contratto 5.4). Non c'è un bottone "Save": un interruttore, una scelta o un ritorno alla
//  piattaforma salva subito, la soglia quando il campo si lascia. Il salvataggio SOSTITUISCE tutto, quindi ogni body si
//  costruisce solo con `settings.payload(applying:to:)` da una vista che contiene già le modifiche precedenti
//  (`adopting`): in coda resta l'ultimo body, una richiesta alla volta. Una soglia non valida non manda niente e blocca il
//  salvataggio finché non si corregge.
//

import Foundation

extension AdminUsageBillingViewModel {
    // MARK: Cosa mostra la scheda

    var noticeSettingsCard: AdminUsageNoticeSettingsCard? {
        guard let settings else { return nil }
        let input = AdminUsageNoticeSettingsInput(
            thresholdDrafts: thresholdDrafts, thresholdErrors: thresholdErrors, inactiveIds: inactiveIds,
            emailEnabled: backend.usage.config?.emailNotificationsEnabled == true)
        let people = page.people
        return AdminUsageNoticeSettingsBuilder.card(settings, input: input, locale: page.locale, names: { people.name(for: $0) })
    }

    /// "Not saved" mostra "Retry" solo quando riprovare può servire.
    var settingsCanRetry: Bool { !settingsRefused }

    /// Salvataggio fallito senza un motivo da correggere: "The settings were not saved. Try again.".
    var settingsSaveFailed: Bool { settingsSaver.state == .error && !settingsRefused }

    /// Il foglio "Sent to" di un avviso: ruoli e persone, con la ricerca.
    func peopleList(for notice: AriaNoticeKey, query: String) -> AdminUsageNoticePeopleList? {
        guard let recipients = noticeSettingsCard?.notices.first(where: { $0.key == notice })?.recipients else { return nil }
        let people = page.people
        return AdminUsageNoticePeopleBuilder.list(recipients: recipients, members: page.members, query: query,
                                                  locale: page.locale, nameOf: { people.name(for: $0) })
    }

    /// Le persone nominate per un avviso (quelle in vigore, anche se non sono più membri attivi: il foglio le mostra per toglierle).
    func namedPeople(of notice: AriaNoticeKey) -> [String] {
        settings?[notice].userIds.resolved ?? []
    }

    // MARK: Lettura

    func loadSettings() async {
        let stamp = currentStamp()
        if settings == nil { settingsPhase = .loading }
        do {
            let fresh = try await api.noticeSettings()
            guard isCurrent(stamp) else { return }
            // Con modifiche in volo o in attesa la vista locale è più nuova di quella del server: non la si sostituisce.
            if !settingsSaver.isBusy && thresholdErrors.isEmpty {
                settings = fresh
                intendedBody = fresh.companyOverrides
                confirmedBody = fresh.companyOverrides
            }
            settingsPhase = .loaded
        } catch {
            guard isCurrent(stamp) else { return }
            if handle(error) {
                if settings == nil { settingsPhase = .failed }
            } else if settings == nil {
                settingsPhase = .idle
            }
        }
    }

    func retrySettings() async {
        settingsPhase = .loading
        await loadSettings()
    }

    func retrySettingsSave() {
        settingsSaver.retry()
    }

    // MARK: Modifiche

    func setBanner(_ notice: AriaNoticeKey, _ isOn: Bool) { apply([(.banner(isOn), notice)]) }

    func setEmail(_ notice: AriaNoticeKey, _ isOn: Bool) {
        // Senza la consegna per email l'interruttore non si muove.
        guard backend.usage.config?.emailNotificationsEnabled == true else { return }
        apply([(.email(isOn), notice)])
    }

    /// `nil` è "Standard": l'azienda non lo fissa, torna al valore della piattaforma.
    func setRepeat(_ notice: AriaNoticeKey, _ value: AriaNoticeRepeat?) {
        let edit: AriaNoticeEdit = value.map { AriaNoticeEdit.repeatPolicy($0) } ?? .usePlatform(.repeatPolicy)
        apply([(edit, notice)])
    }

    /// Tiene o toglie un ruolo; non si manda mai una lista di ruoli vuota.
    func toggleRole(_ notice: AriaNoticeKey, _ role: String) {
        guard let rule = settings?[notice] else { return }
        var roles = AdminUsageNoticeSettingsBuilder.orderedRoles(rule.tenantRecipients.resolved ?? rule.tenantRecipients.platform ?? ["owner"])
        if roles.contains(role) { roles.removeAll { $0 == role } } else { roles.append(role) }
        guard !roles.isEmpty else { return }
        apply([(.tenantRecipients(AdminUsageNoticeSettingsBuilder.orderedRoles(roles)), notice)])
    }

    /// Una persona in più o in meno per questo avviso soltanto; senza persone tornano i ruoli.
    func togglePerson(_ notice: AriaNoticeKey, _ id: String) {
        var ids = namedPeople(of: notice)
        if ids.contains(id) { ids.removeAll { $0 == id } } else { ids.append(id) }
        apply([(.userIds(ids), notice)])
    }

    /// "Use platform value: …" dei destinatari: tornano i ruoli della piattaforma e nessuna persona.
    func usePlatformRecipients(_ notice: AriaNoticeKey) {
        apply([(.usePlatform(.tenantRecipients), notice), (.usePlatform(.userIds), notice)])
    }

    func usePlatform(_ notice: AriaNoticeKey, _ setting: AriaNoticeSetting) {
        if setting == .threshold {
            thresholdDrafts[notice] = nil
            thresholdErrors[notice] = nil
        }
        apply([(.usePlatform(setting), notice)])
    }

    /// "Use platform settings": tutto l'avviso torna alla piattaforma.
    func usePlatformSettings(_ notice: AriaNoticeKey) {
        thresholdDrafts[notice] = nil
        thresholdErrors[notice] = nil
        apply([(.usePlatformForNotice, notice)])
    }

    // MARK: Interno

    /// Applica le modifiche in ordine: ogni body nasce dalla vista che ha già le precedenti, poi si salva l'ultimo.
    func apply(_ edits: [(AriaNoticeEdit, AriaNoticeKey)]) {
        // Le sostituzioni di un'altra azienda non diventano il body di questa.
        guard ownerKey == loadKey, var view = settings else { return }
        var body = intendedBody
        for (edit, notice) in edits {
            body = view.payload(applying: edit, to: notice)
            view = view.adopting(body)
        }
        settings = view
        intendedBody = body
        editVersion += 1
        commitSettings()
    }

    /// Manda quello che si vuole, a meno che una soglia sulla scheda non sia valida: allora non parte niente e si blocca.
    func commitSettings() {
        if !thresholdErrors.isEmpty {
            settingsSaver.block(true)
            return
        }
        settingsSaver.block(false)
        guard settingsSaver.isBusy || intendedBody != confirmedBody else { return }
        settingsSaver.schedule(AdminUsageNoticeSave(body: intendedBody, version: editVersion))
    }

    // MARK: Scrittura

    /// PUT /v1/usage/notice-settings. Dopo, la risposta è la vista nuova e si rilegge il saldo (il punto ambra di Today
    /// segue l'avviso dei crediti del giorno).
    func sendSettings(_ save: AdminUsageNoticeSave) async -> Bool {
        let stamp = currentStamp()
        settingsRefused = false
        inactiveIds = []
        do {
            let answer = try await api.saveNoticeSettings(save.body)
            guard isCurrent(stamp) else { return false }
            confirmedBody = answer.companyOverrides
            // Se non c'è niente di più nuovo, il server ha l'ultima parola sulla vista.
            if save.version == editVersion {
                settings = answer
                intendedBody = answer.companyOverrides
            }
            Task { [backend] in await backend.usage.refreshAllowance() }
            return true
        } catch {
            guard isCurrent(stamp) else { return false }
            if let refusal = Self.refusal(error) {
                switch refusal.code {
                case .recipientNotActiveMember:
                    // La vista tiene la persona: si segna "Inactive" e si toglie per salvare di nuovo.
                    inactiveIds = refusal.userIds
                    settingsRefused = true
                case .noticeThresholdOutOfRange:
                    if let notice = refusal.notice {
                        thresholdErrors[notice] = .error(for: notice)
                        settingsRefused = true
                    }
                default:
                    break
                }
            } else {
                handle(error)
            }
            return false
        }
    }
}
