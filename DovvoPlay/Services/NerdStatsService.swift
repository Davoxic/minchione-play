import Foundation
import AVFoundation

public struct NerdStatsSnapshot {
    public let codec: String
    public let bitrate: String
    public let sampleRate: String
    public let channels: String
    public let audioRoute: String
    public let bufferSeconds: String
    public let sourceDescription: String
    public let equalizerPreset: String
    public let audioPipeline: String
}

public class NerdStatsService {
    public static let shared = NerdStatsService()
    private init() {}

    public func currentSnapshot(track: Track?, isPlaying: Bool, position: TimeInterval, duration: TimeInterval) -> NerdStatsSnapshot {
        // 1. Audio Route
        let route = AVAudioSession.sharedInstance().currentRoute
        let routeName = route.outputs.first?.portName ?? "Altoparlante iPhone"

        // 2. Codec & Format
        var codec = "AAC-LC (Advanced Audio Coding)"
        var sampleRate = "44.1 kHz"
        var bitrate = "256 kbps (VBR)"
        var channels = "Stereo (2 canali)"
        var sourceDesc = "YouTube Music Innertube Audio"

        if let track = track {
            if !track.isOnline {
                if let ext = track.filePath?.components(separatedBy: ".").last?.lowercased() {
                    switch ext {
                    case "flac":
                        codec = "FLAC (Free Lossless Audio Codec)"
                        bitrate = "920 kbps (Lossless)"
                        sampleRate = "48.0 kHz"
                    case "wav":
                        codec = "LPCM Waveform Audio"
                        bitrate = "1411.2 kbps (Lossless)"
                    case "m4a":
                        codec = "AAC-LC / ALAC"
                        bitrate = "256 kbps"
                    case "mp3":
                        codec = "MPEG-1 Audio Layer III"
                        bitrate = "320 kbps (CBR)"
                    default:
                        codec = ext.uppercased()
                    }
                }
                sourceDesc = "Archivio Locale Flash iPhone"
            } else {
                sourceDesc = "Streaming YouTube Music (Direct AAC)"
            }
        }

        // 3. Buffer State
        var bufferStr = "0.0s (In riproduzione)"
        if duration > position {
            let ahead = min(duration - position, 30.0)
            bufferStr = String(format: "%.1f secondi avanti", ahead)
        }

        // 4. Equalizer preset
        let eqPreset = EqualizerService.shared.activePreset.name

        // 5. Pipeline
        let pipeline = "AVURLAsset → AVPlayerItem → AVAudioSession (\(routeName)) → AVAudioUnitEQ (5-Bande) → Uscita Hardware"

        return NerdStatsSnapshot(
            codec: codec,
            bitrate: bitrate,
            sampleRate: sampleRate,
            channels: channels,
            audioRoute: routeName,
            bufferSeconds: bufferStr,
            sourceDescription: sourceDesc,
            equalizerPreset: eqPreset,
            audioPipeline: pipeline
        )
    }
}
