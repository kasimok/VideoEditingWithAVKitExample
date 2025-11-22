import SwiftUI
import AppKit
import AVFoundation
import CoreImage
import Combine

@MainActor
class Renderer: ObservableObject {
    
    /// A player item stores a reference to an AVAsset object, which represents the media to play.
    @Published var playerItem: AVPlayerItem
    
    @Published var isLoading = false
    
    /// The video composition
    private let composition: AVMutableComposition
    
    /// The configuration of a video composition
    private var compositionConfiguration: AVVideoComposition.Configuration
    
    private var mainTrackID: CMPersistentTrackID = -1
    private var mainTrackDuration: CMTime = .zero
    
    init() {
        composition = AVMutableComposition()
        compositionConfiguration = AVVideoComposition.Configuration()
        // Setup some render project preferences.
        compositionConfiguration.renderScale = 1.0
        compositionConfiguration.renderSize = CGSize(width: 2880, height: 1800)
        compositionConfiguration.frameDuration = CMTime(value: 1, timescale: 60)
        // Assign our custom compositor class
        compositionConfiguration.customVideoCompositorClass = CustomVideoCompositor.self
        playerItem = AVPlayerItem(asset: composition)
        playerItem.videoComposition = AVVideoComposition(configuration: compositionConfiguration)
    }
    
    /// Make a video as a main video track(Source sample data)
    /// - Parameter videoURL: video url
    /// - Returns: a renderer
    /// - NOTE: this method is reentrant
    func addMainVideoTrack(videoURL: URL) async throws {
        
        let asset = AVURLAsset(url: videoURL)
        let tracks = try await asset.loadTracks(withMediaType: .video)
        
        // Select main video track from asset
        guard let track = tracks.first else {
            throw NSError(domain: "Renderer", code: -2, userInfo: [NSLocalizedDescriptionKey: "No video track found in asset"])
        }

        mainTrackID = track.trackID
        mainTrackDuration = try await asset.load(.duration)
        
        // Invalidate all previous tracks.
        if let previousTrack = composition.track(withTrackID: mainTrackID) {
            composition.removeTrack(previousTrack)
        }
        
        // Adds an empty track to video composition
        guard let videoCompositionTrack = composition.addMutableTrack(
            withMediaType: .video,
            preferredTrackID: mainTrackID
        ) else {
            throw NSError(domain: "Renderer", code: -3, userInfo: [NSLocalizedDescriptionKey: "Failed to add video track to composition"])
        }

        try await videoCompositionTrack.insertTimeRange(
            CMTimeRange(start: .zero, duration: asset.load(.duration)),
            of: track,
            at: .zero
        )

        compositionConfiguration.sourceSampleDataTrackIDs = [track.trackID]
        
        // Add a base passthrough instruction so compositor is always called
        addPassthroughInstruction()
    }
    
    private func addPassthroughInstruction() {
        // Create a simple passthrough instruction that covers the entire video
        let passthroughInstruction = PassthroughCompositorInstruction(trackID: mainTrackID)
        passthroughInstruction.timeRange = CMTimeRange(start: .zero, duration: mainTrackDuration)
        compositionConfiguration.instructions = [passthroughInstruction]
        
        // CRITICAL: Apply the configuration to the player item
        forceRefresh()
    }
    
    func addTextCompositiorInstruction() {
        // CRITICAL: Must remove passthrough instruction!!!
        compositionConfiguration.instructions.removeAll()
        let instruction = TextCompositorInstruction(text: "Hello World", textColor: .green)
        instruction.timeRange = CMTimeRange(start: .zero, duration: mainTrackDuration)
        instruction.requiredSourceTrackIDs = [NSNumber(value: mainTrackID)]
        compositionConfiguration.instructions.append(instruction)
        // CRITICAL: Apply the updated configuration to the player item
        forceRefresh()
    }
    
    func removeAllCompositiorInstructions() {
        // Keep the base instruction, remove only custom ones (like text)
        compositionConfiguration.instructions.removeAll()
        addPassthroughInstruction()
        // CRITICAL: Apply the updated configuration to the player item
        forceRefresh()
    }
    
    
    func forceRefresh() {
        print("🔄 forceRefresh: Creating new video composition with \(compositionConfiguration.instructions.count) instructions")
        playerItem.videoComposition = AVVideoComposition(configuration: compositionConfiguration)
        print("✅ Video composition updated")
    }
    
}
