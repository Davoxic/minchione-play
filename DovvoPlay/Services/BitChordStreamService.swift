import Foundation
import Combine
import AVFoundation

public struct BitChordResolvedStream: Sendable {
    public let videoId: String
    public let url: URL
    public let itag: Int
    public let kbps: Int
    public let mimeType: String
    public let clientName: String
    public let mediaHeaders: [String: String]

    public init(
        videoId: String,
        url: URL,
        itag: Int,
        kbps: Int,
        mimeType: String,
        clientName: String,
        mediaHeaders: [String: String] = [:]
    ) {
        self.videoId = videoId
        self.url = url
        self.itag = itag
        self.kbps = kbps
        self.mimeType = mimeType
        self.clientName = clientName
        self.mediaHeaders = mediaHeaders
    }
}

public class BitChordStreamService: NSObject, ObservableObject, URLSessionDownloadDelegate {
    public static let shared = BitChordStreamService()

    @Published public var downloadingProgress: [String: Double] = [:]
    @Published public var downloadedVideoIds: Set<String> = []
    @Published public var activeStreamingId: String? = nil
    @Published public var lastErrorMessage: String? = nil

    private var progressCallbacks: [String: (Double) -> Void] = [:]
    private var downloadTasks: [URLSessionDownloadTask: String] = [:]
    private var downloadContinuations: [String: CheckedContinuation<URL?, Never>] = [:]
    private lazy var downloadSession: URLSession = {
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 30
        config.timeoutIntervalForResource = 300
        return URLSession(configuration: config, delegate: self, delegateQueue: .main)
    }()

    override private init() {
        super.init()
        refreshDownloadedSet()
    }

    public func refreshDownloadedSet() {
        let musicDir = LibraryService.shared.musicDirectory
        var set = Set<String>()
        if let files = try? FileManager.default.contentsOfDirectory(at: musicDir, includingPropertiesForKeys: nil) {
            for f in files {
                let name = f.lastPathComponent
                // Check if filename contains a YouTube videoId
                if let range = name.range(of: "yt_") {
                    let idPart = String(name[range.upperBound...]).components(separatedBy: ".")[0]
                    set.insert(idPart)
                }
                for word in name.components(separatedBy: "_") {
                    if word.count == 11 && !word.contains(" ") {
                        set.insert(word)
                    }
                }
            }
        }
        self.downloadedVideoIds = set
    }

    public func isDownloaded(videoId: String) -> Bool {
        let cleanId = videoId.replacingOccurrences(of: "yt_", with: "")
        if downloadedVideoIds.contains(cleanId) { return true }
        return getLocalAudioFile(videoId: cleanId) != nil
    }

    public func isDownloading(videoId: String) -> Bool {
        let cleanId = videoId.replacingOccurrences(of: "yt_", with: "")
        return downloadingProgress[cleanId] != nil
    }

    public func getLocalAudioFile(videoId: String) -> URL? {
        let cleanId = videoId.replacingOccurrences(of: "yt_", with: "")
        let musicDir = LibraryService.shared.musicDirectory

        if let files = try? FileManager.default.contentsOfDirectory(at: musicDir, includingPropertiesForKeys: [.fileSizeKey]) {
            for file in files {
                if file.lastPathComponent.contains(cleanId) {
                    let size = (try? file.resourceValues(forKeys: [.fileSizeKey]).fileSize) ?? 0
                    if size > 50000 {
                        return file
                    }
                }
            }
        }
        return nil
    }

    // MARK: - BitChord Stream Resolver Catalog (VisionOS, Android VR, Web Remix, TV)

    public func resolveStream(videoId: String) async -> BitChordResolvedStream? {
        let cleanId = videoId.replacingOccurrences(of: "yt_", with: "")

        // 1. Try VisionOS client (BitChord #1 client: unthrottled direct m4a/aac without cipher)
        if let stream = await tryVisionOSClient(videoId: cleanId) {
            return stream
        }

        // 2. Try Android VR client (Quest 3 Innertube client)
        if let stream = await tryAndroidVRClient(videoId: cleanId) {
            return stream
        }

        // 3. Try Web Remix client (music.youtube.com)
        if let stream = await tryWebRemixClient(videoId: cleanId) {
            return stream
        }

        // 4. Try TV client fallback
        if let stream = await tryTvClient(videoId: cleanId) {
            return stream
        }

        return nil
    }

