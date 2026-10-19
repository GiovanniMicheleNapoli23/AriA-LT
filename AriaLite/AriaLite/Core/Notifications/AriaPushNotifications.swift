//
//  AriaPushNotifications.swift
//  AriaLite
//
//  Created by Giovanni Michele on 17/10/26.
//
//  Notifiche push dei lavori assegnati all'operatore (APNs).
//
//  • Il permesso si chiede quando l'operatore entra con l'account Aria; il token si registra a ogni
//    apertura e a ogni ritorno in primo piano (APNs lo può cambiare) e si manda al backend.
//  • Tocco sulla notifica → si apre il lavoro (`pendingWorkOrderId`, lo legge AriaShellView).
//    Notifica con l'app aperta → banner e la lista si ricarica (`lastArrival`).
//  • All'uscita il token si toglie dal server, prima che la sessione si chiuda: un altro operatore
//    sullo stesso telefono non riceve i lavori del precedente.
//
//  Contratto col backend (proposto: aria-backend non ha ancora le push, è un follow-up delle spec
//  2026-10-07). Finché le route non esistono il 404 si ignora in silenzio.
//
//      PUT    /v1/mobile/me/push-tokens/{token}   {platform, environment, bundleId, locale, appVersion}  → 204
//      DELETE /v1/mobile/me/push-tokens/{token}                                                          → 204
//
//  `token` è il device token APNs in esadecimale. Il PUT è un upsert sul token: se lo stesso telefono
//  entra con un altro account, il token passa al nuovo operatore. `environment` è "sandbox" (build da
//  Xcode) o "production" (TestFlight / App Store) e dice al server su quale host APNs mandarla.
//
//  Payload che l'app si aspetta:
//
//      {
//        "aps": {
//          "alert": { "title-loc-key": "WORK_ORDER_ASSIGNED_TITLE", "body": "<titolo dell'ordine>" },
//          "sound": "default",
//          "badge": 1,
//          "thread-id": "work-orders"
//        },
//        "type": "work_order_assigned",
//        "workOrderId": "<id dell'ordine>"
//      }
//
//  `title-loc-key` si traduce sul telefono (Localizable.xcstrings), così il server non deve sapere la lingua.
//

import Foundation
import Observation
import OSLog
import UIKit
import UserNotifications

/// Cosa porta una notifica di Aria, letto dallo `userInfo`.
nonisolated struct AriaPushPayload: Equatable, Sendable {
    enum Kind: String, Sendable {
        case workOrderAssigned = "work_order_assigned"
    }

    /// `nil` per un tipo che questa versione dell'app non conosce: l'ordine si apre lo stesso.
    let kind: Kind?
    let workOrderId: String

    init?(userInfo: [AnyHashable: Any]) {
        guard let id = (userInfo["workOrderId"] as? String)?.trimmingCharacters(in: .whitespacesAndNewlines),
              !id.isEmpty else { return nil }
        workOrderId = id
        kind = (userInfo["type"] as? String).flatMap(Kind.init(rawValue:))
    }
}

/// Body di PUT /v1/mobile/me/push-tokens/{token}.
private nonisolated struct AriaPushRegistration: Encodable, Sendable {
    let platform = "ios"
    let environment: String
    let bundleId: String
    let locale: String
    let appVersion: String
}

@Observable
final class AriaPushNotifications: NSObject {
    /// Unica: il delegate di UNUserNotificationCenter va messo all'avvio (AriaAppDelegate),
    /// prima che esista AppViewModel, o il tocco che apre l'app da chiusa va perso.
    static let shared = AriaPushNotifications()

    private(set) var authorization: UNAuthorizationStatus = .notDetermined
    /// Ordine toccato in una notifica, in attesa che la shell lo apra.
    var pendingWorkOrderId: String?
    /// Ultima notifica arrivata con l'app in primo piano: la lista si ricarica.
    private(set) var lastArrival: Date?

    @ObservationIgnored private weak var backend: AriaBackend?
    @ObservationIgnored private var deviceToken: String?
    /// Token già mandato al server in questa esecuzione: non si rimanda a ogni ritorno in primo piano.
    @ObservationIgnored private var uploadedToken: String?

    #if DEBUG
    @ObservationIgnored private let log = Logger(subsystem: "com.giovanniMichele.AriaLite", category: "push")
    #endif

    private override init() {
        super.init()
    }

    func attach(_ backend: AriaBackend) {
        self.backend = backend
    }

    // MARK: Permesso e registrazione

    /// Operatore dentro, app in primo piano: chiede il permesso la prima volta, poi registra il telefono.
    /// Senza permesso non si registra: se l'operatore lo dà più tardi da Impostazioni, al ritorno si riprova.
    func enable() async {
        let center = UNUserNotificationCenter.current()
        var status = await center.notificationSettings().authorizationStatus
        if status == .notDetermined {
            _ = try? await center.requestAuthorization(options: [.alert, .sound, .badge])
            status = await center.notificationSettings().authorizationStatus
        }
        authorization = status
        trace("authorization=\(status.rawValue)")
        guard status == .authorized || status == .provisional || status == .ephemeral else { return }
        UIApplication.shared.registerForRemoteNotifications()
    }

