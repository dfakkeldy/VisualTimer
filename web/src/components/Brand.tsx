export function Brand({ compact = false }: { compact?: boolean }) {
  return (
    <div className={`brand${compact ? " brand--compact" : ""}`}>
      <span className="brand__mark-frame">
        <img alt="" className="brand__mark" src={`${import.meta.env.BASE_URL}turn-timer-icon.png`} />
      </span>
      <span>Turn Timer</span>
    </div>
  );
}
