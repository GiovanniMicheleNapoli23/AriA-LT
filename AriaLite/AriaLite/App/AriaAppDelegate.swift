//
//  AriaAppDelegate.swift
//  AriaLite
//
//  Created by Giovanni Michele on 17/10/26.
//
//  Solo quello che SwiftUI non dà: il token APNs e il delegate delle notifiche messo all'avvio,
//  così anche il tocco che apre l'app da chiusa arriva (AriaPushNotifications).
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
}
