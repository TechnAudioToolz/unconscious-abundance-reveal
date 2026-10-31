import AppKit
import SwiftUI

/// The prompts, in order, each with how far its answer has got.
struct PromptsBox: View {
    @EnvironmentObject var model: AppModel

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                Label("Prompts", systemImage: "questionmark.bubble").font(.headline)
                Spacer()
            }
            .padding(.horizontal, 12).padding(.vertical, 8)
            List(selection: $model.selection) {
                ForEach(Prompts.all.indices, id: \.self) { i in
                    PromptRow(index: i)
                        .tag(i)
                        .contentShape(Rectangle())
                        .contextMenu {
                            if model.answers[i] != nil {
                                Button("Save reversed audio…") { model.export(i, reversed: true) }
                                Divider()
                                Button("Delete answer") { model.delete(i) }
                            }
                        }
                }
            }
            .disabled(model.isRecording)
            .accessibilityLabel("Prompts")
        }
    }
}

struct PromptRow: View {
    @EnvironmentObject var model: AppModel
    let index: Int

    var body: some View {
        HStack(spacing: 10) {
            Text("\(index + 1)")
                .font(.headline)
                .frame(width: 28, height: 28)
                .background(Color.accentColor.opacity(0.15), in: Circle())
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 3) {
                Text(Prompts.all[index]).fontWeight(.medium).lineLimit(2)
                if let answer = model.answers[index] {
                    Text(subtitle(answer)).font(.caption).foregroundColor(.secondary).lineLimit(1)
                }
            }
            Spacer()
            StateBadge(label: badgeLabel, color: badgeColor)
        }
        .padding(.vertical, 4)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Prompt \(index + 1): \(Prompts.all[index]), \(badgeLabel)")
    }

    private func subtitle(_ answer: Answer) -> String {
        var parts = [clock(answer.duration)]
        if answer.state == .revealed {
            parts.append(answer.reversedText.isEmpty ? "no words surfaced" : "“\(answer.reversedText)”")
        }
        return parts.joined(separator: " · ")
    }

    private var badgeLabel: String {
        if model.recordingIndex == index { return "Recording" }
        return model.answers[index]?.state.label ?? "Not answered"
    }

    private var badgeColor: Color {
        if model.recordingIndex == index { return .red }
        switch model.answers[index]?.state {
        case .revealed: return .green
        case .failed: return .red
        case .working: return .accentColor
        case nil: return .secondary
        }
    }
}

struct StateBadge: View {
    let label: String
    let color: Color

    var body: some View {
        Text(label)
            .font(.caption)
            .padding(.horizontal, 8).padding(.vertical, 2)
            .background(color.opacity(0.15))
            .foregroundColor(color)
            .clipShape(Capsule())
            .accessibilityLabel("Status: \(label)")
    }
}

/// The red box while recording: time, how loud, and Stop.
struct RecordingPanel: View {
    @EnvironmentObject var model: AppModel

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) {
                Circle().fill(Color.red).frame(width: 12, height: 12)
                    .accessibilityHidden(true)
                Text("Recording").fontWeight(.semibold)
                Text(clock(model.recordingElapsed)).monospacedDigit()
                Spacer()
                Button("Stop") { model.stopRecording() }
            }
            LevelMeter(label: "Microphone", systemImage: "mic", level: model.level)
            Text("Answer the prompt out loud, then press Stop to hear it backwards.")
                .font(.caption).foregroundColor(.secondary)
        }
        .padding(12)
        .background(Color.red.opacity(0.08), in: RoundedRectangle(cornerRadius: 6))
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Recording")
    }
}

struct LevelMeter: View {
    let label: String
    let systemImage: String
    let level: Float

    var body: some View {
        HStack(spacing: 8) {
            Label(label, systemImage: systemImage).frame(width: 110, alignment: .leading).lineLimit(1)
            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    Capsule().fill(Color.secondary.opacity(0.15))
                    Capsule().fill(level > 0.8 ? Color.orange : Color.green)
                        .frame(width: geometry.size.width * CGFloat(min(1, level)))
                }
            }
            .frame(height: 8)
        }
        .font(.caption)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(label): \(Int(level * 100)) percent")
    }
}

/// The right-hand panel: the prompt, recording, and what the reversed answer revealed.
struct AnswerDetail: View {
    @EnvironmentObject var model: AppModel
    let index: Int

    private var answer: Answer? { model.answers[index] }

