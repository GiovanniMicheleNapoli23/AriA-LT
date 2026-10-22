//
//  AriaTaskStepParts.swift
//  AriaLite
//
//  Created by Giovanni Michele on 22/10/26.
//
//  I pezzi comuni degli step di procedura: colore dello step, segmenti di avanzamento, intestazione,
//  badge dell'aiuto chiesto su un task ed esito dello step.
//

import SwiftUI

extension AriaTaskList {
    /// Arancione per gli step di sicurezza.
    var stepTint: Color { isSafety ? .orange : .accentColor }
}

/// L'esito dell'aiuto chiesto su un task (non chiaro / da cambiare / fallito).
struct AriaTaskMarkBadge: View {
    let mark: AriaTaskStepViewModel.Mark

    var body: some View {
        switch mark {
        case .failed: AriaBadge(text: String(localized: "Failed"), tint: .red)
        case .modify: AriaBadge(text: String(localized: "To change"), tint: .orange)
        case .unclear: AriaBadge(text: String(localized: "Not clear"), tint: .blue)
        }
    }
}

/// Un segmento per task: pieno se fatto, evidenziato quello in corso. Dice insieme quanti sono e dove si è.
struct AriaTaskSegments: View {
    let model: AriaTaskStepViewModel

    var body: some View {
        HStack(spacing: 4) {
            ForEach(model.tasks) { task in
                Capsule()
                    .fill(color(task))
                    .frame(height: 4)
            }
        }
        .animation(.snappy, value: model.doneCount)
    }

    private func color(_ task: AriaTaskList.Task) -> Color {
        if model.isChecked(task) { return model.list.stepTint }
        if model.isNext(task) { return model.list.stepTint.opacity(0.35) }
        return Color(.tertiarySystemFill)
    }
}

/// Lo step è il contesto del task: etichetta colorata sopra, titolo sotto (va a capo, non si taglia mai).
struct AriaTaskStepHeader<Accessory: View>: View {
    let list: AriaTaskList
    var titleSize: CGFloat = 15
    var titleOpacity: Double = 1
    @ViewBuilder var accessory: Accessory

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: list.isSafety ? "exclamationmark.shield.fill" : "list.bullet.clipboard.fill")
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(list.stepTint)
                .frame(width: 34, height: 34)
                .background(list.stepTint.opacity(0.14), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
            VStack(alignment: .leading, spacing: 2) {
                Text(list.label.uppercased())
                    .font(.system(size: 11, weight: .bold))
                    .tracking(0.6)
                    .foregroundStyle(list.stepTint)
                Text(list.stepTitle)
                    .font(.system(size: titleSize, weight: .semibold))
                    .foregroundStyle(.primary.opacity(titleOpacity))
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 4)
            accessory
        }
    }
}

extension AriaTaskStepViewModel.Outcome {
    var text: String {
        switch self {
        case .failed: String(localized: "Failed")
        case .toChange: String(localized: "To change")
        case .notClear: String(localized: "Not clear")
        case .completed: String(localized: "Completed")
        case .inProgress: String(localized: "In progress")
        }
    }

    var tint: Color {
        switch self {
        case .failed: .red
        case .toChange: .orange
        case .notClear: .blue
        case .completed: .green
        case .inProgress: .secondary
        }
    }

    var symbol: String {
        switch self {
        case .failed: "xmark.octagon.fill"
        case .toChange: "pencil.circle.fill"
        case .notClear: "questionmark.circle.fill"
        case .completed: "checkmark.circle.fill"
        case .inProgress: "circle.dotted"
        }
    }
}

/// "Fai una domanda su questo step": l'alert condiviso da pannello e checklist.
struct AriaTaskQuestionAlert: ViewModifier {
    @Bindable var model: AriaTaskStepViewModel

    func body(content: Content) -> some View {
        content.alert("Ask about this step", isPresented: $model.isAsking) {
            TextField("Your question", text: $model.question)
            Button("Cancel", role: .cancel) { model.cancelQuestion() }
            Button("Send") { model.sendQuestion() }
        }
    }
}
