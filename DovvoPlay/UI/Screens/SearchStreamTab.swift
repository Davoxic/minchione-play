import SwiftUI

public struct SearchStreamTab: View {
    @ObservedObject private var ytService = YouTubeService.shared
    @ObservedObject private var streamService = BitChordStreamService.shared
    @ObservedObject private var player = AudioPlayerService.shared
    @ObservedObject private var lib = LibraryService.shared

    @State private var searchInput: String = ""
    @State private var results: [YouTubeTrack] = []
    @State private var isLoading: Bool = false
    @State private var errorMessage: String? = nil
    @State private var toastMessage: String? = nil

    private let quickSearches = [
        "Top Hits Italia 2026",
        "Rap Italiano",
        "Lo-Fi Chill",
        "Pop Hits",
        "Synthwave",
        "Rock Classico",
        "Trap Italia",
        "Estate 2026"
    ]

    public init() {}

    public var body: some View {
        NavigationView {
            ZStack {
                AppTheme.background.ignoresSafeArea()

                VStack(spacing: 0) {
                    // Search Bar
                    searchBar
                        .padding(.horizontal, 16)
                        .padding(.top, 8)
                        .padding(.bottom, 6)

                    // Quick Search Tags
                    quickSearchTags
                        .padding(.bottom, 8)

                    Divider()
                        .background(AppTheme.goldBorder.opacity(0.6))

                    // Content
                    if isLoading {
                        Spacer()
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle(tint: AppTheme.primary))
                            .scaleEffect(1.3)
                        Text("Ricerca musica in corso...")
                            .font(.system(size: 14, weight: .medium))
                            .foregroundColor(AppTheme.textSecondary)
                            .padding(.top, 12)
                        Spacer()
                    } else if let error = errorMessage {
                        errorStateView(error)
                    } else if results.isEmpty {
                        exploreAndMoodsView
                    } else {
                        resultsList
                    }
                }

                // Toast Notification
                if let toast = toastMessage {
                    VStack {
                        Spacer()
                        Text(toast)
                            .font(.system(size: 13, weight: .bold))
                            .foregroundColor(AppTheme.textPrimary)
                            .padding(.horizontal, 16)
                            .padding(.vertical, 10)
                            .background(
                                Capsule()
                                    .fill(AppTheme.surfaceCard)
                                    .overlay(Capsule().stroke(AppTheme.primary, lineWidth: 1))
                            )
                            .padding(.bottom, 110)
                    }
                    .transition(.move(edge: .bottom).combined(with: .opacity))
                }
            }
            .navigationTitle("Cerca & Stream")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    if !results.isEmpty {
                        Button("Pulisci") {
                            results = []
                            searchInput = ""
                        }
                        .font(.system(size: 13, weight: .medium))
                        .foregroundColor(AppTheme.textMuted)
                    }
                }
            }
        }
        .onAppear {
            streamService.refreshDownloadedSet()
        }
    }

    // MARK: - Search Bar
    private var searchBar: some View {
        HStack(spacing: 10) {
            Image(systemName: "magnifyingglass")
                .foregroundColor(AppTheme.primary)
                .font(.system(size: 17))

            TextField("Cerca brani, artisti o album...", text: $searchInput, onCommit: {
                performSearch(searchInput)
            })
            .font(.system(size: 15))
            .foregroundColor(AppTheme.textPrimary)
            .autocapitalization(.none)
            .disableAutocorrection(true)

            if !searchInput.isEmpty {
                Button(action: {
                    searchInput = ""
                }) {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundColor(AppTheme.textMuted)
                }
            }

            Button(action: {
                performSearch(searchInput)
            }) {
                Text("Cerca")
                    .font(.system(size: 13, weight: .bold))
                    .foregroundColor(.black)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(Capsule().fill(AppTheme.primary))
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .background(AppTheme.surfaceCard)
        .cornerRadius(14)
        .overlay(RoundedRectangle(cornerRadius: 14).stroke(AppTheme.goldBorder, lineWidth: 1))
    }

    // MARK: - Quick Search Tags
    private var quickSearchTags: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(quickSearches, id: \.self) { tag in
                    Button(action: {
                        searchInput = tag
                        performSearch(tag)
                    }) {
                        Text(tag)
                            .font(.system(size: 12, weight: .medium))
                            .foregroundColor(AppTheme.textPrimary)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 6)
                            .background(AppTheme.surfaceCard)
                            .cornerRadius(12)
                            .overlay(RoundedRectangle(cornerRadius: 12).stroke(AppTheme.goldBorder.opacity(0.6), lineWidth: 0.8))
                    }
                }
            }
            .padding(.horizontal, 16)
        }
    }

    // MARK: - Results List
    private var resultsList: some View {
        ScrollView {
            LazyVStack(spacing: 10) {
                // Info header
                HStack {
                    Text("\(results.count) BRANI TROVATI (STREAMING & DOWNLOAD)")
                        .font(.system(size: 10, weight: .black))
                        .tracking(1.2)
                        .foregroundColor(AppTheme.primary)
                    Spacer()
                }
                .padding(.horizontal, 16)
                .padding(.top, 10)

                ForEach(results) { track in
                    trackRow(track)
                }

                Color.clear.frame(height: 120) // space for MiniPlayer
            }
        }
    }

    // MARK: - Single Track Row
    private func trackRow(_ track: YouTubeTrack) -> some View {
        let isCurrentPlaying = (player.currentTrack?.id == "yt_\(track.id)" && player.isPlaying)
        let isDownloaded = streamService.isDownloaded(videoId: track.id)
        let downloadProgress = streamService.downloadingProgress[track.id]
        let isDownloading = downloadProgress != nil

        return HStack(spacing: 12) {
            // Thumbnail with Play overlay
            ZStack {
                TrackArtworkView(
                    urlString: track.thumbnailUrl,
                    size: 54,
                    cornerRadius: 10
                )

                if isCurrentPlaying {
                    Color.black.opacity(0.5)
                        .cornerRadius(10)
                    Image(systemName: "waveform")
                        .font(.system(size: 18, weight: .black))
                        .foregroundColor(AppTheme.primary)
                }
            }
            .frame(width: 54, height: 54)

            // Title & Artist
            VStack(alignment: .leading, spacing: 3) {
                Text(track.title)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(isCurrentPlaying ? AppTheme.primary : AppTheme.textPrimary)
                    .lineLimit(1)

                HStack(spacing: 6) {
                    Text(track.author)
                        .font(.system(size: 12))
                        .foregroundColor(AppTheme.secondary)
                        .lineLimit(1)

                    Text("•")
                        .foregroundColor(AppTheme.textMuted)

                    Text(track.formattedDuration)
                        .font(.system(size: 11, design: .monospaced))
                        .foregroundColor(AppTheme.textMuted)

                    if isDownloaded {
                        HStack(spacing: 2) {
                            Image(systemName: "checkmark.circle.fill")
                                .font(.system(size: 10))
                            Text("Offline")
                                .font(.system(size: 10, weight: .bold))
                        }
                        .foregroundColor(.green)
                    }
                }
            }

            Spacer()

            // Action 1: Instant Streaming Play Button
            Button(action: {
                startStreaming(track)
            }) {
                ZStack {
                    Circle()
                        .fill(isCurrentPlaying ? AppTheme.primary : Color.white.opacity(0.1))
                        .frame(width: 36, height: 36)
                    Image(systemName: isCurrentPlaying ? "pause.fill" : "play.fill")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundColor(isCurrentPlaying ? .black : AppTheme.primary)
                }
            }

            // Action 2: Download Button
            Button(action: {
                startDownload(track)
            }) {
                ZStack {
                    Circle()
                        .fill(isDownloaded ? Color.green.opacity(0.15) : Color.white.opacity(0.08))
                        .frame(width: 36, height: 36)

                    if isDownloading {
                        ProgressView(value: downloadProgress ?? 0.0)
                            .progressViewStyle(CircularProgressViewStyle(tint: AppTheme.primary))
                            .scaleEffect(0.8)
                    } else if isDownloaded {
                        Image(systemName: "arrow.down.circle.fill")
                            .font(.system(size: 18))
                            .foregroundColor(.green)
                    } else {
                        Image(systemName: "arrow.down")
                            .font(.system(size: 14, weight: .bold))
                            .foregroundColor(AppTheme.textPrimary)
                    }
                }
            }
            .disabled(isDownloading)
        }
        .padding(10)
        .background(isCurrentPlaying ? AppTheme.primary.opacity(0.08) : AppTheme.surfaceCard)
        .cornerRadius(14)
        .overlay(
            RoundedRectangle(cornerRadius: 14)
                .stroke(isCurrentPlaying ? AppTheme.primary : AppTheme.goldBorder.opacity(0.6), lineWidth: 1)
        )
        .padding(.horizontal, 16)
        .onTapGesture {
            startStreaming(track)
        }
        .contextMenu {
            Button(action: { startStreaming(track) }) {
                Label("Riproduci Ora (Streaming)", systemImage: "play.fill")
            }
            Button(action: { startDownload(track) }) {
                Label("Scarica per Ascolto Offline", systemImage: "arrow.down.circle")
            }
            Button(action: {
                let t = track.toTrack()
                player.playNext(t)
                showToast("Riproduci come successivo: \(track.title)")
            }) {
                Label("Riproduci Successivo", systemImage: "text.insert")
            }
            Button(action: {
                let t = track.toTrack()
                player.addToQueue(t)
                showToast("Aggiunto alla coda: \(track.title)")
            }) {
                Label("Aggiungi alla Coda", systemImage: "text.append")
            }
        }
    }

    // MARK: - Explore & Moods View
    private var exploreAndMoodsView: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                // Header
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("ESPLORA & MOOD BITCHORD")
                            .font(.system(size: 11, weight: .black))
                            .tracking(1.2)
                            .foregroundColor(AppTheme.primary)
                        Text("Cerca o seleziona un'atmosfera:")
                            .font(.system(size: 16, weight: .bold))
                            .foregroundColor(AppTheme.textPrimary)
                    }
                    Spacer()

                    Button(action: {
                        searchInput = "Top Hits Italia 2026"
                        performSearch("Top Hits Italia 2026")
                    }) {
                        HStack(spacing: 4) {
                            Image(systemName: "flame.fill")
                            Text("Top Charts")
                        }
                        .font(.system(size: 12, weight: .bold))
                        .foregroundColor(.black)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(Capsule().fill(AppTheme.primary))
                    }
                }
                .padding(.horizontal, 16)
                .padding(.top, 14)

                // Moods 2x4 Grid
                let moods: [(emoji: String, name: String, query: String, desc: String)] = [
                    ("🏖️", "Chill & Relax", "Lo-Fi Chill Beats", "Battiti rilassanti"),
                    ("⚡", "Allenamento", "Workout Gym Motivation", "Energia e BPM alti"),
                    ("🧠", "Focus & Studio", "Deep Focus Instrumental", "Concentrazione pura"),
                    ("🎉", "Party & Dance", "Dance Club Party Hits", "Balla senza fine"),
                    ("📻", "Top Hits 2026", "Top Hits Italia 2026", "I più ascoltati oggi"),
                    ("💎", "Trap & Hip-Hop", "Rap Trap Italiano", "Rime, 808 e flow"),
                    ("🎸", "Rock Classics", "Rock Classico Anni 80 90", "Chitarre immortali"),
                    ("🌙", "Notte & Sonno", "Sleep Ambient Calm", "Pace e buonanotte")
                ]

                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                    ForEach(moods, id: \.name) { mood in
                        Button(action: {
                            searchInput = mood.query
                            performSearch(mood.query)
                        }) {
                            HStack(spacing: 12) {
                                Text(mood.emoji)
                                    .font(.system(size: 26))

                                VStack(alignment: .leading, spacing: 2) {
                                    Text(mood.name)
                                        .font(.system(size: 14, weight: .bold))
                                        .foregroundColor(AppTheme.textPrimary)
                                    Text(mood.desc)
                                        .font(.system(size: 11))
                                        .foregroundColor(AppTheme.textMuted)
                                        .lineLimit(1)
                                }
                                Spacer()
                            }
                            .padding(14)
                            .background(AppTheme.surfaceCard)
                            .cornerRadius(14)
                            .overlay(RoundedRectangle(cornerRadius: 14).stroke(AppTheme.goldBorder.opacity(0.8), lineWidth: 1))
                        }
                    }
                }
                .padding(.horizontal, 16)

                // Feature Banner
                VStack(alignment: .leading, spacing: 8) {
                    HStack(spacing: 8) {
                        Image(systemName: "bolt.fill")
                            .foregroundColor(AppTheme.primary)
                        Text("Motore Streaming BitChord Attivo")
                            .font(.system(size: 13, weight: .bold))
                            .foregroundColor(AppTheme.primary)
                    }

                    Text("Risoluzione multi-client visionOS & Android VR senza throttling. Ascolta in streaming immediato o scarica con 1 tocco offline.")
                        .font(.system(size: 12))
                        .foregroundColor(AppTheme.textSecondary)
                        .lineSpacing(3)
                }
                .padding(16)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(AppTheme.primary.opacity(0.08))
                .cornerRadius(16)
                .overlay(RoundedRectangle(cornerRadius: 16).stroke(AppTheme.goldBorder.opacity(0.6), lineWidth: 1))
                .padding(.horizontal, 16)
                .padding(.bottom, 120)
            }
        }
    }

    // MARK: - Error State View
    private func errorStateView(_ error: String) -> some View {
        VStack(spacing: 12) {
            Spacer()
            Image(systemName: "wifi.exclamationmark")
                .font(.system(size: 44))
                .foregroundColor(.orange)

            Text("Errore di Ricerca")
                .font(.system(size: 17, weight: .bold))
                .foregroundColor(AppTheme.textPrimary)

            Text(error)
                .font(.system(size: 13))
                .foregroundColor(AppTheme.textSecondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 30)

            Button(action: {
                performSearch(searchInput)
            }) {
                HStack(spacing: 6) {
                    Image(systemName: "arrow.clockwise")
                    Text("Riprova")
                }
                .font(.system(size: 13, weight: .bold))
                .foregroundColor(.black)
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                .background(Capsule().fill(AppTheme.primary))
            }
            .padding(.top, 8)
            Spacer()
        }
    }

    // MARK: - Actions

    private func performSearch(_ query: String) {
        let q = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !q.isEmpty else { return }

        isLoading = true
        errorMessage = nil

        Task {
            do {
                let list = try await ytService.search(q)
                await MainActor.run {
                    self.results = list
                    self.isLoading = false
                    if list.isEmpty {
                        self.errorMessage = "Nessun brano trovato per \"\(q)\"."
                    }
                }
            } catch {
                await MainActor.run {
                    self.isLoading = false
                    self.errorMessage = "Errore di connessione a YouTube: \(error.localizedDescription)"
                }
            }
        }
    }

    private func startStreaming(_ track: YouTubeTrack) {
        if player.currentTrack?.id == "yt_\(track.id)" {
            player.togglePlayPause()
            return
        }

        showToast("Avvio streaming: \(track.title)")

        Task {
            let success = await streamService.playTrack(track: track)
            if !success {
                if let err = streamService.lastErrorMessage {
                    showToast(err)
                }
            }
        }
    }

    private func startDownload(_ track: YouTubeTrack) {
        showToast("Download avviato: \(track.title)")

        Task {
            let file = await streamService.downloadTrack(track: track)
            if file != nil {
                showToast("✅ Scaricato nella libreria: \(track.title)")
            } else {
                let err = streamService.lastErrorMessage ?? "Errore download."
                showToast(err)
            }
        }
    }

    private func showToast(_ msg: String) {
        withAnimation {
            toastMessage = msg
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 3.0) {
            withAnimation {
                if toastMessage == msg {
                    toastMessage = nil
                }
            }
        }
    }
}
