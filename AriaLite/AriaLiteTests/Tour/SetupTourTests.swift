//
//  SetupTourTests.swift
//  AriaLiteTests
//
//  Created by Giovanni Michele on 13/11/26.
//
//  "Primi passi con AriA", il giro guidato dell'admin: i passi filtrati per sezioni e permessi, l'intro, quando
//  parte, "Avanti" e "Indietro" (l'intro fuori dal contatore), la fine per account, la ripresa della prima
//  esecuzione, il replay chiudibile, il ricalcolo se cambiano i permessi e il farsi da parte per un foglio aperto.
//

import CoreGraphics
import Foundation
import Testing
@testable import AriaLite

nonisolated private func freshDefaults() -> UserDefaults {
    UserDefaults(suiteName: "SetupTourTests-\(UUID().uuidString)")!
}

nonisolated private let allSections: Set<AriaDestination> = [
    .adminDocuments, .adminExtractionReview, .adminAgentStudio, .adminUsers, .adminTeams, .adminMarketplace
]

/// Un owner: tutte le sezioni e tutti i permessi.
nonisolated private func fullAccess(
    offered: Set<AriaDestination> = allSections, hasSite: Bool = true, canGovern: Bool = true,
    canInvite: Bool = true, canCreateTeam: Bool = true, canConnect: Bool = true
) -> AriaSetupTourAccess {
    AriaSetupTourAccess(offered: offered, hasSite: hasSite, canGovern: canGovern, canInvite: canInvite,
                        canCreateTeam: canCreateTeam, canConnect: canConnect)
}

nonisolated private let allSteps: [AriaSetupTourStep] = [
    .upload, .extraction, .agents, .workflows, .governance, .invite, .teams, .connectors
]

