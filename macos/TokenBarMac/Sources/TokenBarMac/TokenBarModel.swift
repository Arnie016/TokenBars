import AppKit
import Foundation

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
}

struct CCUsageSnapshot: Hashable, Sendable {
    var period = "Not loaded"
    var latestCost = "--"
    var codexCost = "--"
    var latestTokens = "--"
    var observedCost = "--"
}

struct BuilderProfile: Hashable {
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
    var reportURL: URL?
    var sourceURL: URL?
}

struct ProofReceipt: Hashable {
    var token = "Not published"
    var runID = ""
    var shareMode = "private"
    var publicProfileURL: URL?
    var proofCardURL: URL?
    var socialURL: URL?
    var rankingsURL: URL?

    var hasShareSurface: Bool { publicProfileURL != nil || proofCardURL != nil }
    var isLocalPreview: Bool {
        [publicProfileURL, proofCardURL].compactMap { $0?.host }.contains { $0 == "127.0.0.1" || $0 == "localhost" }
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
    case focus = "Focus"
    case recent = "Recent"
    case review = "Review"

    var id: String { rawValue }
    var subtitle: String {
        switch self {
        case .focus: "Active goal"
        case .recent: "Touched in 24h"
        case .review: "Paused or older"
        }
    }
}

struct CodexThread: Decodable, Identifiable, Hashable {
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
        if goalStatus == "active" { return .focus }
        let age = now.timeIntervalSince(updatedAt)
        if goalStatus == "paused" || goalStatus == "blocked" || goalStatus == "usage_limited" || goalStatus == "budget_limited" {
            return .review
        }
        return age <= 86_400 ? .recent : .review
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
    @Published var costUsage = CCUsageSnapshot()
    @Published var isAnalyzing = false
    @Published var isLoadingCosts = false
    @Published var isRevoking = false
    @Published var isLoadingThreads = false
    @Published var activityMessage = "Local data loaded"
    @Published var lastError: String?

    private let fileManager = FileManager.default
    private let supportDirectory: URL

    init() {
        supportDirectory = fileManager.homeDirectoryForCurrentUser
            .appendingPathComponent("Library/Application Support/CodexLimitBar", isDirectory: true)
        threadDrafts = loadThreadDrafts()
        reload()
        refreshThreads()
    }

    func reload() {
        profile = loadLatestProfile()
        receipt = loadLatestReceipt()
        invitations = loadInvitations()
        activityMessage = profile.sourceURL == nil ? "Ready for a private local analysis" : "Updated from local evidence"
    }

    func refreshIdentity() {
        guard !isAnalyzing else { return }
        isAnalyzing = true
        lastError = nil
        activityMessage = "Reading local Codex evidence…"

        Task {
            let result = await Task.detached(priority: .userInitiated) {
                Self.runTokenBar(arguments: ["claim", "--days", "7"])
            }.value
            isAnalyzing = false
            if result.status == 0 {
                reload()
                activityMessage = "Builder Story refreshed"
            } else {
                lastError = result.output.isEmpty ? "TokenBar could not refresh the identity." : result.output
                activityMessage = "Analysis needs attention"
            }
        }
    }

    func refreshUsageCosts() {
        guard !isLoadingCosts else { return }
        isLoadingCosts = true
        lastError = nil
        activityMessage = "Reading ccusage locally…"

        Task {
            let result = await Task.detached(priority: .userInitiated) {
                Self.runCCUsage(timeZone: TimeZone.current.identifier)
            }.value
            isLoadingCosts = false
            if result.status == 0, let snapshot = result.snapshot {
                costUsage = snapshot
                activityMessage = "Cost snapshot loaded locally"
            } else {
                lastError = result.output.isEmpty ? "TokenBar could not read ccusage." : result.output
                activityMessage = "Cost snapshot needs attention"
            }
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

    func copy(_ value: String, confirmation: String) {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(value, forType: .string)
        activityMessage = confirmation
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

        for bundleID in ["com.openai.codex", "com.openai.chatgpt"] {
            if let appURL = NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleID) {
                NSWorkspace.shared.openApplication(at: appURL, configuration: .init())
                break
            }
        }
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
                model: string(usage["topLocalModel"], fallback: "Local")
            ),
            reportURL: fileManager.fileExists(atPath: reportURL.path) ? reportURL : nil,
            sourceURL: url
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
            let receipt = ProofReceipt(
                token: string(object["token"], fallback: url.deletingPathExtension().lastPathComponent),
                runID: string(object["runId"]),
                shareMode: string(object["shareMode"], fallback: "unlisted"),
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
        let candidates = [
            FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent(".local/bin/tokenbar").path,
            "/usr/local/bin/tokenbar",
            "/opt/homebrew/bin/tokenbar"
        ]
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
                observedCost: currency(report.totals.totalCost)
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
