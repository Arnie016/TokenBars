import AppKit
import Darwin
import Foundation
import UniformTypeIdentifiers

private final class ProcessOutputBuffer: @unchecked Sendable {
    private let lock = NSLock()
    private var data = Data()

    func store(_ newData: Data) {
        lock.lock()
        data = newData
        lock.unlock()
    }

    var string: String {
        lock.lock()
        defer { lock.unlock() }
        return String(data: data, encoding: .utf8) ?? ""
    }
}

struct BuilderDimension: Identifiable, Hashable {
    var id: String { name }
    let name: String
    let score: Int
    let note: String
}

struct BuilderFact: Identifiable, Hashable {
    var id: String { label }
    let label: String
    let value: String
    let copy: String
}

struct ReportTitleComponent: Identifiable, Hashable {
    var id: String { "\(kind)-\(name)" }
    let name: String
    let kind: String
    let reason: String
    let probability: Double?
}

struct ReportTraitDriver: Identifiable, Hashable {
    var id: String { name }
    let name: String
    let score: Int
}

struct ReportTitleRationale: Hashable {
    let components: [ReportTitleComponent]
    let drivers: [ReportTraitDriver]
}

struct ReportStoryBeat: Identifiable, Hashable {
    var id: String { "\(kind)|\(title)|\(value)" }
    let kind: String
    let eyebrow: String
    let title: String
    let value: String
    let copy: String
    let symbolName: String
}

enum ReportIdentityFamily: String, Hashable {
    case architecture
    case commerce
    case orchestration
    case evidence
    case velocity
    case reliability
    case stress
    case design
    case research
    case privacy
    case exploration
    case workflow
    case launch
    case strategy
    case integration
    case coaching
    case portfolio
    case general
}

enum ReportTitleDesign: String, Hashable {
    case standard
    case rounded
    case serif
    case monospaced
}

enum ReportTitleWeight: String, Hashable {
    case medium
    case semibold
    case bold
    case heavy
    case black
}

struct ReportTypographySignature: Hashable {
    let design: ReportTitleDesign
    let weight: ReportTitleWeight
    let italic: Bool
    let trackingTenths: Int
}

struct UsageSnapshot: Hashable {
    var today = "--"
    var last7 = "--"
    var last30 = "--"
    var projectedNext7 = "--"
    var sessions = 0
    var activeDays = 0
    var model = "Local"
    var days: [UsageDaySnapshot] = []
}

struct UsageDaySnapshot: Identifiable, Hashable {
    var id: String { date }
    let date: String
    let tokens: Int64
}

struct StorageItemSnapshot: Identifiable, Hashable, Sendable {
    var id: String { path }
    let name: String
    let workspace: String
    let path: String
    let bytes: Int64
    let fileCount: Int
    let kind: String
    let isTrashable: Bool
}

struct CCUsageSnapshot: Codable, Hashable, Sendable {
    var period = "Not loaded"
    var latestCost = "--"
    var codexCost = "--"
    var latestTokens = "--"
    var observedCost = "--"
    var recentDays: [CCUsageDaySnapshot] = []
}

struct CCUsageDaySnapshot: Codable, Identifiable, Hashable, Sendable {
    var id: String { period }
    let period: String
    let totalCost: String
    let codexCost: String
}

struct BuilderProfile: Hashable {
    var reportToken = ""
    var identityTitle = "Identity not analyzed"
    var archetype = "Builder"
    var stance = "Local-first"
    var subtitle = "Run a private analysis to see how you plan, steer, ship, and recover."
    var proofScore = 0
    var loopScore = 0
    var specificityScore = 0
    var rarity = 0.0
    var generatedAt = "Not generated"
    var dimensions: [BuilderDimension] = []
    var signatureMoves: [String] = []
    var facts: [BuilderFact] = []
    var growthEdge = "Generate an identity to reveal the next useful frontier."
    var usage = UsageSnapshot()
    var evidenceSessions = 0
    var evidenceActiveDays = 0
    var reportURL: URL?
    var sourceURL: URL?

    var displayTitle: String {
        SavedBuilderReport.presentationTitle(for: archetype, fallback: identityTitle)
    }

    var displayMotto: String {
        SavedBuilderReport.presentationMotto(for: archetype, fallback: subtitle)
    }
}

struct SavedBuilderReport: Identifiable, Hashable {
    var id: String { identityURL.path }
    let token: String
    let title: String
    let archetype: String
    let modifier: String
    let stance: String
    let subtitle: String
    let generatedAt: Date
    let windowDays: Int
    let evidenceScore: Int
    let sessions: Int
    let activeDays: Int
    let dimensions: [BuilderDimension]
    let facts: [BuilderFact]
    let signatureMoves: [String]
    let titleRationale: ReportTitleRationale
    let identityURL: URL
    let reportURL: URL?
    let pdfURL: URL?
    let shareURL: URL?
    let shareMode: String?

    var windowLabel: String {
        switch windowDays {
        case 1: "Daily report"
        case 7: "Weekly report"
        case 30: "Monthly report"
        default: "\(windowDays)-day report"
        }
    }

    var presentationTitle: String {
        Self.presentationTitle(for: archetype, fallback: cleanedStoredTitle)
    }

    static func presentationTitle(for archetype: String, fallback: String) -> String {
        presentationTitles[archetype] ?? fallback
    }

    static func presentationMotto(for archetype: String, fallback: String) -> String {
        presentationMottos[archetype] ?? fallback
    }

    var presentationMotto: String {
        Self.presentationMotto(for: archetype, fallback: subtitle)
    }

    var symbolName: String {
        Self.presentationSymbols[archetype] ?? "sparkles.rectangle.stack"
    }

    var emblemSignature: Int {
        Self.presentationSignatures[archetype] ?? archetype.utf8.reduce(0) { ($0 + Int($1)) % 24 }
    }

    var typographySignature: ReportTypographySignature {
        Self.presentationTypography[archetype] ?? ReportTypographySignature(
            design: .rounded,
            weight: .semibold,
            italic: false,
            trackingTenths: 0
        )
    }

    var identityPatternLabel: String {
        Self.presentationPatterns[archetype] ?? Self.humanizedLabel(archetype)
    }

    var workRhythmLabel: String {
        switch modifier.lowercased() {
        case "checklist-driven": "Checklist-led"
        case "observed": "Observed in practice"
        default: Self.humanizedLabel(modifier)
        }
    }

    var operatingStanceLabel: String {
        switch stance.lowercased() {
        case "guardian": "Protective by default"
        case "local-first": "Private by default"
        case "operator": "Direct"
        case "strategist": "Deliberate"
        case "explorer": "Exploratory"
        case "coach": "Developmental"
        case "curator": "Selective"
        case "verifier": "Verification-first"
        default: Self.humanizedLabel(stance)
        }
    }

    var shareCaption: String? {
        guard let shareURL else { return nil }
        let summary = subtitle.trimmingCharacters(in: .whitespacesAndNewlines)
        return [
            "My TokenBar Builder Identity: \(presentationTitle)",
            summary,
            shareURL.absoluteString,
        ]
        .filter { !$0.isEmpty }
        .joined(separator: "\n\n")
    }

    var storyFacts: [BuilderFact] {
        let supportingLabels = Set(["highest trait", "growth lever"])
        let distinctive = facts.filter { !supportingLabels.contains($0.label.lowercased()) }
        let supporting = facts.filter { supportingLabels.contains($0.label.lowercased()) }
        return Array((distinctive + supporting).prefix(4))
    }

    var scrollStoryBeats: [ReportStoryBeat] {
        var beats = [
            ReportStoryBeat(
                kind: "identity",
                eyebrow: "Builder identity",
                title: "You are",
                value: presentationTitle,
                copy: presentationMotto,
                symbolName: symbolName
            ),
        ]

        if let strongestDimension {
            let note = strongestDimension.note.trimmingCharacters(in: .whitespacesAndNewlines)
            beats.append(
                ReportStoryBeat(
                    kind: "signal",
                    eyebrow: "Strongest signal",
                    title: strongestDimension.name,
                    value: "\(strongestDimension.score)",
                    copy: note.isEmpty
                        ? "\(strongestDimension.name) is the clearest repeated signal in this report."
                        : note,
                    symbolName: "waveform.path"
                )
            )
        }

        for (index, fact) in storyFacts.enumerated() {
            beats.append(
                ReportStoryBeat(
                    kind: "fact",
                    eyebrow: "Field note \(String(format: "%02d", index + 1))",
                    title: fact.label,
                    value: fact.value,
                    copy: fact.copy,
                    symbolName: Self.storySymbol(for: fact.label)
                )
            )
        }

        return beats
    }

    var resolvedTitleRationale: ReportTitleRationale {
        let rankedDimensions = dimensions.sorted { $0.score > $1.score }
        let components = titleRationale.components.isEmpty
            ? fallbackTitleComponents(rankedDimensions: rankedDimensions)
            : titleRationale.components
        let drivers = titleRationale.drivers.isEmpty
            ? rankedDimensions.prefix(6).map { ReportTraitDriver(name: $0.name, score: $0.score) }
            : titleRationale.drivers
        return ReportTitleRationale(components: components, drivers: drivers)
    }

    var displayTitleRationale: ReportTitleRationale {
        let rationale = resolvedTitleRationale
        let components = rationale.components.enumerated().map { index, component in
            let kind = component.kind.lowercased()
            if kind.contains("archetype") || index == 0 {
                return ReportTitleComponent(
                    name: identityPatternLabel,
                    kind: "Core pattern",
                    reason: component.reason,
                    probability: component.probability
                )
            }
            if kind.contains("modifier") || index == 1 {
                return ReportTitleComponent(
                    name: workRhythmLabel,
                    kind: "Work rhythm",
                    reason: component.reason,
                    probability: component.probability
                )
            }
            return ReportTitleComponent(
                name: operatingStanceLabel,
                kind: "Operating stance",
                reason: component.reason,
                probability: component.probability
            )
        }
        return ReportTitleRationale(components: components, drivers: rationale.drivers)
    }

    var strongestDimension: BuilderDimension? {
        dimensions.max { $0.score < $1.score }
    }

    var identityFamily: ReportIdentityFamily {
        Self.presentationFamilies[archetype] ?? .general
    }

    func matches(_ query: String) -> Bool {
        let normalized = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !normalized.isEmpty else { return true }
        return [
            token,
            title,
            presentationTitle,
            archetype,
            modifier,
            stance,
            windowLabel,
            identityURL.lastPathComponent,
        ]
        .joined(separator: " ")
        .localizedCaseInsensitiveContains(normalized)
    }

    func matchesReference(_ reference: String) -> Bool {
        let normalized = reference.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !normalized.isEmpty else { return false }
        if token.caseInsensitiveCompare(normalized) == .orderedSame {
            return true
        }

        let candidatePath = NSString(string: normalized).expandingTildeInPath
        let localURLs = [identityURL, reportURL, pdfURL].compactMap { $0 }
        if localURLs.contains(where: {
            $0.path == candidatePath || $0.lastPathComponent.caseInsensitiveCompare(normalized) == .orderedSame
        }) {
            return true
        }

        return shareURL?.absoluteString.caseInsensitiveCompare(normalized) == .orderedSame
    }

    var editionFingerprint: String {
        let dimensionSignature = dimensions
            .sorted { $0.name < $1.name }
            .map { "\($0.name.lowercased()):\($0.score)" }
            .joined(separator: ",")
        return [
            presentationTitle.lowercased(),
            archetype.lowercased(),
            modifier.lowercased(),
            stance.lowercased(),
            String(windowDays),
            String(evidenceScore),
            String(sessions),
            String(activeDays),
            dimensionSignature,
        ].joined(separator: "|")
    }

    private var cleanedStoredTitle: String {
        let technicalWords = [modifier, archetype, stance].filter { !$0.isEmpty }
        let technicalTitle = technicalWords.joined(separator: " ")
        if !technicalTitle.isEmpty, title.caseInsensitiveCompare(technicalTitle) == .orderedSame {
            return archetype
        }
        return title
    }

    private func fallbackTitleComponents(rankedDimensions: [BuilderDimension]) -> [ReportTitleComponent] {
        let archetypeDriver = rankedDimensions.first
        let modifierDriver = rankedDimensions.dropFirst().first
        let observedSessions = sessions > 0 ? " across \(sessions) local sessions" : " in this local report"
        let observedWindow = activeDays > 0
            ? "Observed on \(activeDays) active days during this \(windowLabel.lowercased())."
            : "Observed during this \(windowLabel.lowercased())."

        return [
            ReportTitleComponent(
                name: archetype.isEmpty ? presentationTitle : archetype,
                kind: "archetype",
                reason: rationaleReason(
                    for: archetypeDriver,
                    fallback: "The strongest repeated pattern\(observedSessions)."
                ),
                probability: archetypeDriver.map { Double($0.score) }
            ),
            ReportTitleComponent(
                name: modifier.isEmpty ? "Observed" : modifier,
                kind: "modifier",
                reason: rationaleReason(
                    for: modifierDriver,
                    fallback: "The working style repeated\(observedSessions)."
                ),
                probability: modifierDriver.map { Double($0.score) }
            ),
            ReportTitleComponent(
                name: stance.isEmpty ? "Local-first" : stance,
                kind: "stance",
                reason: observedWindow,
                probability: evidenceScore > 0 ? Double(evidenceScore) : nil
            ),
        ]
    }

