# Unconscious Abundance Reveal

A browser app that records your spoken answer to a guided prompt, plays it **backwards**, and transcribes the reversed audio to reveal guidance from the unconscious mind.

## How it works

1. A prompt is shown (e.g. *"What is blocking abundance from flowing into my life right now?"*).
2. Press **Record** and answer out loud, then press **Stop**.
3. The app reverses the recording and plays it back.
4. The reversed audio is transcribed — the words that surface are your hidden guidance. The forward transcript is shown too, for comparison.

Everything runs locally in your browser. Audio never leaves your device; speech-to-text uses [Whisper](https://huggingface.co/Xenova/whisper-base.en) via [Transformers.js](https://huggingface.co/docs/transformers.js). The model (~75 MB) downloads once on first use and is cached.

## Run it

Microphone access needs `localhost` or HTTPS, so serve the folder rather than opening the file directly:

```bash
python3 -m http.server 8000
```

Then open http://localhost:8000.

It also works as-is on GitHub Pages (Settings → Pages → deploy from `main`).

## Customize the prompts

Edit the `PROMPTS` array at the top of [`app.js`](app.js).

## Files

- `index.html` — page layout
- `style.css` — styling
- `app.js` — recording, reversal, WAV export, and transcription
