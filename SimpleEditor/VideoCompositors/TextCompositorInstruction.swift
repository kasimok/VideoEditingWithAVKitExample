//
//  TextCompositorInstruction.swift
//  SimpleEditor
//
//  Created by 0x67 on 2025-11-22.
//
import AVKit


/// A Full screen text compositing instruction
class TextCompositorInstruction: NSObject, AVVideoCompositionInstructionProtocol {
    var timeRange: CMTimeRange = .zero
    var enablePostProcessing: Bool = false
    var containsTweening: Bool = false
    var requiredSourceTrackIDs: [NSValue]?
    var passthroughTrackID: CMPersistentTrackID = kCMPersistentTrackID_Invalid
    
    var text: String
    var fontSize: CGFloat
    var textColor: CIColor
    
    var cachedTextImage: CIImage?
    
    init(text: String, fontSize: CGFloat = 48, textColor: CIColor = CIColor(red: 1, green: 1, blue: 1, alpha: 1)) {
        self.text = text
        self.fontSize = fontSize
        self.textColor = textColor
    }
    
    func buildTextImage(size: CGSize) -> CIImage {
        let attributes: [NSAttributedString.Key: Any] = [
            .font: NSFont.systemFont(ofSize: fontSize),
            .foregroundColor: NSColor(ciColor: textColor)
        ]
        
        let attributed = NSAttributedString(string: text, attributes: attributes)
        
        // draw text into logical-size NSImage
        let nsImage = NSImage(size: CGSize(width: size.width / 2, height: size.height / 2))
        nsImage.lockFocus()
        NSColor.clear.set()
        NSRect(origin: .zero, size: CGSize(width: size.width / 2, height: size.height / 2)).fill()
        attributed.draw(at: CGPoint(x: size.width / 4, y: size.height / 4))
        nsImage.unlockFocus()
        
        let tiffData = nsImage.tiffRepresentation
        let bitmapRep = NSBitmapImageRep(data: tiffData!)
        let baseTextImage = CIImage(bitmapImageRep: bitmapRep!)
        return baseTextImage!
    }
}
