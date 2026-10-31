import AppKit
import AVFoundation

/// One prompt's answer: what was said forwards, and what the reversed recording revealed.
struct Answer: Codable {
    enum State: String, Codable {
        case working, revealed, failed

        var label: String {
            switch self {
            case .working: return "Revealing…"
            case .revealed: return "Revealed"
            case .failed: return "Failed"
            }
        }
    }

    var state: State = .working
    var forwardText = ""
    var reversedText = ""
    var error = ""
    var duration: TimeInterval = 0
    var date = Date()
}

@MainActor
final class AppModel: NSObject, ObservableObject, AVAudioPlayerDelegate {
    @Published var selection: Int? = 0
    @Published private(set) var answers: [Int: Answer] = [:]
    @Published private(set) var recordingIndex: Int?
    @Published private(set) var recordingElapsed: TimeInterval = 0
    @Published private(set) var level: Float = 0
    @Published private(set) var playing: URL?
    @Published var lastMessage = "Choose a prompt and press Record"

    /// Off by default: answers are deleted when the app quits.
    @Published var keepAnswers = UserDefaults.standard.bool(forKey: "keepAnswers") {
        didSet {
            UserDefaults.standard.set(keepAnswers, forKey: "keepAnswers")
            if keepAnswers { save() }
        }
    }

    var isRecording: Bool { recordingIndex != nil }

    /// Inside the app's sandbox container: ~/Library/Containers/<app>/Data/Library/Application Support/Answers
    let answersFolder = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        .appendingPathComponent("Answers", isDirectory: true)
    private var answersFile: URL { answersFolder.appendingPathComponent("answers.json") }

    func folder(_ i: Int) -> URL { answersFolder.appendingPathComponent("Prompt \(i + 1)", isDirectory: true) }
    func forwardURL(_ i: Int) -> URL { folder(i).appendingPathComponent("Forward.caf") }
    func reversedURL(_ i: Int) -> URL { folder(i).appendingPathComponent("Reversed.caf") }

    private var recorder: AVAudioRecorder?
    private var meterTimer: Timer?
    private var player: AVAudioPlayer?

    override init() {
        super.init()
        if keepAnswers { restore() } else { deleteAll() }  // also cleans up after a crash
    }

    // MARK: Recording

    func startRecording() {
        guard !isRecording else { return }
        let i = selection ?? 0
        Task {
            guard await AVCaptureDevice.requestAccess(for: .audio) else {
                lastMessage = "Microphone access is off: turn it on in System Settings > Privacy & Security > Microphone"
                return
            }
            _ = await Transcriber.requestAuthorization()
            beginRecording(i)
        }
    }

    private func beginRecording(_ i: Int) {
        stopPlaying()
        try? FileManager.default.removeItem(at: folder(i))
        answers[i] = nil
        do {
            try FileManager.default.createDirectory(at: folder(i), withIntermediateDirectories: true)
            let settings: [String: Any] = [
                AVFormatIDKey: kAudioFormatLinearPCM,
                AVSampleRateKey: 44_100,
                AVNumberOfChannelsKey: 1,
                AVLinearPCMBitDepthKey: 16,
                AVLinearPCMIsFloatKey: false,
            ]
            let recorder = try AVAudioRecorder(url: forwardURL(i), settings: settings)
            recorder.isMeteringEnabled = true
            guard recorder.record() else { throw CocoaError(.fileWriteUnknown) }
            self.recorder = recorder
            recordingIndex = i
            selection = i
            lastMessage = "Recording prompt \(i + 1): answer out loud, then press Stop"
            meterTimer = Timer.scheduledTimer(withTimeInterval: 0.05, repeats: true) { [weak self] _ in
                Task { @MainActor in self?.updateMeter() }
            }
        } catch {
            lastMessage = "Couldn't start recording: \(error.localizedDescription)"
        }
    }

