import { useCallback, useEffect, useReducer, useRef, useState } from "react";
import {
  makeTimerState,
  remainingMsAt,
  timerMachine,
  type TimerMachineState,
} from "../domain/timerMachine";

export interface TimerEngine {
  state: TimerMachineState;
  remainingMs: number;
  progress: number;
  clockNow: number;
  setDuration: (durationMs: number) => void;
  configure: (durationMs: number, autoStart?: boolean) => void;
  play: () => void;
  pause: () => void;
  reset: () => void;
}

export function useTimerEngine(initialDurationMs = 25_000): TimerEngine {
  const [state, dispatch] = useReducer(timerMachine, initialDurationMs, makeTimerState);
  const [clockNow, setClockNow] = useState(() => performance.now());
  const finishedRunRef = useRef(-1);

  useEffect(() => {
    if (state.status !== "running") return;

    let frameID = 0;
    const tick = (now: number) => {
      setClockNow(now);
      if (remainingMsAt(state, now) <= 0) {
        if (finishedRunRef.current !== state.runID) {
          finishedRunRef.current = state.runID;
          dispatch({ type: "finish" });
        }
        return;
      }
      frameID = requestAnimationFrame(tick);
    };

    frameID = requestAnimationFrame(tick);
    return () => cancelAnimationFrame(frameID);
  }, [state]);

  const setDuration = useCallback((durationMs: number) => {
    dispatch({ type: "setDuration", durationMs });
  }, []);

  const configure = useCallback((durationMs: number, autoStart = false) => {
    dispatch({ type: "configure", durationMs });
    if (autoStart) {
      dispatch({ type: "play", now: performance.now() });
    }
  }, []);

  const play = useCallback(() => {
    dispatch({ type: "play", now: performance.now() });
  }, []);

  const pause = useCallback(() => {
    dispatch({ type: "pause", now: performance.now() });
  }, []);

  const reset = useCallback(() => {
    dispatch({ type: "reset" });
  }, []);

  const remainingMs = remainingMsAt(state, clockNow);
  const progress = state.totalMs === 0 ? 0 : remainingMs / state.totalMs;

  return {
    state,
    remainingMs,
    progress,
    clockNow,
    setDuration,
    configure,
    play,
    pause,
    reset,
  };
}