@MainActor
struct SetupTourModelTests {
    @Test func stepsKeepTheOrderAndFilterBySection() {
        #expect(fullAccess().steps == allSteps)
        #expect(fullAccess(offered: [.adminMarketplace, .adminDocuments, .adminTeams]).steps
                == [.upload, .teams, .connectors])
        #expect(fullAccess(offered: [.adminAgentStudio]).steps == [.agents, .workflows, .governance])
        #expect(fullAccess(offered: [.chat, .tasks]).steps.isEmpty)
    }

    @Test func eachStepNeedsTheRightToDoWhatItPointsAt() {
        #expect(!fullAccess(canGovern: false).steps.contains(.governance))
        #expect(!fullAccess(canInvite: false).steps.contains(.invite))
        #expect(!fullAccess(canCreateTeam: false).steps.contains(.teams))
        #expect(!fullAccess(canConnect: false).steps.contains(.connectors))
        // Un permesso senza la sezione offerta non basta.
        #expect(!fullAccess(offered: allSections.subtracting([.adminUsers])).steps.contains(.invite))
        // Senza permessi restano i passi che bastano le sezioni (caricamento, revisione, agenti, workflow).
        let plain = fullAccess(canGovern: false, canInvite: false, canCreateTeam: false, canConnect: false)
        #expect(plain.steps == [.upload, .extraction, .agents, .workflows])
    }

    @Test func eachStepGoesToItsSectionAndBelongsToItsGuideSection() {
        #expect(AriaSetupTourStep.allCases == allSteps)
        #expect(allSteps.map(\.destination)
                == [.adminDocuments, .adminExtractionReview, .adminAgentStudio, .adminAgentStudio, .adminAgentStudio,
                    .adminUsers, .adminTeams, .adminMarketplace])
        #expect(allSteps.map(\.section)
                == [.knowledge, .knowledge, .agents, .agents, .agents, .team, .team, .marketplace])
    }

    @Test func sectionsAreOnlyThoseWithAStepInOrder() {
        #expect(fullAccess().sections == [.knowledge, .agents, .team, .marketplace])
        #expect(fullAccess(canInvite: false, canCreateTeam: false).sections == [.knowledge, .agents, .marketplace])
        #expect(fullAccess(offered: [.adminTeams, .adminDocuments]).sections == [.knowledge, .team])
    }

    @Test func chipsAreOnlyOnTheStepsThatHaveThem() {
        #expect(AriaSetupTourStep.upload.chips.count == 7)
        #expect(AriaSetupTourStep.extraction.chips.count == 4)
        #expect(AriaSetupTourStep.teams.chips.count == 3)
        #expect(AriaSetupTourStep.agents.chips.isEmpty)
        #expect(AriaSetupTourStep.connectors.chips.isEmpty)
    }

    @Test func uploadHasAVariantWithoutASite() {
        let withSite = String(localized: AriaSetupTourStep.upload.message(hasSite: true))
        let withoutSite = String(localized: AriaSetupTourStep.upload.message(hasSite: false))
        #expect(withSite != withoutSite)
        // Gli altri passi non cambiano.
        #expect(String(localized: AriaSetupTourStep.teams.message(hasSite: true))
                == String(localized: AriaSetupTourStep.teams.message(hasSite: false)))
    }

    @Test func doneAndStepKeysArePerAccountAndCaseInsensitive() {
        #expect(AriaSetupTourProgress.doneKey(account: "Admin@Example.com") == AriaSetupTourProgress.doneKey(account: "admin@example.com"))
        #expect(AriaSetupTourProgress.stepKey(account: "Admin@Example.com") == AriaSetupTourProgress.stepKey(account: "admin@example.com"))
        // Nelle chiavi c'è un'impronta, non l'email: UserDefaults è un file in chiaro.
        #expect(!AriaSetupTourProgress.doneKey(account: "Admin@Example.com").lowercased().contains("example"))
        #expect(!AriaSetupTourProgress.stepKey(account: "Admin@Example.com").lowercased().contains("example"))
        let defaults = freshDefaults()
        let progress = AriaSetupTourProgress(defaults: defaults)
        progress.markDone(account: "Admin@Example.com")
        #expect(progress.isDone(account: "admin@example.com"))
        #expect(!progress.isDone(account: "other@example.com"))

        progress.saveStep("teams", account: "Admin@Example.com")
        #expect(progress.savedStep(account: "admin@example.com") == "teams")
        #expect(progress.savedStep(account: "other@example.com") == nil)
        progress.clearStep(account: "admin@example.com")
        #expect(progress.savedStep(account: "admin@example.com") == nil)
    }

    @Test func keysWithTheEmailInClearMoveToTheFingerprint() {
        let defaults = freshDefaults()
        defaults.set(true, forKey: "AriaSetupTourDone.admin@example.com")
        defaults.set("teams", forKey: "AriaSetupTourStep.admin@example.com")
        let progress = AriaSetupTourProgress(defaults: defaults)
        #expect(progress.isDone(account: "Admin@Example.com"), "il giro già fatto non si ripete")
        #expect(progress.savedStep(account: "Admin@Example.com") == "teams")
        #expect(defaults.object(forKey: "AriaSetupTourDone.admin@example.com") == nil)
        #expect(defaults.object(forKey: "AriaSetupTourStep.admin@example.com") == nil)
        #expect(!defaults.dictionaryRepresentation().keys.contains { $0.contains("admin@example.com") })
    }

    /// Anche le chiavi di chi non rientra più: l'email non resta, il giro fatto sì.
    @Test func keysOfAccountsThatNeverComeBackAreConvertedToo() {
        let defaults = freshDefaults()
        defaults.set(true, forKey: "AriaSetupTourDone.gone@example.com")
        let progress = AriaSetupTourProgress(defaults: defaults)
        #expect(!progress.isDone(account: "admin@example.com"))
        #expect(!defaults.dictionaryRepresentation().keys.contains { $0.contains("@") })
        #expect(progress.isDone(account: "gone@example.com"))
    }

    @Test func hiddenFollowsTheTipsTourKey() {
        let defaults = freshDefaults()
        #expect(!AriaSetupTourProgress(defaults: defaults).isHidden)
        defaults.set(true, forKey: AriaSetupTourProgress.hiddenKey)
        #expect(AriaSetupTourProgress(defaults: defaults).isHidden)
    }
}

@MainActor
struct SetupTourViewModelTests {
    private let account = "admin@example.com"

    private func makeModel(_ defaults: UserDefaults = freshDefaults(), isTestHost: Bool = false) -> AriaSetupTourViewModel {
        AriaSetupTourViewModel(progress: AriaSetupTourProgress(defaults: defaults), isTestHost: isTestHost)
    }

    private func configure(
        _ model: AriaSetupTourViewModel, account: String? = nil, operatorLayout: Bool = false,
        membershipRead: Bool = true, access: AriaSetupTourAccess = fullAccess()
    ) {
        model.configure(account: account ?? self.account, operatorLayout: operatorLayout,
                        membershipRead: membershipRead, access: access)
    }

    /// Un giro già partito, sul primo passo (dopo l'intro).
    private func startedOnFirstStep(_ defaults: UserDefaults = freshDefaults()) -> AriaSetupTourViewModel {
        let model = makeModel(defaults)
        configure(model)
        model.startIfNeeded()
        model.next()
        return model
    }