    private func rationaleReason(for dimension: BuilderDimension?, fallback: String) -> String {
        guard let dimension else { return fallback }
        let note = dimension.note.trimmingCharacters(in: .whitespacesAndNewlines)
        return note.isEmpty ? "\(dimension.name) leads at \(dimension.score)." : note
    }

    private static let presentationTitles: [String: String] = [
        "Scaffold Architect": "Architect of the Impossible Atlas",
        "Revenue Systems Captain": "Sovereign of the Unwritten Engine",
        "Agent Infrastructure Cartographer": "Cartographer of the Glass Frontier",
        "Report Engine Philosopher": "Oracle of the Last Signal",
        "Velocity Operator": "Corsair of the Black Meridian",
        "Quality Guardian": "Warden of the Iron Constellation",
        "Prompt Stress Tester": "Edgebreaker of the Silent Armada",
        "Design Systems Bard": "Mythmaker of the Ember Crown",
        "Research Alchemist": "Alchemist of the Living Archive",
        "Multi-Agent Conductor": "Conductor of the Threaded Leviathan",
        "Product Mythmaker": "Harbinger of Unwritten Worlds",
        "Local-First Sovereign": "Sovereign of the Hidden Citadel",
        "Session Archaeologist": "Archaeologist of Lost Sessions",
        "Workflow Diplomat": "Envoy of the Interlocking Realms",
        "Launch Systems Producer": "Vanguard of the Final Launch",
        "Heuristic Cartel Builder": "Corsair of Repeatable Magic",
        "Proof Layer Broker": "Marshal of the Evidence Vault",
        "Runway Economist": "Quartermaster of the Token Seas",
        "Connector Locksmith": "Locksmith of the Secret Routes",
        "Narrative Debugger": "Cartographer of Broken Stories",
        "Evidence Gardener": "Keeper of the Proof Garden",
        "Agent Coach": "Steward of the Agent Guild",
        "Chaos-to-Canon Editor": "Forger of the Final Canon",
        "Portfolio Systems Curator": "Curator of the Builder Pantheon",
    ]

    private static let presentationMottos: [String: String] = [
        "Scaffold Architect": "Builds foundations other builders can stand on.",
        "Revenue Systems Captain": "Turns product intent into durable commercial machinery.",
        "Agent Infrastructure Cartographer": "Maps the routes between agents, tools, and durable handoffs.",
        "Report Engine Philosopher": "Finds the claim worth keeping and the proof that makes it hold.",
        "Velocity Operator": "Finds the signal, cuts ceremony, and keeps the build moving.",
        "Quality Guardian": "Shapes constraints until the system can survive contact.",
        "Prompt Stress Tester": "Presses the weak edge until it tells the truth.",
        "Design Systems Bard": "Gives systems a visual language people remember.",
        "Research Alchemist": "Turns scattered sources into one useful direction.",
        "Multi-Agent Conductor": "Weaves many active threads into shared direction.",
        "Product Mythmaker": "Gives a product a world people can enter.",
        "Local-First Sovereign": "Keeps the crown jewels on-device and sharing deliberate.",
        "Session Archaeologist": "Reconstructs the build from the traces it left behind.",
        "Workflow Diplomat": "Makes incompatible tools cooperate without losing the handoff.",
        "Launch Systems Producer": "Carries the build from almost ready to unmistakably shipped.",
        "Heuristic Cartel Builder": "Collects repeatable moves and turns them into leverage.",
        "Proof Layer Broker": "Refuses the victory lap until the evidence is inspectable.",
        "Runway Economist": "Makes tokens, time, and attention last through the mission.",
        "Connector Locksmith": "Forges reliable doors between systems.",
        "Narrative Debugger": "Maps confusion until the product story has a clean route.",
        "Evidence Gardener": "Tends the small facts that make a larger claim credible.",
        "Agent Coach": "Improves the working relationship, not just the immediate output.",
        "Chaos-to-Canon Editor": "Turns experimental sprawl into one trusted source of truth.",
        "Portfolio Systems Curator": "Protects the best work and makes its progression legible.",
    ]

    private static let presentationPatterns: [String: String] = [
        "Scaffold Architect": "System scaffolding",
        "Revenue Systems Captain": "Commercial systems",
        "Agent Infrastructure Cartographer": "Agent infrastructure",
        "Report Engine Philosopher": "Evidence synthesis",
        "Velocity Operator": "Shipping velocity",
        "Quality Guardian": "Reliability discipline",
        "Prompt Stress Tester": "Adversarial prompting",
        "Design Systems Bard": "Interface systems",
        "Research Alchemist": "Research synthesis",
        "Multi-Agent Conductor": "Agent orchestration",
        "Product Mythmaker": "Product narrative",
        "Local-First Sovereign": "Privacy-first systems",
        "Session Archaeologist": "Session forensics",
        "Workflow Diplomat": "Cross-tool workflows",
        "Launch Systems Producer": "Launch operations",
        "Heuristic Cartel Builder": "Pattern heuristics",
        "Proof Layer Broker": "Verifiable outcomes",
        "Runway Economist": "Compute strategy",
        "Connector Locksmith": "Systems integration",
        "Narrative Debugger": "Narrative clarity",
        "Evidence Gardener": "Evidence curation",
        "Agent Coach": "Agent coaching",
        "Chaos-to-Canon Editor": "Operational clarity",
        "Portfolio Systems Curator": "Portfolio systems",
    ]

    private static func humanizedLabel(_ value: String) -> String {
        value
            .replacingOccurrences(of: "-", with: " ")
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private static func storySymbol(for label: String) -> String {
        let normalized = label.lowercased()
        if normalized.contains("identity") { return "square.grid.3x3.fill" }
        if normalized.contains("command") { return "cursorarrow.rays" }
        if normalized.contains("short") { return "bolt.fill" }
        if normalized.contains("question") { return "questionmark.bubble.fill" }
        if normalized.contains("courtesy") || normalized.contains("thank") { return "hand.wave.fill" }
        if normalized.contains("typo") { return "keyboard.badge.ellipsis" }
        if normalized.contains("model") { return "cpu.fill" }
        if normalized.contains("time") || normalized.contains("night") { return "moon.stars.fill" }
        return "sparkles"
    }

    private static let presentationSymbols: [String: String] = [
        "Scaffold Architect": "building.columns",
        "Revenue Systems Captain": "chart.line.uptrend.xyaxis",
        "Agent Infrastructure Cartographer": "point.3.connected.trianglepath.dotted",
        "Report Engine Philosopher": "doc.text.image",
        "Velocity Operator": "bolt.fill",
        "Quality Guardian": "checkmark.shield.fill",
        "Prompt Stress Tester": "waveform.path.ecg",
        "Design Systems Bard": "paintpalette.fill",
        "Research Alchemist": "flask.fill",
        "Multi-Agent Conductor": "circle.hexagongrid.fill",
        "Product Mythmaker": "book.pages.fill",
        "Local-First Sovereign": "lock.laptopcomputer",
        "Session Archaeologist": "fossil.shell.fill",
        "Workflow Diplomat": "arrow.triangle.branch",
        "Launch Systems Producer": "paperplane.fill",
        "Heuristic Cartel Builder": "square.grid.3x3.fill",
        "Proof Layer Broker": "checkmark.seal.fill",
        "Runway Economist": "gauge.with.dots.needle.67percent",
        "Connector Locksmith": "key.horizontal.fill",
        "Narrative Debugger": "text.magnifyingglass",
        "Evidence Gardener": "leaf.fill",
        "Agent Coach": "figure.run.circle.fill",
        "Chaos-to-Canon Editor": "wand.and.stars",
        "Portfolio Systems Curator": "archivebox.fill",
    ]

    // Stable visual signatures keep every supported identity recognizable even
    // when two archetypes share the same broader color and motion family.
    private static let presentationSignatures: [String: Int] = [
        "Scaffold Architect": 0,
        "Revenue Systems Captain": 1,
        "Agent Infrastructure Cartographer": 2,
        "Report Engine Philosopher": 3,
        "Velocity Operator": 4,
        "Quality Guardian": 5,
        "Prompt Stress Tester": 6,
        "Design Systems Bard": 7,
        "Research Alchemist": 8,
        "Multi-Agent Conductor": 9,
        "Product Mythmaker": 10,
        "Local-First Sovereign": 11,
        "Session Archaeologist": 12,
        "Workflow Diplomat": 13,
        "Launch Systems Producer": 14,
        "Heuristic Cartel Builder": 15,
        "Proof Layer Broker": 16,
        "Runway Economist": 17,
        "Connector Locksmith": 18,
        "Narrative Debugger": 19,
        "Evidence Gardener": 20,
        "Agent Coach": 21,
        "Chaos-to-Canon Editor": 22,
        "Portfolio Systems Curator": 23,
    ]

    private static let presentationTypography: [String: ReportTypographySignature] = [
        "Scaffold Architect": .init(design: .serif, weight: .semibold, italic: false, trackingTenths: 1),
        "Revenue Systems Captain": .init(design: .serif, weight: .bold, italic: true, trackingTenths: 0),
        "Agent Infrastructure Cartographer": .init(design: .rounded, weight: .medium, italic: false, trackingTenths: 3),
        "Report Engine Philosopher": .init(design: .serif, weight: .medium, italic: true, trackingTenths: 2),
        "Velocity Operator": .init(design: .rounded, weight: .heavy, italic: true, trackingTenths: 0),
        "Quality Guardian": .init(design: .rounded, weight: .semibold, italic: false, trackingTenths: 1),
        "Prompt Stress Tester": .init(design: .monospaced, weight: .bold, italic: false, trackingTenths: 4),
        "Design Systems Bard": .init(design: .serif, weight: .medium, italic: true, trackingTenths: 5),
        "Research Alchemist": .init(design: .rounded, weight: .semibold, italic: false, trackingTenths: 2),
        "Multi-Agent Conductor": .init(design: .rounded, weight: .bold, italic: false, trackingTenths: 0),
        "Product Mythmaker": .init(design: .serif, weight: .bold, italic: true, trackingTenths: 3),
        "Local-First Sovereign": .init(design: .rounded, weight: .medium, italic: false, trackingTenths: 1),
        "Session Archaeologist": .init(design: .monospaced, weight: .semibold, italic: false, trackingTenths: 2),
        "Workflow Diplomat": .init(design: .rounded, weight: .semibold, italic: true, trackingTenths: 1),
        "Launch Systems Producer": .init(design: .rounded, weight: .heavy, italic: true, trackingTenths: 2),
        "Heuristic Cartel Builder": .init(design: .monospaced, weight: .medium, italic: false, trackingTenths: 5),
        "Proof Layer Broker": .init(design: .serif, weight: .semibold, italic: false, trackingTenths: 4),
        "Runway Economist": .init(design: .serif, weight: .bold, italic: false, trackingTenths: 2),
        "Connector Locksmith": .init(design: .monospaced, weight: .semibold, italic: false, trackingTenths: 4),
        "Narrative Debugger": .init(design: .serif, weight: .medium, italic: true, trackingTenths: 6),
        "Evidence Gardener": .init(design: .serif, weight: .semibold, italic: true, trackingTenths: 2),
        "Agent Coach": .init(design: .rounded, weight: .bold, italic: true, trackingTenths: 1),
        "Chaos-to-Canon Editor": .init(design: .monospaced, weight: .bold, italic: true, trackingTenths: 2),
        "Portfolio Systems Curator": .init(design: .serif, weight: .heavy, italic: false, trackingTenths: 1),
    ]

    private static let presentationFamilies: [String: ReportIdentityFamily] = [
        "Scaffold Architect": .architecture,
        "Revenue Systems Captain": .commerce,
        "Agent Infrastructure Cartographer": .exploration,
        "Report Engine Philosopher": .evidence,
        "Velocity Operator": .velocity,
        "Quality Guardian": .reliability,
        "Prompt Stress Tester": .stress,
        "Design Systems Bard": .design,
        "Research Alchemist": .research,
        "Multi-Agent Conductor": .orchestration,
        "Product Mythmaker": .design,
        "Local-First Sovereign": .privacy,
        "Session Archaeologist": .evidence,
        "Workflow Diplomat": .workflow,
        "Launch Systems Producer": .launch,
        "Heuristic Cartel Builder": .research,
        "Proof Layer Broker": .evidence,
        "Runway Economist": .strategy,
        "Connector Locksmith": .integration,
        "Narrative Debugger": .design,
        "Evidence Gardener": .evidence,
        "Agent Coach": .coaching,
        "Chaos-to-Canon Editor": .reliability,
        "Portfolio Systems Curator": .portfolio,
    ]
}

struct ReportIdentityCollection: Identifiable, Hashable {
    let title: String
    let reports: [SavedBuilderReport]

