import Foundation
import Testing
@testable import TokenBarMac

@MainActor
@Test
func malformedLocalCostCacheFallsBackToEmptySnapshot() throws {
    let supportDirectory = FileManager.default.temporaryDirectory
        .appendingPathComponent("TokenBarCorruptCostCache-\(UUID().uuidString)", isDirectory: true)
    try FileManager.default.createDirectory(at: supportDirectory, withIntermediateDirectories: true)
    defer {
        try? FileManager.default.removeItem(at: supportDirectory)
    }

    try Data("{not-json".utf8).write(
        to: supportDirectory.appendingPathComponent("cost-usage-snapshot.json")
    )

    let model = TokenBarModel(supportDirectory: supportDirectory)

    #expect(model.costUsage == CCUsageSnapshot())
}
