import AppKit
import Foundation
import UniformTypeIdentifiers

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
        case .queued: "Ready to start"
        case .focus: "Active goal"
        case .recent: "Touched in 24h"
        case .review: "Paused or older"
        case .done: "Completed goal"
        }
    }
}

struct ThreadBoardConfiguration: Codable, Identifiable, Hashable {
    static let starterID = UUID(uuidString: "67483EEA-73DA-4A50-920C-84267EF25A68")!
    static let starter = ThreadBoardConfiguration(
        id: starterID,
        name: "My work",
        queuedTitle: "Queue",
        focusTitle: "Now",
        recentTitle: "Fresh",
        reviewTitle: "Revisit",
        doneTitle: "Done",
        workspaceFilter: "",
        includeAutomations: true,
        accentName: "green"
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
        queuedTitle: String = "Queue",
        focusTitle: String,
        recentTitle: String,
        reviewTitle: String,
        doneTitle: String = "Done",
        workspaceFilter: String,
        includeAutomations: Bool,
        accentName: String = "green"
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
        queuedTitle = try container.decodeIfPresent(String.self, forKey: .queuedTitle) ?? "Queue"
        focusTitle = try container.decode(String.self, forKey: .focusTitle)
        recentTitle = try container.decode(String.self, forKey: .recentTitle)
        reviewTitle = try container.decode(String.self, forKey: .reviewTitle)
        doneTitle = try container.decodeIfPresent(String.self, forKey: .doneTitle) ?? "Done"
        workspaceFilter = try container.decodeIfPresent(String.self, forKey: .workspaceFilter) ?? ""
        includeAutomations = try container.decodeIfPresent(Bool.self, forKey: .includeAutomations) ?? true
        accentName = try container.decodeIfPresent(String.self, forKey: .accentName) ?? "green"
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
        guard !isPublishingProof, !receipt.hasShareSurface else { return }
        isPublishingProof = true
        lastError = nil
        activityMessage = "Publishing an unlisted safe proof…"

        Task {
            let result = await Task.detached(priority: .userInitiated) {
                Self.runTokenBar(arguments: ["publish-proof", "--unlisted", "--hide-owner", "--hide-region"])
            }.value
            isPublishingProof = false
            if result.status == 0 {
                reload()
                refreshIdentityBridge()
                if receipt.hasShareSurface {
                    activityMessage = "Unlisted proof ready · receipt saved locally"
                } else {
                    lastError = "The proof action completed but no reloadable share receipt was found."
                    activityMessage = "Proof receipt needs attention"
                }
            } else {
                lastError = result.output.isEmpty ? "TokenBar could not publish the unlisted proof." : result.output
                activityMessage = "Proof publication needs attention"
            }
        }
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
        My TokenBar identity is \(profile.identityTitle). My current growth edge is: \(profile.growthEdge)

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

    nonisolated private static func runTokenBar(arguments: [String]) -> (status: Int32, output: String) {
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
        process.executableURL = URL(fileURLWithPath: executable)
        process.arguments = arguments
        process.standardOutput = pipe
        process.standardError = pipe
        do {
            try process.run()
            process.waitUntilExit()
            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            return (process.terminationStatus, String(data: data, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines) ?? "")
        } catch {
            return (1, error.localizedDescription)
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
