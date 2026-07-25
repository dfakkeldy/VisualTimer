import type { TimerSound } from "../types";

let audioContext: AudioContext | null = null;

const soundSettings: Record<TimerSound, { frequency: number; duration: number }> = {
  chime: { frequency: 880, duration: 0.25 },
  bright: { frequency: 1200, duration: 0.18 },
  deep: { frequency: 523, duration: 0.35 },
};

export function prepareAudio(): void {
  const AudioContextClass = window.AudioContext;
  if (!AudioContextClass) return;
  audioContext ??= new AudioContextClass();
  if (audioContext.state === "suspended") {
    void audioContext.resume();
  }
}

export function playFinishSound(sound: TimerSound): void {
  prepareAudio();
  if (!audioContext) return;

  const settings = soundSettings[sound];
  const start = audioContext.currentTime;

  for (let index = 0; index < 3; index += 1) {
    const toneStart = start + index * 0.35;
    const oscillator = audioContext.createOscillator();
    const gain = audioContext.createGain();
    oscillator.type = "sine";
    oscillator.frequency.setValueAtTime(settings.frequency, toneStart);
    gain.gain.setValueAtTime(0.0001, toneStart);
    gain.gain.exponentialRampToValueAtTime(0.24, toneStart + 0.012);
    gain.gain.exponentialRampToValueAtTime(0.0001, toneStart + settings.duration);
    oscillator.connect(gain);
    gain.connect(audioContext.destination);
    oscillator.start(toneStart);
    oscillator.stop(toneStart + settings.duration + 0.02);
  }
}
