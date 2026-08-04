import Testing
@testable import TokenBarMac

@Test
func onboardingAnalysisWindowRejectsUnsupportedPersistedValues() {
    #expect(TokenBarAnalysisWindow.normalizedDays(1) == 1)
    #expect(TokenBarAnalysisWindow.normalizedDays(7) == 7)
    #expect(TokenBarAnalysisWindow.normalizedDays(30) == 30)
    #expect(TokenBarAnalysisWindow.normalizedDays(0) == 7)
    #expect(TokenBarAnalysisWindow.normalizedDays(365) == 7)
}

@Test
func onboardingQuestionsComeFromTheAnalyzedProfile() {
    var profile = BuilderProfile()
    profile.identityTitle = "The Builder of Quiet Systems"
    profile.evidenceSessions = 42
    profile.dimensions = [
        BuilderDimension(name: "Steering", score: 82, note: "Clear direction"),
        BuilderDimension(name: "Planning", score: 71, note: "Scopes first"),
        BuilderDimension(name: "Execution", score: 66, note: "Moves quickly"),
    ]
    profile.facts = [
        BuilderFact(label: "Deepest session", value: "3h 10m", copy: "A long focused block"),
        BuilderFact(label: "Active days", value: "6", copy: "Worked most days"),
    ]

    let questions = OnboardingQuestionFactory.questions(for: profile)

    #expect(questions.count == 3)
    #expect(questions[0].prompt == "Which pattern should TokenBar watch first?")
    #expect(questions[0].options.first == "Steering · 82")
    #expect(questions[0].context.contains("tunes the app"))
    #expect(questions[1].prompt == "What should your first story open with?")
    #expect(questions[1].options == [
        "Assigned form · The Builder of Quiet Systems",
        "Evidence base · 42 local sessions",
        "Next frontier · Execution · 66",
    ])
    #expect(questions[2].id == "reminder")
    #expect(questions[2].prompt == "Where should TokenBar help before the next run?")
    #expect(questions[2].options == [
        "Budget spikes · warn me before a run gets expensive",
        "Work rhythm · remind me around Deepest session",
        "Share review · ask before anything leaves this Mac",
    ])
    #expect(questions[2].context.contains("does not upload work"))
}

@Test
func onboardingQuestionsAvoidProviderTokenEntryCopy() {
    let questions = OnboardingQuestionFactory.questions(for: BuilderProfile())
    let combined = questions
        .flatMap { [$0.prompt, $0.context] + $0.options }
        .joined(separator: " ")
        .lowercased()

    #expect(!combined.contains("enter token"))
    #expect(!combined.contains("paste token"))
    #expect(!combined.contains("api key"))
    #expect(combined.contains("assigned identity"))
    #expect(combined.contains("before anything leaves this mac"))
}

@Test
func threadLaneOverridesRoundTripWithoutRewritingThreadState() {
    let encoded = ThreadLaneOverrideCodec.encode([
        "thread-a": .focus,
        "thread-b": .done,
    ])
    let decoded = ThreadLaneOverrideCodec.decode(encoded)

    #expect(decoded["thread-a"] == .focus)
    #expect(decoded["thread-b"] == .done)
}
