//
//  AdminUsageBillingViewModel+Threshold.swift
//  AriaLite
//
//  Created by Giovanni Michele on 18/11/26.
//
//  Il campo della soglia di un avviso (contratto 5.4): si scrive come percentuale e si salva quando il campo si lascia. Una
//  soglia non valida non manda niente e blocca il salvataggio finché non si corregge.
//

import Foundation

extension AdminUsageBillingViewModel {
    // MARK: Soglia

    /// Si sta scrivendo nel campo: non parte niente finché non si lascia.
    func thresholdChanged(_ notice: AriaNoticeKey, _ text: String) {
        thresholdDrafts[notice] = text
        thresholdErrors[notice] = nil
    }

    /// Il campo si lascia (o Invio): se è valido e cambia qualcosa si salva, altrimenti si dice perché non si può.
    func thresholdSettled(_ notice: AriaNoticeKey) {
        guard let text = thresholdDrafts[notice], let settings else { return }
        switch AdminUsageNoticeThreshold.check(text, notice: notice) {
        case .invalid(let error):
            thresholdErrors[notice] = error
            commitSettings()
        case .valid(let percent):
            thresholdErrors[notice] = nil
            thresholdDrafts[notice] = nil
            let share = percent / 100
            if (settings[notice].threshold.resolved ?? settings[notice].threshold.platform) == share {
                commitSettings()
            } else {
                apply([(.thresholdPercent(percent), notice)])
            }
        }
    }
}