    var id: String { title }
    var latest: SavedBuilderReport { reports[0] }
}

enum SavedReportLibrary {
    static func deduplicated(_ reports: [SavedBuilderReport]) -> [SavedBuilderReport] {
        var fingerprints = Set<String>()
        return reports.filter { fingerprints.insert($0.editionFingerprint).inserted }
    }

    static func collections(from reports: [SavedBuilderReport]) -> [ReportIdentityCollection] {
        let uniqueReports = deduplicated(reports)
        let grouped = Dictionary(grouping: uniqueReports, by: \.presentationTitle)
        return grouped
            .map { title, reports in
                ReportIdentityCollection(
                    title: title,
                    reports: reports.sorted { $0.generatedAt > $1.generatedAt }
                )
            }
            .sorted { $0.latest.generatedAt > $1.latest.generatedAt }
    }
}

enum IdentityBridgeSource: String, Sendable {
    case checking
    case liveAPI
    case safeSnapshot
    case localFile
    case unavailable

    var label: String {
        switch self {
        case .checking: "Checking safe bundle"
        case .liveAPI: "Safe API live"
        case .safeSnapshot: "Safe CLI snapshot"
        case .localFile: "Local report fallback"
        case .unavailable: "No identity evidence"
        }
    }

    var icon: String {
        switch self {
        case .checking: "arrow.triangle.2.circlepath"
        case .liveAPI: "bolt.horizontal.circle.fill"
        case .safeSnapshot: "shippingbox.fill"
        case .localFile: "doc.text.fill"
        case .unavailable: "exclamationmark.triangle"
        }
    }

    var detail: String {
        switch self {
        case .checking: "Looking for the read-only TokenBar identity contract."
        case .liveAPI: "Loaded from 127.0.0.1 using generated identity fields and aggregate usage only."
        case .safeSnapshot: "Loaded from the packaged tokenbar.builder_bundle.v1 CLI snapshot."
        case .localFile: "The safe bridge is unavailable, so TokenBar is showing the newest private local report."
        case .unavailable: "Run Analyze this week to create a private Builder Identity report."
        }
    }
}

private struct SafeIdentityBundle: Decodable, Sendable {
    let ok: Bool
    let schema: String
    let identity: SafeIdentity?
    let stats: SafeIdentityStats
    let privacy: SafeIdentityPrivacy
}

private struct SafeIdentity: Decodable, Sendable {
    let title: String?
    let subtitle: String?
    let primaryArchetype: String?
    let identityLabel: SafeIdentityLabel?
    let proofScore: Int?
    let loopScore: Int?
    let loopMaturity: Int?
    let specificityScore: Int?
    let estimatedRarityPercent: Double?
    let generatedAt: String?
    let dimensions: [SafeBuilderDimension]?
    let signatureMoves: [String]?
    let curiousFacts: [SafeBuilderFact]?
    let growthEdge: String?
    let usage: SafeIdentityUsage?
}

private struct SafeIdentityLabel: Decodable, Sendable {
    let title: String?
    let stance: String?
}

private struct SafeBuilderDimension: Decodable, Sendable {
    let name: String
    let score: Int
    let note: String?
}

private struct SafeBuilderFact: Decodable, Sendable {
    let label: String
    let value: String
    let copy: String?
}

private struct SafeIdentityUsage: Decodable, Sendable {
    let sessionsIndexed: Int?
    let activeDaysLast30: Int?
}

private struct SafeIdentityStats: Decodable, Sendable {
    let updatedAt: Double?
    let totalTokens: Int64
    let sessionCount: Int
    let activeDayCount: Int
    let activeFolderCount: Int
    let dayTokens: [String: Int64]
    let modelTokens: [String: Int64]
}

private struct SafeIdentityPrivacy: Decodable, Sendable {
    let rawTranscriptsIncluded: Bool
    let sourceCodeIncluded: Bool
    let localPathsIncluded: Bool
    let secretsIncluded: Bool
}

private struct SafeBridgeResult: Sendable {
    let bundle: SafeIdentityBundle?
    let source: IdentityBridgeSource
    let error: String?
}

struct ProofReceipt: Hashable {
    var token = "Not published"
    var runID = ""
    var shareMode = "private"
    var generatedAt = ""
    var completedStages: [String] = []
    var publicMaterial = ""
    var uploadedMaterial = ""
    var neverPublic: [String] = []
    var redactedFields: [String] = []
    var ownerBound = false
    var privacyVerified = false
    var publicProfileURL: URL?
    var proofCardURL: URL?
    var socialURL: URL?
    var rankingsURL: URL?

    var hasShareSurface: Bool { publicProfileURL != nil || proofCardURL != nil }
    var isLocalPreview: Bool {
        [publicProfileURL, proofCardURL].compactMap { $0?.host }.contains { $0 == "127.0.0.1" || $0 == "localhost" }
    }
    var verificationSummary: String {
        let stages = completedStages.isEmpty ? "not recorded" : completedStages.joined(separator: ", ")
        let privacy = privacyVerified ? "raw transcripts and source code excluded" : "privacy receipt unavailable"
        return "TokenBar proof \(token); run \(runID); mode \(shareMode); stages: \(stages); \(privacy)."
    }
}

struct ProjectInvitation: Codable, Identifiable, Hashable {
    let id: UUID
    var title: String
    var proposer: String
    var summary: String
    var sourcePath: String
    var importedAt: Date
    var status: String
}

enum CodexThreadLane: String, CaseIterable, Identifiable {
    case queued = "Queued"
    case focus = "Focus"
    case recent = "Recent"
    case review = "Review"
    case done = "Done"

    var id: String { rawValue }
    var subtitle: String {
        switch self {
        case .queued: "Not started"
        case .focus: "In progress"
        case .recent: "Recently active"
        case .review: "Needs a look"
        case .done: "Finished"
        }
    }
}

struct ThreadBoardConfiguration: Codable, Identifiable, Hashable {
    static let starterID = UUID(uuidString: "67483EEA-73DA-4A50-920C-84267EF25A68")!
    static let starter = ThreadBoardConfiguration(
        id: starterID,
        name: "Project Finish Line",
        queuedTitle: "Waiting",
        focusTitle: "Working",
        recentTitle: "Next",
        reviewTitle: "Check",
        doneTitle: "Complete",
        workspaceFilter: "",
        includeAutomations: true,
        accentName: "cyan"
    )

    let id: UUID
    var name: String
    var queuedTitle: String
    var focusTitle: String
    var recentTitle: String
    var reviewTitle: String
    var doneTitle: String
    var workspaceFilter: String
    var includeAutomations: Bool
    var accentName: String

    init(
        id: UUID,
        name: String,
        queuedTitle: String = "Waiting",
        focusTitle: String,
        recentTitle: String,
        reviewTitle: String,
        doneTitle: String = "Complete",
        workspaceFilter: String,
        includeAutomations: Bool,
        accentName: String = "cyan"
    ) {
        self.id = id
        self.name = name
        self.queuedTitle = queuedTitle
        self.focusTitle = focusTitle
        self.recentTitle = recentTitle
        self.reviewTitle = reviewTitle
        self.doneTitle = doneTitle
        self.workspaceFilter = workspaceFilter
        self.includeAutomations = includeAutomations
        self.accentName = accentName
    }

    enum CodingKeys: String, CodingKey {
        case id, name, queuedTitle, focusTitle, recentTitle, reviewTitle, doneTitle
        case workspaceFilter, includeAutomations, accentName
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        name = try container.decode(String.self, forKey: .name)
        queuedTitle = try container.decodeIfPresent(String.self, forKey: .queuedTitle) ?? "Waiting"
        focusTitle = try container.decode(String.self, forKey: .focusTitle)
        recentTitle = try container.decode(String.self, forKey: .recentTitle)
        reviewTitle = try container.decode(String.self, forKey: .reviewTitle)
        doneTitle = try container.decodeIfPresent(String.self, forKey: .doneTitle) ?? "Complete"
        workspaceFilter = try container.decodeIfPresent(String.self, forKey: .workspaceFilter) ?? ""
        includeAutomations = try container.decodeIfPresent(Bool.self, forKey: .includeAutomations) ?? true
        accentName = try container.decodeIfPresent(String.self, forKey: .accentName) ?? "cyan"
    }

    func title(for lane: CodexThreadLane) -> String {
        switch lane {
        case .queued: queuedTitle
        case .focus: focusTitle
        case .recent: recentTitle
        case .review: reviewTitle
        case .done: doneTitle
        }
    }
}

private struct ThreadBoardStore: Codable {
    var selectedBoardID: UUID
    var boards: [ThreadBoardConfiguration]
}

private struct LocalCostUsageCache: Codable {
    static let schema = "tokenbar.local_cost_usage.v1"

    let schema: String
    let savedAt: Date
    let snapshot: CCUsageSnapshot
}

struct CodexThread: Decodable, Identifiable, Hashable, Sendable {
    let id: String
    let title: String
    let cwd: String
    let tokensUsed: Int64
    let recencyAtMs: Int64
    let source: String
    let gitBranch: String?
    let gitSHA: String?
    let model: String?
    let threadSource: String?
    let parentThreadID: String?
    let childThreadCount: Int
    let goalStatus: String
    var changedFileCount = 0
    var gitReviewState = "unavailable"

    enum CodingKeys: String, CodingKey {
        case id, title, cwd, source
        case tokensUsed = "tokens_used"
        case recencyAtMs = "recency_at_ms"
        case gitBranch = "git_branch"
        case gitSHA = "git_sha"
        case model
        case threadSource = "thread_source"
        case parentThreadID = "parent_thread_id"
        case childThreadCount = "child_thread_count"
        case goalStatus = "goal_status"
    }

    var displayTitle: String {
        let compact = title.replacingOccurrences(of: "\n", with: " ")
            .replacingOccurrences(of: "  ", with: " ")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        if compact.hasPrefix("Automation:"), let marker = compact.range(of: " Automation ID:") {
            return String(compact[..<marker.lowerBound])
        }
        guard compact.count > 92 else { return compact }
        return String(compact.prefix(89)).trimmingCharacters(in: .whitespacesAndNewlines) + "…"
    }

    var cardTitle: String {
        var compact = displayTitle
        let lowercased = compact.lowercased()

        if lowercased.contains("<codex_delegation")
            || lowercased.contains("<source_thread_id") {
            return workspace == "Desktop"
                ? "Continue the local build"
                : "Continue \(workspaceHeadline) build"
        }
        if lowercased.contains("openai developers home api") {
            return "Map the OpenAI developer stack"
        }
        if lowercased.contains("timeline feature") {
            return "Design the builder timeline"
        }
        if lowercased.contains("submit rogii") {
            return "Prepare the ROGII submission"
        }
        if lowercased.contains("blends and 3d assets") {
            return "Audit the Blender asset library"
        }

        let conversationalPrefixes = [
            "Automation:",
            "Can you like,",
            "Can you",
            "Could you",
            "Please",
            "Let's",
            "I want you to",
            "I'm just wondering,",
            "Okay,",
            "Yeah,",
            "So,",
        ]

        for prefix in conversationalPrefixes
        where compact.range(of: prefix, options: [.anchored, .caseInsensitive]) != nil {
            compact = String(compact.dropFirst(prefix.count))
                .trimmingCharacters(in: CharacterSet.whitespacesAndNewlines.union(.punctuationCharacters))
            break
        }

        compact = compact
            .replacingOccurrences(
                of: #"(?i)\bdrastically enhance the following scene\b"#,
                with: "Elevate the scene",
                options: .regularExpression
            )
            .replacingOccurrences(
                of: #"(?i)\b(?:like )?there can be a\b"#,
                with: "Add a",
                options: .regularExpression
            )
            .split(whereSeparator: \.isWhitespace)
            .joined(separator: " ")
        if compact.isEmpty {
            compact = displayTitle
        }

        if let sentenceEnd = compact.firstIndex(where: { ".?!".contains($0) }),
           compact.distance(from: compact.startIndex, to: sentenceEnd) >= 8 {
            compact = String(compact[...sentenceEnd])
        }

        guard compact.count > 58 else { return compact }
        return String(compact.prefix(55)).trimmingCharacters(in: .whitespacesAndNewlines) + "…"
    }

