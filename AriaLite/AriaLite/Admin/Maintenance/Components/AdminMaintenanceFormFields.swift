//
//  AdminMaintenanceFormFields.swift
//  AriaLite
//
//  Created by Giovanni Michele on 22/10/26.
//
//  I campi del foglio di creazione/modifica: testo con titolo, scelta da menu, data facoltativa e giorni
//  della settimana. Tutti sulla stessa scheda di vetro, niente Form: il foglio è una sola ScrollView.
//

import SwiftUI

/// Campo di testo con il titolo sopra, su un riquadro leggero.
struct AdminMaintenanceTextField: View {
    let title: LocalizedStringKey
    @Binding var text: String
    var prompt: LocalizedStringKey?
    var axis: Axis = .horizontal
    var lines: ClosedRange<Int> = 1...1
    var keyboard: UIKeyboardType = .default
    var isMonospaced = false
    var focus: FocusState<Bool>.Binding

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
            TextField(title, text: $text, prompt: prompt.map { Text($0) }, axis: axis)
                .lineLimit(lines)
                .keyboardType(keyboard)
                .font(isMonospaced ? .body.monospaced() : .body)
                .focused(focus)
                .padding(10)
                .background(Color.liteAccent.opacity(0.06), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
        }
    }
}

/// "Titolo … valore ⌄": apre un menu con le scelte (il chiamante le mette in `content`).
struct AdminMaintenanceMenuRow<Choices: View>: View {
    let title: LocalizedStringKey
    let value: String
    @ViewBuilder var choices: Choices

    var body: some View {
        Menu {
            choices
        } label: {
            HStack(spacing: 8) {
                Text(title).foregroundStyle(.secondary)
                Spacer(minLength: 8)
                Text(value).foregroundStyle(.primary).lineLimit(1)
                Image(systemName: "chevron.up.chevron.down")
                    .font(.caption2.weight(.bold))
                    .foregroundStyle(.secondary)
            }
            .font(.subheadline)
            .padding(10)
            .background(Color.liteAccent.opacity(0.06), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
            .contentShape(Rectangle())
        }
        .tint(Color.liteAccent)
    }
}

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
            .font(.subheadline)
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
                            .foregroundStyle(isOn ? Color.white : Color.primary)
                            .background(isOn ? Color.liteAccent : Color.liteAccent.opacity(0.08), in: Capsule())
                    }
                    .buttonStyle(.plain)
                    .accessibilityAddTraits(isOn ? .isSelected : [])
                }
            }
        }
    }
}
