//
//  APIClientTests.swift
//  AriaLiteTests
//
//  Created by Giovanni Michele on 15/10/26.
//
//  Il client HTTP: header comuni, host giusto per ogni chiamata, un solo retry su 401, operatore
//  disabilitato, host giù, limite del body, mai cookie.
//

import Foundation
import Testing
@testable import AriaLite

extension BackendTests {
    @Suite("API client")
    struct APIClient {
        private let server = StubServer.shared

        init() { TestEnv.reset() }

        private func me() -> String {
            #"{"id":"u1","name":"M","email":"m@a.b","specialties":[],"availability":"available","availabilityAt":null}"#
        }

        @Test func mobileCallsGoToTheAPIHostWithAllCommonHeaders() async throws {
            let client = try await TestEnv.signedInClient()
            server.route("GET /v1/mobile/me", .json(me()))

            let profile: AriaMobileProfile = try await client.get("v1/mobile/me")

            #expect(profile.email == "m@a.b")
            let call = try #require(server.calls("GET /v1/mobile/me").first)
            #expect(call.host == TestEnv.apiHost)
            #expect(call.header("authorization") == "Bearer \(TestEnv.jwt(tag: "a"))")
            #expect(call.header("company-id") == "c1")
            #expect(call.header("ngrok-skip-browser-warning") == nil)
            #expect(call.header("user-agent")?.hasPrefix("AriaPLT-Mobile/") == true)
            #expect(call.header("x-aria-client")?.hasPrefix("aria-ios/") == true)
            #expect(call.header("accept") == "application/json")
            #expect(["it", "en"].contains(call.header("accept-language") ?? ""))
        }

        @Test func dataCallsGoToTheAPIHostWithCompanyId() async throws {
            let client = try await TestEnv.signedInClient()
            server.route("GET /v1/plants", .json("[]"))
            let plants: [AriaPlant] = try await client.get("v1/plants")
            #expect(plants.isEmpty)
            let call = try #require(server.calls("GET /v1/plants").first)
            #expect(call.host == TestEnv.apiHost)
            #expect(call.header("company-id") == "c1")
        }

        @Test func companiesLookupSkipsTheCompanyId() async throws {
            let client = try await TestEnv.signedInClient()
            server.route("GET /v1/companies", .json("[]"))
            let _: [AriaCompany] = try await client.get("v1/companies", companyScoped: false)
            #expect(server.calls("GET /v1/companies").last?.header("company-id") == nil)
        }

        @Test func queryItemsAreAppendedInOrder() async throws {
            let client = try await TestEnv.signedInClient()
            server.route("GET /v1/mobile/work-orders", .json("[]"))
            let _: AriaWorkOrderList = try await client.get(
                "v1/mobile/work-orders",
                query: [URLQueryItem(name: "status", value: "open"), URLQueryItem(name: "limit", value: "50")])
            #expect(server.calls("GET /v1/mobile/work-orders").first?.query == "status=open&limit=50")
        }

        // MARK: 401

