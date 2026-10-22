//
//  AriaPushNotifications.swift
//  AriaLite
//
//  Created by Giovanni Michele on 17/10/26.
//
//  Notifiche push dei lavori assegnati all'operatore (APNs).
//
//  • Il permesso si chiede quando l'operatore entra con l'account Aria; il telefono si registra ad APNs a
//    ogni apertura e a ogni ritorno in primo piano (APNs può cambiare il token).
//  • Tocco sulla notifica → si apre il lavoro (`pendingWorkOrderId`, lo legge AriaShellView).
//    Notifica con l'app aperta → banner e la lista si ricarica (`lastArrival`).
//  • All'uscita le notifiche ricevute e il numero sull'icona si cancellano: un altro operatore sullo
//    stesso telefono non vede i lavori del precedente.
//
//  Il token NON si manda al backend: la guida "operator member parity" (20/10/2026) dice che nessuna rotta
//  per i token esiste ancora e di non registrarlo su un percorso indovinato (quello proposto prima,
//  /v1/mobile/me/push-tokens, non esiste più). Il contratto arriverà con un documento suo.
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

    /// Il device token APNs in esadecimale: pronto per quando il backend avrà la rotta per registrarlo.
    @ObservationIgnored private(set) var deviceToken: String?

    #if DEBUG
    @ObservationIgnored private let log = Logger(subsystem: "com.giovanniMichele.AriaLite", category: "push")
    #endif

    private override init() {
        super.init()
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

    /// Da AriaAppDelegate: APNs ha dato il token. Resta sul telefono (vedi l'intestazione).
    func didRegister(_ token: Data) {
        deviceToken = Self.hex(token)
        trace("token \(deviceToken?.count ?? 0) caratteri")
    }

    func didFailToRegister(_ error: any Error) {
        // Simulatore senza APNs, o capability Push Notifications mancante nel profilo.
        trace("registrazione fallita: \(error.localizedDescription)")
    }

    /// Uscita dall'account: le notifiche già ricevute portano i titoli dei lavori, non restano al prossimo operatore.
    func unregister() async {
        let center = UNUserNotificationCenter.current()
        center.removeAllDeliveredNotifications()
        try? await center.setBadgeCount(0)
        pendingWorkOrderId = nil
        lastArrival = nil
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
