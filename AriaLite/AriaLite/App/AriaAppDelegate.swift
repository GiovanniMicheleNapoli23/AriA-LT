//
//  AriaAppDelegate.swift
//  AriaLite
//
//  Created by Giovanni Michele on 17/10/26.
//
//  Solo quello che SwiftUI non dà: il token APNs e il delegate delle notifiche messo all'avvio,
//  così anche il tocco che apre l'app da chiusa arriva (AriaPushNotifications), e la fine dei caricamenti
//  di documenti in background quando il sistema riapre l'app solo per quella (AdminDocumentUploadSession).
//

import UIKit
import UserNotifications

final class AriaAppDelegate: NSObject, UIApplicationDelegate {
    func application(_ application: UIApplication,
                     didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil) -> Bool {
        UNUserNotificationCenter.current().delegate = AriaPushNotifications.shared
        return true
    }

    func application(_ application: UIApplication, didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data) {
        AriaPushNotifications.shared.didRegister(deviceToken)
    }

    func application(_ application: UIApplication, didFailToRegisterForRemoteNotificationsWithError error: any Error) {
        AriaPushNotifications.shared.didFailToRegister(error)
    }

    func application(_ application: UIApplication, handleEventsForBackgroundURLSession identifier: String,
                     completionHandler: @escaping () -> Void) {
        guard identifier == AdminDocumentUploadSession.identifier else { return completionHandler() }
        nonisolated(unsafe) let completion = completionHandler
        AdminDocumentUploadSession.shared.handleEvents { completion() }
    }
}
