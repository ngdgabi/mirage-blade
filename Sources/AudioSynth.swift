import Foundation
import AVFoundation

enum MusicTrack: Int {
    case palaceOverture = 0
    case dungeonAmbient = 1
    case scimitarDuel   = 2
    case mirrorMystique = 3
    case vizierShowdown = 4
    case victoryFanfare = 5
}

enum SoundEffect: Int {
    case footstep = 0
    case jump
    case ledgeGrab
    case swordDraw
    case swordSlash
    case swordParry
    case swordHit
    case chopperSnap
    case spikeSpring
    case gateTick
    case looseSlabCrash
    case potionChime
    case mirrorShimmer
    case menuSelect
}

private struct ActiveSFX {
    var kind: SoundEffect
    var elapsed: Double = 0
    var duration: Double
    var phase: Double = 0
}

final class AudioSynth: @unchecked Sendable {
    static let shared = AudioSynth()

    private let lock = NSLock()
    private var engine: AVAudioEngine?
    private var sourceNode: AVAudioSourceNode?
    private var sampleRate: Double = 44100.0

    private var currentTrack: MusicTrack = .palaceOverture
    private var chipMode: AudioChipMode = .modernSynth
    private var masterVolume: Float = 0.85
    private var isPausedFlag: Bool = false

    private var songTime: Double = 0
    private var leadPhase: Double = 0
    private var harmPhase: Double = 0
    private var bassPhase: Double = 0
    private var lfsr: UInt16 = 0xACE1
    private var activeSFX: [ActiveSFX] = []

    // D Hijaz (Phrygian Dominant) frequencies in Hz: D4, Eb4, F#4, G4, A4, Bb4, C5, D5, Eb5, F#5, G5, A5
    private let hijaz: [Double] = [
        293.66, 311.13, 369.99, 392.00, 440.00, 466.16, 523.25, 587.33, 622.25, 739.99, 783.99, 880.00
    ]

    private let melodies: [[Int]] = [
        // 0: Palace Overture (Heroic Arabian Nights fanfare)
        [0, 2, 3, 4, 5, 4, 3, 2,  3, 4, 7, 5, 4, -1, 2, 3,  4, 7, 8, 7, 5, 4, 3, 2,  1, 2, 3, 1, 0, -1, 0, -1],
        // 1: Dungeon Ambient (Suspenseful torchlit stealth motif)
        [0, -1, 1, -1, 2, 3, 2, -1,  0, -1, -1, 1, 0, -1, -1, -1,  4, -1, 5, 4, 3, -1, 2, -1,  1, -1, 2, 1, 0, -1, -1, -1],
        // 2: Scimitar Duel (Fast urgent fencing pulse)
        [4, 5, 4, 3, 4, 7, 5, 4,  3, 4, 3, 2, 3, 5, 4, 3,  2, 3, 4, 5, 7, 8, 7, 5,  4, 3, 2, 1, 2, 4, 0, -1],
        // 3: Mirror Mystique (Shimmering crystalline arpeggio)
        [7, 4, 2, 0, 8, 5, 3, 1,  9, 7, 4, 2, 7, 5, 4, 2,  10, 7, 5, 3, 9, 7, 4, 2,  7, 4, 2, 1, 0, 2, 4, 7],
        // 4: Vizier Showdown (Dramatic Hourglass climax)
        [7, 7, 8, 7, 9, 7, 5, 4,  7, 7, 10, 9, 8, 7, 5, 4,  3, 4, 5, 7, 8, 9, 10, 9,  7, 5, 4, 3, 2, 1, 0, 4],
        // 5: Victory Fanfare
        [0, 2, 4, 7, 9, 7, 9, 11,  7, -1, 7, 9, 7, -1, -1, -1,  4, 5, 7, 9, 10, 9, 7, 9,  7, -1, 4, -1, 7, -1, -1, -1]
    ]

    private init() {
        startRealtimeEngine()
    }

