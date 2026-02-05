import AppKit
import AudioToolbox

class SoundManager {
    static let shared = SoundManager()

    // System sound IDs for click-like sounds
    private let clickSoundID: SystemSoundID = 1104 // Tock sound

    private init() {}

    func playClick() {
        AudioServicesPlaySystemSound(clickSoundID)
    }

    // Alternative click sounds available:
    // 1103 - Tink
    // 1104 - Tock
    // 1105 - Pop
    // 1306 - Typing sound
}
