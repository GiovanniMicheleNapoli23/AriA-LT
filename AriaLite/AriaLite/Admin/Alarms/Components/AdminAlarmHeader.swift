//
//  AdminAlarmHeader.swift
//  AriaLite
//
//  Created by Giovanni Michele on 22/10/26.
//
//  L'intestazione del dettaglio, come quella di un asset: icona, codice e stato, la descrizione come titolo;
//  sotto, i fatti principali (asset, zona, categoria, pagina HMI) in una griglia con la fiducia
//  dell'estrazione, e in fondo le date.
//

import SwiftUI

struct AdminAlarmHeader: View {
    let viewModel: AdminAlarmDetailViewModel

    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @ScaledMetric(relativeTo: .body) private var iconSide: CGFloat = 52

    private var alarm: AdminAlarm { viewModel.alarm }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .top, spacing: 14) {
                if !dynamicTypeSize.isAccessibilitySize { icon }
                VStack(alignment: .leading, spacing: 6) {
                    codeLine
                    title
                }
                Spacer(minLength: 0)
            }
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

    private var icon: some View {
        Image(systemName: "bell.badge")
            .font(.title2.weight(.semibold))
            .foregroundStyle(Color.liteAccent)
            .frame(width: iconSide, height: iconSide)
            .background(Color.liteAccent.opacity(0.08),
                        in: RoundedRectangle(cornerRadius: iconSide * 0.28, style: .continuous))
            .accessibilityHidden(true)
    }

    private var codeLine: some View {
        ViewThatFits(in: .horizontal) {
            HStack(spacing: 8) { codeText; AdminAlarmStatusBadge(alarm: alarm) }
            VStack(alignment: .leading, spacing: 6) { codeText; AdminAlarmStatusBadge(alarm: alarm) }
        }
    }

    private var codeText: some View {
        Text(verbatim: alarm.code)
            .font(.subheadline.weight(.bold).monospaced())
            .foregroundStyle(Color.liteAccent)
            .textSelection(.enabled)
    }

    @ViewBuilder
    private var title: some View {
        if alarm.description.isEmpty {
            Text("No description")
                .font(.title3.weight(.semibold))
                .foregroundStyle(.secondary)
        } else {
            Text(verbatim: alarm.description)
                .font(.title3.weight(.bold))
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
