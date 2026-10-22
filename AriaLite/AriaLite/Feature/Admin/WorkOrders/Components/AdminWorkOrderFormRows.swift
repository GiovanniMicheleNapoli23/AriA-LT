//
//  AdminWorkOrderFormRows.swift
//  AriaLite
//
//  Created by Giovanni Michele on 22/10/26.
//
//  Le righe del form di un ordine, comuni alla modifica e alla creazione a passi: testo in linea, data
//  facoltativa, durata e scelta da un elenco.
//

import SwiftUI

/// Etichetta a sinistra e testo a destra, sulla stessa riga.
struct AdminWorkOrderFormTextRow<Field: Hashable>: View {
    let title: LocalizedStringKey
    @Binding var text: String
    let focus: FocusState<Field?>.Binding
    let field: Field

    var body: some View {
        LabeledContent(title) {
            TextField(title, text: $text)
                .multilineTextAlignment(.trailing)
                .focused(focus, equals: field)
        }
    }
}

/// Una data facoltativa: "Add" la accende, la x la toglie.
struct AdminWorkOrderFormDateRow: View {
    let title: LocalizedStringKey
    @Binding var isOn: Bool
    @Binding var date: Date

    var body: some View {
        HStack(spacing: 6) {
            Text(title)
            Spacer(minLength: 4)
            if isOn {
                DatePicker(title, selection: $date)
                    .labelsHidden()
                Button("Remove", systemImage: "xmark.circle.fill") {
                    withAnimation { isOn = false }
                }
                .labelStyle(.iconOnly)
                .foregroundStyle(.tertiary)
                .buttonStyle(.borderless)
            } else {
                Button("Add") { withAnimation { isOn = true } }
                    .buttonStyle(.borderless)
            }
        }
    }
}

/// Una riga che apre l'elenco; se il ruolo non può leggerlo, il valore resta in sola lettura.
struct AdminWorkOrderFormChoiceLink<Destination: View>: View {
    let title: LocalizedStringKey
    let value: String
    let unavailable: Bool
    var availability: AriaAvailability?
    @ViewBuilder let destination: () -> Destination

    var body: some View {
        if unavailable {
            LabeledContent(title) {
                VStack(alignment: .trailing, spacing: 2) {
                    Text(value)
                    Text("Not available for your role").font(.caption2).foregroundStyle(.tertiary)
                }
            }
        } else {
            NavigationLink(destination: destination) {
                LabeledContent(title) {
                    HStack(spacing: 6) {
                        if availability != nil { AdminWorkOrderFormAvailabilityDot(availability: availability) }
                        Text(value).lineLimit(1)
                    }
                }
            }
        }
    }
}

/// I minuti stimati, con la stessa durata in ore sotto l'etichetta quando supera l'ora.
struct AdminWorkOrderFormDurationRow<Field: Hashable>: View {
    @Binding var minutes: String
    let hint: String?
    let focus: FocusState<Field?>.Binding
    let field: Field

    var body: some View {
        LabeledContent {
            HStack(spacing: 4) {
                TextField("Minutes", text: $minutes)
                    .keyboardType(.numberPad)
                    .multilineTextAlignment(.trailing)
                    .focused(focus, equals: field)
                Text("min").foregroundStyle(.secondary)
            }
        } label: {
            VStack(alignment: .leading, spacing: 0) {
                Text("Estimated duration")
                if let hint {
                    Text(hint).font(.caption).foregroundStyle(.secondary)
                }
            }
        }
    }
}
