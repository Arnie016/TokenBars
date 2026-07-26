import AppKit
import AVFoundation
import FluidGradient
import SwiftUI

enum TokenBarTheme {
    static let canvas = Color(red: 0.075, green: 0.078, blue: 0.082)
    static let sidebar = Color(red: 0.055, green: 0.058, blue: 0.062)
    static let panel = Color(red: 0.105, green: 0.109, blue: 0.114)
    static let raised = Color(red: 0.132, green: 0.137, blue: 0.143)
    static let border = Color.white.opacity(0.105)
    static let text = Color(red: 0.93, green: 0.93, blue: 0.91)
    static let secondary = Color(red: 0.62, green: 0.63, blue: 0.62)
    static let green = Color(red: 0.43, green: 0.82, blue: 0.63)
    static let cyan = Color(red: 0.38, green: 0.72, blue: 0.80)
    static let amber = Color(red: 0.91, green: 0.66, blue: 0.35)
    static let coral = Color(red: 0.92, green: 0.47, blue: 0.42)
    static let nightInk = Color(red: 0.024, green: 0.024, blue: 0.047)
    static let nightBlue = Color(red: 0.055, green: 0.063, blue: 0.125)
    static let nightMist = Color(red: 0.49, green: 0.72, blue: 0.85)

    static func accent(for seed: String) -> Color {
        let value = seed.unicodeScalars.reduce(0) { ($0 &* 31) &+ Int($1.value) }
        return [green, cyan, amber, coral][abs(value) % 4]
    }

    static func boardAccent(_ name: String) -> Color {
        switch name.lowercased() {
        case "cyan": cyan
        case "amber": amber
        case "coral": coral
        default: green
        }
    }
}

enum TokenBarFieldMood {
    case signal
    case goodNight
}

