//
//  AdminCraftedReportLanguage.swift
//  AriaLite
//
//  Created by Giovanni Michele on 23/10/26.
//
//  Le lingue in cui si può leggere un rapporto d'intervento (LOCALES della web): il backend scrive il
//  documento nella lingua chiesta, che non è quella dell'app. Ogni lingua ha le sue versioni.
//

import Foundation

nonisolated struct AdminCraftedReportLanguage: Identifiable, Hashable, Sendable {
    let code: String
    /// Come la lingua chiama sé stessa: chi legge tedesco non deve cercare "German".
    let native: String

    var id: String { code }

    static let all: [AdminCraftedReportLanguage] = [
        ("en", "English"), ("it", "Italiano"), ("es", "Español"), ("fr", "Français"), ("de", "Deutsch"),
        ("pt", "Português"), ("nl", "Nederlands"), ("pl", "Polski"), ("cs", "Čeština"), ("ro", "Română"),
        ("el", "Ελληνικά"), ("sv", "Svenska"), ("uk", "Українська"), ("ru", "Русский"), ("tr", "Türkçe"),
        ("pt-BR", "Português (Brasil)"), ("zh-CN", "简体中文"), ("ja", "日本語"), ("ko", "한국어"),
        ("hi", "हिन्दी"), ("id", "Bahasa Indonesia"), ("vi", "Tiếng Việt"), ("sw", "Kiswahili")
    ].map { AdminCraftedReportLanguage(code: $0.0, native: $0.1) }

    static func native(_ code: String) -> String {
        all.first { $0.code == code }?.native ?? code
    }
}
