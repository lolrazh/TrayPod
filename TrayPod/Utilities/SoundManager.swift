import AVFoundation

class SoundManager {
    static let shared = SoundManager()

    private let engine = AVAudioEngine()
    private let playerNode = AVAudioPlayerNode()
    private var clickBuffer: AVAudioPCMBuffer?

    // iPod 5G piezo click parameters (from Rockbox reverse engineering)
    // Real hardware: ~3kHz square wave burst driven by piezo register,
    // period 26-27, waveform 0xF0, frequency 0x5B, duration 4-5ms.
    // Software: sine burst with exponential decay to compensate for
    // missing piezo transducer mechanical filtering.
    private let clickFrequency: Float = 3000.0
    private let clickDuration: Float = 0.004
    private let clickAmplitude: Float = 0.08
    private let decayRate: Float = 1200.0
    private let sampleRate: Double = 44100.0

    private init() {
        setupEngine()
        prerenderClickBuffer()
    }

    private func setupEngine() {
        guard let format = AVAudioFormat(
            standardFormatWithSampleRate: sampleRate,
            channels: 1
        ) else { return }

        engine.attach(playerNode)
        engine.connect(playerNode, to: engine.mainMixerNode, format: format)

        do {
            try engine.start()
            playerNode.play()
        } catch {
            print("SoundManager: Audio engine failed to start: \(error)")
        }
    }

    private func prerenderClickBuffer() {
        let frameCount = AVAudioFrameCount(clickDuration * Float(sampleRate))

        guard let format = AVAudioFormat(
            standardFormatWithSampleRate: sampleRate,
            channels: 1
        ) else { return }

        guard let buffer = AVAudioPCMBuffer(
            pcmFormat: format,
            frameCapacity: frameCount
        ) else { return }

        buffer.frameLength = frameCount
        let data = buffer.floatChannelData![0]

        for i in 0..<Int(frameCount) {
            let t = Float(i) / Float(sampleRate)
            let sine = sinf(2.0 * .pi * clickFrequency * t)
            let envelope = expf(-decayRate * t)
            data[i] = clickAmplitude * sine * envelope
        }

        self.clickBuffer = buffer
    }

    func playClick() {
        guard let buffer = clickBuffer else { return }

        // Restart engine if it was interrupted (e.g. audio route change)
        if !engine.isRunning {
            do {
                try engine.start()
                playerNode.play()
            } catch {
                return
            }
        }

        playerNode.scheduleBuffer(buffer, at: nil, options: [], completionHandler: nil)
    }
}