    private var workspaceHeadline: String {
        let cleaned = workspace
            .replacingOccurrences(of: "app-portfolio-", with: "")
            .replacingOccurrences(of: "_", with: "-")
        return cleaned
            .split(separator: "-")
            .map { $0.prefix(1).uppercased() + $0.dropFirst() }
            .joined(separator: " ")
    }

    var workspace: String {
        URL(fileURLWithPath: cwd).lastPathComponent.isEmpty ? cwd : URL(fileURLWithPath: cwd).lastPathComponent
    }

    var shortID: String { String(id.prefix(8)) }
    var parentShortID: String? { parentThreadID.map { String($0.prefix(8)) } }
    var deepLink: URL? { URL(string: "codex://threads/\(id)") }
    var updatedAt: Date { Date(timeIntervalSince1970: TimeInterval(recencyAtMs) / 1_000) }
    var isFork: Bool { parentThreadID != nil }
    var isAutomation: Bool {
        displayTitle.localizedCaseInsensitiveContains("Automation:")
            || (threadSource ?? source).localizedCaseInsensitiveContains("automation")
    }
    var sideChatPrompt: String {
        """
        /side Review the current state of "\(displayTitle)" (thread \(id)). Identify what changed, what remains uncertain, and the smallest verifiable next action. Keep this as a side chat; do not interrupt or rewrite the main thread.
        """
    }

    func lane(now: Date = Date()) -> CodexThreadLane {
        if goalStatus == "complete" || goalStatus == "completed" { return .done }
        if goalStatus == "active" { return .focus }
        let age = now.timeIntervalSince(updatedAt)
        if goalStatus == "paused" || goalStatus == "blocked" || goalStatus == "usage_limited" || goalStatus == "budget_limited" {
            return .review
        }
        if age <= 86_400 { return .recent }
        if age <= 604_800 { return .queued }
        return .review
    }
}

@MainActor
final class TokenBarModel: ObservableObject {
    static let shared = TokenBarModel()

    @Published var profile = BuilderProfile()
    @Published var receipt = ProofReceipt()
    @Published var savedReports: [SavedBuilderReport] = []
    @Published var invitations: [ProjectInvitation] = []
    @Published var codexThreads: [CodexThread] = []
    @Published var threadDrafts: [String: String] = [:]
    @Published var threadBoards: [ThreadBoardConfiguration] = [.starter]
    @Published var selectedThreadBoardID = ThreadBoardConfiguration.starterID
    @Published var costUsage = CCUsageSnapshot()
    @Published var storageItems: [StorageItemSnapshot] = []
    @Published var isAnalyzing = false
    @Published var isPublishingProof = false
    @Published var isExportingProof = false
    @Published var isImportingReport = false
    @Published var lastImportedReportID: String?
    @Published var isLoadingCosts = false
    @Published var isRevoking = false
    @Published var isLoadingThreads = false
    @Published var isScanningStorage = false
    @Published var isLoadingIdentityBridge = false
    @Published var identityBridgeSource = IdentityBridgeSource.checking
    @Published var activityMessage = "Local data loaded"
    @Published var lastError: String?

    private let fileManager = FileManager.default
    private let supportDirectory: URL

    init(supportDirectory overrideDirectory: URL? = nil) {
        if let overrideDirectory {
            supportDirectory = overrideDirectory
        } else if let override = ProcessInfo.processInfo.environment["TOKENBAR_SUPPORT_DIR"], !override.isEmpty {
            supportDirectory = URL(fileURLWithPath: override, isDirectory: true)
        } else {
            supportDirectory = fileManager.homeDirectoryForCurrentUser
                .appendingPathComponent("Library/Application Support/CodexLimitBar", isDirectory: true)
        }
        let boardStore = loadThreadBoardStore()
        threadBoards = boardStore.boards
        selectedThreadBoardID = boardStore.selectedBoardID
        threadDrafts = loadThreadDrafts()
        costUsage = loadCostUsageSnapshot()
        reload()
        refreshIdentityBridge()
        refreshThreads()
    }

    func reload() {
        profile = loadLatestProfile()
        receipt = loadLatestReceipt()
        savedReports = loadReportHistory()
        invitations = loadInvitations()
        identityBridgeSource = profile.sourceURL == nil ? .unavailable : .localFile
        activityMessage = profile.sourceURL == nil ? "Ready for a private local analysis" : "Updated from local evidence"
    }

    func refreshIdentityBridge() {
        guard !isLoadingIdentityBridge else { return }
        isLoadingIdentityBridge = true
        identityBridgeSource = .checking

        Task {
            let result = await Task.detached(priority: .utility) {
                await Self.loadSafeIdentityBridge()
            }.value
            isLoadingIdentityBridge = false
            if let bundle = result.bundle {
                profile = profileFromSafeBundle(bundle, preserving: profile)
                identityBridgeSource = result.source
                activityMessage = result.source == .liveAPI
                    ? "Builder Story synced from the safe local API"
                    : "Builder Story loaded from the safe CLI bundle"
            } else {
                identityBridgeSource = profile.sourceURL == nil ? .unavailable : .localFile
                if profile.sourceURL == nil, let error = result.error {
                    lastError = error
                }
            }
        }
    }

    func refreshIdentity(days: Int = 7) {
        guard !isAnalyzing else { return }
        isAnalyzing = true
        lastError = nil
        let boundedDays = min(max(days, 1), 90)
        activityMessage = "Reading \(boundedDays) day\(boundedDays == 1 ? "" : "s") of local Codex evidence…"

        Task {
            let result = await Task.detached(priority: .userInitiated) {
                Self.runTokenBar(arguments: ["claim", "--days", "\(boundedDays)"])
            }.value
            isAnalyzing = false
            if result.status == 0 {
                reload()
                refreshIdentityBridge()
                activityMessage = "\(boundedDays)-day Builder Story ready"
            } else {
                lastError = result.output.isEmpty ? "TokenBar could not refresh the identity." : result.output
                activityMessage = "Analysis needs attention"
            }
        }
    }

    func publishCurrentProof() {
        guard let report = savedReports.first else {
            lastError = "Analyze your Builder Identity before creating a link."
            return
        }
        publishReport(report)
    }

    func publishReport(_ report: SavedBuilderReport) {
        guard !isPublishingProof, report.shareURL == nil else { return }
        isPublishingProof = true
        lastError = nil
        activityMessage = "Creating a private link for \(report.windowLabel.lowercased())…"

        Task {
            let result = await Task.detached(priority: .userInitiated) {
                Self.runTokenBar(arguments: [
                    "publish-proof",
                    report.identityURL.path,
                    "--unlisted",
                    "--hide-owner",
                    "--hide-region",
                ])
            }.value
            isPublishingProof = false
            if result.status == 0 {
                reload()
                refreshIdentityBridge()
                if savedReports.first(where: { $0.id == report.id })?.shareURL != nil {
                    activityMessage = "Private link ready · this report remains saved locally"
                } else {
                    lastError = "The link action completed but TokenBar could not reload its share receipt."
                    activityMessage = "Report link needs attention"
                }
            } else {
                lastError = result.output.isEmpty ? "TokenBar could not create the private report link." : result.output
                activityMessage = "Report link needs attention"
            }
        }
    }

    func importReportReference(_ rawReference: String) {
        let reference = rawReference.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !reference.isEmpty, !isImportingReport else { return }

        if let local = savedReports.first(where: { $0.matches(reference) }) {
            lastImportedReportID = local.id
            activityMessage = "Opened \(local.presentationTitle)"
            return
        }

        isImportingReport = true
        lastError = nil
        activityMessage = "Checking report reference…"

        Task {
            do {
                let data: Data
                let sourceName: String
                if let localURL = Self.localReportURL(from: reference) {
                    let values = try localURL.resourceValues(forKeys: [.fileSizeKey])
                    guard (values.fileSize ?? 0) <= 2_000_000 else {
                        throw ReportImportError.tooLarge
                    }
                    data = try Data(contentsOf: localURL)
                    sourceName = localURL.lastPathComponent
                } else {
                    guard let url = Self.publicReportAPIURL(from: reference) else {
                        throw ReportImportError.unsupportedReference
                    }
                    var request = URLRequest(url: url)
                    request.setValue("application/json", forHTTPHeaderField: "Accept")
                    let (downloaded, response) = try await URLSession.shared.data(for: request)
                    guard let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode) else {
                        throw ReportImportError.notFound
                    }
                    guard downloaded.count <= 2_000_000 else {
                        throw ReportImportError.tooLarge
                    }
                    data = downloaded
                    sourceName = url.host ?? "shared TokenBar report"
                }

                let importedID = try ingestReportData(data, sourceName: sourceName)
                isImportingReport = false
                lastImportedReportID = importedID
                activityMessage = "Report added to your library"
            } catch {
                isImportingReport = false
                lastError = error.localizedDescription
                activityMessage = "Could not add that report"
            }
        }
    }

    func shareReport(_ report: SavedBuilderReport) {
        guard let url = report.shareURL else {
            lastError = "Create an unlisted link before sharing this report."
            return
        }
        guard let view = NSApp.keyWindow?.contentView else {
            copy(url.absoluteString, confirmation: "Report link copied")
            return
        }
        let picker = NSSharingServicePicker(items: [
            "\(report.presentationTitle) — TokenBar Builder Report",
            url,
        ])
        let anchor = NSRect(x: view.bounds.midX, y: view.bounds.maxY - 24, width: 1, height: 1)
        picker.show(relativeTo: anchor, of: view, preferredEdge: .minY)
    }

    func copyShareCaption(_ report: SavedBuilderReport) {
        guard let caption = report.shareCaption else {
            lastError = "Create an unlisted link before copying a social post."
            return
        }
        copy(caption, confirmation: "Social post copied")
    }

    func exportProofPacket() {
        guard !isExportingProof, profile.sourceURL != nil else { return }

        let panel = NSSavePanel()
        panel.title = "Download Builder Identity report"
        panel.prompt = "Download"
        panel.allowedContentTypes = [.zip]
        panel.canCreateDirectories = true
        let safeToken = profile.reportToken.hasPrefix("TBAR-") ? profile.reportToken.lowercased() : "tokenbar-builder"
        panel.nameFieldStringValue = "\(safeToken)-report.zip"
        guard panel.runModal() == .OK, let destination = panel.url else { return }

        isExportingProof = true
        lastError = nil
        activityMessage = "Preparing your Builder Identity report…"

        Task {
            let result = await Task.detached(priority: .userInitiated) {
                Self.runTokenBar(arguments: ["proof", "--output", destination.path])
            }.value
            guard result.status == 0 else {
                isExportingProof = false
                lastError = result.output.isEmpty ? "TokenBar could not download the report." : result.output
                activityMessage = "Report download needs attention"
                return
            }

            let verification = await Task.detached(priority: .utility) {
                Self.runTokenBar(arguments: ["verify", destination.path])
            }.value
            isExportingProof = false
            guard verification.status == 0 else {
                lastError = verification.output.isEmpty ? "The report was created but failed its safety check." : verification.output
                activityMessage = "Report safety check failed"
                return
            }

            NSWorkspace.shared.activateFileViewerSelecting([destination])
            activityMessage = "Report downloaded and safety-checked"
        }
    }

    func refreshUsageCosts() {
        guard !isLoadingCosts else { return }
        isLoadingCosts = true
        lastError = nil
        activityMessage = "Reading ccusage locally…"

        Task {
            defer { isLoadingCosts = false }
            let result = await Task.detached(priority: .userInitiated) {
                Self.runCCUsage(timeZone: TimeZone.current.identifier)
            }.value
            if result.status == 0, let snapshot = result.snapshot {
                costUsage = snapshot
                if saveCostUsageSnapshot(snapshot) {
                    activityMessage = "Cost snapshot loaded and cached locally"
                } else {
                    activityMessage = "Cost snapshot loaded locally"
                    lastError = "TokenBar loaded costs but could not save its private local cache."
                }
            } else {
                lastError = result.output.isEmpty ? "TokenBar could not read ccusage." : result.output
                activityMessage = "Cost snapshot needs attention"
            }
        }
    }

    private func loadCostUsageSnapshot() -> CCUsageSnapshot {
        let url = supportDirectory.appendingPathComponent("cost-usage-snapshot.json")
        guard
            let data = try? Data(contentsOf: url),
            let cache = try? JSONDecoder().decode(LocalCostUsageCache.self, from: data),
            cache.schema == LocalCostUsageCache.schema
        else {
            return CCUsageSnapshot()
        }
        return cache.snapshot
    }

    private func saveCostUsageSnapshot(_ snapshot: CCUsageSnapshot) -> Bool {
        let url = supportDirectory.appendingPathComponent("cost-usage-snapshot.json")
        let cache = LocalCostUsageCache(
            schema: LocalCostUsageCache.schema,
            savedAt: Date(),
            snapshot: snapshot
        )
        do {
            try fileManager.createDirectory(at: supportDirectory, withIntermediateDirectories: true)
            let data = try JSONEncoder().encode(cache)
            try data.write(to: url, options: .atomic)
            return true
        } catch {
            return false
        }
    }

