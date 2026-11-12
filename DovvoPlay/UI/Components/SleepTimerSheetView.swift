import SwiftUI

public struct SleepTimerSheetView: View {
    @ObservedObject private var sleepTimer = SleepTimerService.shared
    @Environment(\.presentationMode) private var presentationMode

    public init() {}

    public var body: some View {
        NavigationView {
            ZStack {
                AppTheme.background.ignoresSafeArea()

                ScrollView {
                    VStack(spacing: 20) {
                        // Header Status Card
                        VStack(spacing: 8) {
                            ZStack {
                                Circle()
                                    .fill(sleepTimer.isRunning ? AppTheme.primary.opacity(0.18) : Color.white.opacity(0.06))
                                    .frame(width: 64, height: 64)
                                Image(systemName: "moon.zzz.fill")
                                    .font(.system(size: 28))
                                    .foregroundColor(sleepTimer.isRunning ? AppTheme.primary : AppTheme.textMuted)
                            }
                            .padding(.top, 10)

                            Text(sleepTimer.isRunning ? "Timer Attivo" : "Timer di Spegnimento")
                                .font(.system(size: 18, weight: .bold))
                                .foregroundColor(AppTheme.textPrimary)

                            if sleepTimer.isRunning {
                                Text(sleepTimer.countdownString)
                                    .font(.system(size: 32, weight: .black, design: .monospaced))
                                    .foregroundColor(AppTheme.primary)
                                    .padding(.vertical, 4)
                            } else {
                                Text("La riproduzione verrà interrotta automaticamente allo scadere del tempo impostato.")
                                    .font(.system(size: 13))
                                    .foregroundColor(AppTheme.textSecondary)
                                    .multilineTextAlignment(.center)
                                    .padding(.horizontal, 24)
                            }
                        }
                        .padding(20)
                        .frame(maxWidth: .infinity)
                        .background(AppTheme.surfaceCard)
                        .cornerRadius(20)
                        .overlay(RoundedRectangle(cornerRadius: 20).stroke(AppTheme.goldBorder, lineWidth: 1))
                        .padding(.horizontal, 20)
                        .padding(.top, 12)

                        // Presets List
                        VStack(spacing: 8) {
                            ForEach(SleepTimerPreset.allCases) { preset in
                                let isSelected = (sleepTimer.currentPreset == preset)

                                Button(action: {
                                    if preset == .off {
                                        sleepTimer.cancel()
                                    } else {
                                        sleepTimer.start(preset: preset)
                                    }
                                }) {
                                    HStack {
                                        Image(systemName: preset == .endOfTrack ? "forward.end.fill" : (preset == .off ? "nosign" : "clock.fill"))
                                            .font(.system(size: 16))
                                            .foregroundColor(isSelected ? AppTheme.primary : AppTheme.textMuted)
                                            .frame(width: 28)

                                        Text(preset.title)
                                            .font(.system(size: 15, weight: isSelected ? .bold : .medium))
                                            .foregroundColor(isSelected ? AppTheme.primary : AppTheme.textPrimary)

                                        Spacer()

                                        if isSelected {
                                            Image(systemName: "checkmark")
                                                .font(.system(size: 14, weight: .bold))
                                                .foregroundColor(AppTheme.primary)
                                        }
                                    }
                                    .padding(16)
                                    .background(isSelected ? AppTheme.primary.opacity(0.12) : AppTheme.surfaceCard)
                                    .cornerRadius(14)
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 14)
                                            .stroke(isSelected ? AppTheme.primary : Color.clear, lineWidth: 1)
                                    )
                                }
                            }
                        }
                        .padding(.horizontal, 20)

                        if sleepTimer.isRunning {
                            Button(action: {
                                sleepTimer.cancel()
                            }) {
                                HStack {
                                    Image(systemName: "stop.circle.fill")
                                    Text("Ferma Timer Subito")
                                }
                                .font(.system(size: 14, weight: .bold))
                                .foregroundColor(.red)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 14)
                                .background(Color.red.opacity(0.12))
                                .cornerRadius(14)
                            }
                            .padding(.horizontal, 20)
                        }

                        Spacer(minLength: 30)
                    }
                }
            }
            .navigationTitle("Timer Sospensione")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Chiudi") {
                        presentationMode.wrappedValue.dismiss()
                    }
                    .foregroundColor(AppTheme.primary)
                }
            }
        }
    }
}
