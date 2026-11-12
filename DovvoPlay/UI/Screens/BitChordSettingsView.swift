import SwiftUI

public struct BitChordSettingsView: View {
    @ObservedObject private var integrations = IntegrationsService.shared
    @ObservedObject private var player = AudioPlayerService.shared
    @Environment(\.presentationMode) private var presentationMode

    public init() {}

    public var body: some View {
        ZStack {
            AppTheme.background.ignoresSafeArea()

            ScrollView {
                VStack(spacing: 20) {
                    // Header Card
                    VStack(alignment: .leading, spacing: 6) {
                        HStack(spacing: 8) {
                            Image(systemName: "bolt.horizontal.circle.fill")
                                .font(.system(size: 20))
                                .foregroundColor(AppTheme.primary)
                            Text("FUNZIONALITÀ BITCHORD INTEGRATE")
                                .font(.system(size: 11, weight: .black))
                                .tracking(1.2)
                                .foregroundColor(AppTheme.primary)
                        }
                        Text("Configura qualità audio lossless, dissolvenza incrociata, scrobbling e presenza Discord.")
                            .font(.system(size: 13))
                            .foregroundColor(AppTheme.textSecondary)
                    }
                    .padding(16)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(AppTheme.surfaceCard)
                    .cornerRadius(16)
                    .overlay(RoundedRectangle(cornerRadius: 16).stroke(AppTheme.goldBorder, lineWidth: 1))
                    .padding(.horizontal, 16)
                    .padding(.top, 10)

                    // Section: Qualità Streaming
                    VStack(alignment: .leading, spacing: 12) {
                        Text("QUALITÀ AUDIO STREAMING")
                            .font(.system(size: 11, weight: .bold))
                            .foregroundColor(AppTheme.primary)
                            .padding(.horizontal, 16)

                        VStack(spacing: 12) {
                            HStack {
                                Text("Qualità Wi-Fi")
                                    .font(.system(size: 14, weight: .medium))
                                    .foregroundColor(AppTheme.textPrimary)
                                Spacer()
                                Picker("Wi-Fi", selection: $integrations.wifiQuality) {
                                    ForEach(AudioQualityTier.allCases) { tier in
                                        Text(tier.rawValue).tag(tier)
                                    }
                                }
                                .pickerStyle(MenuPickerStyle())
                                .tint(AppTheme.primary)
                            }
                            Divider().background(AppTheme.goldBorder.opacity(0.5))
                            HStack {
                                Text("Qualità Dati Cellulari")
                                    .font(.system(size: 14, weight: .medium))
                                    .foregroundColor(AppTheme.textPrimary)
                                Spacer()
                                Picker("Cellulare", selection: $integrations.cellularQuality) {
                                    ForEach(AudioQualityTier.allCases) { tier in
                                        Text(tier.rawValue).tag(tier)
                                    }
                                }
                                .pickerStyle(MenuPickerStyle())
                                .tint(AppTheme.primary)
                            }
                        }
                        .padding(16)
                        .background(AppTheme.surfaceCard)
                        .cornerRadius(16)
                        .overlay(RoundedRectangle(cornerRadius: 16).stroke(AppTheme.goldBorder.opacity(0.7), lineWidth: 1))
                        .padding(.horizontal, 16)
                    }

                    // Section: Crossfade & DSP
                    VStack(alignment: .leading, spacing: 12) {
                        Text("DISSOLVENZA & DSP AUDIO")
                            .font(.system(size: 11, weight: .bold))
                            .foregroundColor(AppTheme.primary)
                            .padding(.horizontal, 16)

                        VStack(spacing: 14) {
                            HStack {
                                VStack(alignment: .leading, spacing: 2) {
                                    Text("Dissolvenza Incrociata (Crossfade)")
                                        .font(.system(size: 14, weight: .medium))
                                        .foregroundColor(AppTheme.textPrimary)
                                    Text(player.crossfadeSeconds > 0 ? "\(Int(player.crossfadeSeconds)) secondi tra i brani" : "Disattivata")
                                        .font(.system(size: 11))
                                        .foregroundColor(AppTheme.textMuted)
                                }
                                Spacer()
                                Picker("Crossfade", selection: $player.crossfadeSeconds) {
                                    Text("Off (0s)").tag(0.0)
                                    Text("3 Secondi").tag(3.0)
                                    Text("5 Secondi").tag(5.0)
                                    Text("8 Secondi").tag(8.0)
                                    Text("12 Secondi").tag(12.0)
                                }
                                .pickerStyle(MenuPickerStyle())
                                .tint(AppTheme.primary)
                            }

                            Divider().background(AppTheme.goldBorder.opacity(0.5))

                            Toggle(isOn: $player.skipSilence) {
                                VStack(alignment: .leading, spacing: 2) {
                                    Text("Salta Silenzio (Skip Silence)")
                                        .font(.system(size: 14, weight: .medium))
                                        .foregroundColor(AppTheme.textPrimary)
                                    Text("Avanza rapidamente oltre i silenzi all'inizio e alla fine")
                                        .font(.system(size: 11))
                                        .foregroundColor(AppTheme.textMuted)
                                }
                            }
                            .tint(AppTheme.primary)
                        }
                        .padding(16)
                        .background(AppTheme.surfaceCard)
                        .cornerRadius(16)
                        .overlay(RoundedRectangle(cornerRadius: 16).stroke(AppTheme.goldBorder.opacity(0.7), lineWidth: 1))
                        .padding(.horizontal, 16)
                    }

                    // Section: Discord & Last.fm
                    VStack(alignment: .leading, spacing: 12) {
                        Text("INTEGRAZIONI SOCIAL (DISCORD & LAST.FM)")
                            .font(.system(size: 11, weight: .bold))
                            .foregroundColor(AppTheme.primary)
                            .padding(.horizontal, 16)

                        VStack(spacing: 14) {
                            Toggle(isOn: $integrations.discordRpcEnabled) {
                                VStack(alignment: .leading, spacing: 2) {
                                    Text("Discord Rich Presence")
                                        .font(.system(size: 14, weight: .medium))
                                        .foregroundColor(AppTheme.textPrimary)
                                    Text("Invia lo stato Now Playing via Webhook Discord")
                                        .font(.system(size: 11))
                                        .foregroundColor(AppTheme.textMuted)
                                }
                            }
                            .tint(AppTheme.primary)

                            if integrations.discordRpcEnabled {
                                TextField("URL Webhook Discord...", text: $integrations.discordWebhookUrl)
                                    .font(.system(size: 12))
                                    .padding(10)
                                    .background(Color.black.opacity(0.4))
                                    .cornerRadius(8)
                                    .overlay(RoundedRectangle(cornerRadius: 8).stroke(AppTheme.goldBorder.opacity(0.5), lineWidth: 1))
                            }

                            Divider().background(AppTheme.goldBorder.opacity(0.5))

                            Toggle(isOn: $integrations.lastFmEnabled) {
                                VStack(alignment: .leading, spacing: 2) {
                                    Text("Scrobbler Last.fm")
                                        .font(.system(size: 14, weight: .medium))
                                        .foregroundColor(AppTheme.textPrimary)
                                    Text("Traccia gli ascolti al 50% di avanzamento del brano")
                                        .font(.system(size: 11))
                                        .foregroundColor(AppTheme.textMuted)
                                }
                            }
                            .tint(AppTheme.primary)

                            if integrations.lastFmEnabled {
                                TextField("Username Last.fm...", text: $integrations.lastFmUsername)
                                    .font(.system(size: 12))
                                    .padding(10)
                                    .background(Color.black.opacity(0.4))
                                    .cornerRadius(8)
                                    .overlay(RoundedRectangle(cornerRadius: 8).stroke(AppTheme.goldBorder.opacity(0.5), lineWidth: 1))
                            }
                        }
                        .padding(16)
                        .background(AppTheme.surfaceCard)
                        .cornerRadius(16)
                        .overlay(RoundedRectangle(cornerRadius: 16).stroke(AppTheme.goldBorder.opacity(0.7), lineWidth: 1))
                        .padding(.horizontal, 16)
                    }

                    // Save Button
                    Button(action: {
                        integrations.saveSettings()
                        presentationMode.wrappedValue.dismiss()
                    }) {
                        Text("Salva Impostazioni BitChord")
                            .font(.system(size: 15, weight: .bold))
                            .foregroundColor(.black)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 14)
                            .background(Capsule().fill(AppTheme.primary))
                    }
                    .padding(.horizontal, 16)
                    .padding(.bottom, 30)
                }
            }
        }
        .navigationTitle("Funzioni BitChord")
        .navigationBarTitleDisplayMode(.inline)
    }
}
