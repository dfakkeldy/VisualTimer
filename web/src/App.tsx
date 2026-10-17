import { useCallback, useState } from "react";
import { AppShell } from "./components/AppShell";
import { SettingsDialog } from "./components/SettingsDialog";
import { starterTemplates } from "./data/starterTemplates";
import { HistoryScreen } from "./features/history/HistoryScreen";
import { TemplatesScreen } from "./features/templates/TemplatesScreen";
import { TimerScreen } from "./features/timer/TimerScreen";
import { usePersistentState } from "./hooks/usePersistentState";
import { useTurnTimerController } from "./hooks/useTurnTimerController";
import type { AppTab, GameSequence, HistoryRecord, TimerSound } from "./types";

export default function App() {
  const [activeTab, setActiveTab] = useState<AppTab>("timer");
  const [settingsOpen, setSettingsOpen] = useState(false);
  const [customTemplates, setCustomTemplates] = usePersistentState<GameSequence[]>(
    "turntimer.customTemplates",
    [],
  );
  const [history, setHistory] = usePersistentState<HistoryRecord[]>("turntimer.history", []);
  const [quickSound, setQuickSound] = usePersistentState<TimerSound>(
    "turntimer.quickSound",
    "chime",
  );

  const addHistoryRecord = useCallback(
    (record: HistoryRecord) => {
      setHistory((current) => [record, ...current]);
    },
    [setHistory],
  );

  const controller = useTurnTimerController(addHistoryRecord, quickSound);

  const saveTemplate = useCallback(
    (game: GameSequence): GameSequence => {
      const existing = customTemplates.some((template) => template.id === game.id);
      const saved: GameSequence = {
        ...structuredClone(game),
        id: existing ? game.id : crypto.randomUUID(),
        createdAt: existing ? game.createdAt : new Date().toISOString(),
        modifiedAt: new Date().toISOString(),
        rounds: game.rounds.map((round, index) => ({ ...round, orderIndex: index })),
      };
      setCustomTemplates((current) => {
        const index = current.findIndex((template) => template.id === saved.id);
        if (index < 0) return [...current, saved];
        return current.map((template) => (template.id === saved.id ? saved : template));
      });
      return saved;
    },
    [customTemplates, setCustomTemplates],
  );

  return (
    <AppShell
      activeTab={activeTab}
      onNavigate={setActiveTab}
      onOpenSettings={() => setSettingsOpen(true)}
    >
      {activeTab === "timer" && <TimerScreen controller={controller} />}
      {activeTab === "templates" && (
        <TemplatesScreen
          customTemplates={customTemplates}
          onSave={saveTemplate}
          onStart={(game) => {
            controller.startGame(game);
            setActiveTab("timer");
          }}
          starterTemplates={starterTemplates}
        />
      )}
      {activeTab === "history" && (
        <HistoryScreen
          onDelete={(id) =>
            setHistory((current) => current.filter((record) => record.id !== id))
          }
          records={history}
        />
      )}
      {settingsOpen && (
        <SettingsDialog
          onClose={() => setSettingsOpen(false)}
          onSoundChange={setQuickSound}
          sound={quickSound}
        />
      )}
    </AppShell>
  );
}
