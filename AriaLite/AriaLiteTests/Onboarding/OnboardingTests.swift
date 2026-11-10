//
//  OnboardingTests.swift
//  AriaLiteTests
//
//  Created by Giovanni Michele on 10/11/26.
//
//  La presentazione dell'app: scelta del ruolo, pagine avanti e indietro, chiusura e il ricordo di averla vista.
//

import Foundation
import Testing
@testable import AriaLite

@MainActor
struct OnboardingViewModelTests {
    @Test func startsOnTheAudienceChoice() {
        let model = AriaOnboardingViewModel(origin: .firstLaunch) {}
        #expect(model.audience == nil)
        #expect(model.pages.isEmpty)
        #expect(model.audiences == [.technician, .admin])
    }

    @Test func choosingAnAudienceShowsItsPagesFromTheFirst() {
        let model = AriaOnboardingViewModel(origin: .firstLaunch) {}
        model.choose(.admin)
        model.pageIndex = 3
        model.choose(.technician)
        #expect(model.audience == .technician)
        #expect(model.pageIndex == 0)
        #expect(model.pages.map(\.id) == AriaOnboardingPage.technician.map(\.id))
    }

    @Test func theOrbBadgeFollowsThePage() {
        let model = AriaOnboardingViewModel(origin: .firstLaunch) {}
        #expect(model.currentSymbol == nil, "nella scelta del ruolo la sfera non ha medaglione")
        model.choose(.admin)
        #expect(model.currentSymbol == AriaOnboardingPage.admin[0].symbol)
        model.next()
        #expect(model.currentSymbol == AriaOnboardingPage.admin[1].symbol)
        model.back()
        model.back()
        #expect(model.currentSymbol == nil)
        #expect(!model.isLastPage, "senza pagine nessun pulsante dell'ultima pagina")
    }

    @Test func nextWalksThePagesThenFinishes() {
        var finished = 0
        let model = AriaOnboardingViewModel(origin: .firstLaunch) { finished += 1 }
        model.choose(.technician)
        for _ in 1..<model.pages.count { model.next() }
        #expect(model.isLastPage)
        #expect(finished == 0)
        model.next()
        #expect(finished == 1)
    }

    @Test func backFromTheFirstPageReturnsToTheChoice() {
        let model = AriaOnboardingViewModel(origin: .profile) {}
        model.choose(.admin)
        model.next()
        model.back()
        #expect(model.pageIndex == 0)
        #expect(model.audience == .admin)
        model.back()
        #expect(model.audience == nil)
    }

    @Test func skipFinishesFromAnyScreen() {
        var finished = 0
        let model = AriaOnboardingViewModel(origin: .firstLaunch) { finished += 1 }
        model.finish()
        #expect(finished == 1)
    }

    @Test func theLastButtonDependsOnWhereTheTourStarted() {
        let first = AriaOnboardingViewModel(origin: .firstLaunch) {}
        first.choose(.technician)
        #expect(String(localized: first.primaryTitle) == String(localized: "Continue"))
        #expect(!first.showsReplayHint)
        first.pageIndex = first.pages.count - 1
        #expect(String(localized: first.primaryTitle) == String(localized: "Sign in"))
        #expect(first.showsReplayHint, "al primo avvio l'ultima pagina dice che si rivede dal profilo")

        let profile = AriaOnboardingViewModel(origin: .profile) {}
        profile.choose(.admin)
        profile.pageIndex = profile.pages.count - 1
        #expect(String(localized: profile.primaryTitle) == String(localized: "Done"))
        #expect(!profile.showsReplayHint)
    }

    @Test func everyAudienceHasPagesWithUniqueIds() {
        for audience in AriaOnboardingAudience.allCases {
            let ids = audience.pages.map(\.id)
            #expect(!ids.isEmpty)
            #expect(Set(ids).count == ids.count, "id doppi in \(audience)")
            for page in audience.pages {
                let highlightIds = page.highlights.map(\.id)
                #expect(Set(highlightIds).count == highlightIds.count, "voci doppie in \(page.id)")
            }
        }
    }
}

@MainActor
struct OnboardingProgressTests {
    @Test func remembersThatTheTourWasSeen() throws {
        let suite = "OnboardingProgressTests.\(UUID().uuidString)"
        let defaults = try #require(UserDefaults(suiteName: suite))
        defer { defaults.removePersistentDomain(forName: suite) }

        let progress = AriaOnboardingProgress(defaults: defaults)
        #expect(!progress.isSeen)
        progress.markSeen()
        #expect(progress.isSeen)
        #expect(AriaOnboardingProgress(defaults: defaults).isSeen)
    }
}
