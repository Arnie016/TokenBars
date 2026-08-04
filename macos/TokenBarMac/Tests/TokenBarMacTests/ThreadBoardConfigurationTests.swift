import Foundation
import Testing
@testable import TokenBarMac

@Test
func legacyThreeLaneBoardMigratesToFiveLanes() throws {
    let legacy = """
    {
      "id": "67483EEA-73DA-4A50-920C-84267EF25A68",
      "name": "Crew Room",
      "focusTitle": "Leading",
      "recentTitle": "In flight",
      "reviewTitle": "Handoffs",
      "workspaceFilter": "",
      "includeAutomations": true
    }
    """.data(using: .utf8)!

    let board = try JSONDecoder().decode(ThreadBoardConfiguration.self, from: legacy)

    #expect(board.queuedTitle == "Waiting")
    #expect(board.focusTitle == "Leading")
    #expect(board.recentTitle == "In flight")
    #expect(board.reviewTitle == "Handoffs")
    #expect(board.doneTitle == "Complete")
    #expect(board.accentName == "cyan")
}

@Test
func completedThreadMapsToDoneLane() throws {
    let now = Date()
    let thread = CodexThread(
        id: "thread-complete",
        title: "Finished launch pass",
        cwd: "/tmp/tokenbar",
        tokensUsed: 1200,
        recencyAtMs: Int64(now.timeIntervalSince1970 * 1_000),
        source: "codex",
        gitBranch: "main",
        gitSHA: nil,
        model: "gpt-test",
        threadSource: "codex",
        parentThreadID: nil,
        childThreadCount: 0,
        goalStatus: "complete"
    )

    #expect(thread.lane(now: now) == .done)
}
