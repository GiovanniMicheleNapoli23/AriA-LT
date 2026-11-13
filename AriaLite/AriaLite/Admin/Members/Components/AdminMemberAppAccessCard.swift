//
//  AdminMemberAppAccessCard.swift
//  AriaLite
//
//  Created by Giovanni Michele on 12/11/26.
//
//  Il blocco "Accesso all'app" della scheda, solo per owner e admin: lo stato (una riga, come la tabella del §6.4),
//  le licenze, l'esito dell'ultima email e le azioni possibili in quello stato. Le azioni che prenderebbero una
//  licenza sono spente a licenze finite. Niente rosso per gli stati: rosso solo per "Remove access".
//

import SwiftUI

struct AdminMemberAppAccessCard: View {
    let viewModel: AdminMemberDetailViewModel

    var body: some View {
        AdminCard(title: "App access", systemImage: "iphone.gen3") {
            VStack(alignment: .leading, spacing: 12) {
                status
                if let invite = viewModel.inviteLine {
                    Text(verbatim: invite).font(.footnote).foregroundStyle(.secondary)
                }
                if let availability = viewModel.availability {
                    AdminMobileUserAvailabilityLabel(availability: availability)
                }
                if let seats = viewModel.seatsText {
                    Label(seats, systemImage: "ticket")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
                if let info = viewModel.appInfo {
                    Label(info, systemImage: "checkmark.circle")
                        .font(.footnote)
                        .foregroundStyle(.green)
                }
                if let note = viewModel.seatsFullNote {
                    Text(verbatim: note).font(.caption).foregroundStyle(.orange)
                }
                if !viewModel.appOffers.isEmpty {
                    offers
                }
            }
        }
    }

    private var status: some View {
        Label {
            Text(verbatim: viewModel.appStatusText).fixedSize(horizontal: false, vertical: true)
        } icon: {
            Image(systemName: icon).foregroundStyle(tint)
        }
        .font(.subheadline)
    }

    private var offers: some View {
        VStack(spacing: 10) {
            ForEach(viewModel.appOffers, id: \.action) { offer in
                button(for: offer)
            }
        }
        .controlSize(.large)
    }

    @ViewBuilder
    private func button(for offer: AdminAppAccessOffer) -> some View {
        let action = offer.action
        let label = Label(viewModel.title(for: action), systemImage: viewModel.systemImage(for: action))
            .frame(maxWidth: .infinity)
        if viewModel.isProminent(action) {
            Button { Task { await viewModel.perform(action) } } label: { label }
                .buttonStyle(.borderedProminent)
                .tint(Color.liteAccent)
                .foregroundStyle(Color.liteOnAccent)
                .disabled(!viewModel.isEnabled(offer))
        } else if viewModel.isDestructive(action) {
            Button(role: .destructive) { Task { await viewModel.perform(action) } } label: { label }
                .buttonStyle(.bordered)
                .disabled(!viewModel.isEnabled(offer))
        } else {
            Button { Task { await viewModel.perform(action) } } label: { label }
                .buttonStyle(.bordered)
                .tint(Color.liteAccent)
                .disabled(!viewModel.isEnabled(offer))
        }
    }

    // MARK: - Aspetto dello stato

    private var state: AdminAppAccessState { viewModel.appState ?? AdminAppAccessState.none }

    private var icon: String {
        switch state {
        case .active: "checkmark.circle.fill"
        case .invited: "envelope.badge"
        case .expired: "clock.badge.exclamationmark"
        case .appSuspended, .companySuspended: "pause.circle.fill"
        case .ownerOrAdmin: "checkmark.seal"
        case .none: "iphone.slash"
        }
    }

    /// Niente rosso: verde attiva, accento invitato, arancio scaduto, grigio il resto.
    private var tint: Color {
        switch state {
        case .active: .green
        case .invited: .liteAccent
        case .expired: .orange
        case .ownerOrAdmin, .companySuspended, .none, .appSuspended: .secondary
        }
    }
}
