//
//  AriaSignUpView.swift
//  AriaLite
//
//  Created by Giovanni Michele on 11/11/26.
//
//  L'iscrizione dopo il link: quattro passi (Profilo, Azienda, Stabilimento, Piano) sullo sfondo del login, con i
//  segmenti in alto e "Sign out". Tutta la logica è in AriaSignUpViewModel; qui restano layout e animazioni.
//

import SwiftUI

struct AriaSignUpView: View {
    @State private var model: AriaSignUpViewModel
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    init(app: AppViewModel) {
        _model = State(initialValue: AriaSignUpViewModel(app: app))
    }

    var body: some View {
        VStack(spacing: 0) {
            topBar
                .padding(.top, 8)

            ScrollView {
                content
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 28)
                    .padding(.top, 12)
                    .padding(.bottom, 24)
                    .ariaReadableWidth(560)
            }
            .scrollDismissesKeyboard(.interactively)
            .scrollBounceBehavior(.basedOnSize)
        }
        .background { LoginBackdrop() }
        .animation(reduceMotion ? nil : Animation.snappy, value: model.step)
        .sensoryFeedback(.selection, trigger: model.stepIndex)
        .task { await model.load() }
        .alert("Create your company on the web", isPresented: blockingPresented) {
            Button("OK") { model.dismissBlockingMessage() }
        } message: {
            Text(verbatim: model.blockingMessage ?? "")
        }
    }

    /// L'avviso si chiude solo col pulsante, che lo toglie dal modello.
    private var blockingPresented: Binding<Bool> {
        Binding(get: { model.blockingMessage != nil }, set: { _ in })
    }

    // MARK: Barra in alto

    private var topBar: some View {
        HStack(spacing: 16) {
            if model.step != nil {
                AriaOnboardingProgressBar(count: model.stepCount, index: model.stepIndex, label: model.progressLabel)
                    .transition(.opacity)
            } else {
                Spacer()
            }
            Button("Sign out") { model.signOut() }
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(Color.liteAccent)
                .frame(minHeight: 44)
                .buttonStyle(.plain)
        }
        .padding(.horizontal, 28)
        .ariaReadableWidth(560)
    }

    // MARK: Contenuto

    @ViewBuilder
    private var content: some View {
        if let step = model.step {
            VStack(alignment: .leading, spacing: 24) {
                header(step)
                form(step)
                messages
            }
            .id(step)
            .transition(.opacity.combined(with: .move(edge: .trailing)))
        } else if model.needsRetry {
            VStack(spacing: 16) {
                messages
                LoginPrimaryButton(title: "Try again", isEnabled: true, isBusy: false) {
                    Task { await model.load() }
                }
            }
            .padding(.top, 24)
        } else {
            ProgressView()
                .frame(maxWidth: .infinity, minHeight: 240)
        }
    }

    private func header(_ step: AriaSignUpStep) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            AriaOnboardingTitle(text: step.title, size: 40)
            Text(step.subtitle)
                .font(.body)
                .lineSpacing(3)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
            if !model.email.isEmpty {
                Text("Signed in as \(model.email)")
                    .font(.footnote)
                    .foregroundStyle(.tertiary)
            }
        }
    }

    @ViewBuilder
    private func form(_ step: AriaSignUpStep) -> some View {
        switch step {
        case .profile: AriaSignUpProfileForm(model: model)
        case .company: AriaSignUpCompanyForm(model: model)
        case .plant: AriaSignUpPlantForm(model: model)
        case .plan: AriaSignUpPlanCard(model: model)
        }
    }

    /// Offline o errore, come sotto la card del login.
    @ViewBuilder
    private var messages: some View {
        if model.isOffline {
            AriaOfflineNotice()
                .transition(.opacity.combined(with: .move(edge: .top)))
        } else if let errorMessage = model.errorMessage {
            Label(errorMessage, systemImage: "exclamationmark.circle.fill")
                .font(.footnote.weight(.medium))
                .foregroundStyle(.red)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 4)
                .transition(.opacity.combined(with: .move(edge: .top)))
        }
    }
}

extension View {
    /// La card dei moduli dell'iscrizione: la stessa del login.
    func ariaSignUpCard() -> some View {
        background(Color.liteSurface, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .strokeBorder(Color.liteBorder, lineWidth: 1)
            }
            .shadow(color: Color.liteAccent.opacity(0.06), radius: 20, x: 0, y: 8)
    }
}
