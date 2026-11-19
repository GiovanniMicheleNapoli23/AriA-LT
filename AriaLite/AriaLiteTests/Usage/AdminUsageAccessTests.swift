//
//  AdminUsageAccessTests.swift
//  AriaLiteTests
//
//  Created by Giovanni Michele on 18/11/26.
//
//  Chi vede la voce "Usage" (contratto 2) e come si classifica un errore della sezione (contratto 7): titolare, membro
//  con i ruoli accesi e la sessione che segue il ruolo, azienda "legacy", blocco `access` assente; config in lettura,
//  fallita, con i consumi spenti; 403 `operation_forbidden`, `session_ended`, 403 di una chiamata da titolare.
//

import Foundation
import Testing
@testable import AriaLite

private typealias Fx = UsageFixture

@Suite("Usage section access")
struct AdminUsageAccessTests {
    private func rights(model: String = "rbac", admin: Bool = false, follows: Bool = true, granted: Bool = true,
                        roleEnabled: Bool = true) -> AriaRights {
        let role = AriaAccess.Role(id: "r1", name: "Planner", enabled: roleEnabled)
        let access = AriaAccess(model: model, role: role, admin: admin,
                                sections: ["llm_usage": AriaAccess.Grant(granted: granted, actions: [])],
                                version: "v1", appFollowsRole: follows)
        return AriaRights(access: access)
    }

    private func visible() throws -> AriaUsageConfig { try Fx.adminConfig() }

    private func hiddenByCompany() throws -> AriaUsageConfig {
        try Fx.adminConfig(replacing: ["billing": ["customer_visibility": false]])
    }

    private func entry(_ config: AriaUsageConfig?, _ phase: AriaUsageStore.Phase = .loaded, unavailable: Bool = false,
                       rights: AriaRights) -> AdminUsageAccess.Entry {
        AdminUsageAccess.entry(config: config, configPhase: phase, isUnavailable: unavailable, rights: rights)
    }

    // MARK: Chi può aprirla

    @Test func anOwnerMayOpenItWhateverTheModel() {
        #expect(AdminUsageAccess.mayOpen(rights(model: "rbac", admin: true, follows: false, granted: false)))
        #expect(AdminUsageAccess.mayOpen(rights(model: "legacy", admin: true, follows: false, granted: false)))
    }

    @Test func aMemberNeedsRolesTheSessionFollowingTheRoleAndTheSectionGranted() {
        #expect(AdminUsageAccess.mayOpen(rights()))
        // Senza `appFollowsRole` le rotte rispondono 403 `operation_forbidden`.
        #expect(!AdminUsageAccess.mayOpen(rights(follows: false)))
        #expect(!AdminUsageAccess.mayOpen(rights(granted: false)))
        // Un ruolo in pausa non apre niente.
        #expect(!AdminUsageAccess.mayOpen(rights(roleEnabled: false)))
    }

    @Test func aLegacyCompanyHasTheSectionForItsOwnersOnly() {
        #expect(!AdminUsageAccess.mayOpen(rights(model: "legacy", admin: false, follows: true, granted: true)))
    }

    @Test func noAccessBlockMeansAnOlderServerAndTreatsTheSessionLikeAnOwner() {
        #expect(AdminUsageAccess.mayOpen(AriaRights(access: nil)))
        #expect(AdminUsageAccess.mayOpen(.unrestricted))
    }

    // MARK: La voce

    @Test func shownWhenCustomersSeeUsageAndThePersonMayOpenIt() throws {
        #expect(try entry(visible(), rights: rights(admin: true)) == .shown)
        #expect(try entry(visible(), rights: rights()) == .shown)
        #expect(try entry(visible(), rights: .unrestricted) == .shown)
    }

    @Test func hiddenOnceCustomersMayNotSeeUsage() throws {
        #expect(try entry(hiddenByCompany(), rights: rights(admin: true)) == .hidden)
    }

    @Test func hiddenWhenThePersonMayNotOpenItWhateverTheConfigSays() throws {
        #expect(try entry(visible(), rights: rights(follows: false)) == .hidden)
        // Anche mentre la config si legge: niente "caricamento" per chi non ha comunque l'accesso.
        #expect(entry(nil, .loading, rights: rights(granted: false)) == .hidden)
    }

    @Test func loadingWhileTheConfigHasNotAnswered() {
        #expect(entry(nil, .idle, rights: rights(admin: true)) == .loading)
        #expect(entry(nil, .loading, rights: rights(admin: true)) == .loading)
    }

    @Test func shownWhenTheConfigFailedSoThePageCanOfferRetry() {
        #expect(entry(nil, .failed, rights: rights(admin: true)) == .shown)
    }

    @Test func hiddenWhenTheBackendHasNoRoutes() throws {
        #expect(try entry(visible(), unavailable: true, rights: rights(admin: true)) == .hidden)
        #expect(entry(nil, .loading, unavailable: true, rights: rights(admin: true)) == .hidden)
    }

    @Test func aMissingCustomerVisibilityIsNotTrue() throws {
        let oldServer = try Fx.adminConfig(replacing: ["billing": nil])

        #expect(entry(oldServer, rights: rights(admin: true)) == .hidden)
    }
}

@Suite("Usage failure handling")
struct AdminUsageFailureTests {
    @Test func aCancelledCallIsNotAnError() {
        #expect(AdminUsageFailure.classify(CancellationError()) == .cancelled)
        #expect(AdminUsageFailure.classify(URLError(.cancelled)) == .cancelled)
        // Sessione ancora chiusa da Face ID: niente da fare.
        #expect(AdminUsageFailure.classify(AriaError.locked) == .cancelled)
    }

    @Test func aSignedOutSessionAndAnEndedOneAreToldApart() {
        #expect(AdminUsageFailure.classify(AriaError.signedOut) == .signedOut)
        #expect(AdminUsageFailure.classify(AriaError.sessionEnded) == .sessionEnded)
    }

    @Test func operationForbiddenClosesTheSection() {
        #expect(AdminUsageFailure.classify(AriaError.notOnPhone) == .sectionClosed)
        #expect(AdminUsageFailure.classify(AriaError.notOnPhone, ownerCall: true) == .sectionClosed)
    }

    @Test func aPlainForbiddenOnAnOwnerCallHidesTheOwnerPartsAndOnAnyOtherCallIsAFailure() {
        let plain = AriaError.http(status: 403, detail: "Insufficient role")
        let denied = AriaError.permissionDenied(AriaPermissionDenial(reason: "no_section"))

        #expect(AdminUsageFailure.classify(plain, ownerCall: true) == .ownerRefused)
        #expect(AdminUsageFailure.classify(denied, ownerCall: true) == .ownerRefused)
        #expect(AdminUsageFailure.classify(plain) == .failed)
        #expect(AdminUsageFailure.classify(denied) == .failed)
    }

    @Test func aServiceUnavailableAndAnythingElseShowNoNumbersAndRetry() {
        #expect(AdminUsageFailure.classify(AriaError.http(status: 503, detail: "Usage figures cannot be read")) == .failed)
        #expect(AdminUsageFailure.classify(AriaError.http(status: 422, detail: "bad range")) == .failed)
        #expect(AdminUsageFailure.classify(AriaError.serverOffline) == .failed)
        #expect(AdminUsageFailure.classify(URLError(.notConnectedToInternet)) == .failed)
        #expect(AdminUsageFailure.classify(AriaError.decoding("x")) == .failed)
    }
}
