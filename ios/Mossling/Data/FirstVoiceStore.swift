import Foundation
import AVFoundation
import Observation
import UIKit

/// Normalized peak envelope and recording duration for a saved baby-voice keepsake.
struct FirstVoiceMeta: Codable, Equatable, Sendable {
    var duration: Double
    var peaks: [Float]
    var createdAt: Double
}

/// Pure, testable waveform extraction & resampling helpers for baby-voice `.m4a` clips.
enum FirstVoiceWaveform {
    static let barCount = 24
    static let maxDuration: Double = 30.0

    /// Resamples raw normalized amplitude samples (`0...1`) into `targetCount` visual bars clamped to `0.08...1.0`.
    static func normalize(_ raw: [Float], targetCount: Int = barCount) -> [Float] {
        let count = max(4, targetCount)
        guard !raw.isEmpty else {
            return Array(repeating: 0.16, count: count)
        }
        let clipped = raw.map { max(0.0, min(1.0, $0.isFinite ? $0 : 0.0)) }
        let peak = max(0.05, clipped.max() ?? 1.0)
        var bins: [Float] = []
        bins.reserveCapacity(count)
        for i in 0..<count {
            let start = (i * clipped.count) / count
            let end = max(start + 1, ((i + 1) * clipped.count) / count)
            let slice = clipped[start..<min(end, clipped.count)]
            let rms = slice.isEmpty ? 0 : slice.max() ?? 0
            let scaled = Float(min(1.0, max(0.08, Double(rms / peak))))
            bins.append(scaled)
        }
        return bins
    }

    /// Reads decoded PCM frames from a local `.m4a`/audio file and produces `(durationSeconds, peaks)`.
    static func extractPeaks(from url: URL, targetCount: Int = barCount) -> (duration: Double, peaks: [Float]) {
        guard let file = try? AVAudioFile(forReading: url) else {
            return (0, normalize([], targetCount: targetCount))
        }
        let sampleRate = max(1.0, file.processingFormat.sampleRate)
        let totalFrames = AVAudioFrameCount(max(0, file.length))
        let duration = Double(file.length) / sampleRate
        guard totalFrames > 0 else {
            return (duration, normalize([], targetCount: targetCount))
        }

        let count = max(4, targetCount)
        let chunkFrames = max(AVAudioFrameCount(512), min(AVAudioFrameCount(8192), totalFrames / AVAudioFrameCount(count)))
        guard let buffer = AVAudioPCMBuffer(pcmFormat: file.processingFormat, frameCapacity: chunkFrames) else {
            return (duration, normalize([], targetCount: count))
        }

        var rawSamples: [Float] = []
        while true {
            do {
                buffer.frameLength = 0
                try file.read(into: buffer)
                if buffer.frameLength == 0 { break }
                guard let channel = buffer.floatChannelData?[0] else { break }
                let len = Int(buffer.frameLength)
                var sumSq: Float = 0
                let stride = max(1, len / 64)
                var samplesUsed = 0
                var idx = 0
                while idx < len {
                    let s = channel[idx]
                    sumSq += s * s
                    samplesUsed += 1
                    idx += stride
                }
                let rms = samplesUsed > 0 ? sqrt(sumSq / Float(samplesUsed)) : 0
                rawSamples.append(min(1.0, rms * 3.2))
            } catch {
                break
            }
        }
        return (duration, normalize(rawSamples, targetCount: count))
    }
}

/// Strictly local, offline `.m4a` voice keepsake store under `Application Support/first_voices/`.
/// Audio recordings never leave the device and are wiped cleanly on `AppModel.clearAll()` or moment deletion.
enum FirstVoiceStore {
    static var folder: URL {
        FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("first_voices", isDirectory: true)
    }

    static func audioURL(for id: UUID, in dir: URL = folder) -> URL {
        dir.appendingPathComponent("\(id.uuidString).m4a")
    }

    static func metaURL(for id: UUID, in dir: URL = folder) -> URL {
        dir.appendingPathComponent("\(id.uuidString).json")
    }

    static func exists(for id: UUID, in dir: URL = folder) -> Bool {
        FileManager.default.fileExists(atPath: audioURL(for: id, in: dir).path)
    }

    static func loadMeta(for id: UUID, in dir: URL = folder) -> FirstVoiceMeta? {
        if let data = try? Data(contentsOf: metaURL(for: id, in: dir)),
           let decoded = try? JSONDecoder().decode(FirstVoiceMeta.self, from: data) {
            return decoded
        }
        let audio = audioURL(for: id, in: dir)
        guard FileManager.default.fileExists(atPath: audio.path) else { return nil }
        let extracted = FirstVoiceWaveform.extractPeaks(from: audio)
        let meta = FirstVoiceMeta(
            duration: max(0.2, extracted.duration),
            peaks: extracted.peaks,
            createdAt: Date().timeIntervalSince1970
        )
        if let encoded = try? JSONEncoder().encode(meta) {
            try? encoded.write(to: metaURL(for: id, in: dir), options: [.atomic, .completeFileProtectionUntilFirstUserAuthentication])
        }
        return meta
    }

