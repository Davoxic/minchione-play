import Foundation

public struct LyricLine: Identifiable, Equatable, Hashable, Codable {
    public let id: String
    public let timeMs: Int
    public let text: String

    public var timeSeconds: TimeInterval {
        return TimeInterval(timeMs) / 1000.0
    }

    public var formattedTime: String {
        let totalSeconds = max(0, timeMs / 1000)
        let mins = totalSeconds / 60
        let secs = totalSeconds % 60
        return String(format: "%02d:%02d", mins, secs)
    }

    public init(id: String = UUID().uuidString, timeMs: Int, text: String) {
        self.id = id
        self.timeMs = timeMs
        self.text = text
    }
}

public enum LRCParser {
    /// Parses standard and enhanced LRC strings into timestamp-ordered `LyricLine` objects.
    public static func parse(lrc: String) -> [LyricLine] {
        guard !lrc.isEmpty else { return [] }

        var lines: [LyricLine] = []
        let rawLines = lrc.components(separatedBy: .newlines)

        // Matches [mm:ss.xx] or [mm:ss.xxx] or [mm:ss]
        let pattern = #"\[(\d{1,2}):(\d{2})(?:\.(\d{1,3}))?\](.*)"#
        guard let regex = try? NSRegularExpression(pattern: pattern, options: []) else {
            return []
        }

        for rawLine in rawLines {
            let trimmed = rawLine.trimmingCharacters(in: .whitespaces)
            guard !trimmed.isEmpty else { continue }

            // Skip ID3 tags like [ti:...], [ar:...], [length:...]
            if trimmed.hasPrefix("[ti:") || trimmed.hasPrefix("[ar:") || trimmed.hasPrefix("[al:") ||
               trimmed.hasPrefix("[by:") || trimmed.hasPrefix("[offset:") || trimmed.hasPrefix("[length:") {
                continue
            }

            let range = NSRange(location: 0, length: trimmed.utf16.count)
            let matches = regex.matches(in: trimmed, options: [], range: range)

            for match in matches {
                guard match.numberOfRanges >= 3,
                      let minRange = Range(match.range(at: 1), in: trimmed),
                      let secRange = Range(match.range(at: 2), in: trimmed),
                      let minutes = Int(trimmed[minRange]),
                      let seconds = Int(trimmed[secRange]) else { continue }

                var fractionMs = 0
                if match.numberOfRanges >= 4,
                   match.range(at: 3).location != NSNotFound,
                   let fracRange = Range(match.range(at: 3), in: trimmed) {
                    let fracStr = String(trimmed[fracRange])
                    if fracStr.count == 1 {
                        fractionMs = (Int(fracStr) ?? 0) * 100
                    } else if fracStr.count == 2 {
                        fractionMs = (Int(fracStr) ?? 0) * 10
                    } else if fracStr.count >= 3 {
                        fractionMs = Int(fracStr.prefix(3)) ?? 0
                    }
                }

                var text = ""
                if match.numberOfRanges >= 5,
                   match.range(at: 4).location != NSNotFound,
                   let textRange = Range(match.range(at: 4), in: trimmed) {
                    text = String(trimmed[textRange]).trimmingCharacters(in: .whitespaces)
                }

                // Strip inner enhanced LRC word timestamps like <00:12.34>
                text = text.replacingOccurrences(of: #"<\d{1,2}:\d{2}(?:\.\d{1,3})?>"#, with: "", options: .regularExpression)
                text = text.trimmingCharacters(in: .whitespaces)

                let totalMs = (minutes * 60 + seconds) * 1000 + fractionMs
                lines.append(LyricLine(timeMs: totalMs, text: text))
            }
        }

        // Sort chronologically
        lines.sort { $0.timeMs < $1.timeMs }

        // Remove redundant empty trailing lines, but keep meaningful pauses
        return lines.filter { line in
            // Allow lines if they have text or if they mark a break between lyrics
            return !line.text.isEmpty
        }
    }
}

public struct LRCLibHit: Codable {
    public let id: Int?
    public let trackName: String?
    public let artistName: String?
    public let albumName: String?
    public let duration: Double?
    public let instrumental: Bool?
    public let plainLyrics: String?
    public let syncedLyrics: String?
}
