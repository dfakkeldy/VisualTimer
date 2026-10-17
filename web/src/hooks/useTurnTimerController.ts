import { useCallback, useEffect, useMemo, useRef, useState } from "react";
import { playFinishSound, prepareAudio } from "../domain/sound";
import type {
  GameSequence,
  HistoryRecord,
  Round,
  SequencePhase,
  SessionEvent,
  TimerSound,
} from "../types";
import { usePersistentState } from "./usePersistentState";
import { useTimerEngine } from "./useTimerEngine";

interface SequenceRuntime {
  phase: SequencePhase;
  game: GameSequence | null;
  currentRoundIndex: number;
  currentCycle: number;
  startedAt: string | null;
  elapsedBeforeCurrentSegmentMs: number;
  currentSegmentStartedAt: number | null;
  sessionPaused: boolean;
  events: SessionEvent[];
}

const idleSequence: SequenceRuntime = {
  phase: "idle",
  game: null,
  currentRoundIndex: 0,
  currentCycle: 1,
  startedAt: null,
  elapsedBeforeCurrentSegmentMs: 0,
  currentSegmentStartedAt: null,
  sessionPaused: false,
  events: [],
};

function activeRounds(game: GameSequence | null): Round[] {
  return [...(game?.rounds ?? [])]
    .filter((round) => round.isActive)
    .sort((left, right) => left.orderIndex - right.orderIndex);
}

function makeEvent(type: SessionEvent["type"], details: Partial<SessionEvent> = {}): SessionEvent {
  return {
    type,
    timestamp: new Date().toISOString(),
    ...details,
  };
}

function elapsedAt(runtime: SequenceRuntime, now: number): number {
  if (runtime.currentSegmentStartedAt === null) {
    return runtime.elapsedBeforeCurrentSegmentMs;
  }
  return runtime.elapsedBeforeCurrentSegmentMs + Math.max(0, now - runtime.currentSegmentStartedAt);
}

export interface TurnTimerController {
  timer: ReturnType<typeof useTimerEngine>;
  phase: SequencePhase;
  game: GameSequence | null;
  activeRounds: Round[];
  currentRound: Round | null;
  nextRound: Round | null;
  currentRoundIndex: number;
  currentCycle: number;
  elapsedMs: number;
  roundProgressText: string;
  quickDurationMs: number;
  setQuickDuration: (durationMs: number) => void;
  startQuickTimer: () => void;
  togglePause: () => void;
  resetTimer: () => void;
  startGame: (game: GameSequence) => void;
  doOver: () => void;
  skip: () => void;
  restart: () => void;
  endGame: () => void;
  runAgain: () => void;
}

