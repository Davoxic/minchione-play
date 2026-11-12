import SwiftUI

public struct NerdStatsSheetView: View {
    @ObservedObject private var player = AudioPlayerService.shared
    @Environment(\.presentationMode) private var presentationMode

    private var snapshot: NerdStatsSnapshot {
        NerdStatsService.shared.currentSnapshot(
            track: player.currentTrack,
            isPlaying: player.isPlaying,
            position: player.position,
            duration: player.duration
        )
    }

    public init() {}

    public var body: some View {
        NavigationView {
            ZStack {
                AppTheme.background.ignoresSafeArea()

                ScrollView {
                    VStack(spacing: 16) {
                        // Title Info
                        HStack(spacing: 10) {
                            Image(systemName: "waveform.badge.magnifyingglass")
                                .font(.system(size: 24))
                                .foregroundColor(AppTheme.primary)
                            VStack(alignment: .leading, spacing: 2) {
                                Text("AUDIO ENGINE TELEMETRY")
                                    .font(.system(size: 11, weight: .black))
                                    .tracking(1.2)
                                    .foregroundColor(AppTheme.primary)
                                Text("Stats for Nerds (BitChord Pipeline)")
                                    .font(.system(size: 14, weight: .bold))
                                    .foregroundColor(AppTheme.textPrimary)
                            }
                            Spacer()
                        }
                        .padding(.horizontal, 20)
                        .padding(.top, 16)

                        // Data Grid
                        VStack(spacing: 10) {
                            metricRow(title: "Formato & Codec", value: snapshot.codec, icon: "doc.badge.gearshape")
                            metricRow(title: "Bitrate Audio", value: snapshot.bitrate, icon: "speedometer")
                            metricRow(title: "Frequenza Campionamento", value: snapshot.sampleRate, icon: "waveform.path.ecg")
                            metricRow(title: "Configurazione Canali", value: snapshot.channels, icon: "speaker.wave.2.fill")
                            metricRow(title: "Uscita Audio Attiva", value: snapshot.audioRoute, icon: "airpodspro")
                            metricRow(title: "Salute Buffer", value: snapshot.bufferSeconds, icon: "memorychip")
                            metricRow(title: "Equalizzatore Hardware", value: snapshot.equalizerPreset, icon: "slider.vertical.3")
                            metricRow(title: "Sorgente Audio", value: snapshot.sourceDescription, icon: "antenna.radiowaves.left.and.right")
                        }
                        .padding(.horizontal, 20)

                        // Full Pipeline Diagram Card
                        VStack(alignment: .leading, spacing: 8) {
                            Text("PIPELINE DI DECODIFICA & ELABORAZIONE")
                                .font(.system(size: 11, weight: .black))
                                .tracking(1)
                                .foregroundColor(AppTheme.primary)

                            Text(snapshot.audioPipeline)
                                .font(.system(size: 12, weight: .medium, design: .monospaced))
                                .foregroundColor(AppTheme.textSecondary)
                                .lineSpacing(4)
                        }
                        .padding(16)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(AppTheme.surfaceCard)
                        .cornerRadius(16)
                        .overlay(RoundedRectangle(cornerRadius: 16).stroke(AppTheme.goldBorder, lineWidth: 1))
                        .padding(.horizontal, 20)
                        .padding(.bottom, 24)
                    }
                }
            }
            .navigationTitle("Statistiche Tecniche")
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

    private func metricRow(title: String, value: String, icon: String) -> some View {
        HStack {
            Image(systemName: icon)
                .font(.system(size: 16))
                .foregroundColor(AppTheme.primary)
                .frame(width: 28)

            Text(title)
                .font(.system(size: 13, weight: .medium))
                .foregroundColor(AppTheme.textSecondary)

            Spacer()

            Text(value)
                .font(.system(size: 13, weight: .bold))
                .foregroundColor(AppTheme.textPrimary)
                .multilineTextAlignment(.trailing)
        }
        .padding(14)
        .background(AppTheme.surfaceCard)
        .cornerRadius(14)
        .overlay(RoundedRectangle(cornerRadius: 14).stroke(AppTheme.goldBorder.opacity(0.6), lineWidth: 0.8))
    }
}