    /// Saves a temporary `.m4a` recording into protected local keepsake storage and extracts its waveform envelope.
    @discardableResult
    static func saveRecording(from tempURL: URL, for id: UUID, in dir: URL = folder) -> FirstVoiceMeta? {
        guard let data = try? Data(contentsOf: tempURL), !data.isEmpty else { return nil }
        let extracted = FirstVoiceWaveform.extractPeaks(from: tempURL)
        let meta = FirstVoiceMeta(
            duration: max(0.2, min(FirstVoiceWaveform.maxDuration, extracted.duration)),
            peaks: extracted.peaks,
            createdAt: Date().timeIntervalSince1970
        )
        return saveData(audioData: data, meta: meta, for: id, in: dir)
    }

    /// Saves raw audio bytes and explicit waveform metadata (used both internally and by unit tests).
    @discardableResult
    static func saveSample(
        audioData: Data,
        peaks: [Float],
        duration: Double,
        for id: UUID,
        in dir: URL = folder
    ) -> FirstVoiceMeta? {
        let meta = FirstVoiceMeta(
            duration: max(0.1, duration),
            peaks: FirstVoiceWaveform.normalize(peaks),
            createdAt: Date().timeIntervalSince1970
        )
        return saveData(audioData: audioData, meta: meta, for: id, in: dir)
    }

    private static func saveData(audioData: Data, meta: FirstVoiceMeta, for id: UUID, in dir: URL) -> FirstVoiceMeta? {
        do {
            try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
            let audioTarget = audioURL(for: id, in: dir)
            let metaTarget = metaURL(for: id, in: dir)
            try audioData.write(to: audioTarget, options: [.atomic, .completeFileProtectionUntilFirstUserAuthentication])
            let encoded = try JSONEncoder().encode(meta)
            try encoded.write(to: metaTarget, options: [.atomic, .completeFileProtectionUntilFirstUserAuthentication])
            if dir == folder {
                Task { @MainActor in FirstVoiceVersion.shared.bump() }
            }
            return meta
        } catch {
            return nil
        }
    }

    static func delete(for id: UUID, in dir: URL = folder) {
        try? FileManager.default.removeItem(at: audioURL(for: id, in: dir))
        try? FileManager.default.removeItem(at: metaURL(for: id, in: dir))
        if dir == folder {
            Task { @MainActor in FirstVoiceVersion.shared.bump() }
        }
    }

    static func prune(keeping validIDs: Set<UUID>, in dir: URL = folder) {
        guard let files = try? FileManager.default.contentsOfDirectory(at: dir, includingPropertiesForKeys: nil) else { return }
        for f in files {
            let ext = f.pathExtension.lowercased()
            guard ext == "m4a" || ext == "json" else { continue }
            let stem = f.deletingPathExtension().lastPathComponent
            if let uid = UUID(uuidString: stem), !validIDs.contains(uid) {
                try? FileManager.default.removeItem(at: f)
            }
        }
    }

    static func clearAll(in dir: URL = folder) {
        try? FileManager.default.removeItem(at: dir)
        if dir == folder {
            Task { @MainActor in FirstVoiceVersion.shared.bump() }
        }
    }

    static func count(in firstIDs: [UUID], dir: URL = folder) -> Int {
        firstIDs.filter { exists(for: $0, in: dir) }.count
    }

    static func formatDuration(_ seconds: Double) -> String {
        let clamped = max(1, Int(ceil(seconds)))
        let mins = clamped / 60
        let secs = clamped % 60
        return mins > 0 ? String(format: "%d:%02d", mins, secs) : "\(secs)s"
    }
}

@Observable
@MainActor
final class FirstVoiceVersion {
    static let shared = FirstVoiceVersion()
    private(set) var tick: Int = 0
    func bump() { tick &+= 1 }
}

/// Manages short local `.m4a` recording & waveform playback without leaving the iPhone.
@Observable
@MainActor
final class FirstVoiceController {
    static let shared = FirstVoiceController()

    private(set) var isRecording = false
    private(set) var recordingSeconds: Double = 0
    private(set) var livePeaks: [Float] = []
    private(set) var playingID: UUID?
    private(set) var playProgress: Double = 0
    private(set) var permissionDenied = false
    private(set) var errorMessage: String?
    private(set) var lastAutoStoppedURL: URL?