        @Test func a401MintsANewJWTAndRetriesOnce() async throws {
            let client = try await TestEnv.signedInClient()
            server.route("GET /api/aria/token", TestEnv.tokenReply(tag: "second"))
            server.route("GET /v1/mobile/me", .json(#"{"error":"expired"}"#, status: 401), .json(me()))

            let profile: AriaMobileProfile = try await client.get("v1/mobile/me")

            #expect(profile.name == "M")
            let calls = server.calls("GET /v1/mobile/me")
            #expect(calls.count == 2)
            #expect(calls[0].header("authorization") != calls[1].header("authorization"), "il retry usa un JWT nuovo")
        }

        @Test func aSecond401IsReturnedInsteadOfLooping() async throws {
            let client = try await TestEnv.signedInClient()
            server.route("GET /v1/mobile/me", .json(#"{"detail":"nope"}"#, status: 401))
            await #expect { let _: AriaMobileProfile = try await client.get("v1/mobile/me") } throws: { error in
                if case AriaError.http(401, _) = error { true } else { false }
            }
            #expect(server.calls("GET /v1/mobile/me").count == 2, "un solo retry")
        }

        // MARK: 403

        @Test func notAMemberSignsTheOperatorOut() async throws {
            let client = try await TestEnv.signedInClient()
            server.route("GET /v1/mobile/me", .json(#"{"detail":"Not a member of this company"}"#, status: 403))
            await #expect { let _: AriaMobileProfile = try await client.get("v1/mobile/me") } throws: { error in
                if case AriaError.signedOut = error { true } else { false }
            }
            #expect(!client.auth.hasStoredLogin, "stato locale azzerato")
        }

        @Test func otherForbiddenResponsesRejectOnlyThatAction() async throws {
            let client = try await TestEnv.signedInClient()
            server.route("GET /v1/mobile/me", .json(#"{"detail":"Forbidden"}"#, status: 403))
            await #expect { let _: AriaMobileProfile = try await client.get("v1/mobile/me") } throws: { error in
                if case AriaError.http(403, _) = error { true } else { false }
            }
            #expect(client.auth.hasStoredLogin)
        }

        @Test func notAMobileUserIsReported() async throws {
            let client = try await TestEnv.signedInClient()
            server.route("GET /v1/mobile/me", .json(#"{"code":"not_a_mobile_user"}"#, status: 403))
            await #expect { let _: AriaMobileProfile = try await client.get("v1/mobile/me") } throws: { error in
                if case AriaError.notMobileUser = error { true } else { false }
            }
            #expect(client.auth.hasStoredLogin)
        }

        // MARK: Host giù e rete

        @Test func gatewayErrorIsOfflineNotAnAPIError() async throws {
            let client = try await TestEnv.signedInClient()
            server.route("GET /v1/mobile/me", .hostDown())
            await #expect { let _: AriaMobileProfile = try await client.get("v1/mobile/me") } throws: { error in
                if case AriaError.signInHostOffline = error { true } else { false }
            }
        }

        @Test func networkErrorsPropagateAsURLError() async throws {
            let client = try await TestEnv.signedInClient()
            server.route("GET /v1/mobile/me", .failing(.notConnectedToInternet))
            await #expect { let _: AriaMobileProfile = try await client.get("v1/mobile/me") } throws: { error in
                AriaHTTP.isOffline(error)
            }
        }

        @Test func malformedBodyBecomesADecodingErrorNamingTheType() async throws {
            let client = try await TestEnv.signedInClient()
            server.route("GET /v1/mobile/me", .json(#"{"unexpected":true}"#))
            await #expect { let _: AriaMobileProfile = try await client.get("v1/mobile/me") } throws: { error in
                if case AriaError.decoding(let message) = error { message.contains("AriaMobileProfile") } else { false }
            }
        }

        @Test func missingCompanyIdFromTheServerIsAClearHTTPError() async throws {
            let client = try await TestEnv.signedInClient()
            server.route("GET /v1/mobile/me", .json(#"{"detail":"Missing Company-Id header"}"#, status: 400))
            await #expect { let _: AriaMobileProfile = try await client.get("v1/mobile/me") } throws: { error in
                if case AriaError.http(400, let detail) = error { detail.contains("Company-Id") } else { false }
            }
        }

        // MARK: Body e cookie

        @Test func theWAFBodyLimitAppliesToEveryCall() async throws {
            let client = try await TestEnv.signedInClient()
            let big = ["text": String(repeating: "x", count: 9000)]
            server.route("POST /v1/big", .json("{}"))

            await #expect { let _: [String: String] = try await client.send("POST", "v1/big", body: big) } throws: { error in
                if case AriaError.bodyTooLarge = error { true } else { false }
            }
            #expect(server.calls("POST /v1/big").isEmpty, "non esce nemmeno la richiesta")
        }

        @Test func cookiesAreNeverSentOrStored() async throws {
            let client = try await TestEnv.signedInClient()
            HTTPCookieStorage.shared.setCookie(HTTPCookie(properties: [
                .domain: TestEnv.authHost, .path: "/", .name: "sid", .value: "leak"])!)
            server.route("GET /v1/mobile/me", .json(me(), headers: ["Set-Cookie": "tracking=1; Path=/"]))

            let _: AriaMobileProfile = try await client.get("v1/mobile/me")

            #expect(server.calls("GET /v1/mobile/me").first?.header("cookie") == nil)
            let stored = HTTPCookieStorage.shared.cookies(for: URL(string: "https://\(TestEnv.authHost)/")!) ?? []
            #expect(!stored.contains { $0.name == "tracking" })
        }

        @Test func developerTokenTalksToTheAPIHostEvenForMobilePaths() async throws {
            TestEnv.reset()
            let auth = AriaAuth(config: TestEnv.config)
            try await auth.useDeveloperToken(TestEnv.jwt())
            let client = AriaAPIClient(config: TestEnv.config, auth: auth, context: AriaContext())
            server.route("GET /v1/mobile/me", .json(me()))
            let _: AriaMobileProfile = try await client.get("v1/mobile/me")
            #expect(server.calls("GET /v1/mobile/me").first?.host == TestEnv.apiHost)
            #expect(server.calls("GET /v1/mobile/me").first?.header("ngrok-skip-browser-warning") == nil)
        }
    }
}