    func refreshThreads() {
        guard !isLoadingThreads else { return }
        isLoadingThreads = true
        lastError = nil
        activityMessage = "Reading the local Codex thread index…"

        Task {
            let result = await Task.detached(priority: .userInitiated) {
                Self.readCodexThreads()
            }.value
            isLoadingThreads = false
            if result.status == 0 {
                codexThreads = result.threads
                activityMessage = "\(result.threads.count) local Codex threads indexed"
            } else {
                lastError = result.output.isEmpty ? "TokenBar could not read the local Codex thread index." : result.output
                activityMessage = "Thread index needs attention"
            }
        }
    }

    func refreshStorage() {
        guard !isScanningStorage else { return }
        isScanningStorage = true
        lastError = nil
        activityMessage = "Mapping generated storage locally…"
        let threads = codexThreads
        let support = supportDirectory

        Task {
            let items = await Task.detached(priority: .utility) {
                let resolvedThreads = threads.isEmpty ? Self.readCodexThreads().threads : threads
                return Self.scanStorage(supportDirectory: support, threads: resolvedThreads)
            }.value
            storageItems = items
            isScanningStorage = false
            activityMessage = "\(items.count) storage areas mapped"
        }
    }

    func revealStorageItem(_ item: StorageItemSnapshot) {
        NSWorkspace.shared.selectFile(item.path, inFileViewerRootedAtPath: "")
    }

    func moveStorageItemToTrash(_ item: StorageItemSnapshot) {
        guard item.isTrashable else { return }
        do {
            var resultingURL: NSURL?
            try fileManager.trashItem(at: URL(fileURLWithPath: item.path), resultingItemURL: &resultingURL)
            storageItems.removeAll { $0.id == item.id }
            activityMessage = "\(item.name) moved to Trash"
        } catch {
            lastError = "Could not move \(item.name) to Trash: \(error.localizedDescription)"
        }
    }

    var selectedThreadBoard: ThreadBoardConfiguration {
        threadBoards.first { $0.id == selectedThreadBoardID } ?? threadBoards.first ?? .starter
    }

    func selectThreadBoard(_ id: UUID) {
        guard threadBoards.contains(where: { $0.id == id }) else { return }
        selectedThreadBoardID = id
        saveThreadBoardStore()
    }

    func saveThreadBoard(_ board: ThreadBoardConfiguration) {
        var clean = board
        clean.name = clean.name.trimmingCharacters(in: .whitespacesAndNewlines)
        clean.focusTitle = clean.focusTitle.trimmingCharacters(in: .whitespacesAndNewlines)
        clean.recentTitle = clean.recentTitle.trimmingCharacters(in: .whitespacesAndNewlines)
        clean.reviewTitle = clean.reviewTitle.trimmingCharacters(in: .whitespacesAndNewlines)
        clean.workspaceFilter = clean.workspaceFilter.trimmingCharacters(in: .whitespacesAndNewlines)
        if clean.name.isEmpty { clean.name = "Untitled board" }
        if clean.focusTitle.isEmpty { clean.focusTitle = "Now" }
        if clean.recentTitle.isEmpty { clean.recentTitle = "Fresh" }
        if clean.reviewTitle.isEmpty { clean.reviewTitle = "Revisit" }

        if let index = threadBoards.firstIndex(where: { $0.id == clean.id }) {
            threadBoards[index] = clean
        } else {
            threadBoards.append(clean)
        }
        selectedThreadBoardID = clean.id
        saveThreadBoardStore()
        activityMessage = "Thread board saved locally"
    }

    func deleteThreadBoard(_ id: UUID) {
        guard threadBoards.count > 1 else { return }
        threadBoards.removeAll { $0.id == id }
        if selectedThreadBoardID == id {
            selectedThreadBoardID = threadBoards[0].id
        }
        saveThreadBoardStore()
        activityMessage = "Thread board removed"
    }

    func revokeCurrentProof() {
        guard receipt.hasShareSurface, receipt.token.hasPrefix("TBAR-"), !isRevoking else { return }
        let token = receipt.token
        isRevoking = true
        lastError = nil
        activityMessage = "Removing public proof…"

        Task {
            let result = await Task.detached(priority: .userInitiated) {
                Self.runTokenBar(arguments: ["revoke", token])
            }.value
            isRevoking = false
            if result.status == 0 {
                reload()
                activityMessage = receipt.hasShareSurface
                    ? "Proof removed · showing your previous active proof"
                    : "Public proof removed · private report kept"
            } else {
                lastError = result.output.isEmpty ? "TokenBar could not remove the public proof." : result.output
                activityMessage = "Proof removal needs attention"
            }
        }
    }

    func open(_ url: URL?) {
        guard let url else { return }
        NSWorkspace.shared.open(url)
    }

