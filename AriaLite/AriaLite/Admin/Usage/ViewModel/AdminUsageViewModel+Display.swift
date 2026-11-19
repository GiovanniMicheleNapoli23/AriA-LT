//
//  AdminUsageViewModel+Display.swift
//  AriaLite
//
//  Created by Giovanni Michele on 18/11/26.
//
//  I modelli già scritti che le viste disegnano, costruiti dai costruttori puri sullo stato del view model. Le viste
//  non decidono niente: leggono questi e inoltrano le azioni. Ogni modello è `nil` (o nello stato "nascosto") quando la
//  pagina non è pronta.
//

import Foundation

extension AdminUsageViewModel {
    // MARK: Intestazione e selettore

    /// "{plan} · {month} cycle" e la riga dei fatti; `nil` mentre il cruscotto si legge (resta il selettore).
    var heading: AdminUsageHeading? { facts.map(AdminUsageHeadingBuilder.build) }

    /// I cicli del selettore dalla risposta del ciclo corrente, dal più recente. Il selettore resta anche mentre un
    /// ciclo si legge o dopo un errore.
    var cycleOptions: [AdminUsageCycleOption] {
        AdminUsageHeadingBuilder.options(cycles: cycles, current: currentCycle, locale: locale)
    }

    // MARK: Pagina

    /// L'avviso in testa, se ce n'è uno. Con "Back" per un ciclo chiuso.
    var alert: AdminUsageAlert? { facts.flatMap(AdminUsageAlertBuilder.build) }

    var kpis: [AdminUsageKPI] { facts.map(AdminUsageKPIBuilder.build) ?? [] }

    /// La scheda "Included credits": Today e This week.
    var metersState: AdminUsageMetersState {
        AdminUsageMetersBuilder.state(facts, allowance: backend.usage.allowance, phase: allowancePhase, locale: locale)
    }

    var chart: AdminUsageChart? { facts.map(AdminUsageChartBuilder.build) }

    var breakdown: AdminUsageBreakdown? {
        guard let facts else { return nil }
        return AdminUsageBreakdownBuilder.build(facts, people: people)
    }

    var storageState: AdminUsageStorageState? {
        guard let facts else { return nil }
        return AdminUsageStorageBuilder.state(facts, allowance: backend.usage.allowance, phase: allowancePhase)
    }

    var liveTalkState: AdminUsageLiveTalkState {
        guard let facts else { return .hidden }
        return AdminUsageLiveTalkBuilder.state(facts, allowance: backend.usage.allowance, phase: allowancePhase)
    }

    // MARK: Titolari e membri

    /// "Billing controls": un titolare, sul ciclo corrente, con la pagina pronta. La scheda del tetto e il suo storico si
    /// aggiungono se c'è un piano assegnato (`hasPlan`).
    var showsBillingControls: Bool {
        isOwner && !isOnPastCycle && pageState == .ready && facts?.closed == false
    }

    /// Un piano è assegnato: la scheda del tetto e lo storico (e le notifiche di soglia del tetto) ci sono.
    var hasPlan: Bool { facts.map { !$0.noPlan } ?? false }

    /// La scheda "Spending limit" di un membro, al posto dei controlli di fatturazione.
    var memberLimit: AdminUsageMemberLimit? { facts.flatMap(AdminUsageMemberLimitBuilder.card) }

    /// "Amounts in EUR, the spending limit and usage notices are managed by owners.": sotto tutto, a chi non è titolare.
    var footerNote: String? { facts.flatMap(AdminUsageMemberLimitBuilder.footerNote) }

    // MARK: Nomi

    /// Chi si può nominare: i membri letti (titolare) e chi ha fatto l'accesso (`/v1/me`, via `backend.mobileAccount`).
    var people: AdminUsagePeople {
        var names: [String: String] = [:]
        for member in members {
            if let name = member.displayName { names[member.userId] = name }
        }
        let account = backend.mobileAccount
        let own = [account?.name, account?.email].lazy
            .compactMap { $0?.trimmingCharacters(in: .whitespacesAndNewlines) }
            .first { !$0.isEmpty }
        let status: AdminUsagePeople.MembersStatus
        switch membersPhase {
        case .idle: status = .notRead
        case .loading: status = .loading
        case .loaded: status = .loaded
        case .failed: status = .failed
        }
        return AdminUsagePeople(isOwner: isOwner, membersStatus: status, members: names, meID: account?.id, meName: own)
    }

    /// Il nome di una persona per id: righe di `by_user` e "Changed by" dello storico del tetto. `nil` = "AriA support".
    func personName(_ userId: String?) -> AdminUsagePersonName {
        people.name(for: userId)
    }
}