    // Client 1: VisionOS
    private func tryVisionOSClient(videoId: String) async -> BitChordResolvedStream? {
        guard let endpoint = URL(string: "https://youtubei.googleapis.com/youtubei/v1/player") else { return nil }
        var request = URLRequest(url: endpoint)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("2", forHTTPHeaderField: "X-Goog-Api-Format-Version")
        request.setValue("Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/17.0 Safari/605.1.15", forHTTPHeaderField: "User-Agent")

        let payload: [String: Any] = [
            "context": [
                "client": [
                    "clientName": "VISIONOS",
                    "clientVersion": "1.02",
                    "platform": "MOBILE",
                    "deviceMake": "Apple",
                    "deviceModel": "RealityDevice14,1",
                    "osName": "visionOS",
                    "osVersion": "25.6.0.23O471",
                    "hl": "it",
                    "gl": "IT"
                ]
            ],
            "videoId": videoId
        ]
        request.httpBody = try? JSONSerialization.data(withJSONObject: payload)

        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            guard (response as? HTTPURLResponse)?.statusCode == 200 else { return nil }
            return parsePlayerResponse(data: data, videoId: videoId, clientName: "VISIONOS")
        } catch {
            return nil
        }
    }

    // Client 2: Android VR
    private func tryAndroidVRClient(videoId: String) async -> BitChordResolvedStream? {
        guard let endpoint = URL(string: "https://www.youtube.com/youtubei/v1/player") else { return nil }
        var request = URLRequest(url: endpoint)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        let payload: [String: Any] = [
            "context": [
                "client": [
                    "clientName": "ANDROID_VR",
                    "clientVersion": "1.65.10",
                    "deviceMake": "Oculus",
                    "deviceModel": "Quest 3",
                    "osName": "Android",
                    "osVersion": "12L",
                    "androidSdkVersion": 32,
                    "hl": "it",
                    "gl": "IT"
                ]
            ],
            "videoId": videoId
        ]
        request.httpBody = try? JSONSerialization.data(withJSONObject: payload)

        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            guard (response as? HTTPURLResponse)?.statusCode == 200 else { return nil }
            return parsePlayerResponse(data: data, videoId: videoId, clientName: "ANDROID_VR")
        } catch {
            return nil
        }
    }

    // Client 3: Web Remix
    private func tryWebRemixClient(videoId: String) async -> BitChordResolvedStream? {
        guard let endpoint = URL(string: "https://music.youtube.com/youtubei/v1/player") else { return nil }
        var request = URLRequest(url: endpoint)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("https://music.youtube.com", forHTTPHeaderField: "Origin")
        request.setValue("Mozilla/5.0 (iPhone; CPU iPhone OS 17_5 like Mac OS X) AppleWebKit/605.1.15", forHTTPHeaderField: "User-Agent")

        let payload: [String: Any] = [
            "context": [
                "client": [
                    "clientName": "WEB_REMIX",
                    "clientVersion": "1.20260922.09.00",
                    "hl": "it",
                    "gl": "IT"
                ]
            ],
            "videoId": videoId
        ]
        request.httpBody = try? JSONSerialization.data(withJSONObject: payload)

        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            guard (response as? HTTPURLResponse)?.statusCode == 200 else { return nil }
            return parsePlayerResponse(data: data, videoId: videoId, clientName: "WEB_REMIX")
        } catch {
            return nil
        }
    }

    // Client 4: TV Simply
    private func tryTvClient(videoId: String) async -> BitChordResolvedStream? {
        guard let endpoint = URL(string: "https://www.youtube.com/youtubei/v1/player") else { return nil }
        var request = URLRequest(url: endpoint)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        let payload: [String: Any] = [
            "context": [
                "client": [
                    "clientName": "TVHTML5_SIMPLY",
                    "clientVersion": "1.0",
                    "hl": "it",
                    "gl": "IT"
                ]
            ],
            "videoId": videoId
        ]
        request.httpBody = try? JSONSerialization.data(withJSONObject: payload)

        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            guard (response as? HTTPURLResponse)?.statusCode == 200 else { return nil }
            return parsePlayerResponse(data: data, videoId: videoId, clientName: "TVHTML5")
        } catch {
            return nil
        }
    }

    // Parsing formats
    private func parsePlayerResponse(data: Data, videoId: String, clientName: String) -> BitChordResolvedStream? {
        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let streamingData = json["streamingData"] as? [String: Any] else {
            return nil
        }

        let adaptive = (streamingData["adaptiveFormats"] as? [[String: Any]]) ?? []
        let formats = (streamingData["formats"] as? [[String: Any]]) ?? []
        let all = adaptive + formats

        // 1. Audio-only AAC itag 140 or m4a
        for f in all {
            let itag = f["itag"] as? Int ?? 0
            let mime = (f["mimeType"] as? String)?.lowercased() ?? ""
            let bitrate = (f["bitrate"] as? Int) ?? 128000
            if (itag == 140 || mime.contains("audio/mp4") || mime.contains("mp4a")) && !mime.contains("opus") {
                if let urlStr = f["url"] as? String, let url = URL(string: urlStr) {
                    let headers = [
                        "User-Agent": "Mozilla/5.0 (iPhone; CPU iPhone OS 17_5 like Mac OS X) AppleWebKit/605.1.15",
                        "Accept": "*/*",
                        "Referer": "https://music.youtube.com/"
                    ]
                    return BitChordResolvedStream(
                        videoId: videoId,
                        url: url,
                        itag: itag,
                        kbps: bitrate / 1000,
                        mimeType: mime,
                        clientName: clientName,
                        mediaHeaders: headers
                    )
                }
            }
        }

        // 2. Fallback to Opus 251 or any audio stream
        for f in all {
            let itag = f["itag"] as? Int ?? 0
            let mime = (f["mimeType"] as? String)?.lowercased() ?? ""
            let bitrate = (f["bitrate"] as? Int) ?? 128000
            if mime.contains("audio/") {
                if let urlStr = f["url"] as? String, let url = URL(string: urlStr) {
                    return BitChordResolvedStream(
                        videoId: videoId,
                        url: url,
                        itag: itag,
                        kbps: bitrate / 1000,
                        mimeType: mime,
                        clientName: clientName,
                        mediaHeaders: [:]
                    )
                }
            }
        }

        // 3. Fallback to Muxed mp4 (contains audio)
        for f in all {
            let itag = f["itag"] as? Int ?? 0
            let mime = (f["mimeType"] as? String)?.lowercased() ?? ""
            let bitrate = (f["bitrate"] as? Int) ?? 128000
            if mime.contains("video/mp4") {
                if let urlStr = f["url"] as? String, let url = URL(string: urlStr) {
                    return BitChordResolvedStream(
                        videoId: videoId,
                        url: url,
                        itag: itag,
                        kbps: bitrate / 1000,
                        mimeType: mime,
                        clientName: clientName,
                        mediaHeaders: [:]
                    )
                }
            }
        }

        return nil
    }

    // MARK: - Streaming Playback

    public func playTrack(track: YouTubeTrack) async -> Bool {
        activeStreamingId = track.id
        lastErrorMessage = nil

        // If local file exists, play it immediately
        if let localFile = getLocalAudioFile(videoId: track.id) {
            let localTrack = Track(
                id: "yt_\(track.id)",
                title: track.title,
                artist: track.author,
                album: "MinchionePlay Downloads",
                path: localFile.path,
                duration: track.durationSeconds,
                artworkPath: track.thumbnailUrl,
                dateAdded: Date()
            )
            await MainActor.run {
                AudioPlayerService.shared.play(track: localTrack, from: [localTrack])
                self.activeStreamingId = nil
            }
            return true
        }

        // Resolve stream
        guard let resolved = await resolveStream(videoId: track.id) else {
            await MainActor.run {
                self.activeStreamingId = nil
                self.lastErrorMessage = "Impossibile ottenere lo stream audio per \"\(track.title)\"."
            }
            return false
        }

        let onlineTrack = Track(
            id: "yt_\(track.id)",
            title: track.title,
            artist: track.author,
            album: "YouTube Music",
            path: resolved.url.absoluteString,
            duration: track.durationSeconds,
            artworkPath: track.thumbnailUrl,
            dateAdded: Date()
        )

        await MainActor.run {
            AudioPlayerService.shared.play(track: onlineTrack, from: [onlineTrack])
            self.activeStreamingId = nil
        }
        return true
    }

    // MARK: - Downloading

    public func downloadTrack(track: YouTubeTrack) async -> URL? {
        let cleanId = track.id.replacingOccurrences(of: "yt_", with: "")

        // Check if already downloaded
        if let existing = getLocalAudioFile(videoId: cleanId) {
            await MainActor.run {
                self.downloadedVideoIds.insert(cleanId)
            }
            return existing
        }

        guard let resolved = await resolveStream(videoId: cleanId) else {
            await MainActor.run {
                self.lastErrorMessage = "Risoluzione stream fallita per il download."
            }
            return nil
        }

        let safeName = track.title.replacingOccurrences(of: "[^a-zA-Z0-9_-]", with: "_", options: .regularExpression)
        let destination = LibraryService.shared.musicDirectory.appendingPathComponent("\(safeName)_\(cleanId).m4a")

        await MainActor.run {
            self.downloadingProgress[cleanId] = 0.05
        }

        return await withCheckedContinuation { continuation in
            downloadContinuations[cleanId] = continuation

            var request = URLRequest(url: resolved.url)
            for (k, v) in resolved.mediaHeaders {
                request.setValue(v, forHTTPHeaderField: k)
            }

            let task = downloadSession.downloadTask(with: request)
            downloadTasks[task] = cleanId
            task.resume()
        }
    }

    // URLSessionDownloadDelegate implementation
    public func urlSession(_ session: URLSession, downloadTask: URLSessionDownloadTask, didWriteData bytesWritten: Int64, totalBytesWritten: Int64, totalBytesExpectedToWrite: Int64) {
        guard let cleanId = downloadTasks[downloadTask] else { return }
        if totalBytesExpectedToWrite > 0 {
            let progress = Double(totalBytesWritten) / Double(totalBytesExpectedToWrite)
            DispatchQueue.main.async {
                self.downloadingProgress[cleanId] = progress
            }
        }
    }

    public func urlSession(_ session: URLSession, downloadTask: URLSessionDownloadTask, didFinishDownloadingTo location: URL) {
        guard let cleanId = downloadTasks[downloadTask] else { return }
        let musicDir = LibraryService.shared.musicDirectory
        let targetURL = musicDir.appendingPathComponent("track_\(cleanId).m4a")

        try? FileManager.default.removeItem(at: targetURL)
        do {
            try FileManager.default.moveItem(at: location, to: targetURL)
            DispatchQueue.main.async {
                self.downloadingProgress.removeValue(forKey: cleanId)
                self.downloadedVideoIds.insert(cleanId)
                Task {
                    await LibraryService.shared.scanLibrary()
                }
                if let cont = self.downloadContinuations.removeValue(forKey: cleanId) {
                    cont.resume(returning: targetURL)
                }
            }
        } catch {
            DispatchQueue.main.async {
                self.downloadingProgress.removeValue(forKey: cleanId)
                if let cont = self.downloadContinuations.removeValue(forKey: cleanId) {
                    cont.resume(returning: nil)
                }
            }
        }
    }

    public func urlSession(_ session: URLSession, task: URLSessionTask, didCompleteWithError error: Error?) {
        guard let downloadTask = task as? URLSessionDownloadTask,
              let cleanId = downloadTasks.removeValue(forKey: downloadTask) else { return }

        DispatchQueue.main.async {
            self.downloadingProgress.removeValue(forKey: cleanId)
            if let error = error {
                self.lastErrorMessage = "Download interrotto: \(error.localizedDescription)"
                if let cont = self.downloadContinuations.removeValue(forKey: cleanId) {
                    cont.resume(returning: nil)
                }
            }
        }
    }
}
