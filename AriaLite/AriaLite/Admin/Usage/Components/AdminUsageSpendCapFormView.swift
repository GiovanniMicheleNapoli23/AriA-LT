//
//  AdminUsageSpendCapFormView.swift
//  AriaLite
//
//  Created by Giovanni Michele on 18/11/26.
//
//  Il campo "Limit per cycle (EUR)": cifre con al più due decimali, "Set limit" o "Save" (che aspetta il saldo), la frase
//  "= {credits} credits at {price} per credit" mentre si cambia un limite, e gli errori. Il testo lo tiene il view model.
//

import SwiftUI

struct AdminUsageSpendCapFormView: View {
    let form: AdminUsageSpendCapForm
    let billing: AdminUsageBillingViewModel
    var focus: FocusState<AdminUsageBillingField?>.Binding

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(verbatim: form.label).font(.subheadline.weight(.semibold))
            TextField(text: Binding(get: { form.text }, set: { billing.capDraftChanged($0) })) {
                Text(verbatim: form.label)
            }
            .keyboardType(.decimalPad)
            .font(.body.monospacedDigit())
            .focused(focus, equals: .limit)
            .textFieldStyle(.roundedBorder)
            .accessibilityIdentifier("usage.limit.field")
            if let invalid = form.invalidText {
                Text(verbatim: invalid).font(.footnote).foregroundStyle(Color.liteDanger)
                    .fixedSize(horizontal: false, vertical: true)
            }
            if let preview = form.preview {
                Text(verbatim: preview).font(.footnote.monospacedDigit()).foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            if let help = form.help {
                Text(verbatim: help).font(.footnote).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
            }
            if let usedError = form.usedError { AdminUsageBillingAlertBox(text: usedError) }
            if let saveError = form.saveError { AdminUsageBillingAlertBox(text: saveError) }
            actions
        }
    }

    private var actions: some View {
        ViewThatFits(in: .horizontal) {
            HStack(spacing: 8) { Spacer(minLength: 0); buttons }
            VStack(alignment: .leading, spacing: 8) { buttons }
        }
    }

    @ViewBuilder
    private var buttons: some View {
        if form.usedError != nil {
            Button("Retry") { Task { await billing.retryAllowance() } }
                .buttonStyle(.bordered)
                .tint(Color.liteAccent)
        }
        if form.showsCancel {
            Button("Cancel") { focus.wrappedValue = nil; billing.cancelEditing() }
                .buttonStyle(.bordered)
                .tint(Color.liteAccent)
        }
        Button { focus.wrappedValue = nil; billing.submitSpendCap() } label: { Text(verbatim: form.saveTitle) }
            .buttonStyle(.borderedProminent)
            .tint(Color.liteAccent)
            .foregroundStyle(Color.liteOnAccent)
            .disabled(!form.saveEnabled)
    }
}
