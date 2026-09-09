// THIS IS AN APHELION UI FILE
import type { MouseEvent, ReactNode } from 'react';

/** A single plain-text nav link, styled via the .menu_button family of classes in styles/main.scss. */
export function MenuButton({
  onClick,
  newPoll,
  disabled,
  iconState,
  assetMap,
  className,
  children,
}: {
  onClick?: (event: MouseEvent) => void;
  /** Flashes the button and adds arrow glyphs either side, used for "new poll available". */
  newPoll?: boolean;
  /** Inert - no hover/click behavior. Used for the latejoin queue counter and asset-gated buttons. */
  disabled?: boolean;
  /** Optional PNG icon (e.g. "ready", "join_game") shown before the label, looked up in assetMap. */
  iconState?: string;
  assetMap?: Record<string, string>;
  className?: string;
  children: ReactNode;
}) {
  const classes = ['menu_button'];
  if (newPoll) classes.push('menu_newpoll');
  if (disabled) classes.push('info_display');
  if (className) classes.push(className);

  const iconUrl = iconState ? assetMap?.[`${iconState}.png`] : undefined;

  return (
    <div className={classes.join(' ')} onClick={disabled ? undefined : onClick}>
      {!!iconUrl && <img className="menu_button__icon" src={iconUrl} alt="" />}
      {children}
    </div>
  );
}
