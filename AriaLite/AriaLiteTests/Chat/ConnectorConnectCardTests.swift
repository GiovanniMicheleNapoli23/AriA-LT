//
//  ConnectorConnectCardTests.swift
//  AriaLiteTests
//
//  Created by Giovanni Michele on 29/10/26.
//
//  La card `connector-connect` della chat: cosa si legge dai dati, quali link passano e quando c'è
//  il pulsante per la web.
//

import Foundation
import Testing
@testable import AriaLite

struct ConnectorConnectCardTests {
    private func data(_ json: String) throws -> [String: AriaJSON] {
        try #require(try JSONDecoder().decode(AriaJSON.self, from: Data(json.utf8)).objectValue)
    }

    @Test func readsTheContractShape() throws {
        let card = try #require(AriaArtifactContent.connectorConnect(data("""
        {"provider":"gmail-personal","label":"Gmail","scope":"member","flow":"composio","state":"not_connected",
         "callerCan":"connect","guide":{"slug":"gmail-personal","title":"Gmail","lastChecked":"2026-10-23",
         "sources":[{"label":"Google","url":"https://support.google.com/x","checked":"2026-10-23"},
                    {"label":"Plain","url":"http://example.com"},{"label":"Bad","url":"javascript:alert(1)"}]}}
        """)))
        #expect(card.title == "Gmail")
        #expect(card.stateLine != nil)
        #expect(card.sources.map(\.label) == ["Google"], "solo link https con un host")
        #expect(card.showsWebButton)
    }

    @Test func noButtonWhenNobodyCanConnectOrNotAvailable() throws {
        let none = try #require(AriaArtifactContent.connectorConnect(data(#"{"provider":"teams","state":"needs_admin","callerCan":"none"}"#)))
        #expect(!none.showsWebButton)
        #expect(none.title == "teams")
        let unavailable = try #require(AriaArtifactContent.connectorConnect(
            data(#"{"label":"Slack","state":"not_available","callerCan":"connect"}"#)))
        #expect(!unavailable.showsWebButton)
    }

    @Test func unknownValuesDoNotBreakTheCard() throws {
        let card = try #require(AriaArtifactContent.connectorConnect(data(#"{"label":"Asana","state":"brand_new"}"#)))
        #expect(card.stateLine == nil)
        #expect(card.sources.isEmpty)
        #expect(try AriaArtifactContent.connectorConnect(data(#"{"state":"not_connected"}"#)) == nil)
    }
}