    // MARK: Partenza

    @Test func startsOnTheIntroForANewAdmin() {
        let model = makeModel()
        configure(model)
        model.startIfNeeded()
        #expect(model.position == .intro)
        #expect(model.isOnIntro)
        #expect(model.current == nil)
        #expect(model.isActive)
        #expect(model.stepNumber == 0)
        #expect(model.stepCount == 8)
        #expect(!model.canGoBack)
    }

    @Test func doesNotStartWhenDone() {
        let defaults = freshDefaults()
        AriaSetupTourProgress(defaults: defaults).markDone(account: account)
        let model = makeModel(defaults)
        configure(model)
        model.startIfNeeded()
        #expect(!model.isActive)
    }

    @Test func doesNotStartWhenHiddenOrInTheTestHost() {
        let hidden = freshDefaults()
        hidden.set(true, forKey: AriaSetupTourProgress.hiddenKey)
        let hiddenModel = makeModel(hidden)
        configure(hiddenModel)
        hiddenModel.startIfNeeded()
        #expect(!hiddenModel.isActive)

        let testHostModel = makeModel(isTestHost: true)
        configure(testHostModel)
        testHostModel.startIfNeeded()
        #expect(!testHostModel.isActive)
    }

    @Test func doesNotStartForTheOperatorOrBeforeTheAccessIsKnown() {
        let operatorModel = makeModel()
        configure(operatorModel, operatorLayout: true)
        operatorModel.startIfNeeded()
        #expect(!operatorModel.isActive)
        #expect(operatorModel.steps.isEmpty)

        let unreadModel = makeModel()
        configure(unreadModel, membershipRead: false)
        unreadModel.startIfNeeded()
        #expect(!unreadModel.isActive)
        // Letta la membership, parte.
        configure(unreadModel, membershipRead: true)
        unreadModel.startIfNeeded()
        #expect(unreadModel.isActive)
    }

    @Test func doesNotStartWithoutSteps() {
        let model = makeModel()
        configure(model, access: fullAccess(offered: [.chat, .tasks]))
        model.startIfNeeded()
        #expect(!model.isActive)
        #expect(!model.hasSteps)
    }

    @Test func theIntroNeedsAtLeastOneStep() {
        let model = makeModel()
        configure(model, access: fullAccess(offered: [.adminTeams], canCreateTeam: false))
        model.startIfNeeded()
        #expect(!model.isActive)
        model.replay()
        #expect(!model.isActive)
    }

    // MARK: Avanzamento

    @Test func theIntroIsOutsideTheCounter() {
        let model = makeModel()
        configure(model)
        model.startIfNeeded()
        #expect(model.stepNumber == 0)
        model.next()
        #expect(model.current == .upload)
        #expect(model.stepNumber == 1)
        #expect(model.stepCount == 8)
        #expect(model.nextStep == .extraction)
        #expect(model.progressFraction == 1.0 / 8.0)
    }

    @Test func nextWalksEveryStepAndTheLastOneMarksDoneForThatAccountOnly() {
        let defaults = freshDefaults()
        let model = startedOnFirstStep(defaults)
        var seen: [AriaSetupTourStep] = []
        while let step = model.current {
            seen.append(step)
            #expect(model.finishCount == 0)
            if model.isLastStep { break }
            model.next()
        }
        #expect(seen == allSteps)
        #expect(model.current == .connectors)
        #expect(model.isLastStep)
        #expect(model.nextStep == nil)

        model.next()
        #expect(!model.isActive)
        #expect(model.finishCount == 1)

        let progress = AriaSetupTourProgress(defaults: defaults)
        #expect(progress.isDone(account: account))
        #expect(!progress.isDone(account: "other@example.com"))

        // Un altro account sullo stesso telefono lo rivede.
        let other = makeModel(defaults)
        configure(other, account: "other@example.com")
        other.startIfNeeded()
        #expect(other.isActive)
    }

    @Test func backGoesBackAndFromTheFirstStepToTheIntro() {
        let model = startedOnFirstStep()
        model.next()
        model.next()
        #expect(model.current == .agents)
        #expect(model.canGoBack)

        model.back()
        #expect(model.current == .extraction)
        model.back()
        #expect(model.current == .upload)
        model.back()
        #expect(model.isOnIntro)
        #expect(model.stepNumber == 0)
        // All'intro non c'è un indietro.
        model.back()
        #expect(model.isOnIntro)
        // E da lì si riparte dal primo passo.
        model.next()
        #expect(model.current == .upload)
    }

