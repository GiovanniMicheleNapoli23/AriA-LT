//
//  AdminMaintenanceFormFields.swift
//  AriaLite
//
//  Created by Giovanni Michele on 22/10/26.
//
//  Le righe su misura del Form di un piano: una data facoltativa e i giorni della settimana.
//

import SwiftUI

/// Una data facoltativa: l'interruttore la accende (parte da adesso) o la toglie.
struct AdminMaintenanceOptionalDateRow: View {
    let title: LocalizedStringKey
    @Binding var date: Date?
    var components: DatePickerComponents = [.date]

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Toggle(title, isOn: Binding(
                get: { date != nil },
                set: { date = $0 ? (date ?? .now) : nil }
            ))
            .tint(Color.liteAccent)
            if let current = date {
                DatePicker(title, selection: Binding(get: { current }, set: { date = $0 }), displayedComponents: components)
                    .labelsHidden()
                    .datePickerStyle(.compact)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
    }
}

/// I giorni della settimana come chip a pastiglia, che vanno a capo.
struct AdminMaintenanceDaysPicker: View {
    @Binding var days: Set<String>

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Days of the week")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
            LazyVGrid(columns: [GridItem(.adaptive(minimum: 52), spacing: 8)], alignment: .leading, spacing: 8) {
                ForEach(AdminMaintenanceWeekday.allCases) { day in
                    let isOn = days.contains(day.rawValue)
                    Button {
                        if isOn { days.remove(day.rawValue) } else { days.insert(day.rawValue) }
                    } label: {
                        Text(day.shortLabel)
                            .font(.footnote.weight(.semibold))
                            .lineLimit(1)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 8)
                            .foregroundStyle(isOn ? Color.liteOnAccent : Color.primary)
                            .background(isOn ? Color.liteAccent : Color.liteAccent.opacity(0.08), in: Capsule())
                    }
                    .buttonStyle(.plain)
                    .accessibilityAddTraits(isOn ? .isSelected : [])
                }
            }
        }
    }
}