    var body: some View {
        Form {
            Section {
                VStack(alignment: .leading, spacing: 6) {
                    Text("PROMPT \(index + 1) OF \(Prompts.all.count)")
                        .font(.caption.weight(.medium)).foregroundColor(.secondary)
                    Text(Prompts.all[index]).font(.title2).fixedSize(horizontal: false, vertical: true)
                }
                .padding(.vertical, 4)
            }
            Section {
                if model.recordingIndex == index {
                    RecordingPanel()
                } else {
                    status
                }
            }
            if let answer, answer.state == .revealed {
                Section("Guidance from the unconscious (reversed)") {
                    Text(answer.reversedText.isEmpty ? "No words surfaced. Listen again and notice what you hear." : answer.reversedText)
                        .font(.title3.italic())
                        .foregroundColor(answer.reversedText.isEmpty ? .secondary : .primary)
                        .textSelection(.enabled)
                    playButton(reversed: true)
                }
                Section("Your answer (forward)") {
                    Text(answer.forwardText.isEmpty ? "No words detected" : answer.forwardText)
                        .foregroundColor(.secondary)
                        .textSelection(.enabled)
                    playButton(reversed: false)
                }
                Section("Save") {
                    HStack {
                        Button("Save reversed audio…") { model.export(index, reversed: true) }
                        Button("Save forward audio…") { model.export(index, reversed: false) }
                        Spacer()
                        Button("Delete answer", role: .destructive) { model.delete(index) }
                    }
                    Text("Saved copies go where you choose. Everything else stays in the app's private folder.")
                        .font(.caption).foregroundColor(.secondary)
                }
            }
        }
        .formStyle(.grouped)
    }

    @ViewBuilder private var status: some View {
        switch answer?.state {
        case nil:
            HStack {
                Text("Press Record (⌘R) and answer out loud, then press Stop.")
                Spacer()
                Button("Record") { model.startRecording() }.disabled(model.isRecording)
            }
        case .working:
            VStack(alignment: .leading) {
                ProgressView()
                Text("Reversing your answer and listening for the hidden message…").font(.caption).foregroundColor(.secondary)
            }
        case .revealed:
            HStack {
                Label("Revealed · \(clock(answer?.duration ?? 0))", systemImage: "checkmark.circle.fill").foregroundColor(.green)
                Spacer()
                Button("Record again") { model.startRecording() }.disabled(model.isRecording)
            }
        case .failed:
            HStack {
                Label(answer?.error ?? "", systemImage: "exclamationmark.triangle.fill").foregroundColor(.red)
                Spacer()
                Button("Try again") { Task { await model.reveal(index) } }
                Button("Record again") { model.startRecording() }.disabled(model.isRecording)
            }
        }
    }

    private func playButton(reversed: Bool) -> some View {
        let url = reversed ? model.reversedURL(index) : model.forwardURL(index)
        return HStack {
            if model.playing == url {
                Button { model.stopPlaying() } label: { Label("Stop", systemImage: "stop.fill") }
            } else {
                Button { model.play(index, reversed: reversed) } label: {
                    Label(reversed ? "Play backwards" : "Play forwards", systemImage: reversed ? "backward.fill" : "play.fill")
                }
                .disabled(model.isRecording)
            }
            Spacer()
        }
    }
}

struct SettingsView: View {
    @EnvironmentObject var model: AppModel

    var body: some View {
        Form {
            Section("Answers") {
                Toggle("Keep answers after the app quits", isOn: $model.keepAnswers)
                Text(model.keepAnswers
                     ? "Recordings and what they revealed are kept in the app's private folder until you delete them."
                     : "Recordings and what they revealed are deleted when the app quits.")
                    .font(.caption).foregroundColor(.secondary)
                Button("Delete all answers now", role: .destructive) { model.deleteAll() }
                    .disabled(model.answers.isEmpty || model.isRecording)
            }
            Section("Speech recognition") {
                if Transcriber.onDeviceAvailable {
                    Label("The on-device speech model is installed", systemImage: "checkmark.circle.fill")
                        .foregroundColor(.green)
                } else {
                    Label("The on-device speech model isn't installed", systemImage: "exclamationmark.triangle.fill")
                        .foregroundColor(.orange)
                    Text("Turn on Dictation in System Settings > Keyboard and macOS downloads it. Until then, nothing can be transcribed: the app never falls back to Apple's servers.")
                        .font(.caption).foregroundColor(.secondary)
                }
            }
            Section("Privacy") {
                Text("Everything happens on this Mac. The app has no network access at all (macOS's App Sandbox blocks it), sends no telemetry, analytics or crash reports, and speech recognition is on-device only.")
                    .foregroundColor(.secondary)
            }
        }
        .formStyle(.grouped)
        .frame(width: 480, height: 460)
    }
}
