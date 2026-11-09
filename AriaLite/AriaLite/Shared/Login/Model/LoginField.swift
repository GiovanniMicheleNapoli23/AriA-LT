//
//  LoginField.swift
//  AriaLite
//
//  Created by Giovanni Michele on 22/10/26.
//
//  I campi del login: l'email (passo 1) e il link incollato (passo 2). Il view model dice quale
//  mettere a fuoco dopo un'azione; il fuoco vero (@FocusState) resta nella vista.
//

import Foundation

nonisolated enum LoginField: Hashable, Sendable {
    case email
    case link
}
