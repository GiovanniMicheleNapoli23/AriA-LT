//
//  LoginView.swift
//  AriaLite
//
//  Created by Giovanni Michele on 19/03/26.
//
//  Accesso in stile iOS: la sfera di Aria su un alone morbido (pensa mentre aspetta il server),
//  il logo con "Mobile" sotto, una card a gruppo unico come nelle Impostazioni di sistema,
//  un pulsante. Entra con una breve animazione. Tocca fuori per chiudere la tastiera.
//
//  Solo email, niente password: 1) si scrive l'email e si manda il link;
//  2) si copia il link dall'email e lo si incolla (con gli appunti condivisi si copia sul Mac),
//  oppure, se il sistema lo apre nell'app, si entra da soli (AppViewModel.open).
//  Vedi AppViewModel.sendLoginLink / completeLogin.
//

import SwiftUI
import UniformTypeIdentifiers

struct LoginView: View {
    let viewModel: AppViewModel

    private enum Field { case email, link }

    @State private var email = ""
    @State private var pastedLink = ""
    /// Un link vale una volta sola: se è già fallito non lo si rimanda al server.
    @State private var failedLink: String?
    /// Messaggio sotto la card: link non valido o errore del server Aria.
    @State private var errorMessage: String?
    /// Il server non si raggiunge: avviso "offline" al posto dell'errore rosso.
    @State private var isOffline = false
    @State private var isLoading = false
    @State private var shakes = 0
    /// Entrata in tre tempi: la sfera sale dal basso, poi il logo, poi il modulo.
    @State private var orbIn = false
    @State private var titleIn = false
    @State private var formIn = false
    @FocusState private var focus: Field?
    @Environment(\.verticalSizeClass) private var verticalSizeClass

    /// iPhone in orizzontale: sfera e logo più piccoli, così il modulo ci sta.
    private var isCompactHeight: Bool { verticalSizeClass == .compact }

    /// Email a cui è partito il link (e che aspetta di essere toccato o incollato): passo 2.
    private var sentTo: String? { viewModel.backend.pendingLinkEmail }

    /// In attesa del server: richiesta del link, link incollato o link toccato nell'email.
    private var isBusy: Bool { isLoading || viewModel.isOpeningLink }

    private var canSend: Bool {
        !email.trimmingCharacters(in: .whitespaces).isEmpty && !isBusy
    }

    private var canSignIn: Bool {
        !pastedLink.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && !isBusy
    }

    private var version: String {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "1.0"
    }

    var body: some View {
        GeometryReader { proxy in
            ScrollViewReader { scroller in
                ScrollView {
                    VStack(spacing: 0) {
                        Spacer(minLength: isCompactHeight ? 16 : 40)
                        hero
                        Spacer(minLength: isCompactHeight ? 16 : 40)
                        form
                            .opacity(formIn ? 1 : 0)
                            .offset(y: formIn ? 0 : 40)
                        Spacer(minLength: 24)
                        footer
                            .opacity(formIn ? 1 : 0)
                    }
                    .padding(.horizontal, 24)
                    .frame(maxWidth: 480)
                    // Centrato come prima quando ci sta; con la tastiera o in orizzontale scorre.
                    .frame(maxWidth: .infinity, minHeight: proxy.size.height)
                    .contentShape(Rectangle())
                    .onTapGesture { focus = nil }
                }
                .scrollBounceBehavior(.basedOnSize)
                .scrollDismissesKeyboard(.interactively)
                // La sfera sale dal fondo dello schermo: non va tagliata.
                .scrollClipDisabled()
                // La tastiera accorcia lo spazio: la scroll view mostra solo il campo, il pulsante lo riportiamo noi
                // (iPhone in orizzontale: restano ~180pt sopra la tastiera).
                .onChange(of: proxy.size.height) { old, new in
                    guard new < old, focus != nil else { return }
                    withAnimation(.snappy) { scroller.scrollTo(Self.primaryID, anchor: .bottom) }
                }
            }
        }
        .background { backdrop }
        .sensoryFeedback(.error, trigger: shakes)
        .preferredColorScheme(.light)
        .onAppear(perform: enter)
        // Esito del link toccato nell'email: errore e scossone come per quello incollato.
        .onChange(of: viewModel.openedLinkResult, initial: true) { _, result in
            guard let result else { return }
            viewModel.openedLinkResult = nil
            handle(result, field: .link)
        }
    }

    private func enter() {
        withAnimation(.spring(duration: 1.0, bounce: 0.28)) { orbIn = true }
        withAnimation(.spring(duration: 0.7, bounce: 0.15).delay(0.55)) { titleIn = true }
        withAnimation(.spring(duration: 0.7, bounce: 0.15).delay(0.85)) { formIn = true }
    }

