//
//  AriaSignUpWebsiteField.swift
//  AriaLite
//
//  Created by Giovanni Michele on 18/11/26.
//
//  Il sito web aziendale nel passo Azienda, come sulla web: "https://" davanti, l'esito del controllo a destra
//  ("verificato", in corso, problema) e sotto il perché, o il suggerimento. "Non verificato" è grigio con
//  "Riprova": non blocca. Gli altri problemi sono errori del campo.
//

import SwiftUI

struct AriaSignUpWebsiteField: View {
    @Bindable var model: AriaSignUpViewModel
    var focus: FocusState<Bool>.Binding

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            LoginCardRow(icon: "globe") {
                HStack(spacing: 0) {
                    Text(verbatim: "https://")
                        .foregroundStyle(.secondary)
                        .accessibilityHidden(true)
                    TextField("Company website", text: $model.website, prompt: Text("yourcompany.com"))
                        .textContentType(.URL)
                        .keyboardType(.URL)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                        .submitLabel(.next)
                        .focused(focus)
                }
                indicator
            }
            .ariaSignUpCard()

            caption
                .font(.caption)
                .padding(.horizontal, 4)
        }
        .animation(.snappy(duration: 0.25), value: model.websiteStatus)
    }

    @ViewBuilder
    private var indicator: some View {
        switch model.websiteStatus {
        case .checking:
            ProgressView()
                .controlSize(.small)
        case .verified:
            HStack(spacing: 4) {
                Text("verified")
                    .font(.caption)
                Image(systemName: "checkmark.circle.fill")
            }
            .foregroundStyle(Color.liteAccent)
        case .problem(.unverified):
            Image(systemName: "exclamationmark.circle")
                .foregroundStyle(.secondary)
                .accessibilityHidden(true)
        case .problem:
            Image(systemName: "xmark.circle.fill")
                .foregroundStyle(.red)
                .accessibilityHidden(true)
        case .idle:
            EmptyView()
        }
    }

    @ViewBuilder
    private var caption: some View {
        switch model.websiteStatus.problem {
        case .unverified?:
            HStack(spacing: 6) {
                Text(AriaWebsiteProblem.unverified.message)
                    .foregroundStyle(.secondary)
                Button("Try again") { model.retryWebsiteCheck() }
                    .foregroundStyle(Color.liteAccent)
                    .fontWeight(.medium)
            }
        case let problem?:
            Text(problem.message)
                .foregroundStyle(.red)
        case nil:
            Text("We use it to check that the company exists.")
                .foregroundStyle(.tertiary)
        }
    }
}
