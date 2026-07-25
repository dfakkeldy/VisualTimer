export type AppTab = "timer" | "templates" | "history";

export type TimerStatus = "notStarted" | "running" | "paused" | "finished";
export type SequencePhase = "idle" | "playing" | "gameOver";
export type TimerSound = "chime" | "bright" | "deep";

export type RoundColor =
  | { palette: { index: number } }
  | { custom: { hex: string } };

export interface Round {
  id: string;
  name: string;
  color: RoundColor;
  sound: TimerSound;
  emoji: string;
  durationSeconds: number;
  startPaused: boolean;
  isActive: boolean;
  orderIndex: number;
  countsAsPlayer: boolean;
}

export interface GameSequence {
  id: string;
  title: string;
  rounds: Round[];
  roundCount: number;
  createdAt: string;
  modifiedAt: string;
}

export interface StarterTemplate {
  id: string;
  title: string;
  subtitle: string;
  game: GameSequence;
}

export interface TurnTimerTemplateDocument {
  schemaVersion: number;
  templateID: string;
  title: string;
  game: GameSequence;
  createdAt: string;
  modifiedAt: string;
  exportedAt: string;
}

export type SessionEventType =
  | "gameStarted"
  | "roundStarted"
  | "roundFinished"
  | "skipped"
  | "doOver"
  | "restartTimer"
  | "paused"
  | "resumed"
  | "gameEnded";

export interface SessionEvent {
  type: SessionEventType;
  timestamp: string;
  playerName?: string;
  emoji?: string;
  previousPlayer?: string;
}

export interface HistoryRecord {
  id: string;
  gameTitle: string;
  events: SessionEvent[];
  playerNames: string[];
  playedAt: string;
  elapsedSeconds: number;
  completedRounds: number;
}
