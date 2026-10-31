# Unconscious Abundance Reveal

<img src="app/Resources/AppIcon.png" width="128" align="right" alt="Unconscious Abundance Reveal icon">

A Mac app that records your spoken answer to a guided prompt, plays it **backwards**, and transcribes the
reversed recording to reveal guidance from the unconscious mind. Choose a prompt, press **Record**, answer out
loud, and press **Stop**: the reversed answer plays and the words hidden in it appear.

Everything runs on your Mac. Nothing is uploaded, and the app can't go online at all.

![The main window](docs/screenshots/main.png)

- **Guided prompts.** Five questions about abundance, answered one at a time. Each shows whether it's been
  answered and what it revealed.
- **Reversed and revealed.** The recording is flipped sample for sample, played back, and turned into words.
  What you said forwards is shown underneath, to compare.
- **Visible while recording.** A red recording box with the time and a microphone level meter.
- **Play** either direction again, or **save** a copy of the forward or reversed audio where you choose.
- **Toolbar:** record, play reversed, the answers folder, settings and donate.

## Privacy

Privacy comes first. This is enforced by macOS itself, not just promised:

- **No network access.** The app runs in Apple's App Sandbox *without* the network entitlement
  ([`UnconsciousReveal.entitlements`](app/Resources/UnconsciousReveal.entitlements)), so macOS refuses any
  connection it tries to make. Check it yourself:
  ```bash
  codesign -d --entitlements - "app/build/Unconscious Abundance Reveal.app"
  ```
- **No telemetry.** No analytics, crash reporting or update checks, and no third-party code at all: the app
  uses only what comes with macOS.
- **On-device speech recognition only.** Transcription uses the speech model built into macOS with
  `requiresOnDeviceRecognition`, so it fails rather than send audio to Apple's servers.
- **Answers are deleted when the app quits**, unless you turn on *Keep answers* in Settings. Until then they
  live only inside the app's private container:
  `~/Library/Containers/com.technaudiotoolz.unconsciousreveal/Data/Library/Application Support/Answers`.

## Needs

- macOS 14 or newer on Apple Silicon.
- The on-device speech model: turn on **Dictation** in System Settings > Keyboard and macOS downloads it.
  Settings in the app says whether it's installed.
- The first time you record, macOS asks for **Microphone** and **Speech Recognition** permission.

## Build

```bash
cd app
./build.sh --open
```

Then drag `app/build/Unconscious Abundance Reveal.app` to Applications. Redraw the icon with
`swift make_icon.swift`.

The app is signed on your own Mac without an Apple Developer account, so macOS asks again for the microphone
after each new build (unless you make an "Unconscious Reveal Dev" code-signing certificate).

## Change the prompts

Edit the list in [`Prompts.swift`](app/Sources/UnconsciousReveal/Prompts.swift).

## License

MIT.
