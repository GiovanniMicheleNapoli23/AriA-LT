//
//  AriaElicitationRows.swift
//  AriaLite
//
//  Created by Giovanni Michele on 22/10/26.
//
//  Le righe del pannello delle domande guidate: opzione, "Altra risposta", motivo di fine procedura,
//  valore richiesto da un'opzione e la freccia d'invio.
//

import SwiftUI

/// Nella scelta singola la riga selezionata porta la freccia d'invio: l'opzione scelta È la risposta.
struct AriaElicitationOptionRow: View {
    let model: AriaElicitationViewModel
    let option: AriaElicitationOption
    var onPick: () -> Void
    /// Cerchio, quadratino o numero della classifica: crescono col simbolo che contengono.
    @ScaledMetric(relativeTo: .title3) private var indicatorSide: CGFloat = 22

    var body: some View {
        let rank = model.rank(of: option)
        let isOn = rank != nil
        HStack(spacing: 8) {
            Button(action: onPick) {
                HStack(spacing: 12) {
                    indicator(isOn: isOn, rank: rank)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(option.label)
                            .font(.subheadline.weight(isOn ? .semibold : .medium))
                            .foregroundStyle(.primary)
                        if let description = option.description, !description.isEmpty {
                            Text(description)
                                .font(.footnote)
                                .foregroundStyle(.secondary)
                        }
                    }
                    .multilineTextAlignment(.leading)
                    Spacer(minLength: 0)
                    if model.isSingle, option.followUp != nil {
                        Image(systemName: "chevron.right")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(.tertiary)
                    }
                }
                .padding(.vertical, 12)
                .frame(maxWidth: .infinity, minHeight: 52, alignment: .leading)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityAddTraits(isOn ? .isSelected : [])

            if model.isSingle, isOn {
                AriaElicitationSendButton(isLast: model.isLast, enabled: model.closureReady) { model.submit() }
                    .transition(.scale.combined(with: .opacity))
            }
        }
        .padding(.leading, 14)
        .padding(.trailing, model.isSingle && isOn ? 9 : 14)
        // Sul vetro: riempimenti traslucidi, niente vetro sopra vetro.
        .background(isOn ? Color.accentColor.opacity(0.12) : Color.primary.opacity(0.045),
                    in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous)
            .strokeBorder(isOn ? Color.accentColor.opacity(0.5) : Color.liteGlassEdge, lineWidth: isOn ? 1.5 : 0.5))
        .animation(.snappy(duration: 0.2), value: isOn)
    }

    @ViewBuilder
    private func indicator(isOn: Bool, rank: Int?) -> some View {
        switch model.step.mode {
        case "rank":
            ZStack {
                Circle().strokeBorder(isOn ? Color.clear : Color.secondary.opacity(0.5),
                                      style: StrokeStyle(lineWidth: 1.5, dash: [3, 2.5]))
                if let rank {
                    Circle().fill(Color.accentColor)
                    Text(verbatim: "\(rank + 1)")
                        .font(.caption.weight(.bold))
                        .foregroundStyle(Color.liteOnAccent)
                }
            }
            .frame(width: indicatorSide, height: indicatorSide)
        case "multi":
            Image(systemName: isOn ? "checkmark.square.fill" : "square")
                .font(.title3)
                .foregroundStyle(isOn ? Color.accentColor : .secondary)
                .frame(width: indicatorSide, height: indicatorSide)
        default:
            Image(systemName: isOn ? "checkmark.circle.fill" : "circle")
                .font(.title3)
                .foregroundStyle(isOn ? Color.accentColor : Color.secondary.opacity(0.6))
                .frame(width: indicatorSide, height: indicatorSide)
        }
    }
}

/// "Altra risposta": riga compatta che diventa un campo di testo solo quando serve.
struct AriaElicitationCustomRow: View {
    @Bindable var model: AriaElicitationViewModel
    let fieldFocused: FocusState<Bool>.Binding
    /// Allineata al cerchio delle opzioni sopra.
    @ScaledMetric(relativeTo: .title3) private var iconSide: CGFloat = 22
    @ScaledMetric(relativeTo: .body) private var arrowSide: CGFloat = 34

    var body: some View {
        if model.writingCustom {
            HStack(alignment: .bottom, spacing: 8) {
                TextField(model.isSingle ? "Type your answer…" : "Add something (optional)…", text: $model.custom, axis: .vertical)
                    .font(.subheadline)
                    .lineLimit(1...4)
                    .focused(fieldFocused)
                    .submitLabel(.send)
                    .onSubmit { model.submitFromKeyboard() }
                    .padding(.vertical, 6)
                if model.isSingle {
                    AriaElicitationSendButton(isLast: model.isLast, enabled: model.hasTypedAnswer) { model.submit() }
                }
            }
            .padding(.leading, 14)
            .padding(.trailing, 8)
            .padding(.vertical, 6)
            .frame(minHeight: 52)
            .background(Color(.systemBackground), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous)
                .strokeBorder(Color.accentColor.opacity(fieldFocused.wrappedValue ? 0.6 : 0.3), lineWidth: 1.5))
            .onAppear { fieldFocused.wrappedValue = true }
        } else {
            Button { model.startCustomAnswer() } label: {
                // Un campo di testo, non una scheda: fondo pieno e bordo netto lo staccano dalle opzioni (grigie e piatte),
                // e la freccia spenta a destra dice che qui si scrive e si invia.
                HStack(spacing: 12) {
                    Image(systemName: "pencil")
                        .font(.subheadline.weight(.medium))
                        .foregroundStyle(.secondary)
                        .frame(width: iconSide, height: iconSide)
                    Text("Other answer…")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                    Spacer(minLength: 0)
                    Image(systemName: "arrow.up")
                        .font(.footnote.weight(.bold))
                        .foregroundStyle(.white)
                        .frame(width: arrowSide, height: arrowSide)
                        .background(Color.secondary.opacity(0.3), in: Circle())
                }
                .padding(.leading, 14)
                .padding(.trailing, 8)
                .frame(maxWidth: .infinity, minHeight: 52, alignment: .leading)
                .background(Color(.systemBackground), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .strokeBorder(Color.primary.opacity(0.18), lineWidth: 1))
                .contentShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            }
            .buttonStyle(.plain)
        }
    }
}

