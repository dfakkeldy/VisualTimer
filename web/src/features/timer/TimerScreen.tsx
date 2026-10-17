import { Icon } from "../../components/Icon";
import { timerPalette } from "../../theme";
import type { Round, SequencePhase } from "../../types";
import { formatClock, formatElapsed } from "../../utils/format";
import type { TurnTimerController } from "../../hooks/useTurnTimerController";
import { CountdownPie } from "./CountdownPie";
import { SequenceRail } from "./SequenceRail";

function roundColor(round: Round | null): string {
  if (!round) return timerPalette[0];
  if ("custom" in round.color) return `#${round.color.custom.hex}`;
  return timerPalette[round.color.palette.index] ?? timerPalette[0];
}

function ControlButton({
  disabled = false,
  icon,
  label,
  onClick,
  primary = false,
}: {
  disabled?: boolean;
  icon: "pause" | "play" | "doOver" | "skip" | "restart";
  label: string;
  onClick: () => void;
  primary?: boolean;
}) {
  return (
    <button
      className={`timer-control${primary ? " timer-control--primary" : ""}`}
      disabled={disabled}
      onClick={onClick}
      type="button"
    >
      <Icon name={icon} />
      <span>{label}</span>
    </button>
  );
}

function SessionComplete({
  elapsedMs,
  onEnd,
  onRunAgain,
}: {
  elapsedMs: number;
  onEnd: () => void;
  onRunAgain: () => void;
}) {
  return (
    <section className="session-complete">
      <div className="session-complete__mark" aria-hidden="true">
        ✓
      </div>
      <h1>Session Complete</h1>
      <p>{formatElapsed(elapsedMs)} elapsed</p>
      <div className="session-complete__actions">
        <button className="button button--primary" onClick={onRunAgain} type="button">
          <Icon name="restart" />
          Run again
        </button>
        <button className="button" onClick={onEnd} type="button">
          Back to timer
        </button>
      </div>
    </section>
  );
}

function RoundHeading({ current, next }: { current: Round; next: Round | null }) {
  return (
    <div className="round-heading">
      <div className="round-heading__item">
        <span className="eyeline">Current round</span>
        <strong style={{ color: roundColor(current) }}>
          <span aria-hidden="true">{current.emoji}</span>
          {current.name}
        </strong>
      </div>
      <span className="round-heading__divider" />
      <div className="round-heading__item">
        <span className="eyeline">Next round</span>
        <strong>
          {next ? (
            <>
              <span aria-hidden="true">{next.emoji}</span>
              {next.name}
            </>
          ) : (
            "Finish"
          )}
        </strong>
      </div>
    </div>
  );
}

function QuickTimer({ controller }: { controller: TurnTimerController }) {
  const { timer } = controller;
  const displaySeconds = Math.round(controller.quickDurationMs / 1_000);
  const isRunning = timer.state.status === "running";
  const isPaused = timer.state.status === "paused";

  return (
    <section className="timer-stage timer-stage--quick">
      <div className="duration-stepper" aria-label="Timer duration">
        <button
          aria-label="Decrease duration"
          disabled={timer.state.status !== "notStarted"}
          onClick={() => controller.setQuickDuration(controller.quickDurationMs - 5_000)}
          type="button"
        >
          <Icon name="minus" size={18} />
        </button>
        <span>
          {Math.floor(displaySeconds / 60)}m {displaySeconds % 60}s
        </span>
        <button
          aria-label="Increase duration"
          disabled={timer.state.status !== "notStarted"}
          onClick={() => controller.setQuickDuration(controller.quickDurationMs + 5_000)}
          type="button"
        >
          <Icon name="plus" size={18} />
        </button>
      </div>

      <CountdownPie
        color={timerPalette[0]}
        onToggle={controller.togglePause}
        progress={timer.progress}
        status={timer.state.status}
      />
      <div aria-live="off" className="time-primary">
        {formatClock(timer.remainingMs)}
      </div>
      <div className="quick-actions">
        <ControlButton
          icon={isRunning ? "pause" : "play"}
          label={isRunning ? "Pause" : isPaused ? "Resume" : "Start"}
          onClick={isRunning || isPaused ? controller.togglePause : controller.startQuickTimer}
          primary
        />
        {isPaused && (
          <ControlButton icon="restart" label="Reset" onClick={controller.resetTimer} />
        )}
      </div>
    </section>
  );
}

export function TimerScreen({ controller }: { controller: TurnTimerController }) {
  if (controller.phase === "gameOver") {
    return (
      <SessionComplete
        elapsedMs={controller.elapsedMs}
        onEnd={controller.endGame}
        onRunAgain={controller.runAgain}
      />
    );
  }

  if (controller.phase === "idle" || !controller.currentRound) {
    return <QuickTimer controller={controller} />;
  }

  const isRunning = controller.timer.state.status === "running";
  const isPaused = controller.timer.state.status === "paused";

  return (
    <div className="timer-layout">
      <section className="timer-stage">
        <RoundHeading current={controller.currentRound} next={controller.nextRound} />
        <CountdownPie
          color={roundColor(controller.currentRound)}
          onToggle={controller.togglePause}
          progress={controller.timer.progress}
          status={controller.timer.state.status}
        />
        <div aria-live="off" className="time-primary">
          {formatClock(controller.timer.remainingMs)}
        </div>
        <div className="elapsed-time">
          <span>Elapsed</span>
          <strong>{formatElapsed(controller.elapsedMs)}</strong>
        </div>
        <div className="mobile-progress">{controller.roundProgressText}</div>
        <div className="timer-controls">
          <ControlButton
            icon={isRunning ? "pause" : "play"}
            label={isRunning ? "Pause" : "Resume"}
            onClick={controller.togglePause}
            primary
          />
          <ControlButton
            disabled={controller.currentRoundIndex === 0}
            icon="doOver"
            label="Do-over"
            onClick={controller.doOver}
          />
          <ControlButton icon="skip" label="Skip" onClick={controller.skip} />
          <ControlButton icon="restart" label="Restart" onClick={controller.restart} />
        </div>
        {isPaused && <span className="sr-only">Timer paused</span>}
      </section>
      <SequenceRail
        currentIndex={controller.currentRoundIndex}
        progressText={controller.roundProgressText}
        rounds={controller.activeRounds}
      />
    </div>
  );
}
