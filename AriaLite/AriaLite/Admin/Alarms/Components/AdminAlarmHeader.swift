//
//  AdminAlarmHeader.swift
//  AriaLite
//
//  Created by Giovanni Michele on 22/10/26.
//
//  L'intestazione del dettaglio: la descrizione come titolo e, su una riga sotto, lo stato e il codice.
//  Sotto, i fatti principali (asset, zona, categoria, pagina HMI) in una
//  griglia con la fiducia dell'estrazione, e in fondo le date.
//

import SwiftUI

struct AdminAlarmHeader: View {
    let viewModel: AdminAlarmDetailViewModel

    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    private var alarm: AdminAlarm { viewModel.alarm }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            VStack(alignment: .leading, spacing: 8) {
                title
                metaLine
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            let facts = viewModel.facts
            if !facts.isEmpty || viewModel.confidenceFraction != nil {
                factsCard(facts)
            }
            if let line = viewModel.timestampLine {
                Text(verbatim: line)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }

    /// Stato e codice su una riga; uno sotto l'altro solo se non ci stanno (testo molto grande).
    private var metaLine: some View {
        ViewThatFits(in: .horizontal) {
            HStack(spacing: 8) { AdminAlarmStatusBadge(alarm: alarm); codeText }
            VStack(alignment: .leading, spacing: 6) { AdminAlarmStatusBadge(alarm: alarm); codeText }
        }
    }

    private var codeText: some View {
        Text("Code \(alarm.code)")
            .font(.subheadline)
            .foregroundStyle(.secondary)
            .textSelection(.enabled)
    }

    @ViewBuilder
    private var title: some View {
        if alarm.description.isEmpty {
            Text("No description")
                .font(.title2.weight(.semibold))
                .foregroundStyle(.secondary)
        } else {
            Text(verbatim: alarm.description)
                .font(.title2.weight(.bold))
                .fixedSize(horizontal: false, vertical: true)
                .textSelection(.enabled)
        }
    }

    // MARK: Fatti

    private func factsCard(_ facts: [AdminAlarmFact]) -> some View {
        // Due colonne; una sola col testo molto grande.
        let columns = Array(repeating: GridItem(.flexible(), spacing: 12, alignment: .topLeading),
                            count: dynamicTypeSize.isAccessibilitySize ? 1 : 2)
        return VStack(alignment: .leading, spacing: 14) {
            if !facts.isEmpty {
                LazyVGrid(columns: columns, alignment: .leading, spacing: 14) {
                    ForEach(facts) { AdminAlarmFactTile(fact: $0) }
                }
            }
            if let confidence = viewModel.confidenceFraction {
                if !facts.isEmpty { Divider() }
                AdminAlarmConfidenceMeter(title: "Extraction confidence", fraction: confidence)
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .ariaGlass(in: RoundedRectangle(cornerRadius: 16))
    }
}
