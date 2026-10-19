//
//  PushPayloadTests.swift
//  AriaLiteTests
//
//  Created by Giovanni Michele on 17/10/26.
//
//  AriaPushPayload e il token APNs: cosa l'app legge da una notifica e cosa manda al server.
//

import Foundation
import Testing
@testable import AriaLite

struct PushPayloadTests {
    @Test func anAssignedWorkOrderIsRead() {
        let payload = AriaPushPayload(userInfo: [
            "aps": ["alert": ["title-loc-key": "WORK_ORDER_ASSIGNED_TITLE", "body": "Pump P-101 inspection"]],
            "type": "work_order_assigned",
            "workOrderId": "6710a2f4c9e77b0012ab34cd",
        ])

        #expect(payload?.kind == .workOrderAssigned)
        #expect(payload?.workOrderId == "6710a2f4c9e77b0012ab34cd")
    }

    @Test func anUnknownTypeStillOpensTheOrder() {
        let payload = AriaPushPayload(userInfo: ["type": "work_order_reassigned", "workOrderId": "abc"])

        #expect(payload?.kind == nil)
        #expect(payload?.workOrderId == "abc")
    }

    @Test func withoutAnOrderIdThereIsNothingToOpen() {
        #expect(AriaPushPayload(userInfo: ["type": "work_order_assigned"]) == nil)
        #expect(AriaPushPayload(userInfo: ["workOrderId": "  "]) == nil)
        #expect(AriaPushPayload(userInfo: ["workOrderId": 42]) == nil)
    }

    @Test func theTokenIsLowercaseHex() {
        let token = Data([0x00, 0x0f, 0xa0, 0xff])

        #expect(AriaPushNotifications.hex(token) == "000fa0ff")
    }

    @Test func theAssignedTitleIsTranslated() {
        // `title-loc-key` cerca la chiave nel catalogo dell'app: se manca, iOS mostra la chiave così com'è.
        let title = Bundle(for: AriaPushNotifications.self).localizedString(
            forKey: "WORK_ORDER_ASSIGNED_TITLE", value: nil, table: nil)

        #expect(title != "WORK_ORDER_ASSIGNED_TITLE")
    }
}