    @Test func theCurrentMessageFollowsTheSiteForTheUploadStep() {
        let model = makeModel()
        configure(model, access: fullAccess(hasSite: false))
        model.startIfNeeded()
        model.next()
        #expect(model.current == .upload)
        let withoutSite = model.currentMessage.map { String(localized: $0) }
        configure(model, access: fullAccess(hasSite: true))
        let withSite = model.currentMessage.map { String(localized: $0) }
        #expect(withoutSite != nil)
        #expect(withoutSite != withSite)
    }

    // MARK: Ripresa

    @Test func theFirstRunSavesTheCurrentStepAndResumesThere() {
        let defaults = freshDefaults()
        let model = startedOnFirstStep(defaults)
        model.next()
        model.next()
        #expect(model.current == .agents)
        #expect(AriaSetupTourProgress(defaults: defaults).savedStep(account: account) == "agents")

        // Riaperta l'app (anche dopo una chiusura forzata): riparte da lì, non dall'intro.
        let relaunched = makeModel(defaults)
        configure(relaunched)
        relaunched.startIfNeeded()
        #expect(relaunched.current == .agents)
        #expect(!relaunched.isReplay)
    }

    @Test func finishingClearsTheSavedStep() {
        let defaults = freshDefaults()
        let model = startedOnFirstStep(defaults)
        model.next()
        #expect(AriaSetupTourProgress(defaults: defaults).savedStep(account: account) == "extraction")
        while model.isActive { model.next() }
        #expect(AriaSetupTourProgress(defaults: defaults).savedStep(account: account) == nil)
    }

    @Test func goingBackToTheIntroClearsTheSavedStep() {
        let defaults = freshDefaults()
        let model = startedOnFirstStep(defaults)
        model.back()
        #expect(model.isOnIntro)
        #expect(AriaSetupTourProgress(defaults: defaults).savedStep(account: account) == nil)
    }

    @Test func aSavedStepThatNoLongerExistsResumesOnTheNextOne() {
        let defaults = freshDefaults()
        AriaSetupTourProgress(defaults: defaults).saveStep("governance", account: account)
        let model = makeModel(defaults)
        configure(model, access: fullAccess(canGovern: false))
        model.startIfNeeded()
        #expect(model.current == .invite)

        // Un valore sconosciuto riparte dall'intro.
        let other = freshDefaults()
        AriaSetupTourProgress(defaults: other).saveStep("bogus", account: account)
        let unknown = makeModel(other)
        configure(unknown)
        unknown.startIfNeeded()
        #expect(unknown.isOnIntro)
    }

    @Test func stopKeepsTheSavedStepAndDoesNotMarkDone() {
        let defaults = freshDefaults()
        let model = startedOnFirstStep(defaults)
        model.next()
        model.stop()
        #expect(!model.isActive)
        #expect(model.finishCount == 0)
        let progress = AriaSetupTourProgress(defaults: defaults)
        #expect(!progress.isDone(account: account))
        #expect(progress.savedStep(account: account) == "extraction")
    }

    // MARK: Replay

    @Test func replayStartsFromTheIntroEvenWhenDoneAndDoesNotResume() {
        let defaults = freshDefaults()
        let progress = AriaSetupTourProgress(defaults: defaults)
        progress.markDone(account: account)
        progress.saveStep("teams", account: account)
        let model = makeModel(defaults)
        configure(model)
        model.replay()
        #expect(model.isOnIntro)
        #expect(model.isReplay)
        model.next()
        model.next()
        #expect(model.current == .extraction)
        // Il replay non salva il passo: resta quello che c'era.
        #expect(progress.savedStep(account: account) == "teams")
    }

    @Test func replayDoesNothingWithoutSteps() {
        let model = makeModel()
        configure(model, access: fullAccess(offered: []))
        model.replay()
        #expect(!model.isActive)
    }

    @Test func theReplayCanBeClosedAndClosingDoesNotMarkDone() {
        let defaults = freshDefaults()
        let model = makeModel(defaults)
        configure(model)
        model.replay()
        #expect(model.isClosable)
        model.next()
        model.next()
        model.close()
        #expect(!model.isActive)
        #expect(!model.isReplay)
        #expect(model.finishCount == 0)
        #expect(!AriaSetupTourProgress(defaults: defaults).isDone(account: account))
    }

    @Test func theIntroOfAReplayCanBeClosed() {
        let model = makeModel()
        configure(model)
        model.replay()
        model.close()
        #expect(!model.isActive)
    }

