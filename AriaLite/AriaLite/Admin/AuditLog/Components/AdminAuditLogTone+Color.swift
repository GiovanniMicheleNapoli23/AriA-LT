//
//  AdminAuditLogTone+Color.swift
//  AriaLite
//
//  Created by Giovanni Michele on 22/10/26.
//
//  Il colore di un'azione nello storico: verde per le creazioni, rosso per le rimozioni,
//  il blu dell'app per le modifiche.
//

import SwiftUI

extension AdminAuditLogTone {
    var color: Color {
        switch self {
        case .added: .green
        case .removed: .red
        case .changed: Color.liteAccent
        case .neutral: .secondary
        }
    }
}
