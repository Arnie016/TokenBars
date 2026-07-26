import Foundation
import Testing
@testable import TokenBarMac

@MainActor
@Test
func localCostSnapshotSurvivesModelRelaunch() async throws {
    let supportDirectory = FileManager.default.temporaryDirectory
        .appendingPathComponent("TokenBarCostCache-\(UUID().uuidString)", isDirectory: true)
    try FileManager.default.createDirectory(at: supportDirectory, withIntermediateDirectories: true)
    defer {
        try? FileManager.default.removeItem(at: supportDirectory)
    }

    let firstLaunch = TokenBarModel(supportDirectory: supportDirectory)
    firstLaunch.refreshUsageCosts()
    while firstLaunch.isLoadingCosts {
        try await Task.sleep(for: .milliseconds(100))
    }

    #expect(firstLaunch.costUsage.period != "Not loaded")
    #expect(FileManager.default.fileExists(
        atPath: supportDirectory.appendingPathComponent("cost-usage-snapshot.json").path
    ))

    let relaunched = TokenBarModel(supportDirectory: supportDirectory)
    #expect(relaunched.costUsage == firstLaunch.costUsage)
}
