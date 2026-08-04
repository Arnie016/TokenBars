import Foundation
import Testing
@testable import TokenBarMac

@MainActor
@Test
func savedReportsReloadInNewestFirstOrderWithTheirOwnShareState() throws {
    let fileManager = FileManager.default
    let supportDirectory = fileManager.temporaryDirectory
        .appendingPathComponent("TokenBarSavedReports-\(UUID().uuidString)", isDirectory: true)
    let profilesDirectory = supportDirectory.appendingPathComponent("profiles", isDirectory: true)
    let receiptsDirectory = supportDirectory.appendingPathComponent("proof-receipts", isDirectory: true)
    try fileManager.createDirectory(at: profilesDirectory, withIntermediateDirectories: true)
    try fileManager.createDirectory(at: receiptsDirectory, withIntermediateDirectories: true)
    defer { try? fileManager.removeItem(at: supportDirectory) }

    let olderURL = profilesDirectory.appendingPathComponent("older.identity.json")
    let newerURL = profilesDirectory.appendingPathComponent("newer.identity.json")
    try reportJSON(
        token: "TBAR-OLDER",
        title: "Systems Cartographer",
        archetype: "Cartographer",
        generatedAt: "2026-07-01T10:00:00Z",
        windowDays: 30,
        sessions: 120,
        activeDays: 18,
        evidenceScore: 54,
        factValue: "18 maps"
    ).write(to: olderURL)
    try reportJSON(
        token: "TBAR-NEWER",
        title: "Night Shift Navigator",
        archetype: "Navigator",
        generatedAt: "2026-07-26T12:00:00Z",
        windowDays: 7,
        sessions: 42,
        activeDays: 7,
        evidenceScore: 73,
        factValue: "42 sessions"
    ).write(to: newerURL)

    try Data("<html>new report</html>".utf8)
        .write(to: profilesDirectory.appendingPathComponent("newer.html"))
    try fileManager.setAttributes(
        [.modificationDate: Date(timeIntervalSince1970: 100)],
        ofItemAtPath: olderURL.path
    )
    try fileManager.setAttributes(
        [.modificationDate: Date(timeIntervalSince1970: 200)],
        ofItemAtPath: newerURL.path
    )

    let receipt = """
    {
      "token": "TBAR-NEWER",
      "revoked": false,
      "shareMode": "unlisted",
      "surfaces": {
        "publicProfile": "https://tokenbar.example/u/night-shift"
      }
    }
    """
    try Data(receipt.utf8).write(to: receiptsDirectory.appendingPathComponent("newer.json"))

    let model = TokenBarModel(supportDirectory: supportDirectory)

    #expect(model.savedReports.count == 2)
    #expect(model.savedReports[0].title == "Night Shift Navigator")
    #expect(model.savedReports[0].windowLabel == "Weekly report")
    #expect(model.savedReports[0].sessions == 42)
    #expect(model.savedReports[0].facts.first?.value == "42 sessions")
    #expect(model.savedReports[0].storyFacts.map(\.value) == ["42 sessions"])
    #expect(model.savedReports[0].reportURL?.lastPathComponent == "newer.html")
    #expect(model.savedReports[0].shareURL?.absoluteString == "https://tokenbar.example/u/night-shift")
    #expect(model.savedReports[0].shareCaption == """
    My TokenBar Builder Identity: Night Shift Navigator

    A specific local builder snapshot.

    https://tokenbar.example/u/night-shift
    """)
    #expect(model.savedReports[1].title == "Systems Cartographer")
    #expect(model.savedReports[1].windowLabel == "Monthly report")
    #expect(model.savedReports[1].shareURL == nil)
    #expect(model.savedReports[1].shareCaption == nil)
}

@MainActor
@Test
func legacyRevenueReportGetsClearPresentationIdentityAndRationale() throws {
    let fileManager = FileManager.default
    let supportDirectory = fileManager.temporaryDirectory
        .appendingPathComponent("TokenBarRevenueReport-\(UUID().uuidString)", isDirectory: true)
    let profilesDirectory = supportDirectory.appendingPathComponent("profiles", isDirectory: true)
    try fileManager.createDirectory(at: profilesDirectory, withIntermediateDirectories: true)
    defer { try? fileManager.removeItem(at: supportDirectory) }

    let reportURL = profilesDirectory.appendingPathComponent("revenue.identity.json")
    try reportJSON(
        token: "TBAR-REVENUE",
        title: "Revenue Engine Pilot",
        archetype: "Revenue Systems Captain",
        generatedAt: "2026-07-26T13:00:00Z",
        windowDays: 7,
        sessions: 533,
        activeDays: 27,
        evidenceScore: 59,
        factValue: "533 sessions"
    ).write(to: reportURL)

    let model = TokenBarModel(supportDirectory: supportDirectory)
    let report = try #require(model.savedReports.first)

    #expect(report.presentationTitle == "Sovereign of the Unwritten Engine")
    #expect(report.symbolName == "chart.line.uptrend.xyaxis")
    #expect(report.identityFamily == .commerce)
    #expect(report.identityPatternLabel == "Commercial systems")
    #expect(report.workRhythmLabel == "Checklist-led")
    #expect(report.operatingStanceLabel == "Private by default")
    #expect(report.modifier == "Checklist-Driven")
    #expect(report.matches("TBAR-REVENUE"))
    #expect(report.matches("unwritten engine"))
    #expect(report.titleRationale.components.map(\.name) == [
        "Revenue Systems Captain",
        "Checklist-Driven",
        "Guardian",
    ])
    #expect(report.titleRationale.drivers.first?.name == "Steering")
    #expect(report.titleRationale.drivers.first?.score == 80)
    #expect(report.displayTitleRationale.components.map(\.kind) == [
        "Core pattern",
        "Work rhythm",
        "Operating stance",
    ])
    #expect(report.displayTitleRationale.components.map(\.name) == [
        "Commercial systems",
        "Checklist-led",
        "Private by default",
    ])
    #expect(report.scrollStoryBeats.first?.title == "You are")
    #expect(report.scrollStoryBeats.first?.value == "Sovereign of the Unwritten Engine")
    #expect(report.scrollStoryBeats.last?.title == "Work rhythm")
    #expect(report.scrollStoryBeats.last?.value == "533 sessions")
}

@MainActor
@Test
func localIdentityPathCanBeAddedToTheReportLibrary() async throws {
    let fileManager = FileManager.default
    let supportDirectory = fileManager.temporaryDirectory
        .appendingPathComponent("TokenBarReportImport-\(UUID().uuidString)", isDirectory: true)
    let incomingDirectory = fileManager.temporaryDirectory
        .appendingPathComponent("TokenBarIncomingReport-\(UUID().uuidString)", isDirectory: true)
    try fileManager.createDirectory(at: supportDirectory, withIntermediateDirectories: true)
    try fileManager.createDirectory(at: incomingDirectory, withIntermediateDirectories: true)
    defer {
        try? fileManager.removeItem(at: supportDirectory)
        try? fileManager.removeItem(at: incomingDirectory)
    }

    let incomingURL = incomingDirectory.appendingPathComponent("shared.identity.json")
    try reportJSON(
        token: "TBAR-IMPORTED",
        title: "Shared Signal Cartographer",
        archetype: "Research Alchemist",
        generatedAt: "2026-07-26T14:00:00Z",
        windowDays: 30,
        sessions: 88,
        activeDays: 21,
        evidenceScore: 71,
        factValue: "88 sessions"
    ).write(to: incomingURL)

    let model = TokenBarModel(supportDirectory: supportDirectory)
    #expect(model.savedReports.isEmpty)

    model.importReportReference(incomingURL.path)
    for _ in 0..<100 where model.isImportingReport {
        try await Task.sleep(for: .milliseconds(20))
    }

    let imported = try #require(model.savedReports.first)
    #expect(imported.token == "TBAR-IMPORTED")
    #expect(imported.presentationTitle == "Alchemist of the Living Archive")
    #expect(imported.identityFamily == .research)
    #expect(model.lastImportedReportID == imported.id)
    #expect(model.lastError == nil)
}

@Test
func everySupportedArchetypeHasItsOwnDisplayIdentity() {
    let archetypes = [
        "Scaffold Architect",
        "Revenue Systems Captain",
        "Agent Infrastructure Cartographer",
        "Report Engine Philosopher",
        "Velocity Operator",
        "Quality Guardian",
        "Prompt Stress Tester",
        "Design Systems Bard",
        "Research Alchemist",
        "Multi-Agent Conductor",
        "Product Mythmaker",
        "Local-First Sovereign",
        "Session Archaeologist",
        "Workflow Diplomat",
        "Launch Systems Producer",
        "Heuristic Cartel Builder",
        "Proof Layer Broker",
        "Runway Economist",
        "Connector Locksmith",
        "Narrative Debugger",
        "Evidence Gardener",
        "Agent Coach",
        "Chaos-to-Canon Editor",
        "Portfolio Systems Curator",
    ]

    let reports = archetypes.enumerated().map { index, archetype in
        SavedBuilderReport(
            token: "TBAR-CATALOG-\(index)",
            title: archetype,
            archetype: archetype,
            modifier: "Observed",
            stance: "Local-first",
            subtitle: "A local builder snapshot.",
            generatedAt: Date(timeIntervalSince1970: Double(index)),
            windowDays: 7,
            evidenceScore: 60,
            sessions: 40,
            activeDays: 7,
            dimensions: [],
            facts: [],
            signatureMoves: [],
            titleRationale: ReportTitleRationale(components: [], drivers: []),
            identityURL: URL(fileURLWithPath: "/tmp/tokenbar-catalog-\(index).identity.json"),
            reportURL: nil,
            pdfURL: nil,
            shareURL: nil,
            shareMode: nil
        )
    }

    #expect(Set(reports.map(\.presentationTitle)).count == archetypes.count)
    #expect(Set(reports.map(\.identityPatternLabel)).count == archetypes.count)
    #expect(Set(reports.map(\.symbolName)).count == archetypes.count)
    #expect(Set(reports.map(\.emblemSignature)).count == archetypes.count)
    #expect(Set(reports.map(\.typographySignature)).count == archetypes.count)
    #expect(Set(reports.map(\.identityFamily)).count >= 14)
    #expect(reports.first { $0.archetype == "Revenue Systems Captain" }?.presentationTitle == "Sovereign of the Unwritten Engine")
    #expect(reports.first { $0.archetype == "Multi-Agent Conductor" }?.presentationTitle == "Conductor of the Threaded Leviathan")
    #expect(reports.first { $0.archetype == "Velocity Operator" }?.presentationTitle == "Corsair of the Black Meridian")
    #expect(reports.first { $0.archetype == "Scaffold Architect" }?.presentationMotto == "Builds foundations other builders can stand on.")
    #expect(reports.first { $0.archetype == "Prompt Stress Tester" }?.identityFamily == .stress)
}

@Test
func currentBuilderProfileUsesTheSameHumanTitleAsSavedReports() {
    var revenueProfile = BuilderProfile()
    revenueProfile.identityTitle = "Revenue Engine Pilot"
    revenueProfile.archetype = "Revenue Systems Captain"

    var unknownProfile = BuilderProfile()
    unknownProfile.identityTitle = "Night Shift Navigator"
    unknownProfile.archetype = "Navigator"

    #expect(revenueProfile.displayTitle == "Sovereign of the Unwritten Engine")
    #expect(revenueProfile.displayMotto == "Turns product intent into durable commercial machinery.")
    #expect(unknownProfile.displayTitle == "Night Shift Navigator")
    #expect(unknownProfile.displayMotto == "Run a private analysis to see how you plan, steer, ship, and recover.")
}

@Test
func reportLibraryFoldsExactRepeatsButPreservesIdentityHistory() throws {
    let firstDate = try #require(ISO8601DateFormatter().date(from: "2026-07-19T02:04:00Z"))
    let latestDate = try #require(ISO8601DateFormatter().date(from: "2026-07-26T20:16:00Z"))
    let first = savedReport(
        token: "TBAR-FIRST",
        archetype: "Multi-Agent Conductor",
        generatedAt: firstDate,
        sessions: 192
    )
    let exactRepeat = savedReport(
        token: "TBAR-REPEAT",
        archetype: "Multi-Agent Conductor",
        generatedAt: firstDate,
        sessions: 192
    )
    let laterEdition = savedReport(
        token: "TBAR-LATER",
        archetype: "Multi-Agent Conductor",
        generatedAt: latestDate,
        sessions: 423
    )
    let commercialEdition = savedReport(
        token: "TBAR-COMMERCIAL",
        archetype: "Revenue Systems Captain",
        generatedAt: latestDate.addingTimeInterval(60),
        sessions: 533
    )

    let reports = [commercialEdition, laterEdition, exactRepeat, first]
    let unique = SavedReportLibrary.deduplicated(reports)
    let collections = SavedReportLibrary.collections(from: reports)

    #expect(unique.count == 3)
    #expect(collections.count == 2)
    #expect(collections[0].title == "Sovereign of the Unwritten Engine")
    #expect(collections[1].title == "Conductor of the Threaded Leviathan")
    #expect(collections[1].reports.map(\.token) == ["TBAR-LATER", "TBAR-REPEAT"])
    #expect(first.matchesReference("TBAR-FIRST"))
    #expect(first.matchesReference(first.identityURL.path))
    #expect(!first.matchesReference("control room"))
    #expect(first.resolvedTitleRationale.components.map(\.name) == [
        "Multi-Agent Conductor",
        "Checklist-Driven",
        "Guardian",
    ])
    #expect(first.resolvedTitleRationale.components.first?.reason == "Steering leads at 80.")
    #expect(first.resolvedTitleRationale.drivers == [ReportTraitDriver(name: "Steering", score: 80)])
}

@Test
func reportStoryFactsFavorDistinctiveSignalsOverRepeatedScoreCards() {
    let report = SavedBuilderReport(
        token: "TBAR-STORY",
        title: "Revenue Engine Pilot",
        archetype: "Revenue Systems Captain",
        modifier: "Checklist-Driven",
        stance: "Guardian",
        subtitle: "A local builder snapshot.",
        generatedAt: Date(timeIntervalSince1970: 0),
        windowDays: 7,
        evidenceScore: 59,
        sessions: 40,
        activeDays: 7,
        dimensions: [],
        facts: [
            BuilderFact(label: "Highest trait", value: "80", copy: "Steering leads."),
            BuilderFact(label: "Command gravity", value: "6%", copy: "Six percent were commands."),
            BuilderFact(label: "Growth lever", value: "56", copy: "Research depth can improve."),
            BuilderFact(label: "Velocity typos", value: "12", copy: "Twelve shorthand markers."),
            BuilderFact(label: "Question engine", value: "8", copy: "Eight prompts were questions."),
            BuilderFact(label: "Courtesy residue", value: "1", copy: "One courtesy marker."),
        ],
        signatureMoves: [],
        titleRationale: ReportTitleRationale(components: [], drivers: []),
        identityURL: URL(fileURLWithPath: "/tmp/tokenbar-story.identity.json"),
        reportURL: nil,
        pdfURL: nil,
        shareURL: nil,
        shareMode: nil
    )

    #expect(report.storyFacts.map(\.label) == [
        "Command gravity",
        "Velocity typos",
        "Question engine",
        "Courtesy residue",
    ])
    #expect(report.scrollStoryBeats.map(\.title) == [
        "You are",
        "Command gravity",
        "Velocity typos",
        "Question engine",
        "Courtesy residue",
    ])
    #expect(report.scrollStoryBeats.map(\.value) == [
        "Sovereign of the Unwritten Engine",
        "6%",
        "12",
        "8",
        "1",
    ])
}

@Test
func builderPantheonProvidesOneHundredDistinctIdentityDirections() {
    #expect(BuilderIdentityCatalog.styles.count == 100)
    #expect(Set(BuilderIdentityCatalog.styles.map(\.id)).count == 100)
    #expect(Set(BuilderIdentityCatalog.styles.map(\.title)).count == 100)
    #expect(Set(BuilderIdentityCatalog.styles.map(\.order)).count == 10)
    #expect(BuilderIdentityRank.resolve(evidenceScore: 82, sessions: 40).label == "Rank V · Ascendant")
    #expect(BuilderIdentityRank.resolve(evidenceScore: 0, sessions: 0).label == "Rank I · Uncharted")
}

@Test
func threadCustomizationRoundTripsWithoutChangingTheCodexRecord() {
    let custom = ThreadCustomization(
        customTitle: "Recover the impossible launch",
        colorName: "coral",
        isHighlighted: true
    )
    let encoded = ThreadCustomizationCodec.encode(["thread-1": custom])
    let decoded = ThreadCustomizationCodec.decode(encoded)

    #expect(decoded["thread-1"] == custom)
    #expect(ThreadCustomizationCodec.decode("not-json").isEmpty)
}

@Test
func threadCardsTurnPromptsIntoConciseLocalHeadlines() {
    let requestThread = CodexThread(
        id: "request-thread",
        title: "Can you like, drastically enhance the following scene. Keep every existing asset.",
        cwd: "/tmp/tokenbar",
        tokensUsed: 4_200,
        recencyAtMs: 0,
        source: "cli",
        gitBranch: nil,
        gitSHA: nil,
        model: "gpt-5",
        threadSource: nil,
        parentThreadID: nil,
        childThreadCount: 0,
        goalStatus: ""
    )
    let automationThread = CodexThread(
        id: "automation-thread",
        title: "Automation: AutoResearch Archive Daily Brief Automation ID: daily-brief",
        cwd: "/tmp/archive",
        tokensUsed: 2_100,
        recencyAtMs: 0,
        source: "automation",
        gitBranch: nil,
        gitSHA: nil,
        model: "gpt-5",
        threadSource: "automation",
        parentThreadID: nil,
        childThreadCount: 0,
        goalStatus: ""
    )
    let delegatedThread = CodexThread(
        id: "delegated-thread",
        title: "<codex_delegation> <source_thread_id>019f879c-5758</source_thread_id>",
        cwd: "/tmp/app-portfolio-wedding-cinema",
        tokensUsed: 1_200,
        recencyAtMs: 0,
        source: "cli",
        gitBranch: nil,
        gitSHA: nil,
        model: "gpt-5",
        threadSource: nil,
        parentThreadID: "source-thread",
        childThreadCount: 0,
        goalStatus: ""
    )

    #expect(requestThread.cardTitle == "Elevate the scene.")
    #expect(requestThread.displayTitle.contains("Can you like"))
    #expect(automationThread.cardTitle == "AutoResearch Archive Daily Brief")
    #expect(automationThread.isAutomation)
    #expect(delegatedThread.cardTitle == "Continue Wedding Cinema build")
}

private func savedReport(
    token: String,
    archetype: String,
    generatedAt: Date,
    sessions: Int
) -> SavedBuilderReport {
    SavedBuilderReport(
        token: token,
        title: archetype,
        archetype: archetype,
        modifier: "Checklist-Driven",
        stance: "Guardian",
        subtitle: "A private builder snapshot.",
        generatedAt: generatedAt,
        windowDays: 7,
        evidenceScore: 59,
        sessions: sessions,
        activeDays: 27,
        dimensions: [BuilderDimension(name: "Steering", score: 80, note: "")],
        facts: [],
        signatureMoves: [],
        titleRationale: ReportTitleRationale(components: [], drivers: []),
        identityURL: URL(fileURLWithPath: "/tmp/\(token).identity.json"),
        reportURL: nil,
        pdfURL: nil,
        shareURL: nil,
        shareMode: nil
    )
}

private func reportJSON(
    token: String,
    title: String,
    archetype: String,
    generatedAt: String,
    windowDays: Int,
    sessions: Int,
    activeDays: Int,
    evidenceScore: Int,
    factValue: String
) -> Data {
    Data(
        """
        {
          "token": "\(token)",
          "title": "\(title)",
          "primaryArchetype": "\(archetype)",
          "subtitle": "A specific local builder snapshot.",
          "generatedAt": "\(generatedAt)",
          "windowDays": \(windowDays),
          "proofScore": \(evidenceScore),
          "identityLabel": {
            "title": "\(title)",
            "modifier": "Checklist-Driven",
            "stance": "Local-first"
          },
          "labelRationale": {
            "components": [
              {
                "name": "\(archetype)",
                "type": "base archetype",
                "reason": "The strongest repeated pattern.",
                "probability": 21.1
              },
              {
                "name": "Checklist-Driven",
                "type": "modifier",
                "reason": "The dominant operating rhythm."
              },
              {
                "name": "Guardian",
                "type": "stance",
                "reason": "The dominant working posture."
              }
            ],
            "topTraitDrivers": [
              {
                "trait": "Steering",
                "score": 80
              }
            ]
          },
          "usage": {
            "sessionsIndexed": \(sessions),
            "activeDaysLast30": \(activeDays)
          },
          "curiousFacts": [
            {
              "label": "Work rhythm",
              "value": "\(factValue)",
              "copy": "A concrete fact from aggregate local evidence."
            }
          ],
          "signatureMoves": ["Frames the work before editing"]
        }
        """.utf8
    )
}
