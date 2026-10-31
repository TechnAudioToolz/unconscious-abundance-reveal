import Foundation
import Speech

enum TranscriptionError: LocalizedError {
    case notAuthorized
    case noOnDeviceModel

    var errorDescription: String? {
        switch self {
        case .notAuthorized:
            return "Speech Recognition is off for this app: turn it on in System Settings > Privacy & Security > Speech Recognition"
        case .noOnDeviceModel:
            return "The on-device speech model isn't installed: turn on Dictation in System Settings > Keyboard and macOS downloads it"
        }
    }
}

/// Speech to text with the model built into macOS. `requiresOnDeviceRecognition` makes the Speech
/// framework fail rather than fall back to Apple's servers, so audio never leaves the Mac.
enum Transcriber {
    private static let recognizer = SFSpeechRecognizer()

    static var onDeviceAvailable: Bool { recognizer?.supportsOnDeviceRecognition ?? false }

    static func requestAuthorization() async -> Bool {
        await withCheckedContinuation { continuation in
            SFSpeechRecognizer.requestAuthorization { continuation.resume(returning: $0 == .authorized) }
        }
    }

    static func transcribe(_ url: URL) async throws -> String {
        guard SFSpeechRecognizer.authorizationStatus() == .authorized else { throw TranscriptionError.notAuthorized }
        guard let recognizer, recognizer.supportsOnDeviceRecognition else { throw TranscriptionError.noOnDeviceModel }

        let request = SFSpeechURLRecognitionRequest(url: url)
        request.requiresOnDeviceRecognition = true
        request.shouldReportPartialResults = false
        request.addsPunctuation = true

        return try await withCheckedThrowingContinuation { continuation in
            var finished = false
            recognizer.recognitionTask(with: request) { result, error in
                guard !finished else { return }
                if let result, result.isFinal {
                    finished = true
                    continuation.resume(returning: result.bestTranscription.formattedString)
                } else if let error {
                    finished = true
                    // 1110 is "no speech detected": common for reversed speech, so it's an empty reveal, not a failure.
                    if (error as NSError).code == 1110 {
                        continuation.resume(returning: "")
                    } else {
                        continuation.resume(throwing: error)
                    }
                }
            }
        }
    }
}
