import type { GameSequence, Round, StarterTemplate } from "../types";

const starterDate = "2026-07-25T00:00:00Z";

function round(
  id: string,
  name: string,
  emoji: string,
  colorIndex: number,
  durationSeconds: number,
  orderIndex: number,
  countsAsPlayer = true,
): Round {
  return {
    id,
    name,
    color: { palette: { index: colorIndex } },
    sound: "chime",
    emoji,
    durationSeconds,
    startPaused: false,
    isActive: true,
    orderIndex,
    countsAsPlayer,
  };
}

function sequence(id: string, title: string, rounds: Round[]): GameSequence {
  return {
    id,
    title,
    rounds,
    roundCount: 1,
    createdAt: starterDate,
    modifiedAt: starterDate,
  };
}

export const starterTemplates: StarterTemplate[] = [
  {
    id: "game-night",
    title: "Game Night",
    subtitle: "Player turns plus a table timeout.",
    game: sequence("10000000-0000-4000-8000-000000000001", "Game Night", [
      round("11000000-0000-4000-8000-000000000001", "Alice", "🎲", 0, 60, 0),
      round("11000000-0000-4000-8000-000000000002", "Bob", "🎯", 7, 60, 1),
      round("11000000-0000-4000-8000-000000000003", "Charlie", "♟️", 5, 60, 2),
      round("11000000-0000-4000-8000-000000000004", "Timeout", "⏳", 2, 120, 3, false),
    ]),
  },
  {
    id: "recipe-steps",
    title: "Recipe Steps",
    subtitle: "Prep, simmer, stir, and rest.",
    game: sequence("20000000-0000-4000-8000-000000000001", "Recipe Steps", [
      round("21000000-0000-4000-8000-000000000001", "Prep", "🔪", 6, 60, 0, false),
      round("21000000-0000-4000-8000-000000000002", "Simmer", "🥘", 1, 300, 1, false),
      round("21000000-0000-4000-8000-000000000003", "Flip or Stir", "🥄", 2, 120, 2, false),
      round("21000000-0000-4000-8000-000000000004", "Rest", "⏲️", 5, 180, 3, false),
    ]),
  },
  {
    id: "plant-watering",
    title: "Plant Watering",
    subtitle: "Water zones with a soak pause.",
    game: sequence("30000000-0000-4000-8000-000000000001", "Plant Watering", [
      round("31000000-0000-4000-8000-000000000001", "Herbs", "🌿", 3, 45, 0, false),
      round("31000000-0000-4000-8000-000000000002", "Houseplants", "🪴", 4, 90, 1, false),
      round("31000000-0000-4000-8000-000000000003", "Soak Pause", "💧", 6, 120, 2, false),
      round("31000000-0000-4000-8000-000000000004", "Balcony Pots", "🌱", 5, 90, 3, false),
    ]),
  },
  {
    id: "classroom-stations",
    title: "Classroom Stations",
    subtitle: "Rotate groups through timed stations.",
    game: sequence("40000000-0000-4000-8000-000000000001", "Classroom Stations", [
      round("41000000-0000-4000-8000-000000000001", "Station 1", "📚", 7, 300, 0),
      round("41000000-0000-4000-8000-000000000002", "Station 2", "✏️", 8, 300, 1),
      round("41000000-0000-4000-8000-000000000003", "Station 3", "🧪", 9, 300, 2),
      round("41000000-0000-4000-8000-000000000004", "Clean Up", "🧹", 10, 120, 3, false),
    ]),
  },
  {
    id: "meeting-agenda",
    title: "Meeting Agenda",
    subtitle: "Keep speakers and agenda items moving.",
    game: sequence("50000000-0000-4000-8000-000000000001", "Meeting Agenda", [
      round("51000000-0000-4000-8000-000000000001", "Opening", "👋", 11, 120, 0, false),
      round("51000000-0000-4000-8000-000000000002", "Updates", "📣", 12, 300, 1),
      round("51000000-0000-4000-8000-000000000003", "Discussion", "💬", 13, 600, 2),
      round("51000000-0000-4000-8000-000000000004", "Decisions", "✅", 14, 180, 3, false),
    ]),
  },
  {
    id: "morning-routine",
    title: "Morning Routine",
    subtitle: "Get ready and out the door in 40 minutes.",
    game: sequence("60000000-0000-4000-8000-000000000001", "Morning Routine", [
      round("61000000-0000-4000-8000-000000000001", "Wake Up", "⏰", 2, 900, 0, false),
      round("61000000-0000-4000-8000-000000000002", "Wash Up", "🚿", 6, 300, 1, false),
      round("61000000-0000-4000-8000-000000000003", "Get Dressed", "👕", 7, 120, 2, false),
      round("61000000-0000-4000-8000-000000000004", "Breakfast", "🥣", 1, 600, 3, false),
      round("61000000-0000-4000-8000-000000000005", "Brush Teeth", "🪥", 4, 120, 4, false),
      round("61000000-0000-4000-8000-000000000006", "Pack Essentials", "🎒", 8, 180, 5, false),
      round("61000000-0000-4000-8000-000000000007", "Shoes & Coat", "🧥", 9, 120, 6, false),
      round("61000000-0000-4000-8000-000000000008", "Start Commute", "🚗", 13, 60, 7, false),
    ]),
  },
];

export function cloneSequence(game: GameSequence): GameSequence {
  return structuredClone(game);
}
