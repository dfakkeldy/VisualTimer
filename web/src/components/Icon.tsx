import type { SVGProps } from "react";

export type IconName =
  | "timer"
  | "templates"
  | "history"
  | "settings"
  | "pause"
  | "play"
  | "doOver"
  | "skip"
  | "restart"
  | "minus"
  | "plus"
  | "import"
  | "export"
  | "save"
  | "drag"
  | "chevron"
  | "trash"
  | "up"
  | "down"
  | "close";

interface IconProps extends SVGProps<SVGSVGElement> {
  name: IconName;
  size?: number;
}

export function Icon({ name, size = 24, ...props }: IconProps) {
  const paths: Record<IconName, React.ReactNode> = {
    timer: (
      <>
        <circle cx="12" cy="13" r="8" />
        <path d="M12 9v4l2.5 2.5M9 2h6M12 2v3" />
      </>
    ),
    templates: (
      <>
        <path d="M5 4h10a2 2 0 0 1 2 2v12H7a2 2 0 0 1-2-2V4Z" />
        <path d="M17 8h2a2 2 0 0 1 2 2v10H9a2 2 0 0 1-2-2M10 9l4 2.5-4 2.5V9Z" />
      </>
    ),
    history: (
      <>
        <path d="M3 12a9 9 0 1 0 3-6.7L3 8" />
        <path d="M3 3v5h5M12 7v5l3 2" />
      </>
    ),
    settings: (
      <>
        <circle cx="12" cy="12" r="3" />
        <path d="M19.4 15a1.7 1.7 0 0 0 .3 1.9l.1.1-2.8 2.8-.1-.1a1.7 1.7 0 0 0-1.9-.3 1.7 1.7 0 0 0-1 1.6v.2h-4V21a1.7 1.7 0 0 0-1-1.6 1.7 1.7 0 0 0-1.9.3l-.1.1L4.2 17l.1-.1a1.7 1.7 0 0 0 .3-1.9A1.7 1.7 0 0 0 3 14H2.8v-4H3a1.7 1.7 0 0 0 1.6-1 1.7 1.7 0 0 0-.3-1.9L4.2 7 7 4.2l.1.1a1.7 1.7 0 0 0 1.9.3A1.7 1.7 0 0 0 10 3V2.8h4V3a1.7 1.7 0 0 0 1 1.6 1.7 1.7 0 0 0 1.9-.3l.1-.1L19.8 7l-.1.1a1.7 1.7 0 0 0-.3 1.9 1.7 1.7 0 0 0 1.6 1h.2v4H21a1.7 1.7 0 0 0-1.6 1Z" />
      </>
    ),
    pause: (
      <>
        <path d="M8 5v14M16 5v14" />
      </>
    ),
    play: <path d="m8 5 11 7-11 7V5Z" />,
    doOver: (
      <>
        <path d="m9 8-4 4 4 4" />
        <path d="M5 12h8a6 6 0 1 1 0 12" transform="translate(0 -6)" />
      </>
    ),
    skip: (
      <>
        <path d="m6 5 9 7-9 7V5ZM18 5v14" />
      </>
    ),
    restart: (
      <>
        <path d="M20 11a8 8 0 1 0-2 6" />
        <path d="M20 5v6h-6" />
      </>
    ),
    minus: <path d="M5 12h14" />,
    plus: <path d="M12 5v14M5 12h14" />,
    import: (
      <>
        <path d="M12 3v12M7 10l5 5 5-5" />
        <path d="M5 19h14" />
      </>
    ),
    export: (
      <>
        <path d="M12 16V4M7 9l5-5 5 5" />
        <path d="M5 20h14" />
      </>
    ),
    save: (
      <>
        <path d="M4 4h13l3 3v13H4V4Z" />
        <path d="M8 4v6h8V4M8 20v-6h8v6" />
      </>
    ),
    drag: (
      <>
        <circle cx="8" cy="7" r="1" fill="currentColor" stroke="none" />
        <circle cx="8" cy="12" r="1" fill="currentColor" stroke="none" />
        <circle cx="8" cy="17" r="1" fill="currentColor" stroke="none" />
        <circle cx="16" cy="7" r="1" fill="currentColor" stroke="none" />
        <circle cx="16" cy="12" r="1" fill="currentColor" stroke="none" />
        <circle cx="16" cy="17" r="1" fill="currentColor" stroke="none" />
      </>
    ),
    chevron: <path d="m8 10 4 4 4-4" />,
    trash: (
      <>
        <path d="M4 7h16M9 7V4h6v3M7 7l1 13h8l1-13M10 11v5M14 11v5" />
      </>
    ),
    up: <path d="m6 15 6-6 6 6" />,
    down: <path d="m6 9 6 6 6-6" />,
    close: <path d="M6 6l12 12M18 6 6 18" />,
  };

  return (
    <svg
      aria-hidden="true"
      fill="none"
      height={size}
      viewBox="0 0 24 24"
      width={size}
      stroke="currentColor"
      strokeLinecap="round"
      strokeLinejoin="round"
      strokeWidth="1.8"
      {...props}
    >
      {paths[name]}
    </svg>
  );
}