    private func startRealtimeEngine() {
        let eng = AVAudioEngine()
        let outFmt = eng.outputNode.inputFormat(forBus: 0)
        let sr = outFmt.sampleRate > 8000 ? outFmt.sampleRate : 44100.0
        self.sampleRate = sr

        let format = AVAudioFormat(standardFormatWithSampleRate: sr, channels: 2)!
        let node = AVAudioSourceNode { [weak self] _, _, frameCount, audioBufferList -> OSStatus in
            guard let self = self else { return noErr }
            let abl = UnsafeMutableAudioBufferListPointer(audioBufferList)
            let count = Int(frameCount)
            self.fillBuffers(frameCount: count, sampleRate: sr, leftOut: abl[0].mData?.assumingMemoryBound(to: Float.self), rightOut: abl.count > 1 ? abl[1].mData?.assumingMemoryBound(to: Float.self) : nil)
            return noErr
        }

        eng.attach(node)
        eng.connect(node, to: eng.mainMixerNode, format: format)
        do {
            try eng.start()
            self.engine = eng
            self.sourceNode = node
        } catch {
            // Headless or sandboxed fallback: offline renderer still works 100%
        }
    }

    func stopRealtimeEngineForOfflineRender() {
        lock.lock()
        engine?.stop()
        engine = nil
        sourceNode = nil
        isPausedFlag = false
        lock.unlock()
    }

    func setTrack(_ track: MusicTrack) {
        lock.lock()
        if currentTrack != track {
            currentTrack = track
            songTime = 0
        }
        lock.unlock()
    }

    func setChipMode(_ mode: AudioChipMode) {
        lock.lock()
        chipMode = mode
        lock.unlock()
    }

    func setVolume(_ vol: Float) {
        lock.lock()
        masterVolume = max(0, min(1, vol))
        lock.unlock()
    }

    func setPaused(_ paused: Bool) {
        lock.lock()
        isPausedFlag = paused
        lock.unlock()
    }

    func playSFX(_ sfx: SoundEffect) {
        let dur: Double
        switch sfx {
        case .footstep:       dur = 0.055
        case .jump:           dur = 0.14
        case .ledgeGrab:      dur = 0.09
        case .swordDraw:      dur = 0.28
        case .swordSlash:     dur = 0.13
        case .swordParry:     dur = 0.22
        case .swordHit:       dur = 0.20
        case .chopperSnap:    dur = 0.18
        case .spikeSpring:    dur = 0.20
        case .gateTick:       dur = 0.06
        case .looseSlabCrash: dur = 0.28
        case .potionChime:    dur = 0.42
        case .mirrorShimmer:  dur = 0.50
        case .menuSelect:     dur = 0.11
        }
        lock.lock()
        if activeSFX.count > 8 { activeSFX.removeFirst() }
        activeSFX.append(ActiveSFX(kind: sfx, elapsed: 0, duration: dur, phase: 0))
        lock.unlock()
    }

    func renderOfflineInterleavedInt16(frames: Int, sampleRate sr: Double) -> [Int16] {
        var left = [Float](repeating: 0, count: frames)
        var right = [Float](repeating: 0, count: frames)
        left.withUnsafeMutableBufferPointer { lPtr in
            right.withUnsafeMutableBufferPointer { rPtr in
                fillBuffers(frameCount: frames, sampleRate: sr, leftOut: lPtr.baseAddress, rightOut: rPtr.baseAddress)
            }
        }
        var out = [Int16](repeating: 0, count: frames * 2)
        for i in 0..<frames {
            let l = max(-1.0, min(1.0, left[i]))
            let r = max(-1.0, min(1.0, right[i]))
            out[i * 2]     = Int16(l * 30000.0)
            out[i * 2 + 1] = Int16(r * 30000.0)
        }
        return out
    }

    private func nextNoise() -> Double {
        let bit = ((lfsr >> 0) ^ (lfsr >> 2) ^ (lfsr >> 3) ^ (lfsr >> 5)) & 1
        lfsr = (lfsr >> 1) | (bit << 15)
        return Double(lfsr & 0xFF) / 127.5 - 1.0
    }