    func openCodex() {
        for bundleID in ["com.openai.codex", "com.openai.chatgpt"] {
            if let appURL = NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleID) {
                NSWorkspace.shared.openApplication(at: appURL, configuration: .init())
                return
            }
        }
        lastError = "Codex is not installed on this Mac. The handoff is still on your clipboard."
    }

    func copy(_ value: String, confirmation: String) {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(value, forType: .string)
        activityMessage = confirmation
    }

    func copyCodexMCPSetup() {
        let bundled = Bundle.main.resourceURL?.appendingPathComponent("tokenbar/tokenbar").path
        let executable = bundled.flatMap { fileManager.isExecutableFile(atPath: $0) ? $0 : nil } ?? "tokenbar"
        let quoted = "'" + executable.replacingOccurrences(of: "'", with: "'\"'\"'") + "'"
        copy(
            "codex mcp add tokenbar -- \(quoted) mcp",
            confirmation: "Codex MCP setup copied · paste it in Terminal"
        )
    }

    func copyClaimCommand() {
        copy(
            "tokenbar report",
            confirmation: "Report command copied · paste it in Terminal"
        )
    }

    func copyUsageCommand() {
        copy(
            "tokenbar usage",
            confirmation: "Usage command copied · paste it in Terminal"
        )
    }

    func copyPlaybookCatalogJSON() {
        activityMessage = "Reading local playbook catalog…"
        Task {
            let result = await Task.detached(priority: .utility) {
                Self.runTokenBar(arguments: ["playbooks", "json"], timeout: 15)
            }.value
            if result.status == 0, !result.output.isEmpty {
                copy(result.output, confirmation: "Playbook JSON copied")
            } else {
                copy(
                    "tokenbar playbooks json",
                    confirmation: "Playbook JSON command copied · run it in Terminal"
                )
                lastError = result.output.isEmpty ? "TokenBar could not read the playbook catalog." : result.output
            }
        }
    }

    func threadDraft(for threadID: String) -> String {
        threadDrafts[threadID] ?? ""
    }

    func saveThreadDraft(_ draft: String, for threadID: String) {
        let clean = draft.trimmingCharacters(in: .whitespacesAndNewlines)
        if clean.isEmpty {
            threadDrafts.removeValue(forKey: threadID)
        } else {
            threadDrafts[threadID] = clean
        }
        do {
            try fileManager.createDirectory(at: supportDirectory, withIntermediateDirectories: true)
            let data = try JSONEncoder().encode(threadDrafts)
            try data.write(to: supportDirectory.appendingPathComponent("thread-follow-up-drafts.json"), options: .atomic)
            activityMessage = clean.isEmpty ? "Follow-up draft cleared" : "Follow-up draft saved locally"
        } catch {
            lastError = "Could not save the local follow-up draft: \(error.localizedDescription)"
        }
    }

    private func loadThreadDrafts() -> [String: String] {
        let url = supportDirectory.appendingPathComponent("thread-follow-up-drafts.json")
        guard let data = try? Data(contentsOf: url),
              let drafts = try? JSONDecoder().decode([String: String].self, from: data) else { return [:] }
        return drafts
    }

    private func loadThreadBoardStore() -> ThreadBoardStore {
        let url = supportDirectory.appendingPathComponent("thread-boards.json")
        guard let data = try? Data(contentsOf: url),
              let store = try? JSONDecoder().decode(ThreadBoardStore.self, from: data),
              !store.boards.isEmpty else {
            return ThreadBoardStore(selectedBoardID: ThreadBoardConfiguration.starterID, boards: [.starter])
        }
        let selected = store.boards.contains(where: { $0.id == store.selectedBoardID })
            ? store.selectedBoardID
            : store.boards[0].id
        return ThreadBoardStore(selectedBoardID: selected, boards: store.boards)
    }

    private func saveThreadBoardStore() {
        do {
            try fileManager.createDirectory(at: supportDirectory, withIntermediateDirectories: true)
            let store = ThreadBoardStore(selectedBoardID: selectedThreadBoardID, boards: threadBoards)
            let encoder = JSONEncoder()
            encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
            let data = try encoder.encode(store)
            try data.write(to: supportDirectory.appendingPathComponent("thread-boards.json"), options: .atomic)
        } catch {
            lastError = "Could not save thread boards: \(error.localizedDescription)"
        }
    }

    func importBrief(from url: URL) {
        let gainedAccess = url.startAccessingSecurityScopedResource()
        defer {
            if gainedAccess { url.stopAccessingSecurityScopedResource() }
        }

        do {
            let raw = try String(contentsOf: url, encoding: .utf8)
            let invitation = Self.parseInvitation(raw: raw, sourceURL: url)
            invitations.removeAll { $0.sourcePath == invitation.sourcePath }
            invitations.insert(invitation, at: 0)
            try saveInvitations()
            activityMessage = "Project brief added locally"
            lastError = nil
        } catch {
            lastError = "Could not import that brief: \(error.localizedDescription)"
        }
    }

    func previewSampleInvitation() {
        let samplePath = "tokenbar://sample/proof-first-launch"
        guard !invitations.contains(where: { $0.sourcePath == samplePath }) else { return }
        invitations.insert(
            ProjectInvitation(
                id: UUID(),
                title: "Proof-first launch room",
                proposer: "Sample from the TokenBar community",
                summary: "Ship one inspectable onboarding improvement for a local-first AI app. Keep private evidence on-device, publish only a safe outcome card, and close with a reproducible verification receipt.",
                sourcePath: samplePath,
                importedAt: Date(),
                status: "sample"
            ),
            at: 0
        )
        activityMessage = "Sample opportunity previewed · not saved"
    }

    func remove(_ invitation: ProjectInvitation) {
        invitations.removeAll { $0.id == invitation.id }
        if !invitation.sourcePath.hasPrefix("tokenbar://sample/") {
            try? saveInvitations()
            activityMessage = "Project brief removed from the local queue"
        } else {
            activityMessage = "Sample preview closed"
        }
    }

    func accept(_ invitation: ProjectInvitation) {
        guard let index = invitations.firstIndex(where: { $0.id == invitation.id }) else { return }
        invitations[index].status = "in progress"
        try? saveInvitations()
        copy(kickoffPrompt(for: invitations[index]), confirmation: "Codex kickoff copied")

        openCodex()
    }

    func kickoffPrompt(for invitation: ProjectInvitation) -> String {
        """
        Work on this proposed project as a bounded Codex task.

        PROJECT
        \(invitation.title)

        PROPOSED BY
        \(invitation.proposer)

        BRIEF
        \(invitation.summary)

        BUILDER CONTEXT
        My TokenBar identity is \(profile.displayTitle). My current growth edge is: \(profile.growthEdge)

        FIRST LOOP
        1. Inspect the project and state the smallest useful outcome.
        2. Implement one bounded improvement.
        3. Verify it with concrete evidence.
        4. Report what shipped, what remains uncertain, and the next frontier.

        The original local brief is at: \(invitation.sourcePath)
        """
    }

    func opportunityFit(for invitation: ProjectInvitation) -> (label: String, score: Int, note: String) {
        let strongest = profile.dimensions.max { $0.score < $1.score }
        let base = strongest?.score ?? max(profile.proofScore, profile.loopScore)
        let boundedBonus = invitation.summary.lowercased().contains("prototype") || invitation.summary.lowercased().contains("ship") ? 6 : 2
        let score = min(96, max(34, base + boundedBonus))
        let signal = strongest?.name.isEmpty == false ? strongest!.name : profile.archetype
        let note = "Your \(signal.lowercased()) signal can carry the first loop. TokenBar will use the brief, your current growth edge, and a verify-before-share finish."
        return (signal, score, note)
    }

    private func loadLatestProfile() -> BuilderProfile {
        let directory = supportDirectory.appendingPathComponent("profiles", isDirectory: true)
        guard let url = latestFile(in: directory, suffix: ".identity.json"),
              let object = jsonObject(at: url) else {
            return BuilderProfile()
        }

        let identityLabel = dictionary(object["identityLabel"])
        let usage = dictionary(object["usage"])
        let title = string(identityLabel["title"])
        let dimensions = array(object["dimensions"]).compactMap { item -> BuilderDimension? in
            let value = dictionary(item)
            let name = string(value["name"])
            guard !name.isEmpty else { return nil }
            return BuilderDimension(name: name, score: integer(value["score"]), note: string(value["note"]))
        }
        let facts = array(object["curiousFacts"]).compactMap { item -> BuilderFact? in
            let value = dictionary(item)
            let label = string(value["label"])
            guard !label.isEmpty else { return nil }
            return BuilderFact(label: label, value: string(value["value"]), copy: string(value["copy"]))
        }
        let reportURL = URL(fileURLWithPath: url.path.replacingOccurrences(of: ".identity.json", with: ".html"))

        return BuilderProfile(
            reportToken: string(object["token"]),
            identityTitle: title.isEmpty ? string(object["title"]) : title,
            archetype: string(object["primaryArchetype"], fallback: "Builder"),
            stance: string(identityLabel["stance"], fallback: "Local-first"),
            subtitle: string(object["subtitle"], fallback: "A local view of how you build with agents."),
            proofScore: integer(object["proofScore"]),
            loopScore: integer(object["loopScore"]),
            specificityScore: integer(object["specificityScore"]),
            rarity: double(object["estimatedRarityPercent"]),
            generatedAt: string(object["generatedAt"], fallback: "Recently"),
            dimensions: dimensions,
            signatureMoves: array(object["signatureMoves"]).compactMap { $0 as? String },
            facts: facts,
            growthEdge: string(object["growthEdge"], fallback: "Turn the next session into inspectable proof."),
            usage: UsageSnapshot(
                today: string(usage["today"], fallback: "--"),
                last7: string(usage["last7"], fallback: "--"),
                last30: string(usage["last30"], fallback: "--"),
                projectedNext7: string(usage["projectedNext7"], fallback: "--"),
                sessions: integer(usage["sessionsIndexed"]),
                activeDays: integer(usage["activeDaysLast30"]),
                model: string(usage["topLocalModel"], fallback: "Local"),
                days: []
            ),
            evidenceSessions: integer(usage["sessionsIndexed"]),
            evidenceActiveDays: integer(usage["activeDaysLast30"]),
            reportURL: fileManager.fileExists(atPath: reportURL.path) ? reportURL : nil,
            sourceURL: url
        )
    }

    private func loadReportHistory() -> [SavedBuilderReport] {
        let directory = supportDirectory.appendingPathComponent("profiles", isDirectory: true)
        guard let files = try? fileManager.contentsOfDirectory(
            at: directory,
            includingPropertiesForKeys: [.contentModificationDateKey],
            options: [.skipsHiddenFiles]
        ) else {
            return []
        }

        let shares = loadActiveReportShares()
        return files
            .filter { $0.lastPathComponent.hasSuffix(".identity.json") }
            .sorted { modificationDate($0) > modificationDate($1) }
            .prefix(100)
            .compactMap { url in
                guard let object = jsonObject(at: url) else { return nil }
                let identityLabel = dictionary(object["identityLabel"])
                let labelRationale = dictionary(object["labelRationale"])
                let usage = dictionary(object["usage"])
                let token = string(object["token"], fallback: url.deletingPathExtension().lastPathComponent)
                let title = string(identityLabel["title"], fallback: string(object["title"], fallback: "Builder Identity"))
                let subtitle = string(object["subtitle"], fallback: "A private snapshot of how you built.")
                let facts = array(object["curiousFacts"]).compactMap { item -> BuilderFact? in
                    let value = dictionary(item)
                    let label = string(value["label"])
                    guard !label.isEmpty else { return nil }
                    return BuilderFact(
                        label: label,
                        value: string(value["value"]),
                        copy: string(value["copy"])
                    )
                }
                let dimensions = array(object["dimensions"]).compactMap { item -> BuilderDimension? in
                    let value = dictionary(item)
                    let name = string(value["name"])
                    guard !name.isEmpty else { return nil }
                    return BuilderDimension(
                        name: name,
                        score: integer(value["score"]),
                        note: string(value["note"])
                    )
                }
                let rationaleComponents = array(labelRationale["components"]).compactMap { item -> ReportTitleComponent? in
                    let value = dictionary(item)
                    let name = string(value["name"])
                    guard !name.isEmpty else { return nil }
                    return ReportTitleComponent(
                        name: name,
                        kind: string(value["type"], fallback: "signal"),
                        reason: string(value["reason"]),
                        probability: value["probability"] as? Double
                            ?? (value["probability"] as? Int).map(Double.init)
                    )
                }
                let rationaleDrivers = array(labelRationale["topTraitDrivers"]).compactMap { item -> ReportTraitDriver? in
                    let value = dictionary(item)
                    let name = string(value["trait"])
                    guard !name.isEmpty else { return nil }
                    return ReportTraitDriver(name: name, score: integer(value["score"]))
                }
                let generatedText = string(object["generatedAt"])
                let generatedAt = Self.parseReportDate(generatedText) ?? modificationDate(url)
                let stem = url.lastPathComponent.replacingOccurrences(of: ".identity.json", with: "")
                let htmlURL = directory.appendingPathComponent("\(stem).html")
                let pdfURL = directory.appendingPathComponent("\(stem).pdf")
                let shared = shares[token]
                let recordedWindowDays = integer(object["windowDays"])
                return SavedBuilderReport(
                    token: token,
                    title: title,
                    archetype: string(object["primaryArchetype"], fallback: "Builder"),
                    modifier: string(identityLabel["modifier"]),
                    stance: string(identityLabel["stance"], fallback: "Local-first"),
                    subtitle: subtitle,
                    generatedAt: generatedAt,
                    windowDays: recordedWindowDays > 0 ? recordedWindowDays : 7,
                    evidenceScore: integer(object["proofScore"]),
                    sessions: integer(usage["sessionsIndexed"]),
                    activeDays: integer(usage["activeDaysLast30"]),
                    dimensions: dimensions,
                    facts: facts,
                    signatureMoves: array(object["signatureMoves"]).compactMap { $0 as? String },
                    titleRationale: ReportTitleRationale(
                        components: rationaleComponents,
                        drivers: rationaleDrivers
                    ),
                    identityURL: url,
                    reportURL: fileManager.fileExists(atPath: htmlURL.path) ? htmlURL : nil,
                    pdfURL: fileManager.fileExists(atPath: pdfURL.path) ? pdfURL : nil,
                    shareURL: shared?.url,
                    shareMode: shared?.mode
                )
            }
    }

    private func loadActiveReportShares() -> [String: (url: URL, mode: String)] {
        let directory = supportDirectory.appendingPathComponent("proof-receipts", isDirectory: true)
        guard let files = try? fileManager.contentsOfDirectory(at: directory, includingPropertiesForKeys: nil) else {
            return [:]
        }

        var shares: [String: (url: URL, mode: String)] = [:]
        for url in files where url.pathExtension == "json" {
            guard let object = jsonObject(at: url), bool(object["revoked"]) == false else { continue }
            let token = string(object["token"])
            let surfaces = dictionary(object["surfaces"])
            guard !token.isEmpty,
                  let shareURL = webURL(surfaces["publicProfile"]) ?? webURL(surfaces["proofCard"]) else {
                continue
            }
            shares[token] = (shareURL, string(object["shareMode"], fallback: "unlisted"))
        }
        return shares
    }

    private func ingestReportData(_ data: Data, sourceName: String) throws -> String {
        let raw = try JSONSerialization.jsonObject(with: data)
        guard let rawObject = raw as? [String: Any] else {
            throw ReportImportError.invalidReport
        }
        let profile = (rawObject["profile"] as? [String: Any]) ?? rawObject
        guard let token = profile["token"] as? String,
              token.hasPrefix("TBAR-"),
              token.count >= 10 else {
            throw ReportImportError.invalidReport
        }

        let allowedKeys = [
            "token", "title", "subtitle", "primaryArchetype", "npcClass",
            "generatedAt", "windowDays", "proofScore", "loopScore",
            "specificityScore", "estimatedRarityPercent", "identityLabel",
            "labelRationale", "usage", "dimensions", "signatureMoves",
            "curiousFacts", "growthEdge", "privacy", "reportKind",
        ]
        var safeProfile: [String: Any] = [:]
        for key in allowedKeys where profile[key] != nil {
            safeProfile[key] = profile[key]
        }
        safeProfile["importedFrom"] = sourceName
        safeProfile["importedAt"] = ISO8601DateFormatter().string(from: Date())
        guard JSONSerialization.isValidJSONObject(safeProfile) else {
            throw ReportImportError.invalidReport
        }

        let directory = supportDirectory.appendingPathComponent("profiles", isDirectory: true)
        try fileManager.createDirectory(at: directory, withIntermediateDirectories: true)
        let filename = "tokenbar-imported-\(token.lowercased()).identity.json"
        let destination = directory.appendingPathComponent(filename)
        let encoded = try JSONSerialization.data(
            withJSONObject: safeProfile,
            options: [.prettyPrinted, .sortedKeys]
        )
        try encoded.write(to: destination, options: .atomic)
        reload()
        guard let report = savedReports.first(where: { $0.token == token }) else {
            throw ReportImportError.invalidReport
        }
        return report.id
    }

    private static func localReportURL(from reference: String) -> URL? {
        let expanded = NSString(string: reference).expandingTildeInPath
        let url: URL
        if let parsed = URL(string: reference), parsed.isFileURL {
            url = parsed
        } else {
            url = URL(fileURLWithPath: expanded)
        }
        guard FileManager.default.fileExists(atPath: url.path),
              url.lastPathComponent.hasSuffix(".identity.json") else {
            return nil
        }
        return url
    }

    private static func publicReportAPIURL(from reference: String) -> URL? {
        let token = reportToken(in: reference)
        guard let token else { return nil }

        if let provided = URL(string: reference),
           let scheme = provided.scheme?.lowercased(),
           ["http", "https"].contains(scheme),
           provided.host != nil {
            if provided.path.hasSuffix("/api/profiles") {
                var components = URLComponents(url: provided, resolvingAgainstBaseURL: false)
                components?.queryItems = [URLQueryItem(name: "token", value: token)]
                return components?.url
            }
            var components = URLComponents()
            components.scheme = scheme
            components.host = provided.host
            components.port = provided.port
            components.path = "/api/profiles"
            components.queryItems = [URLQueryItem(name: "token", value: token)]
            return components.url
        }

        var components = URLComponents(string: "https://tokenbar-umber.vercel.app/api/profiles")
        components?.queryItems = [URLQueryItem(name: "token", value: token)]
        return components?.url
    }

    private static func reportToken(in value: String) -> String? {
        guard let expression = try? NSRegularExpression(pattern: #"TBAR-[A-Za-z0-9]+"#) else {
            return nil
        }
        let range = NSRange(value.startIndex..<value.endIndex, in: value)
        guard let match = expression.firstMatch(in: value, range: range),
              let tokenRange = Range(match.range, in: value) else {
            return nil
        }
        return String(value[tokenRange]).uppercased()
    }

    private enum ReportImportError: LocalizedError {
        case unsupportedReference
        case invalidReport
        case notFound
        case tooLarge

        var errorDescription: String? {
            switch self {
            case .unsupportedReference:
                "Paste a TBAR token, TokenBar report link, or local .identity.json path."
            case .invalidReport:
                "That file or link is not a valid TokenBar report."
            case .notFound:
                "TokenBar could not find that shared report."
            case .tooLarge:
                "That report is larger than TokenBar's 2 MB safe import limit."
            }
        }
    }

    private static func parseReportDate(_ value: String) -> Date? {
        guard !value.isEmpty else { return nil }
        let internetFormatter = ISO8601DateFormatter()
        if let parsed = internetFormatter.date(from: value) { return parsed }

        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ssZ"
        return formatter.date(from: value)
    }

    private func profileFromSafeBundle(_ bundle: SafeIdentityBundle, preserving local: BuilderProfile) -> BuilderProfile {
        guard let identity = bundle.identity else { return local }
        let days = bundle.stats.dayTokens.sorted { $0.key < $1.key }
        let last7 = days.suffix(7).reduce(Int64(0)) { $0 + $1.value }
        let last30 = days.suffix(30).reduce(Int64(0)) { $0 + $1.value }
        let today = days.last?.value ?? 0
        let topModel = bundle.stats.modelTokens.max { $0.value < $1.value }?.key
        let dimensions = (identity.dimensions ?? []).map {
            BuilderDimension(name: $0.name, score: $0.score, note: $0.note ?? "Safe aggregate evidence from the current Builder Identity bundle.")
        }
        let facts = (identity.curiousFacts ?? []).map {
            BuilderFact(label: $0.label, value: $0.value, copy: $0.copy ?? "Generated from privacy-safe local aggregates.")
        }

        return BuilderProfile(
            reportToken: local.reportToken,
            identityTitle: identity.identityLabel?.title ?? identity.title ?? local.identityTitle,
            archetype: identity.primaryArchetype ?? local.archetype,
            stance: identity.identityLabel?.stance ?? local.stance,
            subtitle: identity.subtitle ?? local.subtitle,
            proofScore: identity.proofScore ?? local.proofScore,
            loopScore: identity.loopScore ?? identity.loopMaturity ?? local.loopScore,
            specificityScore: identity.specificityScore ?? local.specificityScore,
            rarity: identity.estimatedRarityPercent ?? local.rarity,
            generatedAt: identity.generatedAt ?? local.generatedAt,
            dimensions: dimensions.isEmpty ? local.dimensions : dimensions,
            signatureMoves: identity.signatureMoves ?? local.signatureMoves,
            facts: facts.isEmpty ? local.facts : facts,
            growthEdge: identity.growthEdge ?? local.growthEdge,
            usage: UsageSnapshot(
                today: today > 0 ? Self.compactCount(today) : local.usage.today,
                last7: last7 > 0 ? Self.compactCount(last7) : local.usage.last7,
                last30: last30 > 0 ? Self.compactCount(last30) : local.usage.last30,
                projectedNext7: local.usage.projectedNext7,
                sessions: bundle.stats.sessionCount,
                activeDays: bundle.stats.activeDayCount,
                model: topModel ?? local.usage.model,
                days: days.map { UsageDaySnapshot(date: $0.key, tokens: $0.value) }
            ),
            evidenceSessions: identity.usage?.sessionsIndexed ?? local.evidenceSessions,
            evidenceActiveDays: identity.usage?.activeDaysLast30 ?? local.evidenceActiveDays,
            reportURL: local.reportURL,
            sourceURL: local.sourceURL
        )
    }

    private func loadLatestReceipt() -> ProofReceipt {
        let directory = supportDirectory.appendingPathComponent("proof-receipts", isDirectory: true)
        guard let files = try? fileManager.contentsOfDirectory(at: directory, includingPropertiesForKeys: [.contentModificationDateKey]) else {
            return ProofReceipt()
        }
        let candidates = files.filter { $0.lastPathComponent.hasPrefix("TBAR-") && $0.pathExtension == "json" }
            .sorted { modificationDate($0) > modificationDate($1) }

        for url in candidates {
            guard let object = jsonObject(at: url), bool(object["revoked"]) == false else { continue }
            let surfaces = dictionary(object["surfaces"])
            let shareReceipt = dictionary(object["shareReceipt"])
            let privacy = dictionary(object["privacy"])
            let completedStages = strings(shareReceipt["completedStages"])
            let hasPrivacyAssertions = privacy.keys.contains("rawTranscriptsUploaded")
                && privacy.keys.contains("sourceCodeUploaded")
            let receipt = ProofReceipt(
                token: string(object["token"], fallback: url.deletingPathExtension().lastPathComponent),
                runID: string(object["runId"]),
                shareMode: string(object["shareMode"], fallback: "unlisted"),
                generatedAt: string(object["generatedAt"]),
                completedStages: completedStages,
                publicMaterial: string(shareReceipt["publicMaterial"]),
                uploadedMaterial: string(privacy["uploaded"]),
                neverPublic: strings(shareReceipt["neverPublic"]),
                redactedFields: strings(shareReceipt["redactedFields"]),
                ownerBound: bool(object["ownerBound"]),
                privacyVerified: hasPrivacyAssertions
                    && bool(privacy["rawTranscriptsUploaded"]) == false
                    && bool(privacy["sourceCodeUploaded"]) == false,
                publicProfileURL: webURL(surfaces["publicProfile"]),
                proofCardURL: webURL(surfaces["proofCard"]),
                socialURL: webURL(surfaces["socialFeed"]),
                rankingsURL: webURL(surfaces["rankings"])
            )
            if receipt.hasShareSurface { return receipt }
        }
        return ProofReceipt()
    }

    private func loadInvitations() -> [ProjectInvitation] {
        let url = supportDirectory.appendingPathComponent("project-invitations.json")
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        guard let data = try? Data(contentsOf: url),
              let decoded = try? decoder.decode([ProjectInvitation].self, from: data) else { return [] }
        return decoded.sorted { $0.importedAt > $1.importedAt }
    }

    private func saveInvitations() throws {
        try fileManager.createDirectory(at: supportDirectory, withIntermediateDirectories: true)
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601
        let data = try encoder.encode(invitations)
        try data.write(to: supportDirectory.appendingPathComponent("project-invitations.json"), options: .atomic)
    }

    private func latestFile(in directory: URL, suffix: String) -> URL? {
        guard let files = try? fileManager.contentsOfDirectory(at: directory, includingPropertiesForKeys: [.contentModificationDateKey]) else { return nil }
        return files.filter { $0.lastPathComponent.hasSuffix(suffix) }
            .max { modificationDate($0) < modificationDate($1) }
    }

    private func modificationDate(_ url: URL) -> Date {
        (try? url.resourceValues(forKeys: [.contentModificationDateKey]).contentModificationDate) ?? .distantPast
    }

    private func jsonObject(at url: URL) -> [String: Any]? {
        guard let data = try? Data(contentsOf: url),
              let object = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else { return nil }
        return object
    }

    private func dictionary(_ value: Any?) -> [String: Any] { value as? [String: Any] ?? [:] }
    private func array(_ value: Any?) -> [Any] { value as? [Any] ?? [] }
    private func strings(_ value: Any?) -> [String] {
        array(value).compactMap { item in
            guard let string = item as? String, !string.isEmpty else { return nil }
            return string
        }
    }
    private func string(_ value: Any?, fallback: String = "") -> String {
        if let string = value as? String, !string.isEmpty { return string }
        return fallback
    }
    private func integer(_ value: Any?) -> Int {
        if let value = value as? Int { return value }
        if let value = value as? Double { return Int(value.rounded()) }
        if let value = value as? NSNumber { return value.intValue }
        return 0
    }
    private func double(_ value: Any?) -> Double {
        if let value = value as? Double { return value }
        if let value = value as? NSNumber { return value.doubleValue }
        return 0
    }
    private func bool(_ value: Any?) -> Bool { (value as? Bool) ?? false }
    private func webURL(_ value: Any?) -> URL? {
        guard let text = value as? String else { return nil }
        return URL(string: text)
    }

    nonisolated private static func runTokenBar(
        arguments: [String],
        timeout: TimeInterval = 90
    ) -> (status: Int32, output: String) {
        var candidates = [String]()
        if let override = ProcessInfo.processInfo.environment["TOKENBAR_CLI_PATH"], !override.isEmpty {
            candidates.append(override)
        }
        if let bundled = Bundle.main.resourceURL?.appendingPathComponent("tokenbar/tokenbar").path {
            candidates.append(bundled)
        }
        candidates.append(contentsOf: [
            FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent(".local/bin/tokenbar").path,
            "/usr/local/bin/tokenbar",
            "/opt/homebrew/bin/tokenbar"
        ])
        guard let executable = candidates.first(where: { FileManager.default.isExecutableFile(atPath: $0) }) else {
            return (127, "Install the TokenBar CLI before refreshing the native profile.")
        }
        let process = Process()
        let pipe = Pipe()
        let output = ProcessOutputBuffer()
        process.executableURL = URL(fileURLWithPath: executable)
        process.arguments = arguments
        process.currentDirectoryURL = FileManager.default.homeDirectoryForCurrentUser
        process.standardOutput = pipe
        process.standardError = pipe
        do {
            try process.run()
            let reader = DispatchGroup()
            reader.enter()
            DispatchQueue.global(qos: .utility).async {
                output.store(pipe.fileHandleForReading.readDataToEndOfFile())
                reader.leave()
            }

            let deadline = Date().addingTimeInterval(timeout)
            while process.isRunning, Date() < deadline {
                Thread.sleep(forTimeInterval: 0.05)
            }

            if process.isRunning {
                terminateProcessTree(rootPID: process.processIdentifier)
                process.terminate()
                let graceDeadline = Date().addingTimeInterval(1.5)
                while process.isRunning, Date() < graceDeadline {
                    Thread.sleep(forTimeInterval: 0.05)
                }
                if process.isRunning {
                    Darwin.kill(process.processIdentifier, SIGKILL)
                }
                _ = reader.wait(timeout: .now() + 2)
                return (
                    124,
                    "Local analysis took longer than \(Int(timeout)) seconds. TokenBar stopped it without changing your Codex data. Try a shorter window."
                )
            }

            process.waitUntilExit()
            _ = reader.wait(timeout: .now() + 2)
            return (
                process.terminationStatus,
                output.string.trimmingCharacters(in: .whitespacesAndNewlines)
            )
        } catch {
            return (1, error.localizedDescription)
        }
    }

    nonisolated private static func terminateProcessTree(rootPID: pid_t) {
        let listing = Process()
        let pipe = Pipe()
        listing.executableURL = URL(fileURLWithPath: "/bin/ps")
        listing.arguments = ["-axo", "pid=,ppid="]
        listing.standardOutput = pipe
        listing.standardError = FileHandle.nullDevice
        guard (try? listing.run()) != nil else { return }
        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        listing.waitUntilExit()

        var childrenByParent = [pid_t: [pid_t]]()
        let rows = String(data: data, encoding: .utf8) ?? ""
        for row in rows.split(separator: "\n") {
            let fields = row.split(whereSeparator: \.isWhitespace)
            guard fields.count == 2,
                  let pid = pid_t(String(fields[0])),
                  let parent = pid_t(String(fields[1]))
            else { continue }
            childrenByParent[parent, default: []].append(pid)
        }

        func descendants(of pid: pid_t) -> [pid_t] {
            let children = childrenByParent[pid] ?? []
            return children.flatMap { descendants(of: $0) + [$0] }
        }

        for pid in descendants(of: rootPID) {
            Darwin.kill(pid, SIGTERM)
        }
    }

    nonisolated private static func loadSafeIdentityBridge() async -> SafeBridgeResult {
        let endpoint = ProcessInfo.processInfo.environment["TOKENBAR_IDENTITY_API_URL"]
            ?? "http://127.0.0.1:8769/v1/bundle"
        if let url = URL(string: endpoint) {
            var request = URLRequest(url: url)
            request.timeoutInterval = 1.25
            request.cachePolicy = .reloadIgnoringLocalCacheData
            do {
                let (data, response) = try await URLSession.shared.data(for: request)
                if let http = response as? HTTPURLResponse, http.statusCode == 200,
                   let bundle = decodeSafeBundle(data), bundleIsSafe(bundle) {
                    return SafeBridgeResult(bundle: bundle, source: .liveAPI, error: nil)
                }
            } catch {
                // The packaged snapshot below is the normal offline fallback.
            }
        }

        let snapshot = runTokenBar(arguments: ["api", "--snapshot"])
        if snapshot.status == 0,
           let data = snapshot.output.data(using: .utf8),
           let bundle = decodeSafeBundle(data), bundleIsSafe(bundle) {
            return SafeBridgeResult(bundle: bundle, source: .safeSnapshot, error: nil)
        }
        let error = snapshot.output.isEmpty
            ? "TokenBar could not load a safe identity bundle. Run tokenbar claim, then reload."
            : snapshot.output
        return SafeBridgeResult(bundle: nil, source: .unavailable, error: error)
    }

    nonisolated private static func decodeSafeBundle(_ data: Data) -> SafeIdentityBundle? {
        try? JSONDecoder().decode(SafeIdentityBundle.self, from: data)
    }

    nonisolated private static func bundleIsSafe(_ bundle: SafeIdentityBundle) -> Bool {
        bundle.ok
            && bundle.schema == "tokenbar.builder_bundle.v1"
            && bundle.identity != nil
            && !bundle.privacy.rawTranscriptsIncluded
            && !bundle.privacy.sourceCodeIncluded
            && !bundle.privacy.localPathsIncluded
            && !bundle.privacy.secretsIncluded
    }

    nonisolated private static func compactCount(_ value: Int64) -> String {
        let number = Double(value)
        if number >= 1_000_000_000 { return String(format: "%.2fB", number / 1_000_000_000).replacingOccurrences(of: ".00B", with: "B") }
        if number >= 1_000_000 { return String(format: "%.1fM", number / 1_000_000).replacingOccurrences(of: ".0M", with: "M") }
        if number >= 1_000 { return String(format: "%.1fK", number / 1_000).replacingOccurrences(of: ".0K", with: "K") }
        return String(value)
    }

    nonisolated private static func runCCUsage(timeZone: String) -> (status: Int32, snapshot: CCUsageSnapshot?, output: String) {
        let candidates = ["/opt/homebrew/bin/npx", "/usr/local/bin/npx"]
        guard let executable = candidates.first(where: { FileManager.default.isExecutableFile(atPath: $0) }) else {
            return (127, nil, "Install Node.js and run ccusage once before loading costs.")
        }

        let process = Process()
        let outputPipe = Pipe()
        let errorPipe = Pipe()
        process.executableURL = URL(fileURLWithPath: executable)
        process.arguments = [
            "--offline", "ccusage", "daily", "--json", "--by-agent", "--offline",
            "--timezone", timeZone
        ]
        process.standardOutput = outputPipe
        process.standardError = errorPipe
        process.environment = ProcessInfo.processInfo.environment.merging(["NO_COLOR": "1"]) { _, latest in latest }

        do {
            try process.run()
            let data = outputPipe.fileHandleForReading.readDataToEndOfFile()
            let errorData = errorPipe.fileHandleForReading.readDataToEndOfFile()
            process.waitUntilExit()
            let errorText = String(data: errorData, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            guard process.terminationStatus == 0 else {
                return (process.terminationStatus, nil, errorText)
            }

            let report = try JSONDecoder().decode(CCUsageReport.self, from: data)
            guard let latest = report.daily.last else {
                return (1, nil, "ccusage did not find any local usage days.")
            }
            let codexCost = latest.agents?.first(where: { $0.agent.lowercased() == "codex" })?.totalCost ?? 0
            let snapshot = CCUsageSnapshot(
                period: latest.period,
                latestCost: currency(latest.totalCost),
                codexCost: currency(codexCost),
                latestTokens: count(latest.totalTokens),
                observedCost: currency(report.totals.totalCost),
                recentDays: report.daily.suffix(7).map { day in
                    CCUsageDaySnapshot(
                        period: day.period,
                        totalCost: currency(day.totalCost),
                        codexCost: currency(day.agents?.first(where: { $0.agent.lowercased() == "codex" })?.totalCost ?? 0)
                    )
                }
            )
            return (0, snapshot, "")
        } catch {
            return (1, nil, "Could not decode ccusage: \(error.localizedDescription)")
        }
    }

    nonisolated private static func readCodexThreads() -> (status: Int32, threads: [CodexThread], output: String) {
        let home = FileManager.default.homeDirectoryForCurrentUser
        let candidates = [
            home.appendingPathComponent(".codex/state_5.sqlite").path,
            home.appendingPathComponent(".codex/sqlite/state_5.sqlite").path
        ]
        guard let database = candidates.first(where: { FileManager.default.fileExists(atPath: $0) }) else {
            return (2, [], "No local Codex thread index was found.")
        }
        guard FileManager.default.isExecutableFile(atPath: "/usr/bin/sqlite3") else {
            return (127, [], "macOS sqlite3 is unavailable.")
        }

        let query = """
        SELECT t.id,
               substr(replace(replace(t.title, char(10), ' '), char(13), ' '), 1, 180) AS title,
               t.cwd,
               t.tokens_used,
               t.recency_at_ms,
               t.source,
               t.git_branch,
               t.git_sha,
               t.model,
               t.thread_source,
               (SELECT e.parent_thread_id
                  FROM thread_spawn_edges e
                 WHERE e.child_thread_id = t.id
                 LIMIT 1) AS parent_thread_id,
               (SELECT COUNT(*)
                  FROM thread_spawn_edges e
                 WHERE e.parent_thread_id = t.id) AS child_thread_count,
               COALESCE(g.status, '') AS goal_status
        FROM threads t
        LEFT JOIN thread_goals g ON g.thread_id = t.id
        WHERE t.archived = 0 AND t.preview <> ''
        ORDER BY t.recency_at_ms DESC
        LIMIT 48;
        """

        let process = Process()
        let outputPipe = Pipe()
        let errorPipe = Pipe()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/sqlite3")
        process.arguments = ["-readonly", "-json", database, query]
        process.standardOutput = outputPipe
        process.standardError = errorPipe

        do {
            try process.run()
            let data = outputPipe.fileHandleForReading.readDataToEndOfFile()
            let errorData = errorPipe.fileHandleForReading.readDataToEndOfFile()
            process.waitUntilExit()
            let errorText = String(data: errorData, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            guard process.terminationStatus == 0 else { return (process.terminationStatus, [], errorText) }
            var threads = try JSONDecoder().decode([CodexThread].self, from: data)
            let workspaces = Set(threads.map(\.cwd).filter { !$0.isEmpty })
            let reviewStates = Dictionary(uniqueKeysWithValues: workspaces.map { ($0, readGitReviewState(at: $0)) })
            threads = threads.map { thread in
                var enriched = thread
                if let review = reviewStates[thread.cwd] {
                    enriched.changedFileCount = review.changedFiles
                    enriched.gitReviewState = review.state
                }
                return enriched
            }
            return (0, threads, "")
        } catch {
            return (1, [], "Could not decode the Codex thread index: \(error.localizedDescription)")
        }
    }

    nonisolated private static func scanStorage(
        supportDirectory: URL,
        threads: [CodexThread]
    ) -> [StorageItemSnapshot] {
        struct Candidate {
            let name: String
            let workspace: String
            let url: URL
            let kind: String
            let isTrashable: Bool
        }

        let fileManager = FileManager.default
        let home = fileManager.homeDirectoryForCurrentUser
        var candidates = [
            Candidate(
                name: "Builder Identity reports",
                workspace: "TokenBar",
                url: supportDirectory.appendingPathComponent("profiles", isDirectory: true),
                kind: "Reports",
                isTrashable: false
            ),
            Candidate(
                name: "Share receipts",
                workspace: "TokenBar",
                url: supportDirectory.appendingPathComponent("proof-receipts", isDirectory: true),
                kind: "Receipts",
                isTrashable: false
            ),
            Candidate(
                name: "Codex sessions",
                workspace: "Codex",
                url: home.appendingPathComponent(".codex/sessions", isDirectory: true),
                kind: "Session history",
                isTrashable: false
            ),
            Candidate(
                name: "Codex logs",
                workspace: "Codex",
                url: home.appendingPathComponent(".codex/logs", isDirectory: true),
                kind: "Logs",
                isTrashable: false
            ),
        ]

        let generatedNames: Set<String> = [
            "node_modules", ".build", "build", "dist", ".next", ".nuxt",
            "coverage", ".turbo", ".pytest_cache", "__pycache__", ".venv",
            "venv", "DerivedData", ".gradle", "target", "Pods"
        ]
        var seenWorkspaces = Set<String>()
        for thread in threads {
            let cwd = thread.cwd
            guard !cwd.isEmpty, seenWorkspaces.insert(cwd).inserted else { continue }
            let root = URL(fileURLWithPath: cwd, isDirectory: true)
            let rootPath = root.standardizedFileURL.path
            guard rootPath.hasPrefix(home.path + "/"),
                  rootPath != home.path else { continue }
            for url in generatedDirectories(
                under: root,
                matching: generatedNames,
                maximumDepth: 4
            ) {
                candidates.append(
                    Candidate(
                        name: url.lastPathComponent,
                        workspace: thread.workspace,
                        url: url,
                        kind: "Generated",
                        isTrashable: true
                    )
                )
            }
            if seenWorkspaces.count >= 40 { break }
        }

        var seenPaths = Set<String>()
        return candidates.compactMap { candidate in
            let path = candidate.url.standardizedFileURL.path
            guard seenPaths.insert(path).inserted,
                  fileManager.fileExists(atPath: path) else { return nil }
            let stats = directoryStats(at: candidate.url)
            return StorageItemSnapshot(
                name: candidate.name,
                workspace: candidate.workspace,
                path: path,
                bytes: stats.bytes,
                fileCount: stats.files,
                kind: candidate.kind,
                isTrashable: candidate.isTrashable
            )
        }
        .sorted { lhs, rhs in
            if lhs.bytes == rhs.bytes { return lhs.path < rhs.path }
            return lhs.bytes > rhs.bytes
        }
    }

    nonisolated private static func generatedDirectories(
        under root: URL,
        matching names: Set<String>,
        maximumDepth: Int
    ) -> [URL] {
        let keys: [URLResourceKey] = [.isDirectoryKey, .isSymbolicLinkKey]
        guard let enumerator = FileManager.default.enumerator(
            at: root,
            includingPropertiesForKeys: keys,
            options: [.skipsPackageDescendants],
            errorHandler: { _, _ in true }
        ) else { return [] }

        let rootDepth = root.standardizedFileURL.pathComponents.count
        var matches: [URL] = []
        for case let url as URL in enumerator {
            let depth = url.standardizedFileURL.pathComponents.count - rootDepth
            guard depth <= maximumDepth else {
                enumerator.skipDescendants()
                continue
            }
            guard let values = try? url.resourceValues(forKeys: Set(keys)),
                  values.isSymbolicLink != true,
                  values.isDirectory == true else { continue }
            guard names.contains(url.lastPathComponent) else { continue }
            matches.append(url)
            enumerator.skipDescendants()
        }
        return matches
    }

    nonisolated private static func directoryStats(at url: URL) -> (bytes: Int64, files: Int) {
        let keys: [URLResourceKey] = [.isRegularFileKey, .isSymbolicLinkKey, .fileSizeKey]
        guard let enumerator = FileManager.default.enumerator(
            at: url,
            includingPropertiesForKeys: keys,
            options: [.skipsPackageDescendants],
            errorHandler: { _, _ in true }
        ) else { return (0, 0) }

        var bytes: Int64 = 0
        var files = 0
        for case let fileURL as URL in enumerator {
            guard files < 250_000,
                  let values = try? fileURL.resourceValues(forKeys: Set(keys)),
                  values.isSymbolicLink != true,
                  values.isRegularFile == true else { continue }
            bytes += Int64(values.fileSize ?? 0)
            files += 1
        }
        return (bytes, files)
    }

    nonisolated private static func readGitReviewState(at path: String) -> (state: String, changedFiles: Int) {
        guard !path.isEmpty,
              FileManager.default.fileExists(atPath: path),
              FileManager.default.isExecutableFile(atPath: "/usr/bin/git") else {
            return ("unavailable", 0)
        }
        let process = Process()
        let outputPipe = Pipe()
        let errorPipe = Pipe()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/git")
        process.arguments = ["-C", path, "status", "--porcelain=v1", "--untracked-files=no", "--ignore-submodules=all"]
        process.environment = ProcessInfo.processInfo.environment.merging(["GIT_OPTIONAL_LOCKS": "0"]) { _, new in new }
        process.standardOutput = outputPipe
        process.standardError = errorPipe
        do {
            try process.run()
            let data = outputPipe.fileHandleForReading.readDataToEndOfFile()
            process.waitUntilExit()
            guard process.terminationStatus == 0 else { return ("unavailable", 0) }
            let output = String(data: data, encoding: .utf8) ?? ""
            let changedFiles = output.split(whereSeparator: \.isNewline).count
            return changedFiles == 0 ? ("clean", 0) : ("changed", changedFiles)
        } catch {
            return ("unavailable", 0)
        }
    }

    nonisolated private static func currency(_ value: Double) -> String {
        "$" + value.formatted(.number.grouping(.automatic).precision(.fractionLength(2)))
    }

    nonisolated private static func count(_ value: Int64) -> String {
        value.formatted(.number.grouping(.automatic))
    }

    nonisolated private static func parseInvitation(raw: String, sourceURL: URL) -> ProjectInvitation {
        let lines = raw.components(separatedBy: .newlines)
        let heading = lines.first { $0.trimmingCharacters(in: .whitespaces).hasPrefix("#") }?
            .trimmingCharacters(in: CharacterSet(charactersIn: "# "))
        let proposer = lines.first { $0.lowercased().hasPrefix("proposer:") || $0.lowercased().hasPrefix("from:") }?
            .split(separator: ":", maxSplits: 1).last.map(String.init)?.trimmingCharacters(in: .whitespacesAndNewlines)
        let compact = lines
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty && !$0.hasPrefix("#") && !$0.lowercased().hasPrefix("proposer:") && !$0.lowercased().hasPrefix("from:") }
            .joined(separator: " ")
        return ProjectInvitation(
            id: UUID(),
            title: heading?.isEmpty == false ? heading! : sourceURL.deletingPathExtension().lastPathComponent,
            proposer: proposer?.isEmpty == false ? proposer! : "Shared project brief",
            summary: String(compact.prefix(900)),
            sourcePath: sourceURL.path,
            importedAt: Date(),
            status: "review"
        )
    }
}

private struct CCUsageReport: Decodable {
    let daily: [CCUsageDay]
    let totals: CCUsageTotals
}

private struct CCUsageDay: Decodable {
    let period: String
    let totalCost: Double
    let totalTokens: Int64
    let agents: [CCUsageAgent]?
}

private struct CCUsageAgent: Decodable {
    let agent: String
    let totalCost: Double
}

private struct CCUsageTotals: Decodable {
    let totalCost: Double
}
