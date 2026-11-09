//
//  LoginViewModel.swift
//  AriaLite
//
//  Created by Giovanni Michele on 22/10/26.
//
//  Tutta la logica del login. Un solo campo email per i due tipi di account:
//  1) "Send sign-in link" manda insieme il link dell'operatore e, con il captcha Turnstile (di solito
//     pronto in silenzio), il magic link della web. Solo il tipo di account giusto riceve un'email;
//     senza captcha parte solo il link dell'operatore, con una nota.
//  2) Il link si tocca nell'email (AppViewModel.open) o si incolla qui: la sua forma decide come entrare.
//  La vista mostra lo stato e passa le azioni; il fuoco dei campi e le animazioni restano a lei.
//

import Foundation
import Observation
import UniformTypeIdentifiers

@MainActor
@Observable
final class LoginViewModel {
    let app: AppViewModel

    var email = ""
    var pastedLink = ""
    /// Un link vale una volta sola: se è già fallito non lo si rimanda al server.
    private var failedLink: String?
    /// Messaggio sotto la card: link non valido o errore del server Aria.
    private(set) var errorMessage: String?
    /// Il server non si raggiunge: avviso "offline" al posto dell'errore rosso.
    private(set) var isOffline = false
    /// Uno dei due link non è partito per un motivo risolvibile (captcha non pronto, troppi tentativi):
    /// una nota discreta sotto "controlla l'email", non un errore.
    private(set) var notice: String?
    private(set) var isLoading = false
    /// Cresce a ogni errore: la card si scuote.
    private(set) var shakes = 0

    /// Token Turnstile pronto (5', una volta sola).
    private(set) var captcha: String?
    private(set) var captchaFailed = false
    /// Turnstile chiede un tocco: il riquadro si mostra.
    private(set) var captchaNeedsInteraction = false
    /// Cambia dopo ogni invio: la vista ricrea il widget e Turnstile conia un token nuovo.
    private(set) var captchaGeneration = 0

    init(app: AppViewModel) {
        self.app = app
    }

    // MARK: Stato

    /// Email a cui sono partiti i link (in attesa di essere toccati o incollati): passo 2.
    var sentTo: String? { app.backend.pendingLinkEmail }

    /// In attesa del server: invio dei link, link incollato o link toccato nell'email.
    var isBusy: Bool { isLoading || app.isOpeningLink }

    var canSend: Bool {
        !email.trimmingCharacters(in: .whitespaces).isEmpty && !isBusy
    }

    var canSignIn: Bool {
        !pastedLink.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && !isBusy
    }

    var isPrimaryEnabled: Bool { sentTo == nil ? canSend : canSignIn }

    /// Il captcha serve solo per mandare il magic link: al passo dell'email.
    var showsCaptcha: Bool { sentTo == nil }

    var turnstileSiteKey: String { app.backend.api.config.turnstileSiteKey }
    var turnstileOrigin: URL { app.backend.webURL }

    /// Esito del link toccato nell'email, da mostrare come quello incollato.
    var openedLinkResult: AppViewModel.LoginResult? { app.openedLinkResult }

    var version: String {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "1.0"
    }

    // MARK: Captcha

    func captchaEvent(_ event: AriaTurnstileEvent) {
        switch event {
        case .token(let token):
            captcha = token
            captchaFailed = false
            captchaNeedsInteraction = false
        case .expired:
            captcha = nil
        case .failed:
            captcha = nil
            captchaFailed = true
            captchaNeedsInteraction = false
        case .needsInteraction(let needed):
            captchaNeedsInteraction = needed
        }
        AriaAuthTrace.step("captcha.event", Self.traceLabel(event))
    }

    /// Il token, se c'è. Turnstile lavora mentre l'utente scrive: se è stato più veloce si aspetta un poco,
    /// mai a lungo (né se serve un tocco: il link dell'operatore parte comunque).
    private func readyCaptcha() async -> String? {
        let deadline = ContinuousClock.now + .seconds(3)
        while captcha == nil, !captchaFailed, !captchaNeedsInteraction, ContinuousClock.now < deadline {
            try? await Task.sleep(for: .milliseconds(150))
        }
        return captcha
    }

    /// Il token vale una volta sola: dopo ogni invio se ne genera uno nuovo.
    private func renewCaptcha() {
        captcha = nil
        captchaFailed = false
        captchaNeedsInteraction = false
        captchaGeneration += 1
    }

    // MARK: Azioni

    /// Il pulsante principale: manda i link (passo 1) o entra con quello incollato (passo 2).
    /// Restituisce il campo da mettere a fuoco.
    func primaryAction() async -> LoginField? {
        sentTo == nil ? await sendLink() : await signIn()
    }

    /// Passo 1: i due link insieme. Basta che ne parta uno.
    func sendLink() async -> LoginField? {
        guard canSend else { return nil }
        startRequest()
        notice = nil
        defer { isLoading = false }
        let token = await readyCaptcha()
        AriaAuthTrace.step("login.sendLink", "server=\(app.backend.authURL.absoluteString) captcha=\(token != nil)")
        renewCaptcha()
        do {
            let delivery = try await app.backend.sendSignInLink(email: email, captcha: token)
            notice = delivery.note
            return .link
        } catch {
            AriaAuthTrace.failure("login.sendLink.failed", error)
            return handle(AriaHTTP.isOffline(error) ? .offline : .failure(error.localizedDescription), field: .email)
        }
    }

    /// Passo 2: il link incollato, dell'operatore o della web.
    func signIn() async -> LoginField? {
        let text = pastedLink.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty, !isBusy else { return nil }
        startRequest()
        let result = await app.completeLogin(with: text)
        isLoading = false
        if case .failure = result { failedLink = pastedLink }
        return handle(result, field: .link)
    }

    /// Incollato un link valido (e non già fallito), si entra subito.
    var pastedLinkIsReady: Bool {
        app.backend.magicLink(in: pastedLink) != nil && pastedLink != failedLink
    }

    /// Il pulsante Incolla di sistema: un link copiato arriva come URL (Mail, Safari, appunti condivisi)
    /// o come testo, si accettano entrambi.
    func paste(_ providers: [NSItemProvider]) async {
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
        pastedLink = parts.joined(separator: " ")
    }

    /// L'esito del link toccato nell'email, poi azzerato: errore e scossone come per quello incollato.
    func takeOpenedLinkResult() -> LoginField? {
        guard let result = app.openedLinkResult else { return nil }
        app.openedLinkResult = nil
        return handle(result, field: .link)
    }

    /// Torna al passo dell'email, per chiedere nuovi link.
    func useDifferentEmail() {
        app.backend.cancelPendingLink()
        pastedLink = ""
        failedLink = nil
        errorMessage = nil
        isOffline = false
        notice = nil
    }

    private func startRequest() {
        isLoading = true
        errorMessage = nil
        isOffline = false
    }

    private func handle(_ result: AppViewModel.LoginResult, field: LoginField) -> LoginField? {
        switch result {
        case .success:
            return nil
        case .offline:
            isOffline = true
            shakes += 1
            return nil
        case .failure(let message):
            errorMessage = message
            shakes += 1
            return field
        }
    }

    private static func traceLabel(_ event: AriaTurnstileEvent) -> String {
        switch event {
        case .token(let token): "token \(token.count) caratteri"
        case .expired: "scaduto"
        case .failed: "errore"
        case .needsInteraction(let needed): needed ? "serve un tocco" : "tocco fatto"
        }
    }
}
