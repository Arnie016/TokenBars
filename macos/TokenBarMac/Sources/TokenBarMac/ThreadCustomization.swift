import Foundation

struct ThreadCustomization: Codable, Hashable {
    var customTitle = ""
    var colorName = "cyan"
    var isHighlighted = false

    func displayTitle(for thread: CodexThread) -> String {
        let clean = customTitle.trimmingCharacters(in: .whitespacesAndNewlines)
        return clean.isEmpty ? thread.cardTitle : clean
    }
}

enum ThreadCustomizationCodec {
    static func decode(_ json: String) -> [String: ThreadCustomization] {
        guard let data = json.data(using: .utf8),
              let decoded = try? JSONDecoder().decode([String: ThreadCustomization].self, from: data) else {
            return [:]
        }
        return decoded
    }

    static func encode(_ values: [String: ThreadCustomization]) -> String {
        guard let data = try? JSONEncoder().encode(values),
              let json = String(data: data, encoding: .utf8) else {
            return "{}"
        }
        return json
    }
}

enum ThreadLaneOverrideCodec {
    static func decode(_ json: String) -> [String: CodexThreadLane] {
        guard let data = json.data(using: .utf8),
              let raw = try? JSONDecoder().decode([String: String].self, from: data) else {
            return [:]
        }
        return raw.reduce(into: [:]) { result, entry in
            if let lane = CodexThreadLane(rawValue: entry.value) {
                result[entry.key] = lane
            }
        }
    }

    static func encode(_ values: [String: CodexThreadLane]) -> String {
        let raw = values.mapValues(\.rawValue)
        guard let data = try? JSONEncoder().encode(raw),
              let json = String(data: data, encoding: .utf8) else {
            return "{}"
        }
        return json
    }
}
