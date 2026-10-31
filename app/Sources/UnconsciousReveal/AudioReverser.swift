import AVFoundation

enum AudioReverser {
    struct ReadError: Error {}

    /// Writes a copy of `input` to `output` with the samples in reverse order.
    static func reverse(_ input: URL, to output: URL) throws {
        let source = try AVAudioFile(forReading: input)
        let format = source.processingFormat
        guard let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: AVAudioFrameCount(source.length)) else {
            throw ReadError()
        }
        try source.read(into: buffer)

        let count = Int(buffer.frameLength)
        if let channels = buffer.floatChannelData {
            for channel in 0..<Int(format.channelCount) {
                let samples = channels[channel]
                var i = 0, j = count - 1
                while i < j {
                    let tmp = samples[i]
                    samples[i] = samples[j]
                    samples[j] = tmp
                    i += 1
                    j -= 1
                }
            }
        }

        let destination = try AVAudioFile(
            forWriting: output,
            settings: source.fileFormat.settings,
            commonFormat: format.commonFormat,
            interleaved: format.isInterleaved
        )
        try destination.write(from: buffer)
    }
}
