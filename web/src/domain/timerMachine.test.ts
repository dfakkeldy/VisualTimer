import { describe, expect, it } from "vitest";
import {
  makeTimerState,
  minimumDurationMs,
  remainingMsAt,
  timerMachine,
} from "./timerMachine";

describe("timerMachine", () => {
  it("clamps durations and only changes them before playback", () => {
    const initial = makeTimerState(1_000);
    expect(initial.totalMs).toBe(minimumDurationMs);

    const configured = timerMachine(initial, { type: "setDuration", durationMs: 30_000 });
    const running = timerMachine(configured, { type: "play", now: 100 });
    const ignored = timerMachine(running, { type: "setDuration", durationMs: 60_000 });

    expect(ignored.totalMs).toBe(30_000);
    expect(ignored.status).toBe("running");
  });

  it("derives continuous remaining time from the wall clock", () => {
    const running = timerMachine(makeTimerState(25_000), { type: "play", now: 1_000 });

    expect(remainingMsAt(running, 999)).toBe(25_000);
    expect(remainingMsAt(running, 1_250)).toBe(24_750);
    expect(remainingMsAt(running, 26_500)).toBe(0);
  });

  it("pauses with exact remaining time and resumes without drift", () => {
    const running = timerMachine(makeTimerState(10_000), { type: "play", now: 5_000 });
    const paused = timerMachine(running, { type: "pause", now: 7_500 });
    const resumed = timerMachine(paused, { type: "play", now: 20_000 });

    expect(paused.remainingMs).toBe(7_500);
    expect(remainingMsAt(resumed, 21_000)).toBe(6_500);
  });

  it("guards invalid state transitions", () => {
    const initial = makeTimerState();
    expect(timerMachine(initial, { type: "pause", now: 0 })).toBe(initial);
    expect(timerMachine(initial, { type: "finish" })).toBe(initial);

    const running = timerMachine(initial, { type: "play", now: 0 });
    expect(timerMachine(running, { type: "play", now: 5 })).toBe(running);
    expect(timerMachine(running, { type: "reset" })).toBe(running);
  });

  it("reconfigures atomically for the next sequence round", () => {
    const running = timerMachine(makeTimerState(25_000), { type: "play", now: 0 });
    const nextRound = timerMachine(running, { type: "configure", durationMs: 90_000 });

    expect(nextRound.status).toBe("notStarted");
    expect(nextRound.totalMs).toBe(90_000);
    expect(nextRound.remainingMs).toBe(90_000);
    expect(nextRound.runID).toBeGreaterThan(running.runID);
  });
});
