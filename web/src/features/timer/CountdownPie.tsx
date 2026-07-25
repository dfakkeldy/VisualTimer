import type { CSSProperties } from "react";
import type { TimerStatus } from "../../types";
import { Icon } from "../../components/Icon";

interface CountdownPieProps {
  color: string;
  progress: number;
  status: TimerStatus;
  onToggle: () => void;
}

export function CountdownPie({ color, onToggle, progress, status }: CountdownPieProps) {
  const elapsed = Math.min(1, Math.max(0, 1 - progress));
  const style = {
    "--pie-color": color,
    "--pie-elapsed": `${elapsed * 360}deg`,
  } as CSSProperties;
  const isRunning = status === "running";
  const label = isRunning ? "Pause timer" : status === "paused" ? "Resume timer" : "Start timer";

  return (
    <button
      aria-label={label}
      className="countdown-pie"
      data-status={status}
      onClick={onToggle}
      style={style}
      type="button"
    >
      <span className="countdown-pie__center">
        <Icon name={isRunning ? "pause" : "play"} size={52} />
      </span>
    </button>
  );
}
