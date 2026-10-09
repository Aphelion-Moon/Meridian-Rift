// THIS IS AN APHELION UI FILE
import {
  autoUpdate,
  flip,
  offset,
  shift,
  useFloating,
} from '@floating-ui/react';
import { useEffect } from 'react';
import { classes } from 'tgui-core/react';

import type { WornMarking } from './data';

type Props = {
  anchor: HTMLButtonElement;
  marking: WornMarking;
  canGlow: boolean;
  onChange: () => void;
  onGlow: () => void;
  onRemove: () => void;
  onClose: () => void;
};

/** Actions for one worn marking, kept in the room so its theme and zoom apply. */
export function MarkingContextMenu(props: Props) {
  const { anchor, marking, canGlow, onChange, onGlow, onRemove, onClose } =
    props;
  const { refs, floatingStyles } = useFloating({
    elements: { reference: anchor },
    placement: 'bottom-start',
    middleware: [offset(6), flip({ padding: 8 }), shift({ padding: 8 })],
    whileElementsMounted: (reference, floating, update) =>
      autoUpdate(reference, floating, update, { elementResize: false }),
  });

  useEffect(() => {
    refs.floating.current?.querySelector<HTMLButtonElement>('button')?.focus();
  }, [anchor, refs.floating]);

  useEffect(() => {
    const outside = (event: Event) => {
      if (!refs.floating.current?.contains(event.target as Node)) onClose();
    };
    const key = (event: KeyboardEvent) => {
      if (event.key === 'Escape') {
        event.preventDefault();
        onClose();
        anchor.focus();
      }
    };
    document.addEventListener('pointerdown', outside, true);
    document.addEventListener('contextmenu', outside, true);
    document.addEventListener('keydown', key);
    return () => {
      document.removeEventListener('pointerdown', outside, true);
      document.removeEventListener('contextmenu', outside, true);
      document.removeEventListener('keydown', key);
    };
  }, [anchor, onClose, refs.floating]);

  const choose = (action: () => void) => {
    onClose();
    action();
  };
  return (
    <div
      ref={refs.setFloating}
      className="MarkingsRoom__drawer MarkingsRoom__contextMenu"
      style={floatingStyles}
      role="menu"
      aria-label={`${marking.name} actions`}
      onContextMenu={(event) => event.preventDefault()}
      onKeyDown={(event) => {
        if (event.key === 'Tab') {
          onClose();
          anchor.focus();
          return;
        }
        if (!['ArrowDown', 'ArrowUp', 'Home', 'End'].includes(event.key))
          return;
        event.preventDefault();
        const items = Array.from(
          event.currentTarget.querySelectorAll<HTMLButtonElement>(
            'button:not(:disabled)',
          ),
        );
        const current = items.indexOf(
          document.activeElement as HTMLButtonElement,
        );
        const next =
          event.key === 'Home'
            ? 0
            : event.key === 'End'
              ? items.length - 1
              : (current +
                  (event.key === 'ArrowDown' ? 1 : -1) +
                  items.length) %
                items.length;
        items[next]?.focus();
      }}
    >
      {/* The actions in the room's own pills, as at its counter. */}
      <button
        type="button"
        role="menuitem"
        className="MarkingsRoom__pill MarkingsRoom__contextAction"
        onClick={() => choose(onChange)}
      >
        <ActionMark path="M2 4h7.5M7.5 2l2 2-2 2M10 8H2.5M4.5 6l-2 2 2 2" />
        Change
      </button>
      <button
        type="button"
        role="menuitem"
        className={classes([
          'MarkingsRoom__pill',
          'MarkingsRoom__contextAction',
          !!marking.emissive && 'MarkingsRoom__pill--on',
        ])}
        disabled={!canGlow && !marking.emissive}
        title={
          !canGlow && !marking.emissive
            ? 'Turn on Allow Emissives on the Character tab to enable glow.'
            : undefined
        }
        onClick={() => choose(onGlow)}
      >
        <span className="MarkingsRoom__contextMark">
          <span className="MarkingsRoom__pillDot" />
        </span>
        {marking.emissive ? 'Disable glow' : 'Enable glow'}
      </button>
      <button
        type="button"
        role="menuitem"
        className="MarkingsRoom__pill MarkingsRoom__contextAction MarkingsRoom__contextAction--remove"
        onClick={() => choose(onRemove)}
      >
        <ActionMark path="M2 3.5h8M4.75 3.5V2h2.5v1.5M3.25 3.5l.5 6.5h4.5l.5-6.5" />
        Remove
      </button>
    </div>
  );
}

/** An action's mark, in the same box as the glow's dot, so that the names line up. */
function ActionMark(props: { path: string }) {
  return (
    <svg
      className="MarkingsRoom__contextMark"
      viewBox="0 0 12 12"
      aria-hidden="true"
    >
      <path d={props.path} />
    </svg>
  );
}
