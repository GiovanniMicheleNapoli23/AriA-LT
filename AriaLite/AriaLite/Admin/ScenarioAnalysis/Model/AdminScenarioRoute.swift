//
//  AdminScenarioRoute.swift
//  AriaLite
//
//  Created by Giovanni Michele on 22/10/26.
//
//  Dove porta un tocco nella sezione: si naviga per id e il dettaglio rilegge la riga dal view model,
//  così una correzione fatta nel dettaglio si vede anche tornando alla lista.
//

import Foundation

nonisolated enum AdminScenarioRoute: Hashable, Sendable {
    case scenario(String)
    case review(String)
    case closure(String)
}
