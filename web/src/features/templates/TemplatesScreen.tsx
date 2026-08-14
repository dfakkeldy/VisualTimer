import { useMemo, useRef, useState } from "react";
import { Icon } from "../../components/Icon";
import { cloneSequence } from "../../data/starterTemplates";
import {
  decodeTemplateDocument,
  encodeTemplateDocument,
  normalizeSequence,
  safeFileName,
} from "../../domain/templateCodec";
import { paletteNames, timerPalette } from "../../theme";
import type { GameSequence, Round, StarterTemplate, TimerSound } from "../../types";
import { formatDuration, formatDurationLong } from "../../utils/format";

interface TemplatesScreenProps {
  customTemplates: GameSequence[];
  onSave: (game: GameSequence) => GameSequence;
  onStart: (game: GameSequence) => void;
  starterTemplates: StarterTemplate[];
}

interface LibraryItem {
  id: string;
  title: string;
  subtitle: string;
  game: GameSequence;
}

const durationOptions = [5, 10, 15, 25, 30, 45, 60, 90, 120, 180, 300, 600, 900];

function roundColor(round: Round): string {
  if ("custom" in round.color) return `#${round.color.custom.hex}`;
  return timerPalette[round.color.palette.index] ?? timerPalette[0];
}

function customSubtitle(game: GameSequence): string {
  const count = game.rounds.length;
  return `${count} ${count === 1 ? "round" : "rounds"} • ${game.roundCount === 1 ? "once" : `${game.roundCount}x`}`;
}

function downloadTemplate(game: GameSequence): void {
  const data = new Blob([encodeTemplateDocument(game)], { type: "application/json" });
  const url = URL.createObjectURL(data);
  const anchor = document.createElement("a");
  anchor.href = url;
  anchor.download = `${safeFileName(game.title)}.turntimer`;
  anchor.click();
  URL.revokeObjectURL(url);
}

function TemplateRail({
  items,
  onSelect,
  selectedID,
}: {
  items: LibraryItem[];
  onSelect: (item: LibraryItem) => void;
  selectedID: string;
}) {
  return (
    <aside aria-label="Template library" className="template-rail">
      <h2>Templates</h2>
      <div className="template-library">
        {items.map((item) => {
          const firstRound = item.game.rounds[0];
          return (
            <button
              aria-current={selectedID === item.id ? "true" : undefined}
              className={`template-library__item${
                selectedID === item.id ? " template-library__item--selected" : ""
              }`}
              key={item.id}
              onClick={() => onSelect(item)}
              type="button"
            >
              <span aria-hidden="true" className="template-library__emoji">
                {firstRound?.emoji || "⏱️"}
              </span>
              <span>
                <strong>{item.title}</strong>
                <small>{item.subtitle}</small>
              </span>
            </button>
          );
        })}
      </div>
    </aside>
  );
}

function RoundDetails({
  index,
  onDelete,
  onMove,
  onUpdate,
  round,
  totalRounds,
}: {
  index: number;
  onDelete: () => void;
  onMove: (direction: -1 | 1) => void;
  onUpdate: (updates: Partial<Round>) => void;
  round: Round;
  totalRounds: number;
}) {
  const paletteIndex = "palette" in round.color ? round.color.palette.index : 0;

  return (
    <div className="round-details">
      <label>
        <span>Emoji</span>
        <input
          aria-label={`Emoji for ${round.name}`}
          maxLength={4}
          onChange={(event) => onUpdate({ emoji: event.target.value })}
          value={round.emoji}
        />
      </label>
      <label className="round-details__name">
        <span>Name</span>
        <input
          onChange={(event) => onUpdate({ name: event.target.value })}
          value={round.name}
        />
      </label>
      <label>
        <span>Sound</span>
        <select
          onChange={(event) => onUpdate({ sound: event.target.value as TimerSound })}
          value={round.sound}
        >
          <option value="chime">Chime</option>
          <option value="bright">Bright</option>
          <option value="deep">Deep</option>
        </select>
      </label>
      <label>
        <span>Color</span>
        <select
          onChange={(event) =>
            onUpdate({ color: { palette: { index: Number(event.target.value) } } })
          }
          value={paletteIndex}
        >
          {paletteNames.map((name, colorIndex) => (
            <option key={name} value={colorIndex}>
              {name}
            </option>
          ))}
        </select>
      </label>
      <label className="check-field">
        <input
          checked={round.countsAsPlayer}
          onChange={(event) => onUpdate({ countsAsPlayer: event.target.checked })}
          type="checkbox"
        />
        <span>Counts as turn</span>
      </label>
      <label className="check-field">
        <input
          checked={round.startPaused}
          onChange={(event) => onUpdate({ startPaused: event.target.checked })}
          type="checkbox"
        />
        <span>Start paused</span>
      </label>
      <div className="round-details__actions">
        <button
          aria-label={`Move ${round.name} up`}
          className="icon-button"
          disabled={index === 0}
          onClick={() => onMove(-1)}
          type="button"
        >
          <Icon name="up" size={18} />
        </button>
        <button
          aria-label={`Move ${round.name} down`}
          className="icon-button"
          disabled={index === totalRounds - 1}
          onClick={() => onMove(1)}
          type="button"
        >
          <Icon name="down" size={18} />
        </button>
        <button className="danger-button" onClick={onDelete} type="button">
          <Icon name="trash" size={18} />
          Delete
        </button>
      </div>
    </div>
  );
}