    @Test func theFirstRunCannotBeClosed() {
        let model = makeModel()
        configure(model)
        model.startIfNeeded()
        #expect(!model.isClosable)
        model.close()
        #expect(model.isActive)
        model.next()
        model.close()
        #expect(model.current == .upload)
    }

    @Test func aReplayFinishedToTheEndSignalsTheChat() {
        let defaults = freshDefaults()
        AriaSetupTourProgress(defaults: defaults).markDone(account: account)
        let model = makeModel(defaults)
        configure(model)
        model.replay()
        while model.isActive { model.next() }
        #expect(model.finishCount == 1)
        #expect(!model.isReplay)
        #expect(AriaSetupTourProgress(defaults: defaults).isDone(account: account))
    }

    // MARK: Ricalcolo

    @Test func refilterSkipsADroppedCurrentStep() {
        let model = startedOnFirstStep()
        model.next()
        model.next()
        #expect(model.current == .agents)

        model.refilter(access: fullAccess(offered: allSections.subtracting([.adminAgentStudio])))
        #expect(model.current == .invite)
        #expect(model.steps == [.upload, .extraction, .invite, .teams, .connectors])
    }

    @Test func refilterSkipsGovernanceWhenTheRoleLosesIt() {
        let model = startedOnFirstStep()
        for _ in 0..<4 { model.next() }
        #expect(model.current == .governance)
        model.refilter(access: fullAccess(canGovern: false))
        #expect(model.current == .invite)
    }

    @Test func refilterEndsWhenNothingIsLeftAfterTheCurrentStep() {
        let model = makeModel()
        configure(model, access: fullAccess(offered: [.adminDocuments, .adminMarketplace]))
        model.startIfNeeded()
        model.next()
        model.next()
        #expect(model.current == .connectors)

        // Cade l'ultima sezione e non ne resta una dopo: il giro finisce ed è fatto.
        model.refilter(access: fullAccess(offered: [.adminDocuments]))
        #expect(!model.isActive)
        #expect(model.finishCount == 1)
    }

    @Test func refilterStopsWithoutCompletingWhenNoStepIsLeft() {
        let model = makeModel()
        configure(model)
        model.startIfNeeded()
        model.next()
        model.refilter(access: fullAccess(offered: []))
        #expect(!model.isActive)
        #expect(model.finishCount == 0)
    }

    @Test func refilterKeepsTheIntroWhileStepsRemain() {
        let model = makeModel()
        configure(model)
        model.startIfNeeded()
        model.refilter(access: fullAccess(canGovern: false, canInvite: false))
        #expect(model.isOnIntro)
        #expect(model.stepCount == 6)
    }

    @Test func turningIntoTheOperatorLayoutStopsWithoutMarkingDone() {
        let defaults = freshDefaults()
        let model = startedOnFirstStep(defaults)
        configure(model, operatorLayout: true)
        #expect(!model.isActive)
        #expect(!AriaSetupTourProgress(defaults: defaults).isDone(account: account))
    }

    @Test func changingAccountStopsTheTour() {
        let model = startedOnFirstStep()
        configure(model, account: "other@example.com")
        #expect(!model.isActive)
    }

    // MARK: Elementi e foglio aperto

    @Test func framesAreKeptPerStepAndCleared() {
        let model = startedOnFirstStep()
        #expect(model.currentFrame == nil)
        model.setFrame(CGRect(x: 1, y: 2, width: 3, height: 4), for: .upload)
        #expect(model.currentFrame == CGRect(x: 1, y: 2, width: 3, height: 4))
        model.setFrame(CGRect(x: 9, y: 9, width: 9, height: 9), for: .teams)
        #expect(model.currentFrame == CGRect(x: 1, y: 2, width: 3, height: 4))
        model.setFrame(nil, for: .upload)
        #expect(model.currentFrame == nil)
    }

    @Test func aSheetOpenedFromTheSectionSetsTheTourAside() {
        let model = startedOnFirstStep()
        #expect(model.isVisible)
        model.setAside(true, source: "documents.upload")
        #expect(model.isActive)
        #expect(!model.isVisible)
        // Più fogli: torna solo quando si chiudono tutti.
        model.setAside(true, source: "other")
        model.setAside(false, source: "documents.upload")
        #expect(!model.isVisible)
        model.setAside(false, source: "other")
        #expect(model.isVisible)
        // Chiudere due volte, o un foglio mai aperto, non fa danni.
        model.setAside(false, source: "other")
        #expect(model.isVisible)
    }
}
