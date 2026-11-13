//
//  AdminRoleToggleLabel.swift
//  AriaLite
//
//  Created by Giovanni Michele on 13/11/26.
//
//  Il testo di un interruttore di Roles & Rights: titolo e, sotto, "Non incluso nel tuo ruolo" quando serve.
//

import SwiftUI

struct AdminRoleToggleLabel: View {
    let title: Text
    let notInYourRole: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            title
                .font(.body)
            if notInYourRole {
                Text("Not in your role")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }
}
