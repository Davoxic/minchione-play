import Foundation

public enum AudioQualityTier: String, CaseIterable, Identifiable {
    case lossless = "Lossless FLAC (Hi-Res)"
    case high = "Alta Fedeltà (256 kbps AAC)"
    case standard = "Standard (128 kbps AAC)"
    case dataSaver = "Risparmio Dati (96 kbps)"

    public var id: String { rawValue }
}

public class IntegrationsService: ObservableObject {
    public static let shared = IntegrationsService()

    // Quality preferences from BitChord
    @Published public var wifiQuality: AudioQualityTier = .high
    @Published public var cellularQuality: AudioQualityTier = .standard

    // Last.fm Scrobbler
    @Published public var lastFmEnabled: Bool = false
    @Published public var lastFmUsername: String = ""

    // Discord Rich Presence
    @Published public var discordRpcEnabled: Bool = false
    @Published public var discordWebhookUrl: String = ""

    // Add-on Lossless Source URL
    @Published public var customFlacMirrorUrl: String = ""

    private let defaults = UserDefaults.standard

    private init() {
        if let wifi = defaults.string(forKey: "bitchord_wifi_quality"), let tier = AudioQualityTier(rawValue: wifi) {
            self.wifiQuality = tier
        }
        if let cell = defaults.string(forKey: "bitchord_cellular_quality"), let tier = AudioQualityTier(rawValue: cell) {
            self.cellularQuality = tier
        }
        self.lastFmEnabled = defaults.bool(forKey: "bitchord_lastfm_enabled")
        self.lastFmUsername = defaults.string(forKey: "bitchord_lastfm_user") ?? ""
        self.discordRpcEnabled = defaults.bool(forKey: "bitchord_discord_enabled")
        self.discordWebhookUrl = defaults.string(forKey: "bitchord_discord_webhook") ?? ""
        self.customFlacMirrorUrl = defaults.string(forKey: "bitchord_flac_mirror") ?? ""
    }

    public func saveSettings() {
        defaults.set(wifiQuality.rawValue, forKey: "bitchord_wifi_quality")
        defaults.set(cellularQuality.rawValue, forKey: "bitchord_cellular_quality")
        defaults.set(lastFmEnabled, forKey: "bitchord_lastfm_enabled")
        defaults.set(lastFmUsername, forKey: "bitchord_lastfm_user")
        defaults.set(discordRpcEnabled, forKey: "bitchord_discord_enabled")
        defaults.set(discordWebhookUrl, forKey: "bitchord_discord_webhook")
        defaults.set(customFlacMirrorUrl, forKey: "bitchord_flac_mirror")
    }

    public func notifyTrackChange(track: Track) {
        guard discordRpcEnabled, !discordWebhookUrl.isEmpty, let url = URL(string: discordWebhookUrl) else { return }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        let payload: [String: Any] = [
            "content": "🎶 **In riproduzione su MinchionePlay:** \(track.displayTitle) - \(track.displayArtist)"
        ]
        request.httpBody = try? JSONSerialization.data(withJSONObject: payload)

        Task {
            _ = try? await URLSession.shared.data(for: request)
        }
    }
}
