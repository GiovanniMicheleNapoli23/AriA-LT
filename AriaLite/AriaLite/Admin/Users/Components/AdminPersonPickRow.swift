//
//  AdminPersonPickRow.swift
//  AriaLite
//
//  Created by Giovanni Michele on 12/11/26.
//
//  La riga di una persona nei selettori: iniziali, nome, riga secondaria, e a destra spunta o attesa.
//

import SwiftUI

struct AdminPersonPickRow: View {
    let name: String
    let detail: String?
    let isSelected: Bool
    var isBusy: Bool = false

    var body: some View {
        HStack(spacing: 12) {
            AdminMemberAvatar(initials: Self.initials(of: name))
            VStack(alignment: .leading, spacing: 2) {
                Text(verbatim: name)
                    .font(.body)
                    .foregroundStyle(.primary)
                if let detail, !detail.isEmpty {
                    Text(verbatim: detail)
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
            }
            Spacer(minLength: 8)
            trailing
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .contentShape(Rectangle())
    }

    @ViewBuilder
    private var trailing: some View {
        if isBusy {
            ProgressView()
        } else if isSelected {
            Image(systemName: "checkmark.circle.fill")
                .foregroundStyle(Color.liteAccent)
        } else {
            Image(systemName: "circle")
                .foregroundStyle(.tertiary)
        }
    }

    /// Le iniziali per l'avatar: due lettere dal nome (o dall'inizio dell'email), come `AdminMember.initials`.
    static func initials(of name: String) -> String {
        let words = name.split { !$0.isLetter && !$0.isNumber }
        let letters = words.count >= 2 ? words.prefix(2).compactMap(\.first) : Array(words.first?.prefix(2) ?? "?")
        return String(letters).uppercased()
    }
}
