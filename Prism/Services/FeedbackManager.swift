import AVFoundation
import Combine
import UIKit

enum PrismFeedbackCue: Hashable {
    case tap
    case selection
    case step
    case success
    case tab
}

@MainActor
final class FeedbackManager: ObservableObject {
    @Published private(set) var soundEffectsEnabled: Bool
    @Published private(set) var motionEffectsEnabled: Bool

    private let userDefaults: UserDefaults
    private let soundEffectsKey: String
    private let motionEffectsKey: String
    private let audioEngine = AVAudioEngine()
    private let player = AVAudioPlayerNode()
    private let audioFormat: AVAudioFormat
    private var cueBuffers: [PrismFeedbackCue: AVAudioPCMBuffer] = [:]
    private var lastPlaybackAt: [PrismFeedbackCue: TimeInterval] = [:]
    private let sampleRate = 44_100.0

    private let softImpact = UIImpactFeedbackGenerator(style: .soft)
    private let rigidImpact = UIImpactFeedbackGenerator(style: .rigid)
    private let selectionFeedback = UISelectionFeedbackGenerator()
    private let notificationFeedback = UINotificationFeedbackGenerator()

    init(
        userDefaults: UserDefaults = .standard,
        soundEffectsKey: String = "orbit.feedback.sounds.enabled",
        motionEffectsKey: String = "orbit.feedback.motion.enabled"
    ) {
        self.userDefaults = userDefaults
        self.soundEffectsKey = soundEffectsKey
        self.motionEffectsKey = motionEffectsKey
        self.soundEffectsEnabled = userDefaults.object(forKey: soundEffectsKey) as? Bool ?? true
        self.motionEffectsEnabled = userDefaults.object(forKey: motionEffectsKey) as? Bool ?? true
        self.audioFormat = AVAudioFormat(standardFormatWithSampleRate: sampleRate, channels: 1)!

        audioEngine.attach(player)
        audioEngine.connect(player, to: audioEngine.mainMixerNode, format: audioFormat)
        audioEngine.mainMixerNode.outputVolume = 0.16

        cueBuffers = [
            .tap: makeBuffer(notes: [
                ToneNote(frequency: 520, duration: 0.04, volume: 0.08, pitchBend: 18)
            ]),
            .selection: makeBuffer(notes: [
                ToneNote(frequency: 460, duration: 0.045, volume: 0.08, pitchBend: 10)
            ]),
            .step: makeBuffer(notes: [
                ToneNote(frequency: 500, duration: 0.03, volume: 0.05, pitchBend: 6)
            ]),
            .success: makeBuffer(notes: [
                ToneNote(frequency: 470, duration: 0.05, volume: 0.08, pitchBend: 6, trailingSilence: 0.015),
                ToneNote(frequency: 620, duration: 0.055, volume: 0.09, pitchBend: -4)
            ]),
            .tab: makeBuffer(notes: [
                ToneNote(frequency: 400, duration: 0.04, volume: 0.07, pitchBend: 6, trailingSilence: 0.01),
                ToneNote(frequency: 520, duration: 0.04, volume: 0.06, pitchBend: 4)
            ])
        ]

        prepareGenerators()
    }

    func setSoundEffectsEnabled(_ isEnabled: Bool) {
        soundEffectsEnabled = isEnabled
        userDefaults.set(isEnabled, forKey: soundEffectsKey)
    }

    func setMotionEffectsEnabled(_ isEnabled: Bool) {
        motionEffectsEnabled = isEnabled
        userDefaults.set(isEnabled, forKey: motionEffectsKey)
    }

    func perform(_ cue: PrismFeedbackCue) {
        triggerHaptic(for: cue)
        playSound(for: cue)
    }

