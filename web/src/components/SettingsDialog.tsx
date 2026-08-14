import { useEffect, useRef } from "react";
import type { TimerSound } from "../types";
import { Icon } from "./Icon";

interface SettingsDialogProps {
  onClose: () => void;
  onSoundChange: (sound: TimerSound) => void;
  sound: TimerSound;
}

export function SettingsDialog({ onClose, onSoundChange, sound }: SettingsDialogProps) {
  const dialogRef = useRef<HTMLDialogElement>(null);

  useEffect(() => {
    const dialog = dialogRef.current;
    if (!dialog) return;
    dialog.showModal();
    return () => dialog.close();
  }, []);

  return (
    <dialog
      className="settings-dialog"
      onCancel={(event) => {
        event.preventDefault();
        onClose();
      }}
      onClose={onClose}
      ref={dialogRef}
    >
      <header>
        <div>
          <span className="section-label">Turn Timer</span>
          <h2>Settings</h2>
        </div>
        <button aria-label="Close settings" className="icon-button" onClick={onClose} type="button">
          <Icon name="close" />
        </button>
      </header>
      <label className="field-block">
        <span>Quick timer sound</span>
        <select onChange={(event) => onSoundChange(event.target.value as TimerSound)} value={sound}>
          <option value="chime">Chime</option>
          <option value="bright">Bright</option>
          <option value="deep">Deep</option>
        </select>
      </label>
      <p>
        Templates and history stay on this browser. Export a template when you want a portable
        copy.
      </p>
      <button className="button button--primary settings-dialog__done" onClick={onClose} type="button">
        Done
      </button>
    </dialog>
  );
}