    // MARK: - Sfondo

    /// Bianco quasi puro con due aloni appena percettibili: lilla dietro la sfera, navy in basso.
    private var backdrop: some View {
        ZStack {
            Color.liteBackground
            RadialGradient(colors: [Color(red: 0.62, green: 0.52, blue: 0.78).opacity(0.16), .clear],
                           center: UnitPoint(x: 0.5, y: 0.28), startRadius: 0, endRadius: 320)
            RadialGradient(colors: [Color.liteAccent.opacity(0.06), .clear],
                           center: .bottom, startRadius: 0, endRadius: 460)
        }
        .ignoresSafeArea()
    }

    // MARK: - Sfera + logo

    private var hero: some View {
        VStack(spacing: isCompactHeight ? 12 : 22) {
            AriaOrb(mood: isBusy ? .thinking : .idle, radius: 0.8)
                .frame(width: isCompactHeight ? 64 : 104, height: isCompactHeight ? 64 : 104)
                .shadow(color: Color.liteAccent.opacity(0.18), radius: 18, x: 0, y: 10)
                // Sale dal fondo dello schermo e si assesta al suo posto.
                .scaleEffect(orbIn ? 1 : 0.55)
                .offset(y: orbIn ? 0 : 520)
                .opacity(orbIn ? 1 : 0)

            AriaWordmark(size: isCompactHeight ? 28 : 40, stacked: true)
                .opacity(titleIn ? 1 : 0)
                .offset(y: titleIn ? 0 : 16)
                .blur(radius: titleIn ? 0 : 6)
        }
    }

    // MARK: - Campi

    /// Una sola card come nelle Impostazioni di sistema, poi l'avviso e il pulsante.
    private var form: some View {
        VStack(spacing: 16) {
            if let sentTo {
                Text("Check your email: we sent a sign-in link to \(sentTo).")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: .infinity)
                    .padding(.horizontal, 8)
            }

            VStack(spacing: 0) {
                if sentTo == nil { emailRow } else { linkRow }
            }
            .background(Color.liteSurface, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .strokeBorder(Color.liteBorder, lineWidth: 1)
            }
            .shadow(color: Color.liteAccent.opacity(0.06), radius: 20, x: 0, y: 8)
            .modifier(Shake(amount: CGFloat(shakes)))

            if isOffline {
                AriaOfflineNotice()
                    .transition(.opacity.combined(with: .move(edge: .top)))
            } else if let errorMessage {
                Label(errorMessage, systemImage: "exclamationmark.circle.fill")
                    .font(.footnote.weight(.medium))
                    .foregroundStyle(.red)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 4)
                    .transition(.opacity.combined(with: .move(edge: .top)))
            }

            primaryButton