    private var recorder: AVAudioRecorder?
    private var player: AVAudioPlayer?
    private var timer: Timer?
    private var activeTempURL: URL?
    private var startingRecording = false
    private var recordingGeneration = 0
    private var interruptionObserver: NSObjectProtocol?
    private var routeChangeObserver: NSObjectProtocol?
    private let delegateProxy = FirstVoiceAudioDelegate()

    private init() {
        delegateProxy.onRecordFinish = { [weak self] ok in
            self?.handleRecordingStopped(successfully: ok)
        }
        delegateProxy.onPlayFinish = { [weak self] _ in
            guard let self, self.player != nil else { return }
            self.stopPlayback()
        }
        interruptionObserver = NotificationCenter.default.addObserver(
            forName: AVAudioSession.interruptionNotification,
            object: nil,
            queue: nil
        ) { [weak self] note in
            let typeVal = note.userInfo?[AVAudioSessionInterruptionTypeKey] as? UInt
            Task { @MainActor [weak self] in
                guard let self, let typeVal, let type = AVAudioSession.InterruptionType(rawValue: typeVal), type == .began else { return }
                if self.isRecording {
                    self.handleRecordingStopped(successfully: false)
                } else if self.playingID != nil {
                    self.stopPlayback()
                    self.errorMessage = L10n.t("声音播放被系统中断。", "Audio playback was interrupted.")
                }
            }
        }
        routeChangeObserver = NotificationCenter.default.addObserver(
            forName: AVAudioSession.routeChangeNotification,
            object: nil,
            queue: nil
        ) { [weak self] note in
            let reasonVal = note.userInfo?[AVAudioSessionRouteChangeReasonKey] as? UInt
            Task { @MainActor [weak self] in
                guard let self, let reasonVal,
                      let reason = AVAudioSession.RouteChangeReason(rawValue: reasonVal),
                      reason == .oldDeviceUnavailable,
                      self.playingID != nil else { return }
                self.stopPlayback()
            }
        }
    }