export function useTurnTimerController(
  onHistoryRecord: (record: HistoryRecord) => void,
  quickSound: TimerSound,
): TurnTimerController {
  const [quickDurationMs, persistQuickDuration] = usePersistentState(
    "turntimer.quickDurationMs",
    25_000,
  );
  const [sequence, setSequence] = useState<SequenceRuntime>(idleSequence);
  const timer = useTimerEngine(quickDurationMs);
  const handledRunRef = useRef(-1);
  const sequenceRef = useRef(sequence);
  sequenceRef.current = sequence;

  const rounds = useMemo(() => activeRounds(sequence.game), [sequence.game]);
  const currentRound = rounds[sequence.currentRoundIndex] ?? null;

  const configureRound = useCallback(
    (round: Round) => {
      timer.configure(round.durationSeconds * 1_000, !round.startPaused);
    },
    [timer],
  );

  const completeSequence = useCallback(
    (runtime: SequenceRuntime, events: SessionEvent[]) => {
      const now = performance.now();
      const elapsedMs = elapsedAt(runtime, now);
      const endedEvents = [...events, makeEvent("gameEnded")];
      const game = runtime.game;
      if (!game || !runtime.startedAt) return;

      setSequence({
        ...runtime,
        phase: "gameOver",
        elapsedBeforeCurrentSegmentMs: elapsedMs,
        currentSegmentStartedAt: null,
        events: endedEvents,
      });

      onHistoryRecord({
        id: crypto.randomUUID(),
        gameTitle: game.title,
        events: endedEvents,
        playerNames: activeRounds(game).map((round) => round.name),
        playedAt: runtime.startedAt,
        elapsedSeconds: Math.max(0, Math.round(elapsedMs / 1_000)),
        completedRounds: endedEvents.filter((event) => event.type === "roundStarted").length,
      });
    },
    [onHistoryRecord],
  );

  const advance = useCallback(
    (completion: "finished" | "skipped") => {
      const runtime = sequenceRef.current;
      if (runtime.phase !== "playing" || !runtime.game) return;
      const currentRounds = activeRounds(runtime.game);
      const round = currentRounds[runtime.currentRoundIndex];
      if (!round) return;

      const events =
        completion === "finished"
          ? [...runtime.events, makeEvent("roundFinished", { playerName: round.name })]
          : [...runtime.events, makeEvent("skipped", { playerName: round.name })];
      const nextIndex = runtime.currentRoundIndex + 1;

      if (nextIndex < currentRounds.length) {
        const next = currentRounds[nextIndex];
        if (!next) return;
        const nextRuntime = {
          ...runtime,
          currentRoundIndex: nextIndex,
          events: [
            ...events,
            makeEvent("roundStarted", { playerName: next.name, emoji: next.emoji }),
          ],
        };
        setSequence(nextRuntime);
        configureRound(next);
        return;
      }

      if (runtime.currentCycle < Math.max(runtime.game.roundCount, 1)) {
        const next = currentRounds[0];
        if (!next) return;
        const nextRuntime = {
          ...runtime,
          currentRoundIndex: 0,
          currentCycle: runtime.currentCycle + 1,
          events: [
            ...events,
            makeEvent("roundStarted", { playerName: next.name, emoji: next.emoji }),
          ],
        };
        setSequence(nextRuntime);
        configureRound(next);
        return;
      }

      completeSequence(runtime, events);
    },
    [completeSequence, configureRound],
  );

  useEffect(() => {
    if (timer.state.status !== "finished" || handledRunRef.current === timer.state.runID) return;
    handledRunRef.current = timer.state.runID;
    const runtime = sequenceRef.current;
    const sound = activeRounds(runtime.game)[runtime.currentRoundIndex]?.sound ?? quickSound;
    playFinishSound(sound);

    if (runtime.phase === "playing") {
      advance("finished");
    } else {
      timer.reset();
    }
  }, [advance, quickSound, timer]);

  const setQuickDuration = useCallback(
    (durationMs: number) => {
      persistQuickDuration(durationMs);
      timer.setDuration(durationMs);
    },
    [persistQuickDuration, timer],
  );

  const startQuickTimer = useCallback(() => {
    if (sequenceRef.current.phase !== "idle") return;
    prepareAudio();
    timer.play();
  }, [timer]);

  const startGame = useCallback(
    (game: GameSequence) => {
      const currentRounds = activeRounds(game);
      const firstRound = currentRounds[0];
      if (!firstRound) return;
      prepareAudio();
      const startedAt = new Date().toISOString();
      const runtime: SequenceRuntime = {
        phase: "playing",
        game: structuredClone(game),
        currentRoundIndex: 0,
        currentCycle: 1,
        startedAt,
        elapsedBeforeCurrentSegmentMs: 0,
        currentSegmentStartedAt: performance.now(),
        sessionPaused: false,
        events: [
          makeEvent("gameStarted"),
          makeEvent("roundStarted", {
            playerName: firstRound.name,
            emoji: firstRound.emoji,
          }),
        ],
      };
      setSequence(runtime);
      configureRound(firstRound);
    },
    [configureRound],
  );

  const togglePause = useCallback(() => {
    const runtime = sequenceRef.current;
    if (timer.state.status === "running") {
      timer.pause();
      if (runtime.phase === "playing" && !runtime.sessionPaused) {
        const elapsed = elapsedAt(runtime, performance.now());
        setSequence({
          ...runtime,
          elapsedBeforeCurrentSegmentMs: elapsed,
          currentSegmentStartedAt: null,
          sessionPaused: true,
          events: [...runtime.events, makeEvent("paused")],
        });
      }
      return;
    }

    if (timer.state.status === "paused" || timer.state.status === "notStarted") {
      prepareAudio();
      timer.play();
      if (runtime.phase === "playing" && runtime.sessionPaused) {
        setSequence({
          ...runtime,
          currentSegmentStartedAt: performance.now(),
          sessionPaused: false,
          events: [...runtime.events, makeEvent("resumed")],
        });
      }
    }
  }, [timer]);

  const resetTimer = useCallback(() => {
    if (sequenceRef.current.phase === "idle") timer.reset();
  }, [timer]);

  const skip = useCallback(() => advance("skipped"), [advance]);

  const restart = useCallback(() => {
    const runtime = sequenceRef.current;
    const round = activeRounds(runtime.game)[runtime.currentRoundIndex];
    if (runtime.phase !== "playing" || !round) return;
    setSequence({
      ...runtime,
      events: [
        ...runtime.events,
        makeEvent("restartTimer", { playerName: round.name }),
        makeEvent("roundStarted", { playerName: round.name, emoji: round.emoji }),
      ],
    });
    configureRound(round);
  }, [configureRound]);

  const doOver = useCallback(() => {
    const runtime = sequenceRef.current;
    if (runtime.phase !== "playing" || runtime.currentRoundIndex <= 0) return;
    const previousIndex = runtime.currentRoundIndex - 1;
    const previous = activeRounds(runtime.game)[previousIndex];
    if (!previous) return;
    setSequence({
      ...runtime,
      currentRoundIndex: previousIndex,
      events: [
        ...runtime.events,
        makeEvent("doOver", { previousPlayer: previous.name }),
        makeEvent("roundStarted", { playerName: previous.name, emoji: previous.emoji }),
      ],
    });
    configureRound(previous);
  }, [configureRound]);

  const endGame = useCallback(() => {
    setSequence(idleSequence);
    timer.configure(quickDurationMs);
  }, [quickDurationMs, timer]);

  const runAgain = useCallback(() => {
    const game = sequenceRef.current.game;
    if (game) startGame(game);
  }, [startGame]);

  const nextRound = useMemo(() => {
    if (!currentRound || !sequence.game) return null;
    const nextIndex = sequence.currentRoundIndex + 1;
    if (nextIndex < rounds.length) return rounds[nextIndex] ?? null;
    if (sequence.currentCycle < Math.max(sequence.game.roundCount, 1)) return rounds[0] ?? null;
    return null;
  }, [currentRound, rounds, sequence.currentCycle, sequence.currentRoundIndex, sequence.game]);

  const roundProgressText = useMemo(() => {
    const countingRounds = rounds.filter((round) => round.countsAsPlayer);
    if (countingRounds.length === 0) {
      return `Round ${sequence.currentRoundIndex + 1} of ${rounds.length}`;
    }
    const countingIndex = Math.max(
      1,
      rounds
        .slice(0, sequence.currentRoundIndex + 1)
        .filter((round) => round.countsAsPlayer).length,
    );
    return `Turn ${countingIndex} of ${countingRounds.length}`;
  }, [currentRound, rounds, sequence.currentRoundIndex]);

  return {
    timer,
    phase: sequence.phase,
    game: sequence.game,
    activeRounds: rounds,
    currentRound,
    nextRound,
    currentRoundIndex: sequence.currentRoundIndex,
    currentCycle: sequence.currentCycle,
    elapsedMs: elapsedAt(sequence, timer.clockNow),
    roundProgressText,
    quickDurationMs,
    setQuickDuration,
    startQuickTimer,
    togglePause,
    resetTimer,
    startGame,
    doOver,
    skip,
    restart,
    endGame,
    runAgain,
  };
}
