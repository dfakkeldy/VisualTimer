import { describe, expect, it } from "vitest";
import { starterTemplates } from "../data/starterTemplates";
import {
  currentTemplateSchemaVersion,
  decodeTemplateDocument,
  encodeTemplateDocument,
  normalizeSequence,
  safeFileName,
} from "./templateCodec";

describe("templateCodec", () => {
  it("round-trips the portable Turn Timer schema", () => {
    const source = starterTemplates[0]!.game;
    const encoded = encodeTemplateDocument(source);
    const decoded = decodeTemplateDocument(encoded);

    expect(decoded.schemaVersion).toBe(currentTemplateSchemaVersion);
    expect(decoded.title).toBe("Game Night");
    expect(decoded.game.rounds).toHaveLength(4);
    expect(decoded.game.rounds[0]).toMatchObject({
      name: "Alice",
      emoji: "🎲",
      durationSeconds: 60,
      color: { palette: { index: 0 } },
      sound: "chime",
    });
  });

  it("normalizes unsafe duration, repeat, and ordering values", () => {
    const source = structuredClone(starterTemplates[0]!.game);
    source.roundCount = 0;
    source.rounds[0]!.durationSeconds = 1;
    source.rounds[0]!.orderIndex = 99;

    const normalized = normalizeSequence(source);
    expect(normalized.roundCount).toBe(1);
    expect(normalized.rounds[0]!.durationSeconds).toBe(5);
    expect(normalized.rounds.map((round) => round.orderIndex)).toEqual([0, 1, 2, 3]);
  });

  it("rejects a schema version newer than this client supports", () => {
    const encoded = JSON.parse(encodeTemplateDocument(starterTemplates[0]!.game)) as Record<
      string,
      unknown
    >;
    encoded.schemaVersion = currentTemplateSchemaVersion + 1;

    expect(() => decodeTemplateDocument(JSON.stringify(encoded))).toThrow(
      "newer file format",
    );
  });

  it("rejects malformed template files without crashing", () => {
    expect(() => decodeTemplateDocument("not json")).toThrow("not valid JSON");
    expect(() => decodeTemplateDocument("{}")).toThrow("schema version");
  });

  it("creates safe portable file names", () => {
    expect(safeFileName("  Morning Routine! ")).toBe("morning-routine");
    expect(safeFileName("***")).toBe("turn-timer-template");
  });
});