    func refreshPermission() {
        if #available(iOS 17.0, *) {
            permissionDenied = (AVAudioApplication.shared.recordPermission == .denied)
        }
    }

    private func deactivateSessionIfIdle() {
        guard !SoundscapeEngine.shared.hasActiveEngine && !ToyboxAudioEngine.shared.isPlaying else { return }
        try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
    }

    func clearError() {
        errorMessage = nil
    }

    func togglePlay(id: UUID, url: URL) {
        if playingID == id {
            stopPlayback()
            return
        }
        stopAll()
        SoundscapeEngine.shared.stopImmediately(deactivateSession: false)
        ToyboxAudioEngine.shared.stop()
        errorMessage = nil
        do {
            let session = AVAudioSession.sharedInstance()
            try session.setCategory(.playback, mode: .default, options: [])
            try session.setActive(true)
            let audioPlayer = try AVAudioPlayer(contentsOf: url)
            audioPlayer.delegate = delegateProxy
            audioPlayer.prepareToPlay()
            guard audioPlayer.play() else {
                deactivateSessionIfIdle()
                errorMessage = L10n.t("这段声音暂时无法播放。", "Could not play this voice keepsake.")
                return
            }
            player = audioPlayer
            playingID = id
            playProgress = 0
            TactileEngine.shared.beadClick()
            startPlaybackTimer()
        } catch {
            deactivateSessionIfIdle()
            errorMessage = L10n.t("这段声音暂时无法播放。", "Could not play this voice keepsake.")
        }
    }

    func startDraftRecording() async -> URL? {
        guard !startingRecording else { return nil }
        startingRecording = true
        defer { startingRecording = false }

        recordingGeneration &+= 1
        let expectedGen = recordingGeneration

        stopPlayback()
        errorMessage = nil
        permissionDenied = false
        lastAutoStoppedURL = nil

        let granted = await requestMicPermission()
        guard granted else {
            permissionDenied = true
            return nil
        }
        guard recordingGeneration == expectedGen else { return nil }

        SoundscapeEngine.shared.stopImmediately(deactivateSession: false)
        ToyboxAudioEngine.shared.stop()
        discardTemp(activeTempURL)

        let tempURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("voice_draft_\(UUID().uuidString).m4a")
        try? FileManager.default.removeItem(at: tempURL)

        do {
            let session = AVAudioSession.sharedInstance()
            try session.setCategory(.playAndRecord, mode: .default, options: [.defaultToSpeaker])
            try session.setActive(true)
            let settings: [String: Any] = [
                AVFormatIDKey: Int(kAudioFormatMPEG4AAC),
                AVSampleRateKey: 44100.0,
                AVNumberOfChannelsKey: 1,
                AVEncoderAudioQualityKey: AVAudioQuality.high.rawValue
            ]
            let rec = try AVAudioRecorder(url: tempURL, settings: settings)
            rec.delegate = delegateProxy
            rec.isMeteringEnabled = true
            rec.prepareToRecord()
            guard rec.record(forDuration: FirstVoiceWaveform.maxDuration) else {
                deactivateSessionIfIdle()
                errorMessage = L10n.t("未能启动麦克风录音。", "Could not start microphone recording.")
                return nil
            }
            recorder = rec
            activeTempURL = tempURL
            isRecording = true
            recordingSeconds = 0
            livePeaks = []
            if !TactileEngine.shared.quietNight {
                UIImpactFeedbackGenerator(style: .light).impactOccurred()
            }
            startRecordTimer()
            return tempURL
        } catch {
            deactivateSessionIfIdle()
            errorMessage = L10n.t("未能启动麦克风录音。", "Could not start microphone recording.")
            return nil
        }
    }

    func finishDraftRecording() -> URL? {
        recordingGeneration &+= 1
        guard isRecording else { return activeTempURL }
        let url = activeTempURL
        recorder?.delegate = nil
        recorder?.stop()
        recorder = nil
        isRecording = false
        stopTimer()
        deactivateSessionIfIdle()
        return url
    }

    func stopPlayback() {
        let hadPlayer = (player != nil || playingID != nil)
        player?.delegate = nil
        player?.stop()
        player = nil
        playingID = nil
        playProgress = 0
        if !isRecording {
            stopTimer()
            if hadPlayer {
                deactivateSessionIfIdle()
            }
        }
    }

    func stopAll() {
        recordingGeneration &+= 1
        let hadAudio = isRecording || recorder != nil || player != nil || playingID != nil
        recorder?.delegate = nil
        if isRecording {
            recorder?.stop()
            isRecording = false
        }
        recorder = nil
        player?.delegate = nil
        player?.stop()
        player = nil
        playingID = nil
        playProgress = 0
        stopTimer()
        if hadAudio {
            deactivateSessionIfIdle()
        }
    }

    func discardTemp(_ url: URL?) {
        if let url {
            try? FileManager.default.removeItem(at: url)
        }
        if activeTempURL == url {
            activeTempURL = nil
        }
    }

    private func requestMicPermission() async -> Bool {
        if #available(iOS 17.0, *) {
            switch AVAudioApplication.shared.recordPermission {
            case .granted:
                return true
            case .denied:
                return false
            case .undetermined:
                return await withCheckedContinuation { cont in
                    AVAudioApplication.requestRecordPermission { ok in
                        cont.resume(returning: ok)
                    }
                }
            @unknown default:
                return false
            }
        } else {
            return true
        }
    }

    private func handleRecordingStopped(successfully ok: Bool) {
        guard isRecording || recorder != nil else { return }
        isRecording = false
        recorder?.delegate = nil
        if !ok {
            recorder?.stop()
        }
        recorder = nil
        stopTimer()
        if ok {
            lastAutoStoppedURL = activeTempURL
        } else {
            discardTemp(activeTempURL)
            errorMessage = L10n.t("录音被系统中断，请再试一次。", "Recording was interrupted. Please try again.")
        }
        deactivateSessionIfIdle()
    }

    private func startRecordTimer() {
        stopTimer()
        timer = Timer.scheduledTimer(withTimeInterval: 0.08, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in
                guard let self, self.isRecording, let rec = self.recorder else { return }
                rec.updateMeters()
                self.recordingSeconds = rec.currentTime
                let power = rec.averagePower(forChannel: 0)
                let linear = max(0.08, min(1.0, pow(10.0, power / 28.0)))
                self.livePeaks.append(Float(linear))
                if self.livePeaks.count > 48 {
                    self.livePeaks.removeFirst()
                }
            }
        }
    }

    private func startPlaybackTimer() {
        stopTimer()
        timer = Timer.scheduledTimer(withTimeInterval: 0.05, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in
                guard let self, let p = self.player, p.isPlaying else { return }
                let dur = max(0.1, p.duration)
                self.playProgress = max(0, min(1, p.currentTime / dur))
            }
        }
    }

    private func stopTimer() {
        timer?.invalidate()
        timer = nil
    }
}

private final class FirstVoiceAudioDelegate: NSObject, AVAudioRecorderDelegate, AVAudioPlayerDelegate, @unchecked Sendable {
    var onRecordFinish: (@MainActor @Sendable (Bool) -> Void)?
    var onPlayFinish: (@MainActor @Sendable (Bool) -> Void)?

    func audioRecorderDidFinishRecording(_ recorder: AVAudioRecorder, successfully flag: Bool) {
        let cb = onRecordFinish
        Task { @MainActor in cb?(flag) }
    }

    func audioPlayerDidFinishPlaying(_ player: AVAudioPlayer, successfully flag: Bool) {
        let cb = onPlayFinish
        Task { @MainActor in cb?(flag) }
    }
}
