//
//  AdminScenarioStat.swift
//  AriaLite
//
//  Created by Giovanni Michele on 22/10/26.
//
//  Una cifra riassuntiva già pronta da mostrare in una tessera (titolo, valore formattato, icona, tono).
//

import Foundation

nonisolated struct AdminScenarioStat: Sendable, Identifiable, Hashable {
    let title: String
    let value: String
    let systemImage: String
    var tone: AdminScenarioTone = .info

    var id: String { title }
}
