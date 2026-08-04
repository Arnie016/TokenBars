import Foundation

struct BuilderIdentityRank: Hashable {
    let level: Int
    let name: String
    let threshold: Int

    var label: String { "Rank \(Self.roman(level)) · \(name)" }

    static func resolve(evidenceScore: Int, sessions: Int) -> BuilderIdentityRank {
        let score = min(100, max(0, evidenceScore))
        switch score {
        case 95...:
            return BuilderIdentityRank(level: 6, name: "Mythic", threshold: 95)
        case 80...:
            return BuilderIdentityRank(level: 5, name: "Ascendant", threshold: 80)
        case 64...:
            return BuilderIdentityRank(level: 4, name: "Paragon", threshold: 64)
        case 46...:
            return BuilderIdentityRank(level: 3, name: "Vanguard", threshold: 46)
        case 26...:
            return BuilderIdentityRank(level: 2, name: "Wayfinder", threshold: 26)
        default:
            return BuilderIdentityRank(level: 1, name: sessions > 0 ? "Sparkbound" : "Uncharted", threshold: 0)
        }
    }

    private static func roman(_ number: Int) -> String {
        ["I", "II", "III", "IV", "V", "VI"][min(5, max(0, number - 1))]
    }
}

struct BuilderIdentityStyle: Identifiable, Hashable {
    let id: String
    let title: String
    let order: String
    let motto: String
    let symbolName: String
    let textureName: String
    let paletteIndex: Int
}

enum BuilderIdentityCatalog {
    private struct Office {
        let slug: String
        let title: String
        let symbol: String
        let promise: String
    }

    private struct Realm {
        let slug: String
        let title: String
        let order: String
        let texture: String
        let promise: String
    }

    private static let offices: [Office] = [
        Office(slug: "cartographer", title: "Cartographer of", symbol: "map.fill", promise: "Maps the route before the frontier hardens."),
        Office(slug: "warden", title: "Warden of", symbol: "shield.lefthalf.filled", promise: "Protects the boundary without slowing the expedition."),
        Office(slug: "oracle", title: "Oracle of", symbol: "eye.fill", promise: "Finds the signal that changes the next decision."),
        Office(slug: "architect", title: "Architect of", symbol: "building.columns.fill", promise: "Builds structures that outlive the first victory."),
        Office(slug: "sovereign", title: "Sovereign of", symbol: "crown.fill", promise: "Turns intent into a system others can trust."),
        Office(slug: "forgekeeper", title: "Forgekeeper of", symbol: "hammer.fill", promise: "Tempers rough experiments into durable instruments."),
        Office(slug: "navigator", title: "Navigator of", symbol: "location.north.fill", promise: "Keeps the mission moving through uncertain terrain."),
        Office(slug: "harbinger", title: "Harbinger of", symbol: "bolt.fill", promise: "Makes the next era visible before it arrives."),
        Office(slug: "mythmaker", title: "Mythmaker of", symbol: "sparkles", promise: "Gives the build a world people can remember."),
        Office(slug: "pathfinder", title: "Pathfinder of", symbol: "point.topleft.down.to.point.bottomright.curvepath.fill", promise: "Finds the smallest passage through impossible work."),
    ]

    private static let realms: [Realm] = [
        Realm(slug: "impossible-atlas", title: "the Impossible Atlas", order: "Order of Unmapped Systems", texture: "engraved atlas", promise: "Every mark is earned by a path another builder can follow."),
        Realm(slug: "last-signal", title: "the Last Signal", order: "Order of the Distant Beacon", texture: "signal glass", promise: "Noise falls away until only the decisive proof remains."),
        Realm(slug: "black-meridian", title: "the Black Meridian", order: "Corsairs of the Midnight Route", texture: "salt-dark chart", promise: "Momentum survives the crossing because the bearing stays legible."),
        Realm(slug: "threaded-leviathan", title: "the Threaded Leviathan", order: "Guild of Interwoven Agents", texture: "braided current", promise: "Many active minds become one coordinated force."),
        Realm(slug: "living-archive", title: "the Living Archive", order: "Keepers of Remembered Work", texture: "illuminated folio", promise: "What happened, when it happened, and why it mattered remain visible."),
        Realm(slug: "glass-frontier", title: "the Glass Frontier", order: "Pilots of Transparent Systems", texture: "prismatic grid", promise: "Complex machinery stays inspectable from edge to edge."),
        Realm(slug: "iron-constellation", title: "the Iron Constellation", order: "Foundry of Reliable Stars", texture: "forged star map", promise: "Strong boundaries connect into a system that holds."),
        Realm(slug: "unwritten-engine", title: "the Unwritten Engine", order: "Makers of Product Machinery", texture: "mechanical vellum", promise: "Commercial intent becomes a repeatable operating machine."),
        Realm(slug: "ember-crown", title: "the Ember Crown", order: "Court of Memorable Interfaces", texture: "burnished heraldry", promise: "The product earns a presence people are proud to carry."),
        Realm(slug: "silent-armada", title: "the Silent Armada", order: "Fleet of Local Intelligence", texture: "moonlit rigging", promise: "Private tools move together without surrendering their cargo."),
    ]

    static let styles: [BuilderIdentityStyle] = realms.enumerated().flatMap { realmIndex, realm in
        offices.map { office in
            BuilderIdentityStyle(
                id: "\(office.slug)-\(realm.slug)",
                title: "\(office.title) \(realm.title)",
                order: realm.order,
                motto: "\(office.promise) \(realm.promise)",
                symbolName: office.symbol,
                textureName: realm.texture,
                paletteIndex: realmIndex
            )
        }
    }

    static func defaultIndex(seed: String) -> Int {
        guard !styles.isEmpty else { return 0 }
        let hash = seed.unicodeScalars.reduce(0) { ($0 &* 31) &+ Int($1.value) }
        return abs(hash) % styles.count
    }

    static func style(at preferredIndex: Int, seed: String) -> BuilderIdentityStyle {
        let index = styles.indices.contains(preferredIndex) ? preferredIndex : defaultIndex(seed: seed)
        return styles[index]
    }
}