struct TokenBarFluidField: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    let primary: Color
    var secondary = TokenBarTheme.amber
    var speed: CGFloat = 0.42
    var intensity = 0.74
    var mood: TokenBarFieldMood = .signal

    private var motionPaused: Bool {
        reduceMotion || ProcessInfo.processInfo.environment["TOKENBAR_DISABLE_MOTION"] == "1"
    }

    var body: some View {
        FluidGradient(
            blobs: blobColors,
            highlights: highlightColors,
            speed: motionPaused ? 0 : speed,
            blur: mood == .goodNight ? 0.92 : 0.8
        )
        .saturation(mood == .goodNight ? 0.74 : 0.82)
        .contrast(mood == .goodNight ? 1.12 : 1.06)
        .opacity(intensity)
        .overlay {
            LinearGradient(
                colors: [
                    (mood == .goodNight ? TokenBarTheme.nightInk : TokenBarTheme.canvas).opacity(0.06),
                    (mood == .goodNight ? TokenBarTheme.nightInk : TokenBarTheme.canvas).opacity(0.32),
                    (mood == .goodNight ? TokenBarTheme.nightInk : TokenBarTheme.canvas).opacity(0.72)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        }
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }

    private var blobColors: [Color] {
        switch mood {
        case .signal:
            [
                TokenBarTheme.canvas,
                primary.opacity(0.96),
                secondary.opacity(0.72),
                TokenBarTheme.raised,
            ]
        case .goodNight:
            [
                TokenBarTheme.nightInk,
                TokenBarTheme.nightBlue,
                primary.opacity(0.62),
                TokenBarTheme.nightMist.opacity(0.40),
                secondary.opacity(0.28),
            ]
        }
    }

    private var highlightColors: [Color] {
        switch mood {
        case .signal:
            [primary.opacity(0.52), secondary.opacity(0.36), Color.white.opacity(0.08)]
        case .goodNight:
            [TokenBarTheme.nightMist.opacity(0.26), primary.opacity(0.24), secondary.opacity(0.16)]
        }
    }
}

@MainActor
enum TokenBarSound {
    enum Cue {
        case enter
        case inspect
        case press
        case release
        case page
        case analysisStart
        case analysisComplete
        case error
    }

    private enum Waveform {
        case sine
        case triangle
        case noise
    }

    private struct Layer {
        let waveform: Waveform
        let frequency: Double
        var glideTo: Double? = nil
        var offset: Double = 0
        let attack: Double
        let decay: Double
        let peak: Double
    }

    private struct Recipe {
        let master: Double
        let layers: [Layer]
    }

    private static let engine = AVAudioEngine()
    private static let synthPlayer = AVAudioPlayerNode()
    private static let format = AVAudioFormat(standardFormatWithSampleRate: 44_100, channels: 1)!
    private static var prepared = false
    private static var cinematicPlayer: AVAudioPlayer?

    static func play(_ cue: Cue) {
        let defaults = UserDefaults.standard
        guard defaults.object(forKey: "tokenbar.sound.enabled") == nil
                || defaults.bool(forKey: "tokenbar.sound.enabled") else {
            return
        }

        prepareIfNeeded()
        guard engine.isRunning else { return }

        let recipe = recipe(for: cue)
        let duration = recipe.layers.map { $0.offset + $0.attack + $0.decay }.max() ?? 0.1
        let frameCount = AVAudioFrameCount(format.sampleRate * duration)
        guard let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: frameCount),
              let channel = buffer.floatChannelData?[0] else {
            return
        }
        buffer.frameLength = frameCount

        for frame in 0..<Int(frameCount) {
            let time = Double(frame) / format.sampleRate
            let mixed = recipe.layers.enumerated().reduce(0.0) { partial, entry in
                let (index, layer) = entry
                let localTime = time - layer.offset
                guard localTime >= 0, localTime <= layer.attack + layer.decay else {
                    return partial
                }

                let envelope: Double
                if localTime < layer.attack {
                    envelope = layer.attack > 0 ? localTime / layer.attack : 1
                } else {
                    envelope = max(0, 1 - ((localTime - layer.attack) / max(layer.decay, 0.001)))
                }
                let easedEnvelope = sin(.pi * min(1, envelope) / 2)
                let progress = min(1, localTime / max(layer.attack + layer.decay, 0.001))
                let endFrequency = layer.glideTo ?? layer.frequency
                let frequency = layer.frequency + ((endFrequency - layer.frequency) * progress)
                let phase = 2 * Double.pi * frequency * localTime
                let sample: Double

                switch layer.waveform {
                case .sine:
                    sample = sin(phase)
                case .triangle:
                    sample = (2 / Double.pi) * asin(sin(phase))
                case .noise:
                    let seed = sin(Double((frame + 1) * (index + 11) * 12_989)) * 43_758.5453
                    sample = ((seed - floor(seed)) * 2) - 1
                }
                return partial + (sample * easedEnvelope * layer.peak)
            }
            channel[frame] = Float(max(-1, min(1, mixed * recipe.master)))
        }

        synthPlayer.stop()
        synthPlayer.scheduleBuffer(buffer)
        synthPlayer.play()

        if defaults.bool(forKey: "tokenbar.cinematicSound.enabled") {
            switch cue {
            case .analysisStart:
                playCinematic(resource: "analysis-start")
            case .analysisComplete:
                playCinematic(resource: "story-ready")
            default:
                break
            }
        }
    }

    private static func prepareIfNeeded() {
        guard !prepared else { return }
        engine.attach(synthPlayer)
        engine.connect(synthPlayer, to: engine.mainMixerNode, format: format)
        engine.mainMixerNode.outputVolume = 0.82
        do {
            try engine.start()
            prepared = true
        } catch {
            prepared = false
        }
    }

    private static func playCinematic(resource: String) {
        guard let url = Bundle.main.url(
            forResource: resource,
            withExtension: "mp3",
            subdirectory: "Sounds"
        ) else {
            return
        }
        do {
            cinematicPlayer = try AVAudioPlayer(contentsOf: url)
            cinematicPlayer?.volume = 0.42
            cinematicPlayer?.prepareToPlay()
            cinematicPlayer?.play()
        } catch {
            cinematicPlayer = nil
        }
    }

    private static func recipe(for cue: Cue) -> Recipe {
        switch cue {
        case .enter:
            Recipe(master: 0.72, layers: [
                Layer(waveform: .sine, frequency: 523.25, attack: 0.008, decay: 0.16, peak: 0.10),
                Layer(waveform: .sine, frequency: 783.99, offset: 0.07, attack: 0.008, decay: 0.22, peak: 0.08),
            ])
        case .inspect:
            Recipe(master: 0.62, layers: [
                Layer(waveform: .sine, frequency: 1_100, glideTo: 560, attack: 0.004, decay: 0.13, peak: 0.08),
            ])
        case .press:
            Recipe(master: 0.38, layers: [
                Layer(waveform: .noise, frequency: 0, attack: 0.001, decay: 0.018, peak: 0.12),
                Layer(waveform: .triangle, frequency: 170, attack: 0.001, decay: 0.025, peak: 0.04),
            ])
        case .release:
            Recipe(master: 0.34, layers: [
                Layer(waveform: .noise, frequency: 0, attack: 0.001, decay: 0.014, peak: 0.09),
                Layer(waveform: .sine, frequency: 2_800, offset: 0.004, attack: 0.001, decay: 0.04, peak: 0.025),
            ])
        case .page:
            Recipe(master: 0.32, layers: [
                Layer(waveform: .noise, frequency: 0, attack: 0.004, decay: 0.055, peak: 0.08),
                Layer(waveform: .sine, frequency: 2_100, offset: 0.045, attack: 0.002, decay: 0.045, peak: 0.025),
            ])
        case .analysisStart:
            Recipe(master: 0.56, layers: [
                Layer(waveform: .noise, frequency: 0, attack: 0.03, decay: 0.14, peak: 0.035),
                Layer(waveform: .sine, frequency: 420, glideTo: 630, attack: 0.025, decay: 0.18, peak: 0.07),
            ])
        case .analysisComplete:
            Recipe(master: 0.56, layers: [
                Layer(waveform: .noise, frequency: 0, attack: 0.001, decay: 0.018, peak: 0.07),
                Layer(waveform: .sine, frequency: 659.25, offset: 0.025, attack: 0.012, decay: 0.20, peak: 0.07),
                Layer(waveform: .sine, frequency: 987.77, offset: 0.025, attack: 0.012, decay: 0.22, peak: 0.05),
            ])
        case .error:
            Recipe(master: 0.48, layers: [
                Layer(waveform: .noise, frequency: 0, attack: 0.001, decay: 0.03, peak: 0.08),
                Layer(waveform: .triangle, frequency: 440, offset: 0.025, attack: 0.004, decay: 0.09, peak: 0.055),
                Layer(waveform: .triangle, frequency: 349.23, offset: 0.10, attack: 0.004, decay: 0.14, peak: 0.05),
            ])
        }
    }
}

