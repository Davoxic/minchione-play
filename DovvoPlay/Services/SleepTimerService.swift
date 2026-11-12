import Foundation
import Combine
import AVFoundation

public enum SleepTimerPreset: String, CaseIterable, Identifiable {
    case off = "off"
    case min15 = "15m"
    case min30 = "30m"
    case min45 = "45m"
    case min60 = "60m"
    case endOfTrack = "endOfTrack"

    public var id: String { rawValue }

    public var title: String {
        switch self {
        case .off: return "Disattivato"
        case .min15: return "15 Minuti"
        case .min30: return "30 Minuti"
        case .min45: return "45 Minuti"
        case .min60: return "60 Minuti"
        case .endOfTrack: return "Fine del brano corrente"
        }
    }

    public var durationSeconds: Int? {
        switch self {
        case .off: return nil
        case .min15: return 15 * 60
        case .min30: return 30 * 60
        case .min45: return 45 * 60
        case .min60: return 60 * 60
        case .endOfTrack: return nil
        }
    }
}

public class SleepTimerService: ObservableObject {
    public static let shared = SleepTimerService()

    @Published public private(set) var currentPreset: SleepTimerPreset = .off
    @Published public private(set) var remainingSeconds: Int = 0
    @Published public private(set) var isRunning: Bool = false

    private var timer: Timer?

    private init() {}

    public var countdownString: String {
        guard isRunning else { return "Inattivo" }
        if currentPreset == .endOfTrack {
            return "Al termine del brano"
        }
        let mins = remainingSeconds / 60
        let secs = remainingSeconds % 60
        return String(format: "%d:%02d", mins, secs)
    }

    public func start(preset: SleepTimerPreset) {
        cancel()
        currentPreset = preset

        if preset == .off {
            return
        }

        if preset == .endOfTrack {
            isRunning = true
            remainingSeconds = 0
            return
        }

        if let seconds = preset.durationSeconds {
            isRunning = true
            remainingSeconds = seconds

            timer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
                guard let self = self else { return }
                DispatchQueue.main.async {
                    if self.remainingSeconds > 1 {
                        self.remainingSeconds -= 1
                    } else {
                        self.expireTimer()
                    }
                }
            }
        }
    }

    public func cancel() {
        timer?.invalidate()
        timer = nil
        currentPreset = .off
        remainingSeconds = 0
        isRunning = false
    }

    /// Called by AudioPlayerService when a track reaches the end naturally.
    /// Returns true if sleep timer intercepted it and stopped playback.
    public func consumeAfterTrack() -> Bool {
        guard isRunning && currentPreset == .endOfTrack else { return false }
        cancel()
        AudioPlayerService.shared.pause()
        return true
    }

    private func expireTimer() {
        cancel()
        // Smoothly fade volume out
        Task { @MainActor in
            AudioPlayerService.shared.pause()
        }
    }
}
