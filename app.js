// Speech-to-text runs entirely in the browser with Whisper via Transformers.js.
import { pipeline } from 'https://cdn.jsdelivr.net/npm/@huggingface/transformers@3.0.2';

// Edit these to change the questions the user answers.
const PROMPTS = [
  'What is blocking abundance from flowing into my life right now?',
  'What do I truly believe I deserve?',
  'What step should I take next to welcome more abundance?',
  'What is my unconscious mind trying to tell me about money?',
  'What do I need to let go of?',
];

const $ = (id) => document.getElementById(id);
const statusEl = $('status');
let promptIndex = 0;
let recorder;
let chunks = [];
let transcriberPromise;

function showPrompt() {
  $('prompt-step').textContent = `Prompt ${promptIndex + 1} of ${PROMPTS.length}`;
  $('prompt-text').textContent = PROMPTS[promptIndex];
  $('prev').disabled = promptIndex === 0;
  $('next').disabled = promptIndex === PROMPTS.length - 1;
  $('results').classList.add('hidden');
}

function getTranscriber() {
  transcriberPromise ??= pipeline('automatic-speech-recognition', 'Xenova/whisper-base.en');
  return transcriberPromise;
}

async function startRecording() {
  const stream = await navigator.mediaDevices.getUserMedia({ audio: true });
  recorder = new MediaRecorder(stream);
  chunks = [];
  recorder.ondataavailable = (e) => chunks.push(e.data);
  recorder.onstop = () => {
    stream.getTracks().forEach((t) => t.stop());
    process(new Blob(chunks, { type: recorder.mimeType }));
  };
  recorder.start();
  $('record').disabled = true;
  $('record').classList.add('live');
  $('stop').disabled = false;
  statusEl.textContent = 'Recording… speak your answer, then press Stop.';
  getTranscriber(); // warm up the model while the user talks
}

function stopRecording() {
  recorder.stop();
  $('record').classList.remove('live');
  $('stop').disabled = true;
}

function reverseBuffer(ctx, buffer) {
  const reversed = ctx.createBuffer(buffer.numberOfChannels, buffer.length, buffer.sampleRate);
  for (let ch = 0; ch < buffer.numberOfChannels; ch++) {
    reversed.getChannelData(ch).set(buffer.getChannelData(ch).slice().reverse());
  }
  return reversed;
}

// Whisper expects 16 kHz mono Float32 samples.
async function toWhisperInput(buffer) {
  const offline = new OfflineAudioContext(1, Math.ceil(buffer.duration * 16000), 16000);
  const src = offline.createBufferSource();
  src.buffer = buffer;
  src.connect(offline.destination);
  src.start();
  return (await offline.startRendering()).getChannelData(0);
}

function encodeWav(buffer) {
  const samples = buffer.getChannelData(0);
  const view = new DataView(new ArrayBuffer(44 + samples.length * 2));
  const write = (off, str) => [...str].forEach((c, i) => view.setUint8(off + i, c.charCodeAt(0)));
  write(0, 'RIFF');
  view.setUint32(4, 36 + samples.length * 2, true);
  write(8, 'WAVEfmt ');
  view.setUint32(16, 16, true);
  view.setUint16(20, 1, true);
  view.setUint16(22, 1, true);
  view.setUint32(24, buffer.sampleRate, true);
  view.setUint32(28, buffer.sampleRate * 2, true);
  view.setUint16(32, 2, true);
  view.setUint16(34, 16, true);
  write(36, 'data');
  view.setUint32(40, samples.length * 2, true);
  samples.forEach((s, i) => {
    const v = Math.max(-1, Math.min(1, s));
    view.setInt16(44 + i * 2, v < 0 ? v * 0x8000 : v * 0x7fff, true);
  });
  return new Blob([view], { type: 'audio/wav' });
}

async function transcribe(buffer) {
  const transcriber = await getTranscriber();
  const { text } = await transcriber(await toWhisperInput(buffer));
  return text.trim() || '(no words detected)';
}

async function process(blob) {
  statusEl.textContent = 'Reversing your recording…';
  const ctx = new AudioContext();
  const forward = await ctx.decodeAudioData(await blob.arrayBuffer());
  const reversed = reverseBuffer(ctx, forward);
  const reversedWav = encodeWav(reversed);

  $('forward-audio').src = URL.createObjectURL(blob);
  $('reverse-audio').src = URL.createObjectURL(reversedWav);
  $('download').href = $('reverse-audio').src;
  $('forward-text').textContent = '';
  $('reverse-text').textContent = '';
  $('results').classList.remove('hidden');
  $('reverse-audio').play();

  statusEl.textContent = 'Listening for the hidden message (first run downloads the speech model)…';
  try {
    $('reverse-text').textContent = await transcribe(reversed);
    $('forward-text').textContent = await transcribe(forward);
    statusEl.textContent = 'Revealed. Sit with the message, then try the next prompt.';
  } catch (err) {
    console.error(err);
    statusEl.textContent = `Transcription failed: ${err.message}`;
  }
  $('record').disabled = false;
  ctx.close();
}

$('record').onclick = () => startRecording().catch((err) => {
  statusEl.textContent = `Microphone unavailable: ${err.message}`;
});
$('stop').onclick = stopRecording;
$('prev').onclick = () => { promptIndex--; showPrompt(); };
$('next').onclick = () => { promptIndex++; showPrompt(); };

showPrompt();