@MainActor
enum TokenBarHaptics {
    enum Cue {
        case selection
        case analysisStart
        case success

        var pattern: NSHapticFeedbackManager.FeedbackPattern {
            switch self {
            case .selection: .alignment
            case .analysisStart: .levelChange
            case .success: .generic
            }
        }
    }

    static func perform(_ cue: Cue) {
        let defaults = UserDefaults.standard
        guard defaults.object(forKey: "tokenbar.haptics.enabled") == nil
                || defaults.bool(forKey: "tokenbar.haptics.enabled") else {
            return
        }
        NSHapticFeedbackManager.defaultPerformer.perform(cue.pattern, performanceTime: .now)
    }
}

struct TokenBarPrimaryActionStyle: ButtonStyle {
    let tint: Color

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 13, weight: .semibold))
            .foregroundStyle(TokenBarTheme.canvas)
            .padding(.horizontal, 16)
            .frame(height: 38)
            .background(tint)
            .overlay {
                RoundedRectangle(cornerRadius: 7)
                    .stroke(Color.white.opacity(configuration.isPressed ? 0.08 : 0.20), lineWidth: 1)
            }
            .clipShape(RoundedRectangle(cornerRadius: 7))
            .shadow(
                color: tint.opacity(configuration.isPressed ? 0.08 : 0.25),
                radius: configuration.isPressed ? 2 : 12,
                y: configuration.isPressed ? 1 : 5
            )
            .scaleEffect(configuration.isPressed ? 0.965 : 1)
            .brightness(configuration.isPressed ? -0.08 : 0)
            .animation(
                .spring(response: 0.24, dampingFraction: 0.72),
                value: configuration.isPressed
            )
    }
}

struct TokenBarPanel<Content: View>: View {
    private let content: Content

    init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }

    var body: some View {
        content
            .padding(18)
            .background(TokenBarTheme.panel)
            .overlay {
                RoundedRectangle(cornerRadius: 8)
                    .stroke(TokenBarTheme.border, lineWidth: 1)
            }
            .clipShape(RoundedRectangle(cornerRadius: 8))
    }
}

struct TokenBarPill: View {
    let label: String
    let value: String
    var tint: Color = TokenBarTheme.secondary

    var body: some View {
        HStack(spacing: 7) {
            Circle()
                .fill(tint)
                .frame(width: 6, height: 6)
            Text(label.uppercased())
                .font(.system(size: 10, weight: .semibold))
                .foregroundStyle(TokenBarTheme.secondary)
            Text(value)
                .font(.system(size: 11, weight: .semibold, design: .monospaced))
                .foregroundStyle(TokenBarTheme.text)
        }
        .padding(.horizontal, 10)
        .frame(height: 28)
        .background(TokenBarTheme.raised)
        .clipShape(RoundedRectangle(cornerRadius: 6))
    }
}

struct SectionLabel: View {
    let text: String

    var body: some View {
        Text(text.uppercased())
            .font(.system(size: 10, weight: .bold))
            .tracking(1.1)
            .foregroundStyle(TokenBarTheme.secondary)
    }
}