/// Tra l'ultima opzione e la freccia d'invio, solo dopo aver scelto di terminare (come la web).
struct AriaClosureReasonForm: View {
    @Bindable var model: AriaElicitationViewModel
    let fieldFocused: FocusState<Bool>.Binding

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("What is stopping you from continuing?")
                .font(.subheadline.weight(.semibold))
            Menu {
                ForEach(AriaClosureReason.allCases) { reason in
                    Button {
                        model.closureReason = reason
                    } label: {
                        if model.closureReason == reason {
                            Label(reason.label, systemImage: "checkmark")
                        } else {
                            Text(reason.label)
                        }
                    }
                }
            } label: {
                HStack(spacing: 8) {
                    Text(model.closureReason?.label ?? String(localized: "Select…"))
                        .font(.subheadline.weight(.medium))
                        .foregroundStyle(model.closureReason == nil ? Color.secondary : Color.primary)
                        .multilineTextAlignment(.leading)
                    Spacer(minLength: 0)
                    Image(systemName: "chevron.up.chevron.down")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)
                }
                .padding(.horizontal, 14)
                .frame(maxWidth: .infinity, minHeight: 46, alignment: .leading)
                .background(Color.primary.opacity(0.06), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                .overlay(RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .strokeBorder(model.closureReason == nil ? Color.accentColor.opacity(0.5) : Color.liteGlassEdge,
                                  lineWidth: model.closureReason == nil ? 1.5 : 0.5))
                .contentShape(Rectangle())
            }
            .accessibilityLabel(Text("What is stopping you from continuing?"))

            Text("Give details (optional)")
                .font(.subheadline.weight(.semibold))
            TextField("Explain in your own words what got in the way…", text: $model.closureDetails, axis: .vertical)
                .font(.subheadline)
                .lineLimit(2...5)
                .focused(fieldFocused)
                .padding(.horizontal, 14)
                .padding(.vertical, 10)
                .background(Color.primary.opacity(0.06), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
        }
        .padding(12)
        .background(Color.primary.opacity(0.03), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        .transition(.opacity.combined(with: .move(edge: .top)))
    }
}

/// Un'opzione che promette un valore: il campo per scriverlo.
struct AriaElicitationFollowUpForm: View {
    @Bindable var model: AriaElicitationViewModel
    let option: AriaElicitationOption
    let fieldFocused: FocusState<Bool>.Binding

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label(option.label, systemImage: "checkmark.circle.fill")
                .font(.footnote.weight(.semibold))
                .foregroundStyle(Color.accentColor)
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(Color.accentColor.opacity(0.1), in: Capsule())
            Text(AriaMarkdown.inline(option.followUp ?? ""))
                .font(.headline)
                .fixedSize(horizontal: false, vertical: true)
            HStack(alignment: .bottom, spacing: 8) {
                TextField("Type your answer…", text: $model.followUpValue, axis: .vertical)
                    .font(.subheadline)
                    .lineLimit(1...4)
                    .focused(fieldFocused)
                    .submitLabel(.send)
                    .onSubmit { model.submitFollowUp() }
                    .padding(.vertical, 6)
                AriaElicitationSendButton(isLast: model.isLast, enabled: model.canSubmitFollowUp) { model.submitFollowUp() }
            }
            .padding(.leading, 14)
            .padding(.trailing, 8)
            .padding(.vertical, 6)
            .frame(minHeight: 52)
            .background(Color.primary.opacity(0.045), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous)
                .strokeBorder(Color.accentColor.opacity(fieldFocused.wrappedValue ? 0.5 : 0.2), lineWidth: 1.5))
        }
        .onAppear { fieldFocused.wrappedValue = true }
    }
}

/// La freccia tonda: "Invia" all'ultimo passo, "Avanti" prima.
struct AriaElicitationSendButton: View {
    let isLast: Bool
    let enabled: Bool
    var action: () -> Void
    @ScaledMetric(relativeTo: .body) private var side: CGFloat = 34

    var body: some View {
        Button(action: action) {
            Image(systemName: isLast ? "arrow.up" : "arrow.right")
                .font(.footnote.weight(.bold))
                .foregroundStyle(enabled ? Color.liteOnAccent : .white)
                .frame(width: side, height: side)
                .background(enabled ? Color.accentColor : Color.secondary.opacity(0.35), in: Circle())
        }
        .buttonStyle(.plain)
        .disabled(!enabled)
        .accessibilityLabel(isLast ? "Send" : "Next")
    }
}
