import SwiftUI
import Foundation
import AppKit
import Combine
import AVKit

struct ProjectEditorView: View {
    
    @ObservedObject
    private var renderer: Renderer = Renderer()
    
    @State
    private var player: AVPlayer?
    
    @State
    private var isImporting = false
    
    @State
    private var addTextInstruction = true
    
    /// Initial URL, maybe nil
    var videoURL: URL?
    
    var body: some View {
        VStack(spacing: 20) {
            if let player {
                VideoPlayer(player: player)
                    .frame(height: 400)
                    .onAppear {
                        player.play()
                    }
            } else {
                Rectangle()
                    .fill(Color.gray.opacity(0.3))
                    .frame(height: 400)
                    .overlay(Text("Loading..."))
            }
            HStack {
                Button("Import your video") {
                    isImporting = true
                }
                Toggle(isOn: $addTextInstruction) {
                    Label("Add text overlay", systemImage: "character.textbox")
                }.onChange(of: addTextInstruction) { _, newValue in
                    if newValue {
                        renderer.addTextCompositiorInstruction()
                    } else {
                        renderer.removeAllCompositiorInstructions()
                    }
                }
            }
            .padding()
            
            Text("💡 Try importing a 30 second video")
                .font(.caption)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal)
        }
        .task { @MainActor in
            guard let videoURL else { return }
            do {
                try await renderer.addMainVideoTrack(videoURL: videoURL)
                renderer.addTextCompositiorInstruction()
                self.player = AVPlayer(playerItem: renderer.playerItem)
            } catch {
                print("Failed to create renderer:", error)
            }
        }
        .fileImporter(
            isPresented: $isImporting,
            allowedContentTypes: [.movie, .video],
            allowsMultipleSelection: false
        ) { result in
            switch result {
            case .success(let urls):
                guard let url = urls.first else { return }
                Task(priority: .userInitiated) {
                    await handlePickedVideo(url)
                }
            case .failure(let error):
                print("File import error:", error)
            }
        }
    }
    
    private func handlePickedVideo(_ url: URL) async {
        guard url.startAccessingSecurityScopedResource() else {
            print("Failed to access security-scoped resource")
            return
        }
        
        defer {
            url.stopAccessingSecurityScopedResource()
        }
            
        try? await renderer.addMainVideoTrack(videoURL: url)
        
        renderer.forceRefresh()
        // Force the video to re-render by seeking to current time
        if let player = player {
            let currentTime = player.currentTime()
            let wasPlaying = player.rate > 0
            
            await player.seek(to: currentTime, toleranceBefore: .zero, toleranceAfter: .zero)
            
            // Resume playback if it was playing
            if wasPlaying {
                player.play()
            }
            print("✅ UI: Sought to \(CMTimeGetSeconds(currentTime))s to refresh frame")
        }
    }
}