    private func fillBuffers(frameCount: Int, sampleRate sr: Double, leftOut: UnsafeMutablePointer<Float>?, rightOut: UnsafeMutablePointer<Float>?) {
        lock.lock()
        defer { lock.unlock() }

        guard !isPausedFlag else {
            for i in 0..<frameCount {
                leftOut?[i] = 0
                rightOut?[i] = 0
            }
            return
        }

        let dt = 1.0 / sr
        let tempo: Double = {
            switch currentTrack {
            case .palaceOverture: return 6.2
            case .dungeonAmbient: return 3.8
            case .scimitarDuel:   return 8.4
            case .mirrorMystique: return 6.8
            case .vizierShowdown: return 9.0
            case .victoryFanfare: return 7.2
            }
        }()
        let mel = melodies[currentTrack.rawValue]
        let vol = Double(masterVolume)

        for i in 0..<frameCount {
            songTime += dt
            let stepFloat = songTime * tempo
            let stepIdx = Int(stepFloat) % mel.count
            let stepFrac = stepFloat - floor(stepFloat)
            let noteIdx = mel[stepIdx]

            var musicL = 0.0
            var musicR = 0.0

            // Lead Oud / AdLib FM voice
            if noteIdx >= 0 && noteIdx < hijaz.count {
                let vibrato = 1.0 + 0.006 * sin(songTime * 34.0)
                let freq = hijaz[noteIdx] * vibrato
                leadPhase += freq * dt
                if leadPhase >= 1.0 { leadPhase -= 1.0 }
                let env = exp(-stepFrac * (currentTrack == .dungeonAmbient ? 2.6 : 4.2))

                if chipMode == .retroAdLib {
                    // OPL2 2-operator FM brass/harpsichord timbre
                    let mod = sin(leadPhase * .pi * 4.0) * 1.65 * env
                    let fm = sin(leadPhase * .pi * 2.0 + mod) * 0.24 * env
                    musicL += fm * 1.05
                    musicR += fm * 0.95
                } else {
                    // Plucked Arabian Oud + warm fifth harmonic
                    let pluck = (sin(leadPhase * .pi * 2.0) * 0.65 + sin(leadPhase * .pi * 4.0) * 0.25 + sin(leadPhase * .pi * 6.0) * 0.10) * env * 0.25
                    musicL += pluck * 1.08
                    musicR += pluck * 0.92
                }
            }

            // Drone / Bass fifth (D2 / A2 pedal)
            let bassRoot = (stepIdx % 8 < 6) ? (hijaz[0] * 0.25) : (hijaz[4] * 0.25)
            bassPhase += bassRoot * dt
            if bassPhase >= 1.0 { bassPhase -= 1.0 }
            let bassEnv = exp(-stepFrac * 3.0)
            let bassSig: Double
            if chipMode == .retroAdLib {
                bassSig = (bassPhase < 0.5 ? 0.15 : -0.15) * bassEnv
            } else {
                bassSig = sin(bassPhase * .pi * 2.0) * 0.18 * (0.45 + 0.55 * bassEnv)
            }
            musicL += bassSig
            musicR += bassSig

            // Shimmering palace harmony pad
            let harmFreq = hijaz[(stepIdx / 4) % 2 == 0 ? 2 : 4] * 0.5
            harmPhase += harmFreq * dt
            if harmPhase >= 1.0 { harmPhase -= 1.0 }
            let pad = sin(harmPhase * .pi * 2.0) * 0.06
            musicL += pad * 0.85
            musicR += pad * 1.15

            // Darbuka goblet drum percussion (DUM - tek - tek - DUM - tek)
            if currentTrack != .dungeonAmbient || stepIdx % 4 == 0 {
                let subBeat = stepIdx % 4
                if stepFrac < 0.18 {
                    let pEnv = exp(-stepFrac * 24.0)
                    if subBeat == 0 {
                        let dum = sin(stepFrac * 420.0) * pEnv * 0.20
                        musicL += dum
                        musicR += dum
                    } else if subBeat == 2 || subBeat == 3 {
                        let tek = nextNoise() * pEnv * 0.07
                        musicL += tek * 0.9
                        musicR += tek * 1.1
                    }
                }
            }

            // Mix active SFX
            var sfxMix = 0.0
            var idx = activeSFX.count - 1
            while idx >= 0 {
                activeSFX[idx].elapsed += dt
                let t = activeSFX[idx].elapsed
                let dur = activeSFX[idx].duration
                if t >= dur {
                    activeSFX.remove(at: idx)
                } else {
                    let p = t / dur
                    let env = 1.0 - p
                    switch activeSFX[idx].kind {
                    case .footstep:
                        sfxMix += nextNoise() * exp(-t * 55.0) * 0.18
                    case .jump:
                        let f = 220.0 + 360.0 * p
                        activeSFX[idx].phase += f * dt
                        sfxMix += sin(activeSFX[idx].phase * .pi * 2.0) * env * 0.22
                    case .ledgeGrab:
                        sfxMix += (sin(t * 780.0) + nextNoise() * 0.5) * exp(-t * 35.0) * 0.22
                    case .swordDraw:
                        let f = 900.0 + 1800.0 * p
                        activeSFX[idx].phase += f * dt
                        sfxMix += (sin(activeSFX[idx].phase * .pi * 2.0) * 0.6 + nextNoise() * 0.4) * env * 0.30
                    case .swordSlash:
                        sfxMix += nextNoise() * sin(p * .pi) * 0.28
                    case .swordParry:
                        let clang = sin(t * 2480.0 * .pi * 2.0) * 0.5 + sin(t * 3710.0 * .pi * 2.0) * 0.4 + nextNoise() * 0.25
                        sfxMix += clang * exp(-t * 16.0) * 0.40
                    case .swordHit:
                        let thud = sin(t * 320.0 * .pi * 2.0) * 0.6 + nextNoise() * 0.4
                        sfxMix += thud * exp(-t * 18.0) * 0.36
                    case .chopperSnap:
                        let snap = sin(t * 1820.0 * .pi * 2.0) * 0.55 + nextNoise() * 0.45
                        sfxMix += snap * exp(-t * 20.0) * 0.38
                    case .spikeSpring:
                        let shing = sin(t * 2150.0 * .pi * 2.0) * 0.65 + nextNoise() * 0.35
                        sfxMix += shing * exp(-t * 17.0) * 0.34
                    case .gateTick:
                        sfxMix += (sin(t * 1150.0 * .pi * 2.0) + nextNoise() * 0.3) * exp(-t * 48.0) * 0.24
                    case .looseSlabCrash:
                        sfxMix += (sin(t * 140.0 * .pi * 2.0) * 0.5 + nextNoise() * 0.6) * exp(-t * 12.0) * 0.36
                    case .potionChime:
                        let notes = [587.33, 739.99, 880.0, 1174.66]
                        let ni = min(3, Int(p * 4.0))
                        activeSFX[idx].phase += notes[ni] * dt
                        sfxMix += sin(activeSFX[idx].phase * .pi * 2.0) * env * 0.30
                    case .mirrorShimmer:
                        let f = 660.0 + sin(t * 38.0) * 180.0 + p * 620.0
                        activeSFX[idx].phase += f * dt
                        sfxMix += sin(activeSFX[idx].phase * .pi * 2.0) * env * 0.28
                    case .menuSelect:
                        let f = p < 0.5 ? 587.33 : 880.0
                        activeSFX[idx].phase += f * dt
                        sfxMix += sin(activeSFX[idx].phase * .pi * 2.0) * env * 0.25
                    }
                }
                idx -= 1
            }

            let outL = Float(max(-0.98, min(0.98, (musicL + sfxMix) * vol)))
            let outR = Float(max(-0.98, min(0.98, (musicR + sfxMix) * vol)))
            leftOut?[i] = outL
            rightOut?[i] = outR
        }
    }
}
