import SwiftUI

public struct LyricsSheetView: View {
    @ObservedObject private var lyricsService = LyricsService.shared
    @ObservedObject private var player = AudioPlayerService.shared
    @Environment(\.presentationMode) private var presentationMode

    @State private var showingShareCard: Bool = false
    @State private var autoScrollEnabled: Bool = true
    @State private var userIsScrolling: Bool = false

    public init() {}

    public var body: some View {
        ZStack {
            // Blurred Artwork Background
            if let track = player.currentTrack {
                TrackArtworkView(
                    urlString: track.thumbnailUrl,
                    size: 800,
                    cornerRadius: 0
                )
                .blur(radius: 65)
                .overlay(Color.black.opacity(0.72))
                .ignoresSafeArea()
            } else {
                AppTheme.background.ignoresSafeArea()
            }

            VStack(spacing: 0) {
                // Header Bar
                headerView
                    .padding(.horizontal, 20)
                    .padding(.top, 14)
                    .padding(.bottom, 10)

                Divider()
                    .background(AppTheme.goldBorder.opacity(0.4))

                // Content
                if lyricsService.isLoading {
                    Spacer()
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle(tint: AppTheme.primary))
                        .scaleEffect(1.3)
                    Text("Ricerca testi sincronizzati...")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(AppTheme.textSecondary)
                        .padding(.top, 12)
                    Spacer()
                } else if lyricsService.hasSyncedLyrics {
                    syncedLyricsScrollView
                } else if let plain = lyricsService.plainLyrics, !plain.isEmpty {
                    plainLyricsScrollView(plain)
                } else {
                    noLyricsView
                }

                // Footer Offset Adjuster Bar
                if lyricsService.hasSyncedLyrics {
                    offsetControlBar
                        .padding(.horizontal, 20)
                        .padding(.vertical, 10)
                        .background(Color.black.opacity(0.4))
                }
            }
        }
        .sheet(isPresented: $showingShareCard) {
            LyricsShareCardView()
        }
    }

    // MARK: - Header
    private var headerView: some View {
        HStack(alignment: .center) {
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 6) {
                    Text("TESTI IN TEMPO REALE")
                        .font(.system(size: 11, weight: .black))
                        .tracking(1.2)
                        .foregroundColor(AppTheme.primary)

                    Text("• \(lyricsService.providerName)")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundColor(AppTheme.textMuted)
                }

                if let track = player.currentTrack {
                    Text(track.displayTitle)
                        .font(.system(size: 15, weight: .bold))
                        .foregroundColor(AppTheme.textPrimary)
                        .lineLimit(1)
                }
            }

            Spacer()

            // Share Card Button
            Button(action: {
                showingShareCard = true
            }) {
                Image(systemName: "square.and.arrow.up")
                    .font(.system(size: 16, weight: .bold))
                    .foregroundColor(AppTheme.textPrimary)
                    .frame(width: 36, height: 36)
                    .background(Circle().fill(Color.white.opacity(0.12)))
            }

            // Close Sheet Button
            Button(action: {
                presentationMode.wrappedValue.dismiss()
            }) {
                Image(systemName: "xmark")
                    .font(.system(size: 15, weight: .bold))
                    .foregroundColor(AppTheme.textPrimary)
                    .frame(width: 36, height: 36)
                    .background(Circle().fill(Color.white.opacity(0.12)))
            }
        }
    }

    // MARK: - Synced Lyrics List
    private var syncedLyricsScrollView: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 22) {
                    Color.clear.frame(height: 20)

                    ForEach(Array(lyricsService.currentLyrics.enumerated()), id: \.element.id) { index, line in
                        let isActive = (index == lyricsService.activeLineIndex)

                        Button(action: {
                            // Tap to seek playback directly
                            player.seek(to: line.timeSeconds)
                            lyricsService.updateActiveLine(currentPlaybackTime: line.timeSeconds)
                        }) {
                            HStack(alignment: .top, spacing: 12) {
                                Text(line.text)
                                    .font(.system(size: isActive ? 26 : 20, weight: isActive ? .black : .semibold, design: .rounded))
                                    .foregroundColor(isActive ? AppTheme.primary : AppTheme.textPrimary.opacity(0.4))
                                    .multilineTextAlignment(.leading)
                                    .scaleEffect(isActive ? 1.03 : 1.0, anchor: .leading)
                                    .animation(.spring(response: 0.35, dampingFraction: 0.75), value: isActive)

                                Spacer()
                            }
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(PlainButtonStyle())
                        .id(index)
                    }

                    Color.clear.frame(height: 120)
                }
                .padding(.horizontal, 24)
            }
            .onChange(of: lyricsService.activeLineIndex) { newIndex in
                if autoScrollEnabled {
                    withAnimation(.easeInOut(duration: 0.45)) {
                        proxy.scrollTo(newIndex, anchor: .center)
                    }
                }
            }
        }
    }

    // MARK: - Plain Lyrics List
    private func plainLyricsScrollView(_ text: String) -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 12) {
                Text(text)
                    .font(.system(size: 18, weight: .medium, design: .rounded))
                    .foregroundColor(AppTheme.textPrimary.opacity(0.85))
                    .lineSpacing(8)
                    .padding(.horizontal, 24)
                    .padding(.top, 24)
                    .padding(.bottom, 60)
            }
        }
    }

    // MARK: - No Lyrics Fallback
    private var noLyricsView: some View {
        VStack(spacing: 12) {
            Spacer()

            Image(systemName: "quote.bubble")
                .font(.system(size: 44))
                .foregroundColor(AppTheme.textMuted)

            Text("Nessun testo trovato")
                .font(.system(size: 18, weight: .bold))
                .foregroundColor(AppTheme.textPrimary)

            Text("Non sono stati trovati testi sincronizzati per questo brano su LRCLIB.")
                .font(.system(size: 13))
                .foregroundColor(AppTheme.textSecondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)

            if let track = player.currentTrack {
                Button(action: {
                    lyricsService.fetchLyrics(for: track)
                }) {
                    HStack(spacing: 6) {
                        Image(systemName: "arrow.clockwise")
                        Text("Riprova Ricerca")
                    }
                    .font(.system(size: 13, weight: .bold))
                    .foregroundColor(.black)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
                    .background(Capsule().fill(AppTheme.primary))
                }
                .padding(.top, 8)
            }

            Spacer()
        }
    }

    // MARK: - Offset Adjustment Bar
    private var offsetControlBar: some View {
        HStack(spacing: 16) {
            Button(action: {
                lyricsService.adjustOffset(by: -0.5)
            }) {
                Text("-0.5s")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundColor(AppTheme.textPrimary)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(Capsule().fill(Color.white.opacity(0.1)))
            }

            Spacer()

            Button(action: {
                lyricsService.resetOffset()
            }) {
                Text(String(format: "Sincro: %+.1fs", lyricsService.offsetSeconds))
                    .font(.system(size: 12, weight: .bold, design: .monospaced))
                    .foregroundColor(lyricsService.offsetSeconds == 0.0 ? AppTheme.textSecondary : AppTheme.primary)
            }

            Spacer()

            Button(action: {
                lyricsService.adjustOffset(by: 0.5)
            }) {
                Text("+0.5s")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundColor(AppTheme.textPrimary)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(Capsule().fill(Color.white.opacity(0.1)))
            }
        }
    }
}
