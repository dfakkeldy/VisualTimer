import type {
  GameSequence,
  Round,
  RoundColor,
  TimerSound,
  TurnTimerTemplateDocument,
} from "../types";

export const currentTemplateSchemaVersion = 1;

function isObject(value: unknown): value is Record<string, unknown> {
  return typeof value === "object" && value !== null && !Array.isArray(value);
}

function isString(value: unknown): value is string {
  return typeof value === "string" && value.trim().length > 0;
}

function isTimerSound(value: unknown): value is TimerSound {
  return value === "chime" || value === "bright" || value === "deep";
}

function decodeColor(value: unknown): RoundColor {
  if (!isObject(value)) return { palette: { index: 0 } };

  const palette = value.palette;
  if (
    isObject(palette) &&
    typeof palette.index === "number" &&
    Number.isInteger(palette.index) &&
    palette.index >= 0 &&
    palette.index <= 15
  ) {
    return { palette: { index: palette.index } };
  }

  const custom = value.custom;
  if (isObject(custom) && typeof custom.hex === "string" && /^[0-9a-f]{6}$/i.test(custom.hex)) {
    return { custom: { hex: custom.hex.toUpperCase() } };
  }

  return { palette: { index: 0 } };
}

function decodeRound(value: unknown, index: number): Round {
  if (!isObject(value) || !isString(value.name)) {
    throw new Error(`Round ${index + 1} is missing a name.`);
  }

  const durationSeconds =
    typeof value.durationSeconds === "number" && Number.isFinite(value.durationSeconds)
      ? Math.max(5, Math.round(value.durationSeconds))
      : 5;

  return {
    id: isString(value.id) ? value.id : crypto.randomUUID(),
    name: value.name.trim(),
    color: decodeColor(value.color),
    sound: isTimerSound(value.sound) ? value.sound : "chime",
    emoji: typeof value.emoji === "string" ? value.emoji : "",
    durationSeconds,
    startPaused: value.startPaused === true,
    isActive: value.isActive !== false,
    orderIndex: index,
    countsAsPlayer: value.countsAsPlayer !== false,
  };
}

export function normalizeSequence(game: GameSequence): GameSequence {
  const now = new Date().toISOString();
  return {
    ...structuredClone(game),
    title: game.title.trim() || "Untitled Template",
    roundCount: Math.max(1, Math.round(game.roundCount)),
    rounds: game.rounds.map((round, index) => ({
      ...round,
      name: round.name.trim() || `Round ${index + 1}`,
      durationSeconds: Math.max(5, Math.round(round.durationSeconds)),
      orderIndex: index,
    })),
    modifiedAt: now,
  };
}

export function decodeTemplateDocument(json: string): TurnTimerTemplateDocument {
  let parsed: unknown;
  try {
    parsed = JSON.parse(json);
  } catch {
    throw new Error("This file is not valid JSON.");
  }

  if (!isObject(parsed)) {
    throw new Error("This file is not a valid Turn Timer template.");
  }

  const schemaVersion = parsed.schemaVersion;
  if (typeof schemaVersion !== "number" || !Number.isInteger(schemaVersion)) {
    throw new Error("This file is missing its schema version.");
  }
  if (schemaVersion > currentTemplateSchemaVersion) {
    throw new Error(`This template uses a newer file format (version ${schemaVersion}).`);
  }
  if (!isString(parsed.title) || !isObject(parsed.game)) {
    throw new Error("This file is not a valid Turn Timer template.");
  }

  const rawGame = parsed.game;
  if (!Array.isArray(rawGame.rounds) || rawGame.rounds.length === 0) {
    throw new Error("A template needs at least one round.");
  }

  const now = new Date().toISOString();
  const title = parsed.title.trim();
  const game: GameSequence = {
    id: isString(rawGame.id) ? rawGame.id : crypto.randomUUID(),
    title,
    rounds: rawGame.rounds.map(decodeRound),
    roundCount:
      typeof rawGame.roundCount === "number" ? Math.max(1, Math.round(rawGame.roundCount)) : 1,
    createdAt: isString(rawGame.createdAt) ? rawGame.createdAt : now,
    modifiedAt: isString(rawGame.modifiedAt) ? rawGame.modifiedAt : now,
  };

  return {
    schemaVersion,
    templateID: isString(parsed.templateID) ? parsed.templateID : crypto.randomUUID(),
    title,
    game: normalizeSequence(game),
    createdAt: isString(parsed.createdAt) ? parsed.createdAt : now,
    modifiedAt: isString(parsed.modifiedAt) ? parsed.modifiedAt : now,
    exportedAt: isString(parsed.exportedAt) ? parsed.exportedAt : now,
  };
}

export function makeTemplateDocument(game: GameSequence): TurnTimerTemplateDocument {
  const normalized = normalizeSequence(game);
  const now = new Date().toISOString();
  return {
    schemaVersion: currentTemplateSchemaVersion,
    templateID: crypto.randomUUID(),
    title: normalized.title,
    game: normalized,
    createdAt: normalized.createdAt || now,
    modifiedAt: now,
    exportedAt: now,
  };
}

export function encodeTemplateDocument(game: GameSequence): string {
  return JSON.stringify(makeTemplateDocument(game), null, 2);
}

export function safeFileName(title: string): string {
  const safe = title
    .normalize("NFKD")
    .replace(/[^a-zA-Z0-9]+/g, "-")
    .replace(/^-+|-+$/g, "")
    .toLowerCase();
  return safe || "turn-timer-template";
}