export function TemplatesScreen({
  customTemplates,
  onSave,
  onStart,
  starterTemplates,
}: TemplatesScreenProps) {
  const library = useMemo<LibraryItem[]>(
    () => [
      ...starterTemplates.map((template) => ({
        id: template.id,
        title: template.title,
        subtitle: template.subtitle,
        game: template.game,
      })),
      ...customTemplates.map((game) => ({
        id: game.id,
        title: game.title,
        subtitle: customSubtitle(game),
        game,
      })),
    ],
    [customTemplates, starterTemplates],
  );
  const [selectedID, setSelectedID] = useState(library[0]?.id ?? "");
  const [draft, setDraft] = useState<GameSequence>(() =>
    cloneSequence(library[0]?.game ?? starterTemplates[0]!.game),
  );
  const [expandedRoundID, setExpandedRoundID] = useState<string | null>(null);
  const [draggedRoundID, setDraggedRoundID] = useState<string | null>(null);
  const [notice, setNotice] = useState("");
  const fileInputRef = useRef<HTMLInputElement>(null);

  const selectTemplate = (item: LibraryItem) => {
    setSelectedID(item.id);
    setDraft(cloneSequence(item.game));
    setExpandedRoundID(null);
    setNotice("");
  };

  const updateRound = (id: string, updates: Partial<Round>) => {
    setDraft((current) => ({
      ...current,
      rounds: current.rounds.map((round) => (round.id === id ? { ...round, ...updates } : round)),
    }));
  };

  const reorderRound = (fromID: string, targetIndex: number) => {
    setDraft((current) => {
      const sourceIndex = current.rounds.findIndex((round) => round.id === fromID);
      if (sourceIndex < 0 || targetIndex < 0 || targetIndex >= current.rounds.length) return current;
      const next = [...current.rounds];
      const [moved] = next.splice(sourceIndex, 1);
      if (!moved) return current;
      next.splice(targetIndex, 0, moved);
      return {
        ...current,
        rounds: next.map((round, index) => ({ ...round, orderIndex: index })),
      };
    });
  };

  const addRound = () => {
    const nextIndex = draft.rounds.length;
    const newRound: Round = {
      id: crypto.randomUUID(),
      name: `Round ${nextIndex + 1}`,
      color: { palette: { index: nextIndex % timerPalette.length } },
      sound: "chime",
      emoji: "⏱️",
      durationSeconds: 60,
      startPaused: false,
      isActive: true,
      orderIndex: nextIndex,
      countsAsPlayer: true,
    };
    setDraft((current) => ({ ...current, rounds: [...current.rounds, newRound] }));
    setExpandedRoundID(newRound.id);
  };

  const save = () => {
    if (draft.rounds.length === 0) {
      setNotice("Add at least one round before saving.");
      return;
    }
    const saved = onSave(normalizeSequence(draft));
    setDraft(saved);
    setSelectedID(saved.id);
    setNotice("Template saved");
  };

  const importTemplate = async (file: File) => {
    try {
      const document = decodeTemplateDocument(await file.text());
      const imported = onSave({
        ...document.game,
        id: crypto.randomUUID(),
        title: document.title,
      });
      setDraft(imported);
      setSelectedID(imported.id);
      setNotice("Template imported");
    } catch (error) {
      setNotice(error instanceof Error ? error.message : "The template could not be imported.");
    }
  };

  return (
    <div className="templates-layout">
      <TemplateRail items={library} onSelect={selectTemplate} selectedID={selectedID} />

      <section className="template-editor">
        <div className="template-toolbar">
          <input
            accept=".turntimer,application/json"
            className="sr-only"
            onChange={(event) => {
              const file = event.target.files?.[0];
              if (file) void importTemplate(file);
              event.target.value = "";
            }}
            ref={fileInputRef}
            type="file"
          />
          <button className="button" onClick={() => fileInputRef.current?.click()} type="button">
            <Icon name="import" />
            Import
          </button>
          <button className="button" onClick={() => downloadTemplate(draft)} type="button">
            <Icon name="export" />
            Export
          </button>
          <button className="button" onClick={save} type="button">
            <Icon name="save" />
            Save
          </button>
          <button className="button button--primary" onClick={() => onStart(normalizeSequence(draft))} type="button">
            <Icon name="play" />
            Start
          </button>
        </div>

        <div className="template-editor__body">
          <label className="field-block">
            <span>Template name</span>
            <input
              onChange={(event) =>
                setDraft((current) => ({ ...current, title: event.target.value }))
              }
              value={draft.title}
            />
          </label>

          <div className="sequence-editor">
            <span className="section-label">Sequence</span>
            <div className="repeat-control">
              <strong>Repeat Sequence</strong>
              <div className="stepper">
                <button
                  aria-label="Decrease repeats"
                  disabled={draft.roundCount <= 1}
                  onClick={() =>
                    setDraft((current) => ({
                      ...current,
                      roundCount: Math.max(1, current.roundCount - 1),
                    }))
                  }
                  type="button"
                >
                  <Icon name="minus" size={18} />
                </button>
                <span>{draft.roundCount}</span>
                <button
                  aria-label="Increase repeats"
                  onClick={() =>
                    setDraft((current) => ({ ...current, roundCount: current.roundCount + 1 }))
                  }
                  type="button"
                >
                  <Icon name="plus" size={18} />
                </button>
              </div>
            </div>

            <div className="round-list">
              {draft.rounds.map((round, index) => {
                const expanded = expandedRoundID === round.id;
                const availableDurations = durationOptions.includes(round.durationSeconds)
                  ? durationOptions
                  : [...durationOptions, round.durationSeconds].sort((a, b) => a - b);
                return (
                  <div
                    className={`round-row${expanded ? " round-row--expanded" : ""}`}
                    draggable
                    key={round.id}
                    onDragEnd={() => setDraggedRoundID(null)}
                    onDragOver={(event) => event.preventDefault()}
                    onDragStart={() => setDraggedRoundID(round.id)}
                    onDrop={(event) => {
                      event.preventDefault();
                      if (draggedRoundID) reorderRound(draggedRoundID, index);
                      setDraggedRoundID(null);
                    }}
                  >
                    <div className="round-row__summary">
                      <span className="drag-handle" title="Drag to reorder">
                        <Icon name="drag" size={20} />
                      </span>
                      <button
                        aria-label={round.isActive ? `Mark ${round.name} inactive` : `Mark ${round.name} active`}
                        className="round-status"
                        onClick={() => updateRound(round.id, { isActive: !round.isActive })}
                        style={{ background: roundColor(round) }}
                        type="button"
                      >
                        {index + 1}
                      </button>
                      <span className="round-row__emoji" aria-hidden="true">
                        {round.emoji}
                      </span>
                      <strong className="round-row__name">{round.name}</strong>
                      <select
                        aria-label={`Duration for ${round.name}`}
                        onChange={(event) =>
                          updateRound(round.id, { durationSeconds: Number(event.target.value) })
                        }
                        value={round.durationSeconds}
                      >
                        {availableDurations.map((duration) => (
                          <option key={duration} value={duration}>
                            {formatDurationLong(duration)}
                          </option>
                        ))}
                      </select>
                      <button
                        aria-expanded={expanded}
                        aria-label={`Edit ${round.name}`}
                        className="icon-button"
                        onClick={() => setExpandedRoundID(expanded ? null : round.id)}
                        type="button"
                      >
                        <Icon className={expanded ? "rotate-180" : ""} name="chevron" size={20} />
                      </button>
                    </div>
                    {expanded && (
                      <RoundDetails
                        index={index}
                        onDelete={() => {
                          setDraft((current) => ({
                            ...current,
                            rounds: current.rounds
                              .filter((candidate) => candidate.id !== round.id)
                              .map((candidate, orderIndex) => ({ ...candidate, orderIndex })),
                          }));
                          setExpandedRoundID(null);
                        }}
                        onMove={(direction) => reorderRound(round.id, index + direction)}
                        onUpdate={(updates) => updateRound(round.id, updates)}
                        round={round}
                        totalRounds={draft.rounds.length}
                      />
                    )}
                  </div>
                );
              })}
            </div>

            <button className="add-round" onClick={addRound} type="button">
              <span>
                <Icon name="plus" />
              </span>
              Add round
            </button>
          </div>
          <p aria-live="polite" className="editor-notice">
            {notice}
          </p>
        </div>
      </section>
    </div>
  );
}
