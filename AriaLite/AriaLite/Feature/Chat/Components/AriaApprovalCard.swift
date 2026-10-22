//
//  AriaApprovalCard.swift
//  AriaLite
//
//  Created by Giovanni Michele on 26/09/26.
//
//  Dove l'operatore approva un'azione di Aria: la card con i parametri modificabili e la riga che resta
//  dopo la decisione. Il LOTO è in AriaLotoSheet, le domande guidate in AriaElicitationPanel.
//  La logica sta in AriaApprovalViewModel.
//

import SwiftUI

// MARK: - Approvazione tool

/// interrupt-approval-card della web: ogni parametro semplice è modificabile;
/// se cambia qualcosa, "Approva con modifiche" manda decision "edit" con gli args completi.
struct AriaApprovalCard: View {
    let interrupt: AriaInterrupt
    var onDecide: (AriaResumeDecision) -> Void

    var body: some View {
        AriaApprovalCardContent(model: AriaApprovalViewModel(interrupt: interrupt, onDecide: onDecide))
            // Il view model nasce con la pausa: un'altra pausa riparte dai suoi parametri.
            .id(interrupt.interruptId)
    }
}

private struct AriaApprovalCardContent: View {
    @State private var model: AriaApprovalViewModel
    @FocusState private var focusedKey: String?

    init(model: @autoclosure () -> AriaApprovalViewModel) {
        _model = State(wrappedValue: model())
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            header
            if let warning = model.warning {
                Label {
                    Text(AriaMarkdown.inline(warning)).font(.system(size: 13))
                } icon: {
                    Image(systemName: "exclamationmark.triangle.fill")
                }
                .foregroundStyle(.orange)
            }

            VStack(alignment: .leading, spacing: 14) {
                ForEach(model.keys, id: \.self) { key in
                    argField(key)
                }
            }

            actions
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 22, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 22, style: .continuous).strokeBorder(Color.orange.opacity(0.35), lineWidth: 1))
        .preference(key: AriaInlineEditorFocusKey.self, value: focusedKey != nil)
    }

    /// Cosa Aria vuole fare (a capo, mai tagliato) e lo stato "in attesa" sotto, non stretto accanto al titolo.
    private var header: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: "hand.raised.fill")
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(.orange)
                .frame(width: 34, height: 34)
                .background(Color.orange.opacity(0.16), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
            VStack(alignment: .leading, spacing: 6) {
                Text(model.toolLabel)
                    .font(.system(size: 17, weight: .semibold))
                    .fixedSize(horizontal: false, vertical: true)
                AriaBadge(text: String(localized: "awaiting approval"), tint: .orange)
            }
        }
    }

    /// Approvare è l'azione principale e prende lo spazio; rifiutare è accanto, in vetro con il rosso del testo.
    private var actions: some View {
        HStack(spacing: 10) {
            Button(role: .destructive) { model.reject() } label: {
                Text("Reject")
                    .font(.system(size: 16, weight: .semibold))
                    .padding(.horizontal, 10)
                    .frame(minHeight: 46)
            }
            .ariaGlassButtonStyle()
            .buttonBorderShape(.capsule)
            .tint(.red)

            Button { model.approve() } label: {
                Text(model.isEdited ? "Approve with changes" : "Approve")
                    .font(.system(size: 16, weight: .semibold))
                    .frame(maxWidth: .infinity, minHeight: 46)
            }
            .ariaProminentGlassButtonStyle(tint: .accentColor)
            .buttonBorderShape(.capsule)
        }
        .animation(.snappy(duration: 0.2), value: model.isEdited)
    }

    /// Etichetta piccola sopra e valore in un campo pieno e discreto (niente bordo bianco su fondo bianco).
    private func field<Content: View>(_ label: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(label)
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(.secondary)
            content()
        }
    }

    private func fieldBox<Content: View>(@ViewBuilder content: () -> Content) -> some View {
        content()
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color(.tertiarySystemFill), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
    }

    @ViewBuilder
    private func argField(_ key: String) -> some View {
        let label = model.label(key)
        switch model.value(key) {
        case .bool(let value):
            Toggle(label, isOn: Binding(get: { value }, set: { model.set(key, .bool($0)) }))
                .font(.system(size: 15))
        case .number(let value):
            field(label) {
                fieldBox {
                    TextField(label, value: Binding(get: { value }, set: { model.set(key, .number($0)) }), format: .number)
                        .keyboardType(.decimalPad)
                        .font(.system(size: 16))
                        .focused($focusedKey, equals: key)
                }
            }
        case .string(let value):
            field(label) {
                fieldBox {
                    TextField(label, text: Binding(get: { value }, set: { model.set(key, .string($0)) }), axis: .vertical)
                        .lineLimit(1...5)
                        .font(.system(size: 16))
                        .focused($focusedKey, equals: key)
                }
            }
        case .array(let items) where key == "moves":
            // Spostamenti di calendario: tabella in sola lettura.
            field(label) {
                fieldBox {
                    VStack(alignment: .leading, spacing: 6) {
                        ForEach(Array(items.enumerated()), id: \.offset) { _, move in
                            Text(verbatim: model.moveDescription(move))
                                .font(.system(size: 13))
                        }
                    }
                }
            }
        case .null:
            EmptyView()
        case let other:
            // Valore che non si modifica (liste, oggetti): in sola lettura, senza l'aspetto di un campo.
            field(label) {
                Text(verbatim: other.compactDescription)
                    .font(.system(size: 13, design: .monospaced))
                    .foregroundStyle(.secondary)
                    .lineLimit(6)
            }
        }
    }
}

/// Riga che resta al posto della card dopo la decisione.
struct AriaInterruptOutcomeLine: View {
    let outcome: AriaInterruptOutcome

    var body: some View {
        let (text, icon, tint): (LocalizedStringKey, String, Color) = switch outcome {
        case .approved: ("Approved", "checkmark.circle.fill", .green)
        case .edited: ("Approved with changes", "checkmark.circle.fill", .green)
        case .rejected: ("Rejected", "xmark.circle.fill", .red)
        case .lotoConfirmed: ("LOTO confirmed", "lock.fill", .green)
        case .lotoDeclined: ("LOTO not confirmed", "lock.open.fill", .orange)
        }
        Label(text, systemImage: icon)
            .font(.system(size: 12, weight: .medium))
            .foregroundStyle(tint)
    }
}
