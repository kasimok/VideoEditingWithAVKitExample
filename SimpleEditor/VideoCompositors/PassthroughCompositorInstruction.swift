//
//  BaseCompositorInstruction.swift
//  SimpleEditor
//
//  Created by AI Assistant on 2025-11-22.
//
import AVKit

/// A passthrough instruction that does not do any custom effects / transitions / overlays in that timeRange.
class PassthroughCompositorInstruction: NSObject, AVVideoCompositionInstructionProtocol {
    var timeRange: CMTimeRange = .zero
    var enablePostProcessing: Bool = false
    var containsTweening: Bool = false
    var requiredSourceTrackIDs: [NSValue]?
    var passthroughTrackID: CMPersistentTrackID = kCMPersistentTrackID_Invalid
    
    init(trackID: CMPersistentTrackID) {
        super.init()
        self.passthroughTrackID = trackID
        self.requiredSourceTrackIDs = [NSNumber(value: trackID)]
    }
}
