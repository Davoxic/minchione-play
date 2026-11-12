import Foundation
import Combine

public class LyricsService: ObservableObject {
    public static let shared = LyricsService()

    @Published public private(set) var currentLyrics: [LyricLine] = []
    @Published public private(set) var plainLyrics: String? = nil
    @Published public private(set) var activeLineIndex: Int = 0
    @Published public private(set) var isLoading: Bool = false
    @Published public private(set) var currentTrackId: String? = nil
    @Published public private(set) var providerName: String = "LRCLIB"
    @Published public var offsetSeconds: Double = 0.0

    private var activeTask: Task<Void, Never>?
    private let cacheDirectory: URL

    private init() {
        let paths = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask)
        let dir = paths[0].appendingPathComponent("lyrics_cache", isDirectory: true)
        if !FileManager.default.fileExists(atPath: dir.path) {
            try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        }
        self.cacheDirectory = dir
    }

    public var hasSyncedLyrics: Bool {
        return !currentLyrics.isEmpty
    }

    public var hasAnyLyrics: Bool {
        return hasSyncedLyrics || (plainLyrics != nil && !(plainLyrics?.isEmpty ?? true))
    }

    // MARK: - Fetching

    public func fetchLyrics(for track: Track) {
        if currentTrackId == track.id && (hasSyncedLyrics || plainLyrics != nil) {
            return
        }

        activeTask?.cancel()
        currentTrackId = track.id
        currentLyrics = []
        plainLyrics = nil
        activeLineIndex = 0
        offsetSeconds = 0.0
        isLoading = true

        activeTask = Task { @MainActor in
            // 1. Check local on-disk cache
            if let cached = self.loadCachedLyrics(trackId: track.id) {
                if !Task.isCancelled {
                    self.currentLyrics = cached.synced
                    self.plainLyrics = cached.plain
                    self.isLoading = false
                }
                return
            }

            // 2. Fetch from LRCLIB
            let result = await self.fetchFromLrcLib(track: track)
            guard !Task.isCancelled else { return }

            self.isLoading = false
            if let result = result {
                if let synced = result.syncedLyrics, !synced.isEmpty {
                    let parsed = LRCParser.parse(lrc: synced)
                    self.currentLyrics = parsed
                    self.plainLyrics = result.plainLyrics
                    self.saveCachedLyrics(trackId: track.id, synced: parsed, plain: result.plainLyrics)
                } else if let plain = result.plainLyrics, !plain.isEmpty {
                    self.plainLyrics = plain
                    self.saveCachedLyrics(trackId: track.id, synced: [], plain: plain)
                }
            }
        }
    }

    private func fetchFromLrcLib(track: Track) async -> LRCLibHit? {
        let cleanTitle = cleanSearchTerm(track.title)
        let cleanArtist = cleanSearchTerm(track.artist)
        let durationSec = max(track.durationMs / 1000, 1)

        // Attempt 1: Exact match endpoint
        if let exact = await requestLrcLibExact(title: cleanTitle, artist: cleanArtist, duration: durationSec) {
            if (exact.syncedLyrics != nil && !exact.syncedLyrics!.isEmpty) || (exact.plainLyrics != nil && !exact.plainLyrics!.isEmpty) {
                return exact
            }
        }

        // Attempt 2: Search endpoint fallback
        if let hits = await requestLrcLibSearch(title: cleanTitle, artist: cleanArtist) {
            // Find the hit closest in duration
            let sorted = hits.sorted { a, b in
                let diffA = abs((a.duration ?? Double(durationSec)) - Double(durationSec))
                let diffB = abs((b.duration ?? Double(durationSec)) - Double(durationSec))
                return diffA < diffB
            }
            if let best = sorted.first(where: { ($0.syncedLyrics != nil && !$0.syncedLyrics!.isEmpty) || ($0.plainLyrics != nil && !$0.plainLyrics!.isEmpty) }) {
                return best
            }
        }

        return nil
    }

    private func requestLrcLibExact(title: String, artist: String, duration: Int) async -> LRCLibHit? {
        guard var components = URLComponents(string: "https://lrclib.net/api/get") else { return nil }
        components.queryItems = [
            URLQueryItem(name: "track_name", value: title),
            URLQueryItem(name: "artist_name", value: artist),
            URLQueryItem(name: "duration", value: String(duration))
        ]
        guard let url = components.url else { return nil }

        var request = URLRequest(url: url)
        request.setValue("MinchionePlay/2.0 (iOS; DovvoPlay-BitChord-Merge)", forHTTPHeaderField: "User-Agent")
        request.timeoutInterval = 10

        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            guard (response as? HTTPURLResponse)?.statusCode == 200 else { return nil }
            return try? JSONDecoder().decode(LRCLibHit.self, from: data)
        } catch {
            return nil
        }
    }

    private func requestLrcLibSearch(title: String, artist: String) async -> [LRCLibHit]? {
        guard var components = URLComponents(string: "https://lrclib.net/api/search") else { return nil }
        components.queryItems = [
            URLQueryItem(name: "track_name", value: title),
            URLQueryItem(name: "artist_name", value: artist)
        ]
        guard let url = components.url else { return nil }

        var request = URLRequest(url: url)
        request.setValue("MinchionePlay/2.0 (iOS; DovvoPlay-BitChord-Merge)", forHTTPHeaderField: "User-Agent")
        request.timeoutInterval = 10

        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            guard (response as? HTTPURLResponse)?.statusCode == 200 else { return nil }
            return try? JSONDecoder().decode([LRCLibHit].self, from: data)
        } catch {
            return nil
        }
    }

    // MARK: - Real-time Synchronization

    public func updateActiveLine(currentPlaybackTime: TimeInterval) {
        guard !currentLyrics.isEmpty else { return }

        let adjustedTimeMs = Int((currentPlaybackTime + offsetSeconds) * 1000)

        // Find the last line whose timestamp is <= current playback time
        var newIndex = 0
        for (idx, line) in currentLyrics.enumerated() {
            if line.timeMs <= adjustedTimeMs {
                newIndex = idx
            } else {
                break
            }
        }

        if newIndex != activeLineIndex {
            activeLineIndex = newIndex
        }
    }

    public func adjustOffset(by delta: Double) {
        offsetSeconds += delta
        if let currentPos = AudioPlayerService.shared.position as TimeInterval? {
            updateActiveLine(currentPlaybackTime: currentPos)
        }
    }

    public func resetOffset() {
        offsetSeconds = 0.0
        if let currentPos = AudioPlayerService.shared.position as TimeInterval? {
            updateActiveLine(currentPlaybackTime: currentPos)
        }
    }

    public func clear() {
        activeTask?.cancel()
        currentTrackId = nil
        currentLyrics = []
        plainLyrics = nil
        activeLineIndex = 0
        offsetSeconds = 0.0
    }

    // MARK: - String Cleaning Helpers

    private func cleanSearchTerm(_ raw: String) -> String {
        var str = raw
        // Remove common YouTube / music noise in titles
        let patterns = [
            #"\((?:official|video|audio|lyric|lyrics|from|feat\.?|remix|live|clip|hd|4k)[^)]*\)"#,
            #"\[(?:official|video|audio|lyric|lyrics|from|feat\.?|remix|live|clip|hd|4k)[^\]]*\]"#,
            #"\b(?:official (?:video|audio|music video)|lyric video|full song)\b"#
        ]
        for pattern in patterns {
            str = str.replacingOccurrences(of: pattern, with: "", options: [.regularExpression, .caseInsensitive])
        }

        if let pipeIdx = str.firstIndex(of: "|") {
            str = String(str[..<pipeIdx])
        }
        if let dashIdx = str.firstIndex(of: "-"), str.components(separatedBy: "-").count == 2 {
            // Often "Artist - Title", if this is title it might have had artist
            let parts = str.components(separatedBy: "-")
            str = parts.last ?? str
        }

        return str.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    // MARK: - Disk Cache

    private struct CachedPayload: Codable {
        let synced: [LyricLine]
        let plain: String?
    }

    private func cacheFilePath(trackId: String) -> URL {
        let safeName = trackId.replacingOccurrences(of: "[^a-zA-Z0-9_-]", with: "_", options: .regularExpression)
        return cacheDirectory.appendingPathComponent("\(safeName).json")
    }

    private func loadCachedLyrics(trackId: String) -> (synced: [LyricLine], plain: String?)? {
        let path = cacheFilePath(trackId: trackId)
        guard let data = try? Data(contentsOf: path),
              let payload = try? JSONDecoder().decode(CachedPayload.self, from: data) else {
            return nil
        }
        return (payload.synced, payload.plain)
    }

    private func saveCachedLyrics(trackId: String, synced: [LyricLine], plain: String?) {
        let path = cacheFilePath(trackId: trackId)
        let payload = CachedPayload(synced: synced, plain: plain)
        if let data = try? JSONEncoder().encode(payload) {
            try? data.write(to: path)
        }
    }
}
