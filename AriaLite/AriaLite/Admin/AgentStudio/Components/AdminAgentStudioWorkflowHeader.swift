//
//  AdminAgentStudioWorkflowHeader.swift
//  AriaLite
//
//  Created by Giovanni Michele on 27/10/26.
//
//  L'intestazione del dettaglio, senza scheda: nome, riga di stato (pallino, run di oggi, ultimo run),
//  descrizione e, sotto, una riga di vetro con l'interruttore "Runs automatically".
//

import SwiftUI

struct AdminAgentStudioWorkflowHeader: View {
    let title: String
    let description: String?
    let statusLine: String
    let isEnabledNow: Bool
    let errorMessage: String?
    @Binding var isEnabled: Bool
    let isToggling: Bool

    @ScaledMetric(relativeTo: .subheadline) private var dot: CGFloat = 8

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            VStack(alignment: .leading, spacing: 6) {
                Text(title)
                    .font(.title2.bold())
                    .multilineTextAlignment(.leading)
                    .accessibilityAddTraits(.isHeader)
                HStack(alignment: .firstTextBaseline, spacing: 8) {
                    Circle()
                        .fill(isEnabledNow ? Color.green : Color.secondary)
                        .frame(width: dot, height: dot)
                        .accessibilityHidden(true)
                    Text(statusLine)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.leading)
                    Spacer(minLength: 0)
                }
                if let description, !description.isEmpty {
                    Text(description)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.leading)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            if let errorMessage {
                AdminSectionNotice(text: errorMessage, isError: true)
            }
            toggleRow
        }
    }

    private var toggleRow: some View {
        Toggle(isOn: $isEnabled) {
            VStack(alignment: .leading, spacing: 2) {
                Text("Runs automatically")
                    .font(.subheadline.weight(.semibold))
                Text("When on, it runs on its trigger.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .multilineTextAlignment(.leading)
        }
        .tint(Color.liteAccent)
        .disabled(isToggling)
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .ariaGlass(in: RoundedRectangle(cornerRadius: 16))
    }
}
