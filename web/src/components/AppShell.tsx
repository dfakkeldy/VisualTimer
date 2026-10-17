import type { PropsWithChildren } from "react";
import type { AppTab } from "../types";
import { Brand } from "./Brand";
import { Icon, type IconName } from "./Icon";

interface AppShellProps extends PropsWithChildren {
  activeTab: AppTab;
  onNavigate: (tab: AppTab) => void;
  onOpenSettings: () => void;
}

const navigation: Array<{ id: AppTab; label: string; icon: IconName }> = [
  { id: "timer", label: "Timer", icon: "timer" },
  { id: "templates", label: "Templates", icon: "templates" },
  { id: "history", label: "History", icon: "history" },
];

function NavigationItems({
  activeTab,
  onNavigate,
}: Pick<AppShellProps, "activeTab" | "onNavigate">) {
  return navigation.map((item) => (
    <button
      aria-current={activeTab === item.id ? "page" : undefined}
      className={`nav-item${activeTab === item.id ? " nav-item--active" : ""}`}
      key={item.id}
      onClick={() => onNavigate(item.id)}
      type="button"
    >
      <Icon name={item.icon} />
      <span>{item.label}</span>
    </button>
  ));
}

export function AppShell({
  activeTab,
  children,
  onNavigate,
  onOpenSettings,
}: AppShellProps) {
  return (
    <div className="app-shell">
      <aside className="side-nav">
        <Brand />
        <nav aria-label="Primary">
          <NavigationItems activeTab={activeTab} onNavigate={onNavigate} />
        </nav>
        <button className="settings-link" onClick={onOpenSettings} type="button">
          <Icon name="settings" />
          <span>Settings</span>
        </button>
      </aside>

      <header className="mobile-header">
        <Brand compact />
        <button
          aria-label="Settings"
          className="icon-button"
          onClick={onOpenSettings}
          type="button"
        >
          <Icon name="settings" size={26} />
        </button>
      </header>

      <main className="app-content">{children}</main>

      <nav aria-label="Primary" className="bottom-nav">
        <NavigationItems activeTab={activeTab} onNavigate={onNavigate} />
      </nav>
    </div>
  );
}
