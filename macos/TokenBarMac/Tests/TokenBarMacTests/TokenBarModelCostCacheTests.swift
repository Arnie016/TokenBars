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

    let cacheURL = supportDirectory.appendingPathComponent("cost-usage-snapshot.json")
    let cacheJSON = """
    {
      "schema": "tokenbar.local_cost_usage.v1",
      "savedAt": 0,
      "snapshot": {
        "period": "2026-08-02",
        "latestCost": "$4.20",
        "codexCost": "$3.80",
        "latestTokens": "84M",
        "observedCost": "$42.00",
        "recentDays": [
          {
            "period": "2026-08-01",
            "totalCost": "$2.10",
            "codexCost": "$1.90"
          },
          {
            "period": "2026-08-02",
            "totalCost": "$4.20",
            "codexCost": "$3.80"
          }
        ]
      }
    }
    """
    let cacheData = try #require(cacheJSON.data(using: .utf8))
    try cacheData.write(to: cacheURL)

    let firstLaunch = TokenBarModel(supportDirectory: supportDirectory)
    let expected = CCUsageSnapshot(
        period: "2026-08-02",
        latestCost: "$4.20",
        codexCost: "$3.80",
        latestTokens: "84M",
        observedCost: "$42.00",
        recentDays: [
            CCUsageDaySnapshot(period: "2026-08-01", totalCost: "$2.10", codexCost: "$1.90"),
            CCUsageDaySnapshot(period: "2026-08-02", totalCost: "$4.20", codexCost: "$3.80"),
        ]
    )
    #expect(firstLaunch.costUsage == expected)
    #expect(FileManager.default.fileExists(atPath: cacheURL.path))

    let relaunched = TokenBarModel(supportDirectory: supportDirectory)
    #expect(relaunched.costUsage == firstLaunch.costUsage)
}