    private func playSound(for cue: PrismFeedbackCue) {
        guard soundEffectsEnabled else { return }
        guard shouldPlay(cue) else { return }
        guard let buffer = cueBuffers[cue] else { return }

        do {
            try ensureAudioReady()
            player.scheduleBuffer(buffer, at: nil, options: .interrupts)
            if !player.isPlaying {
                player.play()
            }
            lastPlaybackAt[cue] = Date().timeIntervalSinceReferenceDate
        } catch {
            assertionFailure("Failed playing Prism feedback sound: \(error)")
        }
    }

    private func shouldPlay(_ cue: PrismFeedbackCue) -> Bool {
        let now = Date().timeIntervalSinceReferenceDate
        let minimumSpacing: TimeInterval

        switch cue {
        case .step:
            minimumSpacing = 0.05
        case .tap, .selection:
            minimumSpacing = 0.08
        case .tab:
            minimumSpacing = 0.12
        case .success:
            minimumSpacing = 0.2
        }

        guard let lastPlayback = lastPlaybackAt[cue] else { return true }
        return now - lastPlayback >= minimumSpacing
    }

    private func triggerHaptic(for cue: PrismFeedbackCue) {
        switch cue {
        case .tap:
            softImpact.impactOccurred(intensity: 0.7)
            softImpact.prepare()
        case .selection, .step, .tab:
            selectionFeedback.selectionChanged()
            selectionFeedback.prepare()
        case .success:
            notificationFeedback.notificationOccurred(.success)
            notificationFeedback.prepare()
            rigidImpact.prepare()
        }
    }

    private func prepareGenerators() {
        softImpact.prepare()
        rigidImpact.prepare()
        selectionFeedback.prepare()
        notificationFeedback.prepare()
    }

    private func ensureAudioReady() throws {
        let session = AVAudioSession.sharedInstance()
        try session.setCategory(.ambient, options: [.mixWithOthers])
        try session.setActive(true, options: [])

        guard !audioEngine.isRunning else { return }
        try audioEngine.start()
    }

    private func makeBuffer(notes: [ToneNote]) -> AVAudioPCMBuffer {
        let totalFrameCount = max(
            1,
            notes.reduce(0) { partialResult, note in
                partialResult + Int((note.duration + note.trailingSilence) * sampleRate)
            }
        )

        let buffer = AVAudioPCMBuffer(
            pcmFormat: audioFormat,
            frameCapacity: AVAudioFrameCount(totalFrameCount)
        )!
        buffer.frameLength = AVAudioFrameCount(totalFrameCount)

        guard let channel = buffer.floatChannelData?.pointee else {
            return buffer
        }

        var cursor = 0

        for note in notes {
            let toneFrameCount = Int(note.duration * sampleRate)
            let trailingFrameCount = Int(note.trailingSilence * sampleRate)
            let attackFrameCount = max(1, Int(0.012 * sampleRate))
            let releaseFrameCount = max(1, Int(0.055 * sampleRate))

            for frame in 0..<toneFrameCount {
                let progress = Double(frame) / Double(max(1, toneFrameCount - 1))
                let currentFrequency = note.frequency + (note.pitchBend * (1.0 - progress))
                let time = Double(frame) / sampleRate

                let attack = min(1.0, Double(frame) / Double(attackFrameCount))
                let framesRemaining = toneFrameCount - frame
                let release = min(1.0, Double(framesRemaining) / Double(releaseFrameCount))
                let envelope = pow(max(0.0, attack * release), 0.7)

                let fundamental = sin(2.0 * .pi * currentFrequency * time)
                let overtone = 0.1 * sin(2.0 * .pi * currentFrequency * 1.5 * time)
                channel[cursor + frame] = Float((fundamental + overtone) * note.volume * envelope)
            }

            cursor += toneFrameCount

            if trailingFrameCount > 0 {
                for silenceFrame in 0..<trailingFrameCount {
                    channel[cursor + silenceFrame] = 0
                }
                cursor += trailingFrameCount
            }
        }

        return buffer
    }
}

private struct ToneNote {
    let frequency: Double
    let duration: Double
    let volume: Double
    var pitchBend: Double = 0
    var trailingSilence: Double = 0
}