    /// Da AriaAppDelegate: APNs ha dato il token.
    func didRegister(_ token: Data) {
        let hex = Self.hex(token)
        trace("token \(hex.count) caratteri")
        if hex != deviceToken { uploadedToken = nil }
        deviceToken = hex
        Task { await upload() }
    }

    func didFailToRegister(_ error: any Error) {
        // Simulatore senza APNs, o capability Push Notifications mancante nel profilo.
        trace("registrazione fallita: \(error.localizedDescription)")
    }

    private func upload() async {
        guard let token = deviceToken, token != uploadedToken, let backend, backend.isSignedIn else { return }
        // Ogni chiamata /v1/mobile vuole il Company-Id.
        await backend.bootstrapIfNeeded()
        guard backend.isSignedIn, backend.activeCompanyId != nil else { return }
        let body = AriaPushRegistration(
            environment: AriaAPNsEnvironment.current.rawValue,
            bundleId: Bundle.main.bundleIdentifier ?? "",
            locale: backend.api.context.locale,
            appVersion: Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "")
        do {
            try await backend.api.perform("PUT", "v1/mobile/me/push-tokens/\(token)", body: body)
            uploadedToken = token
            trace("token registrato (\(body.environment))")
        } catch AriaError.http(let status, _) where status == 404 || status == 405 {
            trace("il backend non ha ancora la route dei token (\(status))")
        } catch {
            trace("token non registrato: \(error.localizedDescription)")
        }
    }

    /// Uscita dall'account: il server smette di mandare a questo telefono. Al massimo qualche secondo,
    /// poi la sessione si chiude comunque (senza rete il server la scarterà al primo invio fallito).
    func unregister() async {
        let center = UNUserNotificationCenter.current()
        // Le notifiche già ricevute portano i titoli dei lavori: non restano al prossimo operatore.
        center.removeAllDeliveredNotifications()
        try? await center.setBadgeCount(0)
        pendingWorkOrderId = nil
        lastArrival = nil
        guard let token = deviceToken, let api = backend?.api else { return }
        uploadedToken = nil
        await withTaskGroup(of: Void.self) { group in
            group.addTask { try? await api.perform("DELETE", "v1/mobile/me/push-tokens/\(token)") }
            group.addTask { try? await Task.sleep(for: .seconds(4)) }
            await group.next()
            group.cancelAll()
        }
    }

    /// App in primo piano: il numero sull'icona si azzera, la lista è già lì.
    func clearBadge() async {
        try? await UNUserNotificationCenter.current().setBadgeCount(0)
    }

    // MARK: Arrivo e tocco

    private func received(_ payload: AriaPushPayload) {
        trace("arrivata \(payload.kind?.rawValue ?? "tipo sconosciuto")")
        lastArrival = .now
    }

    private func opened(_ payload: AriaPushPayload) {
        trace("toccata \(payload.kind?.rawValue ?? "tipo sconosciuto")")
        pendingWorkOrderId = payload.workOrderId
    }

    // MARK: Utilità

    nonisolated static func hex(_ token: Data) -> String {
        token.map { String(format: "%02x", $0) }.joined()
    }

    private func trace(_ message: String) {
        #if DEBUG
        log.notice("\(message, privacy: .public)")
        #endif
    }
}

extension AriaPushNotifications: UNUserNotificationCenterDelegate {
    /// App aperta: la notifica si mostra lo stesso (di default iOS la nasconde).
    nonisolated func userNotificationCenter(_ center: UNUserNotificationCenter,
                                            willPresent notification: UNNotification) async -> UNNotificationPresentationOptions {
        if let payload = AriaPushPayload(userInfo: notification.request.content.userInfo) {
            await received(payload)
        }
        return [.banner, .list, .sound]
    }

    nonisolated func userNotificationCenter(_ center: UNUserNotificationCenter,
                                            didReceive response: UNNotificationResponse) async {
        guard response.actionIdentifier == UNNotificationDefaultActionIdentifier,
              let payload = AriaPushPayload(userInfo: response.notification.request.content.userInfo) else { return }
        await opened(payload)
    }
}

/// Host APNs a cui il server deve mandare per questo build.
nonisolated enum AriaAPNsEnvironment: String, Sendable {
    case sandbox, production

    /// Build da Xcode (e ad hoc firmati in development) hanno il profilo incluso con `aps-environment`;
    /// TestFlight e App Store non lo includono e sono sempre production.
    static let current: AriaAPNsEnvironment = {
        #if targetEnvironment(simulator)
        return .sandbox
        #else
        guard let url = Bundle.main.url(forResource: "embedded", withExtension: "mobileprovision"),
              let data = try? Data(contentsOf: url),
              let start = data.range(of: Data("<?xml".utf8)),
              let end = data.range(of: Data("</plist>".utf8), in: start.lowerBound..<data.endIndex),
              let plist = try? PropertyListSerialization.propertyList(
                from: data[start.lowerBound..<end.upperBound], format: nil) as? [String: Any],
              let entitlements = plist["Entitlements"] as? [String: Any],
              let value = entitlements["aps-environment"] as? String
        else { return .production }
        return value == "development" ? .sandbox : .production
        #endif
    }()
}