            if sentTo != nil {
                VStack(spacing: 10) {
                    Text("Copy the sign-in link from the email and paste it here. With Universal Clipboard you can copy it on your Mac. Don't open it in the browser: it works once and expires in 15 minutes.")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
                    .multilineTextAlignment(.center)
                    Button("Use a different email", action: useDifferentEmail)
                        .font(.footnote.weight(.medium))
                        .foregroundStyle(Color.liteAccent)
                }
                .padding(.horizontal, 8)
            }
        }
        .animation(.snappy(duration: 0.25), value: errorMessage)
        .animation(.snappy(duration: 0.25), value: isOffline)
        .animation(.snappy(duration: 0.25), value: sentTo)
    }

    private var emailRow: some View {
        row(icon: "envelope") {
            TextField("Work email", text: $email)
                .textContentType(.emailAddress)
                .keyboardType(.emailAddress)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                .submitLabel(.send)
                .focused($focus, equals: .email)
                .onSubmit(sendLink)
        }
    }

    private var linkRow: some View {
        row(icon: "link") {
            TextField("Paste the sign-in link", text: $pastedLink)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                .keyboardType(.URL)
                .submitLabel(.go)
                .focused($focus, equals: .link)
                .onSubmit { signIn() }
                // Incollato un link valido, si entra subito.
                .onChange(of: pastedLink) { _, text in
                    if viewModel.backend.magicLink(in: text) != nil, text != failedLink { signIn() }
                }

            // Il pulsante di sistema non chiede il permesso di leggere gli appunti (come invece fa il menu "Incolla").
            PasteButton(supportedContentTypes: [.url, .plainText]) { providers in
                Task { @MainActor in pastedLink = await Self.text(from: providers) }
            }
            .labelStyle(.iconOnly)
            .buttonBorderShape(.capsule)
            .tint(Color.liteAccent)
        }
    }

    private var primaryButton: some View {
        let enabled = sentTo == nil ? canSend : canSignIn
        return Button(action: sentTo == nil ? sendLink : { signIn() }) {
            ZStack {
                if isBusy {
                    ProgressView().tint(.white)
                } else {
                    Text(sentTo == nil ? "Send sign-in link" : "Sign in")
                        .font(.system(size: 17, weight: .semibold))
                }
            }
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity)
            .frame(height: 54)
            .background(Color.liteAccent.opacity(enabled || isBusy ? 1 : 0.3),
                        in: RoundedRectangle(cornerRadius: 18, style: .continuous))
            .shadow(color: Color.liteAccent.opacity(enabled ? 0.25 : 0), radius: 12, x: 0, y: 6)
        }
        .buttonStyle(.plain)
        .disabled(!enabled)
        .animation(.easeInOut(duration: 0.2), value: enabled)
        .id(Self.primaryID)
    }

    private static let primaryID = "login.primary"

    private func row<Content: View>(icon: String, @ViewBuilder content: () -> Content) -> some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 16))
                .foregroundStyle(.secondary)
                .frame(width: 20)
            content()
                .font(.system(size: 17))
                .foregroundStyle(Color.liteText)
        }
        .padding(.horizontal, 16)
        .frame(height: 54)
    }

    // MARK: - Piè di pagina

    private var footer: some View {
        HStack(spacing: 8) {
            Image("AriaLite")
                .resizable()
                .scaledToFit()
                .frame(width: 16, height: 16)
                .clipShape(RoundedRectangle(cornerRadius: 4, style: .continuous))
            Text(verbatim: "Sinaura · v\(version)")
                .font(.system(size: 12))
                .foregroundStyle(.tertiary)
        }
        .padding(.bottom, 12)
    }

    // MARK: - Accesso

    private func sendLink() {
        guard canSend else { return }
        focus = nil
        isLoading = true
        errorMessage = nil
        isOffline = false
        Task {
            let result = await viewModel.sendLoginLink(email: email)
            isLoading = false
            handle(result, field: .email)
            if result == .success { focus = .link }
        }
    }

    private func signIn() {
        let text = pastedLink.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty, !isBusy else { return }
        focus = nil
        isLoading = true
        errorMessage = nil
        isOffline = false
        Task {
            let result = await viewModel.completeLogin(with: text)
            isLoading = false
            if case .failure = result { failedLink = pastedLink }
            handle(result, field: .link)
        }
    }

    private func handle(_ result: AppViewModel.LoginResult, field: Field) {
        switch result {
        case .success:
            break
        case .offline:
            isOffline = true
            withAnimation(.linear(duration: 0.4)) { shakes += 1 }
        case .failure(let message):
            errorMessage = message
            withAnimation(.linear(duration: 0.4)) { shakes += 1 }
            focus = field
        }
    }

    /// Torna al passo dell'email, per chiedere un nuovo link.
    private func useDifferentEmail() {
        viewModel.backend.cancelPendingLink()
        pastedLink = ""
        failedLink = nil
        errorMessage = nil
        isOffline = false
        focus = .email
    }

    /// Un link copiato arriva come URL (Mail, Safari, appunti condivisi) o come testo: si accettano entrambi.
    private static func text(from providers: [NSItemProvider]) async -> String {
        var parts: [String] = []
        for provider in providers {
            if provider.canLoadObject(ofClass: URL.self) {
                let url = await withCheckedContinuation { continuation in
                    _ = provider.loadObject(ofClass: URL.self) { url, _ in continuation.resume(returning: url) }
                }
                if let url { parts.append(url.absoluteString) }
            } else if provider.canLoadObject(ofClass: String.self) {
                let text = await withCheckedContinuation { continuation in
                    _ = provider.loadObject(ofClass: String.self) { text, _ in continuation.resume(returning: text) }
                }
                if let text { parts.append(text) }
            }
        }
        return parts.joined(separator: " ")
    }
}

/// Scuote orizzontalmente la card quando il link o l'email non vanno.
private struct Shake: GeometryEffect {
    var amount: CGFloat
    var animatableData: CGFloat {
        get { amount }
        set { amount = newValue }
    }

    func effectValue(size: CGSize) -> ProjectionTransform {
        ProjectionTransform(CGAffineTransform(translationX: 8 * sin(amount * .pi * 4), y: 0))
    }
}

#Preview {
    LoginView(viewModel: AppViewModel())
}
