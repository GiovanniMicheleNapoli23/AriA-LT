# Phase B report (recreated: the earlier file was gone when the final wave finished; only the final wave is recorded here)

## Final fix wave

Not built, not tested by me.

1. 402 final: `AriaAgentMessage.errorIsFinal` (AriaAgentMessage.swift, next to `errorIsOffline`, reset in `prepareForResume`); set in `fail()` for `.spendCapReached` (AriaAgentChat.swift:1029); `failedTurn` ignores final errors (AriaAgentChatViewModel.swift:82) so `canRetry` is false and the dock shows no Retry; `chat.handle` returns before `backend.handle` for `.spendCapReached` (the banner still comes from `chat.lastError`); `usage.replyEnded()` still runs in `endTurn`.
2. `chat.warning: String?` (AriaAgentChat.swift) replaces `notice` for the failed effort PATCH (AriaAgentChat+Effort.swift); new `AriaChatWarningBanner` (AriaChatBanners.swift:33, `info.circle.fill`, gray, 5 s, no haptic); shown in AriaChatDock.swift:122; `AriaAgentChatViewModel.warning/dismissWarning`; animation in AriaAgentChatView.swift. `resetEffort()` clears it.
3. Token line removed: AriaMessageToolbar.swift (the trailing usage Text) and `usageText` in AriaAgentMessageViewModel.swift. Composer context meter untouched.
4. Tests: AriaLiteTests/Usage/EffortChatTests.swift, `BackendTests.EffortChat` (nested in the serialized parent): normalSendsCarryTheDefaultLevel, aDirectToolCallCarriesNoLevel, resumingAPauseCarriesNoLevel, noLevelWhenTheConfigCouldNotBeRead, noLevelWhenChatReplyIsNotEnabled, aPickAfterATurnIsSavedOnTheSessionAndTravelsWithTheNextMessage, aPickOnAFreshChatSavesNothingAndTheFirstTurnCarriesIt, aFailedSaveWarnsWithoutASuccessNoticeAndKeepsThePick, reopeningRestoresTheSavedLevelAndTheNextSendCarriesIt, aPickMadeBeforeTheSessionAnswersWins, aSavedLevelTheAppCannotNameIsNeverOverwrittenWithTheDefault, aFailedRestoreSendsNoLevelUntilThePersonPicks, aTurnUsageEventLandsOnTheReply, aReplyWithoutTheEventHasNoUsage, aStoredReplyFoldsAContinuationIntoTheEarlierCharge, theSpendCapIsFinalAndStaysOutOfTheGlobalError, anOrdinaryFailureStillOffersRetry, aCompanySwitchDropsTheFiguresAndReloadsForTheNewCompany, aServiceUnavailableAnswerLeavesNoFiguresAndNoGlobalError, aFailedRefreshDropsTheFiguresOfTheLastGoodAnswer, aServerWithoutTheRoutesHidesTheFeatureInsteadOfShowingAnError. Not covered: the non-operator restore path (no non-operator test backend) and the Stop/backfill path (timing would flake). Config/allowance are stubbed BEFORE sign-in so the bootstrap reload finds them.
5. `warmUsageConfig()` always calls `usage.loadConfig()` (AriaAgentChat+Credits.swift:22).
6. `awaitingSavedEffort` (AriaAgentChat.swift stored; set in `open()`; cleared in `restoreEffort` when the GET answers; `effortForTurn` returns nil while it is set and no pick was made: AriaAgentChat+Effort.swift:27).
7. `AriaUsageStore.resetAvailability()` (AriaUsageStore.swift:136), called from AriaBackend.swift next to both `unavailableFeatures = []` (signOut, and the followsRole change). A company change already cleared it through `drop`.
8. 404 on config/allowance counts as unavailable (`noteRefusal(_, includingNotFound: true)`, AriaUsageStore.swift:127); not for estimate.
9. AriaAllowanceSummary.swift:218: `pct` (and its unreadable check) is required only when not in day mode.
10. AriaUsageStore.swift:225: `.loading` only if nothing is stored and the phase is not `.failed`.
11. AriaTurnCreditNote.swift:31: `String(localized: "credits.note.stopped", defaultValue: "Stopped")`.
12. VoiceOver: `creditNoteAccessibilityLabel` replaces " · " with ", " (AriaAgentMessageViewModel.swift:102); `effortAccessibilityLabel` in AriaChatComposerViewModel+Effort.swift:57, applied to the effort button in AriaChatComposer.swift:194.

New user-facing strings (exact keys, English source):
- `credits.note.stopped` = "Stopped"
- "Effort: %@, not available on your plan"  (code: `Effort: \(title), not available on your plan`)
- "Effort: %@, %@ times"  (code: `Effort: \(title), \(spoken) times`, e.g. "Effort: High, 2.4 times")
No other new strings; the PATCH-failure text is unchanged.
