
import SwiftUI

@main
struct SimpleEditorApp: App {
    var body: some Scene {
        WindowGroup {
            if let url = Bundle.main.url(forResource: "output", withExtension: "mp4") {
                ProjectEditorView(videoURL: url)
            }
        }
    }
}
