import SwiftUI
import UIKit

public struct LyricsShareCardView: View {
    @ObservedObject private var lyricsService = LyricsService.shared
    @ObservedObject private var player = AudioPlayerService.shared
    @Environment(\.presentationMode) private var presentationMode

    @State private var selectedLineIds: Set<String> = []

    public init() {}

    public var body: some View {
        NavigationView {
            ZStack {
                AppTheme.background.ignoresSafeArea()

                ScrollView {
                    VStack(spacing: 20) {
                        // Card Preview
                        cardPreview
                            .padding(.top, 16)
                            .padding(.horizontal, 20)

                        Text("Tocca le righe per aggiungerle alla card di condivisione:")
                            .font(.system(size: 13, weight: .medium))
                            .foregroundColor(AppTheme.textSecondary)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.horizontal, 20)

                        // Selectable Lines List
                        VStack(spacing: 8) {
                            ForEach(lyricsService.currentLyrics) { line in
                                let isSelected = selectedLineIds.contains(line.id)
                                Button(action: {
                                    if isSelected {
                                        selectedLineIds.remove(line.id)
                                    } else {
                                        if selectedLineIds.count < 6 {
                                            selectedLineIds.insert(line.id)
                                        }
                                    }
                                }) {
                                    HStack {
                                        Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                                            .foregroundColor(isSelected ? AppTheme.primary : AppTheme.textMuted)

                                        Text(line.text)
                                            .font(.system(size: 14, weight: isSelected ? .bold : .regular))
                                            .foregroundColor(isSelected ? AppTheme.textPrimary : AppTheme.textSecondary)
                                            .multilineTextAlignment(.leading)

                                        Spacer()
                                    }
                                    .padding(12)
                                    .background(isSelected ? AppTheme.primary.opacity(0.12) : AppTheme.surfaceCard)
                                    .cornerRadius(12)
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 12)
                                            .stroke(isSelected ? AppTheme.primary : Color.clear, lineWidth: 1)
                                    )
                                }
                            }
                        }
                        .padding(.horizontal, 20)

                        // Share Action Button
                        Button(action: {
                            shareSelectedLyrics()
                        }) {
                            HStack(spacing: 8) {
                                Image(systemName: "square.and.arrow.up.fill")
                                Text("Condividi Testo")
                            }
                            .font(.system(size: 15, weight: .bold))
                            .foregroundColor(.black)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 14)
                            .background(Capsule().fill(AppTheme.primary))
                        }
                        .padding(.horizontal, 20)
                        .padding(.bottom, 30)
                    }
                }
            }
            .navigationTitle("Condividi Testo")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Chiudi") {
                        presentationMode.wrappedValue.dismiss()
                    }
                    .foregroundColor(AppTheme.primary)
                }
            }
            .onAppear {
                // Pre-select current active line
                if let activeLine = lyricsService.currentLyrics[safe: lyricsService.activeLineIndex] {
                    selectedLineIds.insert(activeLine.id)
                }
            }
        }
    }

    // MARK: - Card Preview
    private var cardPreview: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Header: Artwork + Title + Artist
            HStack(spacing: 12) {
                if let track = player.currentTrack {
                    TrackArtworkView(
                        urlString: track.thumbnailUrl,
                        size: 48,
                        cornerRadius: 10
                    )

                    VStack(alignment: .leading, spacing: 2) {
                        Text(track.displayTitle)
                            .font(.system(size: 15, weight: .bold))
                            .foregroundColor(AppTheme.textPrimary)
                            .lineLimit(1)

                        Text(track.displayArtist)
                            .font(.system(size: 12, weight: .medium))
                            .foregroundColor(AppTheme.primary)
                            .lineLimit(1)
                    }
                }
                Spacer()

                Image(systemName: "quote.opening")
                    .font(.system(size: 24))
                    .foregroundColor(AppTheme.primary.opacity(0.6))
            }

            Divider()
                .background(AppTheme.goldBorder)

            // Selected Lines
            VStack(alignment: .leading, spacing: 8) {
                let chosen = lyricsService.currentLyrics.filter { selectedLineIds.contains($0.id) }
                if chosen.isEmpty {
                    Text("Seleziona almeno una riga del testo per creare la card...")
                        .font(.system(size: 14, style: .italic))
                        .foregroundColor(AppTheme.textMuted)
                } else {
                    ForEach(chosen) { line in
                        Text("“\(line.text)”")
                            .font(.system(size: 16, weight: .semibold, design: .serif))
                            .foregroundColor(AppTheme.textPrimary)
                    }
                }
            }

            HStack {
                Spacer()
                Text("Ascoltato con MinchionePlay")
                    .font(.system(size: 10, weight: .black))
                    .tracking(1)
                    .foregroundColor(AppTheme.textMuted)
            }
        }
        .padding(18)
        .background(AppTheme.surfaceCard)
        .cornerRadius(18)
        .overlay(RoundedRectangle(cornerRadius: 18).stroke(AppTheme.goldBorder, lineWidth: 1.2))
        .shadow(color: AppTheme.primary.opacity(0.15), radius: 16)
    }

    private func shareSelectedLyrics() {
        let chosen = lyricsService.currentLyrics.filter { selectedLineIds.contains($0.id) }
        guard !chosen.isEmpty else { return }

        let trackTitle = player.currentTrack?.displayTitle ?? "Brano"
        let trackArtist = player.currentTrack?.displayArtist ?? "Artista"
        let textLines = chosen.map { "“\($0.text)”" }.joined(separator: "\n")
        let fullShareText = "\(textLines)\n\n— \(trackTitle) (\(trackArtist))\nAscoltato su MinchionePlay"

        let activityVC = UIActivityViewController(activityItems: [fullShareText], applicationActivities: nil)
        if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
           let rootVC = windowScene.windows.first?.rootViewController {
            rootVC.present(activityVC, animated: true, completion: nil)
        }
    }
}

private extension Array {
    subscript(safe index: Int) -> Element? {
        return indices.contains(index) ? self[index] : nil
    }
}
