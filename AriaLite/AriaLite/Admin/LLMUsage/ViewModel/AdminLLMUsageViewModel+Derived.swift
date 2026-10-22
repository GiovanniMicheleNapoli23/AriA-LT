//
//  AdminLLMUsageViewModel+Derived.swift
//  AriaLite
//
//  Created by Giovanni Michele on 22/10/26.
//
//  Quello che la vista mostra già pronto: giorni del grafico, quota di ogni modello nella barra,
//  testi dei totali e del listino.
//

import Foundation

/// Un punto del grafico giornaliero.
struct AdminLLMUsageChartDay: Identifiable, Equatable {
    let date: Date
    let costEur: Double
    let totalTokens: Int

    var id: Date { date }
}

extension AdminLLMUsageViewModel {
    var totals: AdminLLMUsageTotals { summary?.totals ?? .empty }

    /// I giorni con una data leggibile, in ordine di tempo.
    var chartDays: [AdminLLMUsageChartDay] {
        (summary?.byDay ?? [])
            .compactMap { day -> AdminLLMUsageChartDay? in
                guard let date = Self.date(fromBucket: day.bucket) else { return nil }
                return AdminLLMUsageChartDay(date: date, costEur: day.totals.costEur,
                                             totalTokens: day.totals.totalTokens)
            }
            .sorted { $0.date < $1.date }
    }

    /// Quota della barra di un modello: rispetto al costo più alto,
    /// o ai token se nessun modello ha un prezzo.
    func share(of model: AdminLLMUsageModel) -> Double {
        let models = summary?.byModel ?? []
        let maxCost = models.compactMap(\.costEur).max() ?? 0
        if maxCost > 0 {
            return (model.costEur ?? 0) / maxCost
        }
        let maxTokens = models.map(\.totalTokens).max() ?? 0
        return maxTokens > 0 ? Double(model.totalTokens) / Double(maxTokens) : 0
    }

    var pricingCurrency: String { pricing?.currency ?? AdminLLMUsageFormat.summaryCurrency }

    /// La data di un giorno: `AAAA-MM-GG`, o un istante ISO 8601 se il server lo manda così.
    private static func date(fromBucket bucket: String) -> Date? {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone(identifier: "UTC")
        formatter.dateFormat = "yyyy-MM-dd"
        if let date = formatter.date(from: bucket) { return date }
        return try? Date(bucket, strategy: Date.ISO8601FormatStyle())
    }
}
