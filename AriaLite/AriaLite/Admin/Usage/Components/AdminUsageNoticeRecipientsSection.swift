//
//  AdminUsageNoticeRecipientsSection.swift
//  AriaLite
//
//  Created by Giovanni Michele on 18/11/26.
//
//  La scheda "Usage notices" (contratto 5.3): chi è sempre avvisato ("Owners"), chi si avvisa in più con un tasto per
//  toglierlo, "Add a member" (un foglio con ricerca) e come arrivano gli avvisi. Non c'è "Save": ogni modifica salva da sola e
//  l'intestazione dice "Saving…", "Saved" o "Not saved" con "Retry".
//

import SwiftUI

struct AdminUsageNoticeRecipientsSection: View {
    let billing: AdminUsageBillingViewModel

    @State private var picking = false

    var body: some View {
        let card = billing.recipientsCard
        AdminUsageCardFrame(title: Text(verbatim: card.title), description: Text(verbatim: card.description)) {
            switch billing.recipientsPhase {
            case .idle, .loading:
                ProgressView()
                    .frame(maxWidth: .infinity, minHeight: 80)
                    .accessibilityLabel("Loading notice recipients")
            case .failed:
                VStack(alignment: .leading, spacing: 10) {
                    AdminUsageBillingAlertBox(text: String(localized: "Recipients could not be loaded. Notices still reach owners."))
                    Button("Retry") { Task { await billing.retryMembers() } }
                        .buttonStyle(.bordered)
                        .tint(Color.liteAccent)
                }
            case .loaded:
                loaded(card)
            }
        }
        .sheet(isPresented: $picking) { AdminUsageRecipientPickerSheet(billing: billing) }
    }

    private func loaded(_ card: AdminUsageNoticeRecipientsCard) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            AdminUsageBillingSaveStatus(state: billing.recipientsSaver.state, canRetry: billing.recipientsCanRetry) {
                billing.retryRecipients()
            }
            group(title: card.alwaysTitle, hint: card.alwaysHint) {
                ForEach(card.always) { person in
                    AdminUsageNoticePersonRow(name: person.name, role: person.role, inactive: nil, removeLabel: nil, onRemove: nil)
                }
            }
            group(title: card.alsoTitle, hint: card.alsoHint) {
                if card.also.isEmpty {
                    Text(verbatim: card.alsoEmpty).font(.subheadline).foregroundStyle(.secondary)
                }
                ForEach(card.also) { person in
                    AdminUsageNoticePersonRow(name: person.name, role: person.role, inactive: person.inactiveChip,
                                              removeLabel: person.removeLabel) { billing.removeRecipient(person.id) }
                }
                Button { picking = true } label: { Label { Text(verbatim: card.addLabel) } icon: { Image(systemName: "plus") } }
                    .buttonStyle(.bordered)
                    .tint(Color.liteAccent)
            }
            ForEach(card.inactiveNotes, id: \.self) { AdminUsageBillingAlertBox(text: $0) }
            if billing.recipientsSaveFailed {
                AdminUsageBillingAlertBox(text: String(localized: "The recipients were not saved. Try again."))
            }
            AdminUsageBillingDeliveryLine(text: card.delivery, isEmail: card.deliveryIsEmail)
        }
    }

    private func group<Content: View>(title: String, hint: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            VStack(alignment: .leading, spacing: 2) {
                Text(verbatim: title).font(.subheadline.weight(.semibold))
                Text(verbatim: hint).font(.footnote).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
            }
            .accessibilityElement(children: .combine)
            content()
        }
    }
}

/// Una persona nell'elenco: il nome, il ruolo (e "Inactive" se non è più un membro attivo) e, per chi si è aggiunto, il tasto per toglierla.
struct AdminUsageNoticePersonRow: View {
    let name: String
    let role: String
    let inactive: String?
    let removeLabel: String?
    let onRemove: (() -> Void)?

    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    var body: some View {
        HStack(alignment: .center, spacing: 8) {
            let layout = dynamicTypeSize.isAccessibilitySize
                ? AnyLayout(VStackLayout(alignment: .leading, spacing: 4))
                : AnyLayout(HStackLayout(alignment: .firstTextBaseline, spacing: 8))
            layout {
                Text(verbatim: name).font(.body).foregroundStyle(inactive == nil ? Color.primary : Color.secondary)
                    .fixedSize(horizontal: false, vertical: true)
                if !dynamicTypeSize.isAccessibilitySize { Spacer(minLength: 4) }
                HStack(spacing: 6) {
                    if let inactive { AdminUsageBillingChip(text: inactive, tone: .over) }
                    AdminUsageBillingChip(text: role)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .accessibilityElement(children: .combine)
            if let onRemove, let removeLabel {
                Button(action: onRemove) { Image(systemName: "xmark").font(.footnote.weight(.semibold)) }
                    .buttonStyle(.bordered)
                    .buttonBorderShape(.circle)
                    .tint(Color.secondary)
                    .frame(minWidth: 44, minHeight: 44)
                    .accessibilityLabel(removeLabel)
            }
        }
        .padding(.vertical, 4)
    }
}
