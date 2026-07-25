import type { TimerStatus } from "../types";

export const minimumDurationMs = 5_000;

export interface TimerMachineState {
  status: TimerStatus;
  totalMs: number;
  remainingMs: number;
  runStartedAt: number | null;
  runStartedRemainingMs: number;
  runID: number;
}

export type TimerMachineAction =
  | { type: "setDuration"; durationMs: number }
  | { type: "configure"; durationMs: number }
  | { type: "play"; now: number }
  | { type: "pause"; now: number }
  | { type: "reset" }
  | { type: "finish" };

export function makeTimerState(durationMs = 25_000): TimerMachineState {
  const clamped = Math.max(minimumDurationMs, durationMs);
  return {
    status: "notStarted",
    totalMs: clamped,
    remainingMs: clamped,
    runStartedAt: null,
    runStartedRemainingMs: clamped,
    runID: 0,
  };
}

export function remainingMsAt(state: TimerMachineState, now: number): number {
  if (state.status !== "running" || state.runStartedAt === null) {
    return state.remainingMs;
  }
  return Math.min(
    state.runStartedRemainingMs,
    Math.max(0, state.runStartedRemainingMs - (now - state.runStartedAt)),
  );
}

export function timerMachine(
  state: TimerMachineState,
  action: TimerMachineAction,
): TimerMachineState {
  switch (action.type) {
    case "setDuration": {
      if (state.status !== "notStarted") return state;
      const durationMs = Math.max(minimumDurationMs, action.durationMs);
      return {
        ...state,
        totalMs: durationMs,
        remainingMs: durationMs,
        runStartedRemainingMs: durationMs,
      };
    }
    case "configure": {
      const durationMs = Math.max(minimumDurationMs, action.durationMs);
      return {
        status: "notStarted",
        totalMs: durationMs,
        remainingMs: durationMs,
        runStartedAt: null,
        runStartedRemainingMs: durationMs,
        runID: state.runID + 1,
      };
    }
    case "play": {
      if (state.status !== "notStarted" && state.status !== "paused") return state;
      return {
        ...state,
        status: "running",
        runStartedAt: action.now,
        runStartedRemainingMs: state.remainingMs,
        runID: state.runID + 1,
      };
    }
    case "pause": {
      if (state.status !== "running") return state;
      const remainingMs = remainingMsAt(state, action.now);
      return {
        ...state,
        status: "paused",
        remainingMs,
        runStartedAt: null,
        runStartedRemainingMs: remainingMs,
      };
    }
    case "reset": {
      if (state.status !== "paused" && state.status !== "finished") return state;
      return {
        ...state,
        status: "notStarted",
        remainingMs: state.totalMs,
        runStartedAt: null,
        runStartedRemainingMs: state.totalMs,
        runID: state.runID + 1,
      };
    }
    case "finish": {
      if (state.status !== "running") return state;
      return {
        ...state,
        status: "finished",
        remainingMs: 0,
        runStartedAt: null,
        runStartedRemainingMs: 0,
      };
    }
  }
}
