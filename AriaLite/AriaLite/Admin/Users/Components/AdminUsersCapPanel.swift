//
//  AdminUsersCapPanel.swift
//  AriaLite
//
//  Created by Giovanni Michele on 18/11/26.
//
//  Il pannello del tetto di utenti in cima all'elenco, solo per i titolari (§6.4): quanti utenti su quanti, la
//  nota del piano, l'avviso a tetto pieno e "Mobile operators use mobile seats…". Solo testo: nessun pulsante di
//  piano. Se la lettura è fallita: "Couldn't load your user limits." con Riprova (Add user resta acceso).
//

import SwiftUI

struct AdminUsersCapPanel: View {
    let viewModel: AdminUsersViewModel

    var body: some View {
        if viewModel.showsCapFailure {
            failure
        } else if let wording = viewModel.seatsWording {
            Section {
                summary(wording)
                if let alert = wording.alert { alertRow(alert) }
                if let noPlan = wording.noPlan {
                    Label {
                        Text(verbatim: noPlan).font(.footnote)
                    } icon: {
                        Image(systemName: "info.circle").foregroundStyle(.secondary)
                    }
                }
            } footer: {
                Text(verbatim: AdminUsersSeatsWording.mobileNote)
            }
        }
    }

    // MARK: - Pezzi

    private func summary(_ wording: AdminUsersSeatsWording) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .firstTextBaseline, spacing: 6) {
                Text(verbatim: wording.headline)
                    .font(.title.weight(.semibold))
                    .monospacedDigit()
                if let unit = wording.unit {
                    Text(verbatim: unit)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
            }
            if let caption = wording.caption {
                Text(verbatim: caption).font(.footnote).foregroundStyle(.secondary)
            }
            if let fraction = wording.fraction {
                ProgressView(value: fraction)
                    .tint(wording.alert == nil ? Color.liteAccent : Color.orange)
                    .accessibilityHidden(true)
            }
            AdminMobileUserFlowLayout(spacing: 6) {
                ForEach(wording.chips) { chip in
                    AdminMemberBadge(text: chip.text, tint: tint(chip.tone))
                }
            }
            if let billing = wording.billing {
                VStack(alignment: .leading, spacing: 2) {
                    Text(verbatim: billing.label).font(.footnote).foregroundStyle(.secondary)
                    Text(verbatim: billing.amount).font(.title3.weight(.semibold)).monospacedDigit()
                    Text(verbatim: billing.caption).font(.footnote).foregroundStyle(.secondary)
                }
                .padding(.top, 4)
            }
            if let note = wording.note {
                Text(verbatim: note).font(.footnote).foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 4)
    }

    private func alertRow(_ alert: AdminUsersSeatsWording.Alert) -> some View {
        Label {
            VStack(alignment: .leading, spacing: 4) {
                Text(verbatim: alert.title).font(.subheadline.weight(.semibold))
                Text(verbatim: alert.body).font(.footnote)
                if viewModel.addIsPausedByCap {
                    Text(verbatim: AdminUsersSeatsWording.addPausedNote)
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
            }
        } icon: {
            Image(systemName: "exclamationmark.triangle.fill").foregroundStyle(.orange)
        }
        .accessibilityElement(children: .combine)
    }

    private var failure: some View {
        Section {
            Label {
                VStack(alignment: .leading, spacing: 4) {
                    Text(verbatim: AdminUsersSeatsWording.errorTitle).font(.subheadline.weight(.semibold))
                    Text(verbatim: AdminUsersSeatsWording.errorBody).font(.footnote).foregroundStyle(.secondary)
                }
            } icon: {
                Image(systemName: "exclamationmark.circle").foregroundStyle(.secondary)
            }
            Button("Retry") { Task { await viewModel.refreshSeats() } }
        } footer: {
            Text(verbatim: AdminUsersSeatsWording.mobileNote)
        }
    }

    private func tint(_ tone: AdminUsersSeatsWording.Tone) -> Color {
        switch tone {
        case .neutral: Color.secondary
        case .warning, .critical: Color.orange
        }
    }
}
