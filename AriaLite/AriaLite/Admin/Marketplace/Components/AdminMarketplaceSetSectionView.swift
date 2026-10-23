//
//  AdminMarketplaceSetSectionView.swift
//  AriaLite
//
//  Created by Giovanni Michele on 23/10/26.
//
//  Il contenuto di una sezione di un full set (regole, fatti, glossario, procedure, allarmi, piani, ricambi, checklist, documenti, policy), una riga o una voce ripiegabile per voce.
//

import SwiftUI

struct AdminMarketplaceSetSectionView: View {
    let viewModel: AdminMarketplaceItemDetailViewModel
    let section: AdminMarketplaceSetSection

    @ScaledMetric(relativeTo: .body) private var termColumn: CGFloat = 260

    var body: some View {
        if let info = viewModel.fullSetInfo {
            content(info)
        }
    }

    @ViewBuilder
    private func content(_ info: AdminMarketplaceItem.FullSetInfo) -> some View {
        switch section {
        case .rules:
            AdminMarketplaceNumberedList(items: info.rules)
        case .facts:
            column {
                ForEach(Array(info.facts.enumerated()), id: \.offset) { _, fact in
                    Text(verbatim: fact).font(.subheadline)
                }
            }
        case .glossary:
            LazyVGrid(columns: [GridItem(.adaptive(minimum: termColumn), alignment: .top)],
                      alignment: .leading, spacing: 10) {
                ForEach(Array(info.glossary.enumerated()), id: \.offset) { _, entry in
                    VStack(alignment: .leading, spacing: 2) {
                        Text(verbatim: entry.term).font(.subheadline.weight(.semibold))
                        Text(verbatim: entry.definition).font(.subheadline).foregroundStyle(.secondary)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
        case .procedures:
            column {
                ForEach(Array(info.procedures.enumerated()), id: \.offset) { _, procedure in
                    AdminMarketplaceSetFold(title: procedure.title, meta: viewModel.stepsMeta(procedure.steps.count)) {
                        AdminMarketplaceNumberedList(items: procedure.steps)
                    }
                }
            }
        case .learned:
            column {
                ForEach(Array(info.learned.enumerated()), id: \.offset) { _, fact in
                    VStack(alignment: .leading, spacing: 2) {
                        Text(verbatim: fact.content).font(.subheadline)
                        Text(verbatim: viewModel.learnedCaption(fact)).font(.footnote).foregroundStyle(.secondary)
                    }
                }
            }
        case .alarms:
            column {
                ForEach(Array(info.alarms.enumerated()), id: \.offset) { _, alarm in
                    AdminMarketplaceSetFold(code: alarm.code, title: alarm.description, meta: alarm.category) {
                        alarmDetail(alarm)
                    }
                }
            }
        case .maintenancePlans:
            column {
                ForEach(Array(info.maintenancePlans.enumerated()), id: \.offset) { _, plan in
                    AdminMarketplaceSetFold(title: plan.name, meta: plan.frequencyLabel) {
                        AdminMarketplaceNumberedList(items: plan.steps)
                    }
                }
            }
        case .spareParts:
            column {
                ForEach(Array(info.spareParts.enumerated()), id: \.offset) { _, part in
                    HStack(alignment: .firstTextBaseline, spacing: 8) {
                        AdminMarketplaceCodeBadge(code: part.code)
                        Text(verbatim: part.name)
                            .font(.subheadline)
                            .frame(maxWidth: .infinity, alignment: .leading)
                        Text(verbatim: viewModel.categoryLabel(part.category))
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }
                }
            }
        case .checklists:
            column {
                ForEach(Array(info.checklists.enumerated()), id: \.offset) { _, checklist in
                    AdminMarketplaceSetFold(title: checklist.name, meta: viewModel.tasksMeta(checklist.tasks.count)) {
                        VStack(alignment: .leading, spacing: 6) {
                            ForEach(Array(checklist.tasks.enumerated()), id: \.offset) { _, task in
                                HStack(alignment: .firstTextBaseline, spacing: 8) {
                                    Image(systemName: "square")
                                        .font(.footnote)
                                        .foregroundStyle(.secondary)
                                        .accessibilityHidden(true)
                                    Text(verbatim: task)
                                        .font(.subheadline)
                                        .frame(maxWidth: .infinity, alignment: .leading)
                                }
                            }
                        }
                    }
                }
            }
        case .documents:
            column {
                ForEach(Array(info.documents.enumerated()), id: \.offset) { _, document in
                    HStack(alignment: .firstTextBaseline, spacing: 8) {
                        Image(systemName: "doc.text")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                            .accessibilityHidden(true)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(verbatim: document.title).font(.subheadline.weight(.semibold))
                            Text(verbatim: document.note).font(.footnote).foregroundStyle(.secondary)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                    }
                }
            }
        case .policies:
            column {
                ForEach(Array(info.policies.enumerated()), id: \.offset) { _, policy in
                    VStack(alignment: .leading, spacing: 2) {
                        Text(verbatim: policy.label)
                            .font(.caption.weight(.semibold))
                            .textCase(.uppercase)
                            .foregroundStyle(.secondary)
                        Text(verbatim: policy.text).font(.subheadline)
                    }
                }
            }
        }
    }

    /// Le voci una sotto l'altra, tutte a larghezza piena.
    private func column<Rows: View>(@ViewBuilder _ rows: () -> Rows) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            rows()
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    /// Cause e risoluzione affiancate se c'è posto, altrimenti una sotto l'altra.
    private func alarmDetail(_ alarm: AdminMarketplaceItem.FullSetInfo.Alarm) -> some View {
        ViewThatFits(in: .horizontal) {
            HStack(alignment: .top, spacing: 16) {
                causes(alarm)
                resolution(alarm)
            }
            VStack(alignment: .leading, spacing: 14) {
                causes(alarm)
                resolution(alarm)
            }
        }
    }

    private func causes(_ alarm: AdminMarketplaceItem.FullSetInfo.Alarm) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Typical causes").font(.caption.weight(.semibold)).textCase(.uppercase).foregroundStyle(.secondary)
            AdminMarketplaceBulletList(items: alarm.typicalCauses)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func resolution(_ alarm: AdminMarketplaceItem.FullSetInfo.Alarm) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Resolution").font(.caption.weight(.semibold)).textCase(.uppercase).foregroundStyle(.secondary)
            AdminMarketplaceNumberedList(items: alarm.resolutionSteps)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}
