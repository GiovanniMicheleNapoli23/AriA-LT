//
//  AdminUsageBillingDeliveryLine.swift
//  AriaLite
//
//  Created by Giovanni Michele on 18/11/26.
//
//  "Notices arrive in the app and by email." o "Notices arrive in the app. Email delivery is coming soon.": in fondo alle
//  schede dei destinatari e delle regole degli avvisi.
//

import SwiftUI

struct AdminUsageBillingDeliveryLine: View {
    let text: String
    let isEmail: Bool

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 8) {
            Image(systemName: isEmail ? "envelope" : "bell")
                .accessibilityHidden(true)
            Text(verbatim: text)
                .fixedSize(horizontal: false, vertical: true)
        }
        .font(.footnote)
        .foregroundStyle(.secondary)
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityElement(children: .combine)
    }
}
