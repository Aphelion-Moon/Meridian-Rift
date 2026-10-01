// THIS IS AN APHELION UI FILE
import { atom, useAtom } from 'jotai';
import { memo, type SyntheticEvent } from 'react';
import { useBackend } from 'tgui/backend';

import { LightsButton } from '../../../common/LightsOff';

/** Whether the character preview's lights are off, shared by every tab as its turn is. */
export const previewLightsOffAtom = atom(false);

/**
 * Whether the preview's lights are off, and the switch that turns them. The
 * server draws what glows only while they're off, so it's told each time they
 * change.
 */
function usePreviewLights() {
  const [off, setOff] = useAtom(previewLightsOffAtom);
  const { act } = useBackend();
  const toggle = () => {
    setOff(!off);
    act('character_preview_lights', { off: !off });
  };
  return [off, toggle] as const;
}

type Props = {
  fontSize?: string;
  tooltipPosition?: 'top' | 'bottom';
};

/** The preview's lights switch, for a tab's preview controls. */
export function PreviewLightsButton(props: Props) {
  const [off, toggle] = usePreviewLights();
  return (
    <LightsButton
      off={off}
      fontSize={props.fontSize}
      tooltipPosition={props.tooltipPosition}
      onToggle={toggle}
    />
  );
}

/** Keeps a press on the key to the key: no turn, pan or reset of the view under it. */
const keepToKey = (event: SyntheticEvent) => event.stopPropagation();

/** The key's face, its ring and its bulb, on a 28px square. */
const FACE = (
  <>
    <circle cx="14" cy="14" r="13.5" />
    <path d="M14 8.5a3.6 3.6 0 0 0-2.2 6.5c.6.5.8 1 .8 1.6h2.8c0-.6.2-1.1.8-1.6A3.6 3.6 0 0 0 14 8.5zM12 17.5h4M12.5 19.5h3" />
  </>
);

/**
 * The preview's lights switch as a key on its frame, the way a smart mirror
 * has one: a bulb in a ring, in the frame's own colours, that lights up while
 * the lights are off, which says all it needs to. Its face is there twice, as
 * printed and as lit, so the light comes up over the print rather than the
 * print changing colour; see _character_preview.scss. It draws again only
 * when the lights change, not with the preview round it.
 */
export const PreviewLightKey = memo(function PreviewLightKey() {
  const [off, toggle] = usePreviewLights();
  return (
    <button
      type="button"
      className="CharacterPreview__light"
      aria-label="Lights off"
      aria-pressed={off}
      onClick={toggle}
      onPointerDown={keepToKey}
      onDoubleClick={keepToKey}
    >
      <svg viewBox="0 0 28 28" aria-hidden="true">
        <g>{FACE}</g>
        <g>{FACE}</g>
      </svg>
    </button>
  );
});
