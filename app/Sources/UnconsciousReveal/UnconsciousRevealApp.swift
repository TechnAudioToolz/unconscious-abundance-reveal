import AppKit
import SwiftUI

@main
struct UnconsciousRevealApp: App {
    @StateObject private var model = AppModel()

    init() {
        // Hover text appears after half a second instead of the Mac's usual second or so.
        UserDefaults.standard.register(defaults: ["NSInitialToolTipDelay": 500])
    }

    var body: some Scene {
        WindowGroup("Unconscious Abundance Reveal") {
            ContentView()
                .environmentObject(model)
                .frame(minWidth: 820, minHeight: 540)
                .onAppear { handleLaunchArguments() }
                .onReceive(NotificationCenter.default.publisher(for: NSApplication.willTerminateNotification)) { _ in
                    model.appWillQuit()
                }
        }
        .commands {
            CommandGroup(replacing: .help) {
                Button("Support this project…") { openDonatePage() }
                Button("Project on GitHub") { NSWorkspace.shared.open(projectURL) }
            }
        }

        Settings {
            SettingsView()
                .environmentObject(model)
        }
    }

    /// Optional launch arguments, for testing:
    ///   open -a "Unconscious Abundance Reveal" --args --snapshot window.png
    /// (sandboxed, so a relative path lands in the app's container: ~/Library/Containers/com.technaudiotoolz.unconsciousreveal/Data)
    func handleLaunchArguments() {
        let args = CommandLine.arguments
        if let i = args.firstIndex(of: "--snapshot"), args.indices.contains(i + 1) {
            let path = args[i + 1]
            let home = URL(fileURLWithPath: NSHomeDirectory())
            startSnapshots(to: path.hasPrefix("/") ? URL(fileURLWithPath: path) : home.appendingPathComponent(path))
        }
    }

    /// For testing and README images: saves a picture of the window to `file` every 3 seconds.
    func startSnapshots(to file: URL) {
        Timer.scheduledTimer(withTimeInterval: 3, repeats: true) { _ in
            DispatchQueue.main.async {
                guard let frame = NSApp.windows.first(where: { $0.isVisible && $0.toolbar != nil })?.contentView?.superview,
                      let rep = frame.bitmapImageRepForCachingDisplay(in: frame.bounds) else { return }
                frame.cacheDisplay(in: frame.bounds, to: rep)
                try? rep.representation(using: .png, properties: [:])?.write(to: file)
            }
        }
    }
}

let projectURL = URL(string: "https://github.com/TechnAudioToolz/unconscious-abundance-reveal")!

/// The donation page ships inside the app and opens in the default browser.
func openDonatePage() {
    if let page = Bundle.main.url(forResource: "donate", withExtension: "html") {
        NSWorkspace.shared.open(page)
    }
}

/// "1:05" for 65 seconds.
func clock(_ seconds: TimeInterval) -> String {
    let s = Int(seconds.rounded())
    return String(format: "%d:%02d", s / 60, s % 60)
}

struct ContentView: View {
    @EnvironmentObject var model: AppModel

    var body: some View {
        VStack(spacing: 0) {
            HSplitView {
                PromptsBox()
                    .frame(minWidth: 280, idealWidth: 340)
                detail
                    .frame(minWidth: 420)
            }
            statusBar
        }
        .toolbar {
            ToolbarItemGroup {
                if model.isRecording {
                    Button { model.stopRecording() } label: { Label("Stop recording", systemImage: "stop.fill") }
                        .keyboardShortcut(".")
                        .help(tip("Stop recording"))
                } else {
                    Button { model.startRecording() } label: {
                        Label("Record", systemImage: "record.circle").foregroundStyle(.red)
                    }
                    .keyboardShortcut("r")
                    .help(tip("Record"))
                }
                if model.playing != nil {
                    Button { model.stopPlaying() } label: { Label("Stop playing", systemImage: "speaker.slash") }
                        .keyboardShortcut("p")
                        .help(tip("Stop playing"))
                } else {
                    Button { if let i = model.selection { model.play(i, reversed: true) } } label: {
                        Label("Play reversed", systemImage: "backward.fill")
                    }
                    .keyboardShortcut("p")
                    .help(tip("Play reversed"))
                    .disabled(model.selection.flatMap { model.answers[$0] } == nil || model.isRecording)
                }
                Button {
                    try? FileManager.default.createDirectory(at: model.answersFolder, withIntermediateDirectories: true)
                    NSWorkspace.shared.open(model.answersFolder)
                } label: { Label("Answers folder", systemImage: "folder") }
                    .help(tip("Answers folder"))
                SettingsLink { Label("Settings", systemImage: "gearshape") }
                    .help(tip("Settings"))
                Button { openDonatePage() } label: { Label("Donate", systemImage: "heart") }
                    .help(tip("Donate"))
            }
        }
        // SwiftUI's .help doesn't always show on toolbar buttons, so the toolbar items get the same text as
        // ordinary Mac tooltips too, again whenever a button changes (Record/Stop, Play/Stop playing).
        .onAppear { applyToolbarTips() }
        .onChange(of: model.isRecording) { applyToolbarTips() }
        .onChange(of: model.playing) { applyToolbarTips() }
    }

    /// What each toolbar button does, shown when the mouse rests on it. Keyed by the button's label.
    private func tip(_ label: String) -> String {
        switch label {
        case "Record": return "Record (⌘R): answer the selected prompt out loud"
        case "Stop recording": return "Stop recording (⌘.): reverse the answer and reveal what's hidden in it"
        case "Play reversed": return "Play reversed (⌘P): hear the selected answer backwards"
        case "Stop playing": return "Stop playing (⌘P)"
        case "Answers folder": return "Open the answers folder: the recordings, kept inside the app's private container"
        case "Settings": return "Settings (⌘,)"
        case "Donate": return "Donate: support this project"
        default: return ""
        }
    }

    private func applyToolbarTips() {
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {  // after SwiftUI has rebuilt the toolbar
            for window in NSApp.windows {
                for item in window.toolbar?.items ?? [] where !tip(item.label).isEmpty {
                    item.toolTip = tip(item.label)
                }
            }
        }
    }

    @ViewBuilder private var detail: some View {
        if let i = model.selection {
            AnswerDetail(index: i)
                .id(i)
        } else {
            Text("Select a prompt to answer it")
                .foregroundColor(.secondary)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }

    private var statusBar: some View {
        HStack {
            Text(model.lastMessage)
            Spacer()
            Label("Offline: nothing leaves this Mac", systemImage: "lock.fill")
        }
        .font(.caption)
        .foregroundColor(.secondary)
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .background(Color(nsColor: .windowBackgroundColor))
    }
}
