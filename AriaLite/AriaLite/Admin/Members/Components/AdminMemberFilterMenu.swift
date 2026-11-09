//
//  AdminMemberFilterMenu.swift
//  AriaLite
//
//  Created by Giovanni Michele on 22/10/26.
//
//  Un filtro dell'elenco come menu: la capsula dice cosa è scelto (o il nome del filtro), il menu elenca
//  le voci con quanti membri hanno e "All" per toglierlo.
//

import SwiftUI

struct AdminMemberFilterMenu: View {
    let title: String
    let allLabel: String
    let options: [AdminMemberFilterOption]
    let selection: String?
    let onSelect: (String?) -> Void

    private var selectedLabel: String? { options.first { $0.key == selection }?.label ?? selection }

    var body: some View {
        Menu {
            Button {
                onSelect(nil)
            } label: {
                if selection == nil { Label(allLabel, systemImage: "checkmark") } else { Text(verbatim: allLabel) }
            }
            ForEach(options) { option in
                Button {
                    onSelect(option.key)
                } label: {
                    let text = "\(option.label) (\(option.count))"
                    if option.key == selection { Label(text, systemImage: "checkmark") } else { Text(verbatim: text) }
                }
            }
        } label: {
            HStack(spacing: 6) {
                Text(verbatim: selectedLabel ?? title)
                    .lineLimit(1)
                Image(systemName: "chevron.down")
                    .font(.caption2.weight(.bold))
            }
            .font(.footnote.weight(.semibold))
            .foregroundStyle(selection == nil ? Color.liteAccent : Color.liteOnAccent)
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .frame(maxWidth: .infinity)
            .background {
                if selection != nil { Capsule().fill(Color.liteAccent) }
            }
            .ariaGlass(in: Capsule())
            .contentShape(Capsule())
        }
        .accessibilityLabel(Text(verbatim: title))
        .accessibilityValue(Text(verbatim: selectedLabel ?? allLabel))
    }
}
