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
//  Solo email, niente password, un solo campo per operatori e account della web:
//  1) si scrive l'email e si mandano i link (il captcha della web lavora in silenzio sotto la card);
//  2) si tocca il link nell'email (AppViewModel.open) o lo si incolla qui.
//  Tutta la logica è in LoginViewModel; qui restano il fuoco dei campi, lo scorrimento e le animazioni.
//

import SwiftUI
import UniformTypeIdentifiers

struct LoginView: View {
    @State private var model: LoginViewModel

    /// Entrata in tre tempi: la sfera sale dal basso, poi il logo, poi il modulo.
    @State private var orbIn = false
    @State private var titleIn = false
    @State private var formIn = false
    @FocusState private var focus: LoginField?
    @Environment(\.verticalSizeClass) private var verticalSizeClass

    init(viewModel: AppViewModel) {
        _model = State(initialValue: LoginViewModel(app: viewModel))
    }

    /// iPhone in orizzontale: sfera e logo più piccoli, così il modulo ci sta.
    private var isCompactHeight: Bool { verticalSizeClass == .compact }

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
                        LoginFooter(version: model.version)
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
        .background { LoginBackdrop() }
        .sensoryFeedback(.error, trigger: model.shakes)
        .preferredColorScheme(.light)
        .onAppear(perform: enter)
        // Esito del link toccato nell'email: errore e scossone come per quello incollato.
        .onChange(of: model.openedLinkResult, initial: true) { _, result in
            guard result != nil else { return }
            focus = model.takeOpenedLinkResult()
        }
    }

    private func enter() {
        withAnimation(.spring(duration: 1.0, bounce: 0.28)) { orbIn = true }
        withAnimation(.spring(duration: 0.7, bounce: 0.15).delay(0.55)) { titleIn = true }
        withAnimation(.spring(duration: 0.7, bounce: 0.15).delay(0.85)) { formIn = true }
    }

    // MARK: - Sfera + logo

    private var hero: some View {
        VStack(spacing: isCompactHeight ? 12 : 22) {
            AriaOrb(mood: model.isBusy ? .thinking : .idle, radius: 0.8)
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
            if let sentTo = model.sentTo {
                VStack(spacing: 8) {
                    Text("Check your email: we sent a sign-in link to \(sentTo).")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                    if let notice = model.notice {
                        Label(notice, systemImage: "info.circle")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .transition(.opacity)
                    }
                }
                .multilineTextAlignment(.center)
                .frame(maxWidth: .infinity)
                .padding(.horizontal, 8)
            }

            VStack(spacing: 0) {
                card
                if model.showsCaptcha { captcha }
            }

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

            LoginPrimaryButton(title: model.sentTo == nil ? "Send sign-in link" : "Sign in",
                               isEnabled: model.isPrimaryEnabled, isBusy: model.isBusy, action: primaryAction)
                .id(Self.primaryID)

            if model.sentTo != nil {
                VStack(spacing: 10) {
                    Text("Copy the link from the email and paste it here. With Universal Clipboard you can copy it on your Mac. Don't open it in the browser: it works once and expires in 10 minutes.")
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
        .animation(.snappy(duration: 0.25), value: model.errorMessage)
        .animation(.snappy(duration: 0.25), value: model.isOffline)
        .animation(.snappy(duration: 0.25), value: model.sentTo)
        .animation(.snappy(duration: 0.25), value: model.notice)
        .animation(.snappy(duration: 0.25), value: model.captchaNeedsInteraction)
    }

    private var card: some View {
        VStack(spacing: 0) {
            if model.sentTo == nil { emailRow } else { linkRow }
        }
        .background(Color.liteSurface, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .strokeBorder(Color.liteBorder, lineWidth: 1)
        }
        .shadow(color: Color.liteAccent.opacity(0.06), radius: 20, x: 0, y: 8)
        .modifier(LoginShake(amount: CGFloat(model.shakes)))
        .animation(.linear(duration: 0.4), value: model.shakes)
    }

    private var emailRow: some View {
        LoginCardRow(icon: "envelope") {
            TextField("Work email", text: $model.email)
                .textContentType(.emailAddress)
                .keyboardType(.emailAddress)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                .submitLabel(.send)
                .focused($focus, equals: .email)
                .onSubmit(primaryAction)
        }
    }

    private var linkRow: some View {
        LoginCardRow(icon: "link") {
            TextField("Paste the sign-in link", text: $model.pastedLink)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                .keyboardType(.URL)
                .submitLabel(.go)
                .focused($focus, equals: .link)
                .onSubmit(primaryAction)
                // Incollato un link valido, si entra subito.
                .onChange(of: model.pastedLink) {
                    if model.pastedLinkIsReady { primaryAction() }
                }

            // Il pulsante di sistema non chiede il permesso di leggere gli appunti (come invece fa il menu "Incolla").
            PasteButton(supportedContentTypes: [.url, .plainText]) { providers in
                Task { @MainActor in await model.paste(providers) }
            }
            .labelStyle(.iconOnly)
            .buttonBorderShape(.capsule)
            .tint(Color.liteAccent)
        }
    }

    /// Captcha della web per il magic link: invisibile finché Turnstile non chiede un tocco.
    /// Un token nuovo dopo ogni invio (`captchaGeneration`).
    private var captcha: some View {
        AriaTurnstileView(siteKey: model.turnstileSiteKey, origin: model.turnstileOrigin) { event in
            model.captchaEvent(event)
        }
        .id(model.captchaGeneration)
        .frame(height: model.captchaNeedsInteraction ? 65 : 1)
        .opacity(model.captchaNeedsInteraction ? 1 : 0)
        .allowsHitTesting(model.captchaNeedsInteraction)
        .accessibilityHidden(!model.captchaNeedsInteraction)
        .padding(.top, model.captchaNeedsInteraction ? 16 : 0)
    }

    private static let primaryID = "login.primary"

    // MARK: - Azioni

    private func primaryAction() {
        guard model.isPrimaryEnabled else { return }
        focus = nil
        Task { focus = await model.primaryAction() }
    }

    private func useDifferentEmail() {
        model.useDifferentEmail()
        focus = .email
    }
}

#Preview {
    LoginView(viewModel: AppViewModel())
}
