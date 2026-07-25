import { useState } from "react";
import { Icon } from "../../components/Icon";
import type { HistoryRecord } from "../../types";
import { formatDuration, formatSessionDate } from "../../utils/format";

interface HistoryScreenProps {
  onDelete: (id: string) => void;
  records: HistoryRecord[];
}

export function HistoryScreen({ onDelete, records }: HistoryScreenProps) {
  const [selectedID, setSelectedID] = useState<string | null>(records[0]?.id ?? null);
  const selected = records.find((record) => record.id === selectedID) ?? records[0] ?? null;

  if (records.length === 0) {
    return (
      <section className="history-empty">
        <span aria-hidden="true">
          <Icon name="history" size={44} />
        </span>
        <h1>No sessions yet</h1>
        <p>Completed sequences will appear here.</p>
      </section>
    );
  }

  return (
    <div className="history-layout">
      <section className="history-list">
        <header>
          <span className="section-label">History</span>
          <h1>Recent sessions</h1>
        </header>
        <div>
          {records.map((record) => (
            <button
              aria-current={record.id === selected?.id ? "true" : undefined}
              className={`history-row${record.id === selected?.id ? " history-row--selected" : ""}`}
              key={record.id}
              onClick={() => setSelectedID(record.id)}
              type="button"
            >
              <span className="history-row__icon">
                <Icon name="timer" />
              </span>
              <span>
                <strong>{record.gameTitle}</strong>
                <small>{formatSessionDate(record.playedAt)}</small>
              </span>
              <span>{formatDuration(record.elapsedSeconds)}</span>
            </button>
          ))}
        </div>
      </section>

      {selected && (
        <section className="history-detail">
          <header>
            <div>
              <span className="section-label">Session</span>
              <h2>{selected.gameTitle}</h2>
              <p>{formatSessionDate(selected.playedAt)}</p>
            </div>
            <button
              aria-label={`Delete ${selected.gameTitle} session`}
              className="icon-button danger-icon"
              onClick={() => {
                onDelete(selected.id);
                setSelectedID(null);
              }}
              type="button"
            >
              <Icon name="trash" />
            </button>
          </header>
          <dl className="history-summary">
            <div>
              <dt>Elapsed</dt>
              <dd>{formatDuration(selected.elapsedSeconds)}</dd>
            </div>
            <div>
              <dt>Rounds</dt>
              <dd>{selected.completedRounds}</dd>
            </div>
            <div>
              <dt>People</dt>
              <dd>{selected.playerNames.length}</dd>
            </div>
          </dl>
          <ol className="event-list">
            {selected.events.map((event, index) => (
              <li key={`${event.timestamp}-${event.type}-${index}`}>
                <span className="event-list__dot" />
                <span>
                  <strong>
                    {event.type === "gameStarted" && "Session started"}
                    {event.type === "roundStarted" && `${event.emoji ?? ""} ${event.playerName} started`}
                    {event.type === "roundFinished" && `${event.playerName} finished`}
                    {event.type === "skipped" && `${event.playerName} skipped`}
                    {event.type === "doOver" && `Do-over to ${event.previousPlayer}`}
                    {event.type === "restartTimer" && `${event.playerName} restarted`}
                    {event.type === "paused" && "Paused"}
                    {event.type === "resumed" && "Resumed"}
                    {event.type === "gameEnded" && "Session complete"}
                  </strong>
                  <small>
                    {new Intl.DateTimeFormat(undefined, { timeStyle: "medium" }).format(
                      new Date(event.timestamp),
                    )}
                  </small>
                </span>
              </li>
            ))}
          </ol>
        </section>
      )}
    </div>
  );
}