    private func updateMeter() {
        guard let recorder else { return }
        recorder.updateMeters()
        recordingElapsed = recorder.currentTime
        level = max(0, (recorder.averagePower(forChannel: 0) + 50) / 50)  // -50 dB … 0 dB → 0 … 1
    }

    func stopRecording() {
        guard let i = recordingIndex, let recorder else { return }
        let duration = recorder.currentTime
        recorder.stop()
        self.recorder = nil
        meterTimer?.invalidate()
        meterTimer = nil
        recordingIndex = nil
        level = 0
        answers[i] = Answer(duration: duration)
        Task { await reveal(i) }
    }

    /// Reverses the recording, plays it, and transcribes both directions.
    func reveal(_ i: Int) async {
        answers[i]?.state = .working
        lastMessage = "Reversing prompt \(i + 1)…"
        do {
            try AudioReverser.reverse(forwardURL(i), to: reversedURL(i))
            play(i, reversed: true)
            lastMessage = "Listening for the hidden message…"
            answers[i]?.reversedText = try await Transcriber.transcribe(reversedURL(i))
            answers[i]?.forwardText = try await Transcriber.transcribe(forwardURL(i))
            answers[i]?.state = .revealed
            lastMessage = "Prompt \(i + 1) revealed"
        } catch {
            answers[i]?.state = .failed
            answers[i]?.error = error.localizedDescription
            lastMessage = error.localizedDescription
        }
        save()
    }

    // MARK: Listening

    func play(_ i: Int, reversed: Bool) {
        let url = reversed ? reversedURL(i) : forwardURL(i)
        stopPlaying()
        guard let player = try? AVAudioPlayer(contentsOf: url) else { return }
        player.delegate = self
        player.play()
        self.player = player
        playing = url
    }

    func stopPlaying() {
        player?.stop()
        player = nil
        playing = nil
    }

    nonisolated func audioPlayerDidFinishPlaying(_ player: AVAudioPlayer, successfully flag: Bool) {
        Task { @MainActor in self.playing = nil }
    }

    // MARK: Saving

    /// A copy outside the app, where the person chooses (the only way files leave the app's container).
    func export(_ i: Int, reversed: Bool) {
        let panel = NSSavePanel()
        panel.allowedContentTypes = [.audio]
        panel.nameFieldStringValue = "Prompt \(i + 1) \(reversed ? "Reversed" : "Forward").caf"
        guard panel.runModal() == .OK, let destination = panel.url else { return }
        try? FileManager.default.removeItem(at: destination)
        do {
            try FileManager.default.copyItem(at: reversed ? reversedURL(i) : forwardURL(i), to: destination)
            lastMessage = "Saved \(destination.lastPathComponent)"
        } catch {
            lastMessage = "Couldn't save: \(error.localizedDescription)"
        }
    }

    func delete(_ i: Int) {
        stopPlaying()
        try? FileManager.default.removeItem(at: folder(i))
        answers[i] = nil
        save()
        lastMessage = "Deleted the answer to prompt \(i + 1)"
    }

    func deleteAll() {
        stopPlaying()
        try? FileManager.default.removeItem(at: answersFolder)
        answers = [:]
    }

    func appWillQuit() {
        if isRecording { recorder?.stop() }
        if !keepAnswers { deleteAll() }
    }

    private func save() {
        guard keepAnswers else { return }
        try? FileManager.default.createDirectory(at: answersFolder, withIntermediateDirectories: true)
        let byPrompt = Dictionary(uniqueKeysWithValues: answers.map { (String($0.key), $0.value) })
        try? JSONEncoder().encode(byPrompt).write(to: answersFile)
    }

    private func restore() {
        guard let data = try? Data(contentsOf: answersFile),
              let byPrompt = try? JSONDecoder().decode([String: Answer].self, from: data) else { return }
        for (key, answer) in byPrompt {
            guard let i = Int(key), Prompts.all.indices.contains(i), answer.state != .working else { continue }
            answers[i] = answer
        }
    }
}
