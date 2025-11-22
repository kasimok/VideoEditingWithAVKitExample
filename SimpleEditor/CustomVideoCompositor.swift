//
//  CustomVideoCompositor.swift
//  SimpleEditor
//
//  Created by 0x67 on 2025-11-22.
//
import AVKit

/// VideoCompositor or renderer.
class CustomVideoCompositor: NSObject, AVVideoCompositing {
    
    private let renderQueue = DispatchQueue(label: "compositor.render", qos: .userInteractive)
    
    var sourcePixelBufferAttributes: [String : Any]? {
        return [
            kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA,
            kCVPixelBufferMetalCompatibilityKey as String: true
        ]
    }
    
    var requiredPixelBufferAttributesForRenderContext: [String : Any] {
        return [
            kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA,
            kCVPixelBufferMetalCompatibilityKey as String: true
        ]
    }
    
    func renderContextChanged(_ newRenderContext: AVVideoCompositionRenderContext) {
        
    }
    
    private let ciContext = CIContext(options: nil)
    
    func startRequest(_ request: AVAsynchronousVideoCompositionRequest) {
        print("🎬 startRequest called at time: \(CMTimeGetSeconds(request.compositionTime))")
        
        renderQueue.async { [weak self] in
            guard let self = self else {
                request.finish(with: self?.makeError("Compositor deallocated") ?? NSError())
                return
            }
            
            // Get the instruction (could be any type but passthrough) 
            let instruction = request.videoCompositionInstruction
            
            // Think of it as a new canvas for us to draw.
            guard let dstPixelBuffer = request.renderContext.newPixelBuffer() else {
                request.finish(with: self.makeError("Failed to create output buffer"))
                return
            }
            
            // Assume Single main track - get the first required source track
            guard let trackIDNumber = instruction.requiredSourceTrackIDs?.first as? NSNumber else {
                // No source tracks - render blank frame or handle error
                print("⚠️ No source track IDs in instruction")
                request.finish(with: self.makeError("instruction's main track ID is missing"))
                return
            }
            let trackID = CMPersistentTrackID(truncatingIfNeeded: trackIDNumber.int32Value)
            
            guard let srcPixelBuffer = request.sourceFrame(byTrackID: trackID) else {
                request.finish(with: self.makeError("unable to read frame from main track"))
                return
            }
            
            let renderContext = request.renderContext
            let scale = CGFloat(renderContext.renderScale)
            
            // Logical composition size (AVMutableVideoComposition.renderSize)
            let canvasSize = CGSize(
                width: renderContext.size.width / scale,
                height: renderContext.size.height / scale
            )
            
            // Start with the source image
            let srcImage = CIImage(cvPixelBuffer: srcPixelBuffer)
            var finalImage = srcImage
            
            // Check if this is a TextCompositorInstruction and composite text if so
            if let textInstruction = instruction as? TextCompositorInstruction {
                print("✅ Got TextCompositorInstruction with text: '\(textInstruction.text)'")
                
                // Build or use cached text image
                if textInstruction.cachedTextImage == nil {
                    textInstruction.cachedTextImage = textInstruction.buildTextImage(size: canvasSize)
                }
                
                if let textImage = textInstruction.cachedTextImage {
                    // Composite text over source video
                    finalImage = textImage.composited(over: srcImage)
                }
            }
            
            // Render the final image into the destination pixel buffer
            let pixelBounds = CGRect(origin: .zero, size: renderContext.size)
            
            self.ciContext.render(
                finalImage,
                to: dstPixelBuffer,
                bounds: pixelBounds,
                colorSpace: CGColorSpaceCreateDeviceRGB()
            )
            
            // Finish the request
            request.finish(withComposedVideoFrame: dstPixelBuffer)
        }
    }
    
    func cancelAllPendingVideoCompositionRequests() {
        renderQueue.sync(flags: .barrier) {}
    }
    
    
    private func makeError(_ message: String) -> NSError {
        return NSError(
            domain: "CustomVideoCompositor",
            code: -1,
            userInfo: [NSLocalizedDescriptionKey: message]
        )
    }
}
