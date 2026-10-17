import { timerPalette } from "../../theme";
import type { Round } from "../../types";
import { formatDuration } from "../../utils/format";

interface SequenceRailProps {
  currentIndex: number;
  progressText: string;
  rounds: Round[];
}

function colorFor(round: Round): string {
  if ("custom" in round.color) return `#${round.color.custom.hex}`;
  return timerPalette[round.color.palette.index] ?? timerPalette[0];
}

export function SequenceRail({ currentIndex, progressText, rounds }: SequenceRailProps) {
  return (
    <aside aria-label="Sequence progress" className="sequence-rail">
      <h2>{progressText}</h2>
      <ol className="sequence-list">
        {rounds.map((round, index) => (
          <li
            aria-current={index === currentIndex ? "step" : undefined}
            className={index === currentIndex ? "sequence-step sequence-step--current" : "sequence-step"}
            key={round.id}
          >
            <span className="sequence-step__index" style={{ background: colorFor(round) }}>
              {index + 1}
            </span>
            <span className="sequence-step__emoji">{round.emoji}</span>
            <span className="sequence-step__name">{round.name}</span>
            <span className="sequence-step__duration">{formatDuration(round.durationSeconds)}</span>
          </li>
        ))}
      </ol>
    </aside>
  );
}
