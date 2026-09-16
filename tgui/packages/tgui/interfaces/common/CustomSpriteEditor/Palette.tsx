// THIS IS AN APHELION UI FILE
import {
  autoUpdate,
  FloatingPortal,
  flip,
  offset,
  shift,
  useFloating,
  useTransitionStatus,
} from '@floating-ui/react';
import { useAtom } from 'jotai';
import { type ReactNode, useEffect, useRef, useState } from 'react';
import transparency_checkerboard from 'tgui/assets/transparency_checkerboard.svg';
import { useBackend } from 'tgui/backend';
import { Button, Divider, Section, Stack } from 'tgui-core/components';
import { KEY_DELETE } from 'tgui-core/keycodes';
import { currentColorAtom } from '../SpriteEditor/atoms';
import {
  colorsAreEqual,
  colorToCssString,
  hsv2rgb,
  isRgb,
  parseHexColorString,
} from '../SpriteEditor/colorSpaces';
import type { EditorColor, RGBA } from '../SpriteEditor/Types/types';

/** Multiply displayed RGB channels without changing the stored shade or alpha. */
const tintColor = (color: EditorColor, tint: EditorColor): RGBA => {
  const source = isRgb(color) ? color : hsv2rgb(color);
  const multiplier = isRgb(tint) ? tint : hsv2rgb(tint);
  return {
    r: Math.round((source.r * multiplier.r) / 255),
    g: Math.round((source.g * multiplier.g) / 255),
    b: Math.round((source.b * multiplier.b) / 255),
    a: source.a,
  };
};

const PaletteContextMenu = ({
  anchor,
  children,
}: {
  anchor: HTMLElement;
  children: ReactNode;
}) => {
  const { refs, floatingStyles, context, placement } = useFloating({
    elements: { reference: anchor },
    open: true,
    placement: 'bottom-start',
    transform: false,
    middleware: [offset(6), flip({ padding: 6 }), shift()],
    whileElementsMounted: (reference, floating, update) =>
      autoUpdate(reference, floating, update, {
        ancestorResize: false,
        ancestorScroll: false,
        elementResize: false,
      }),
  });
  const { isMounted, status } = useTransitionStatus(context, { duration: 200 });
  return (
    isMounted && (
      <FloatingPortal id="tgui-root">
        <div
          ref={refs.setFloating}
          className="Floating Floating--animated Tooltip"
          data-position={placement}
          data-transition={status}
          style={{ ...floatingStyles, pointerEvents: 'auto' }}
        >
          {children}
        </div>
      </FloatingPortal>
    )
  );
};

type CustomPaletteSectionProps = {
  colors: EditorColor[];
  selectedColor: EditorColor;
  onClickColor: (
    color: EditorColor,
    rightClick: boolean,
    index: number,
  ) => void;
  onClickAddColor: () => void;
  onRemoveColor: (index: number) => void;
  colorContextMenu: (index: number, close: () => void) => ReactNode;
  readOnly?: boolean;
  title?: string;
  canAddColor?: boolean;
  disabledColors?: boolean[];
  disabledColorTooltip?: string;
  footer?: ReactNode;
};

const CustomPaletteSection = ({
  colors,
  selectedColor,
  onClickColor,
  onClickAddColor,
  onRemoveColor,
  colorContextMenu,
  readOnly = false,
  title = 'Palette',
  canAddColor,
  disabledColors,
  disabledColorTooltip,
  footer,
}: CustomPaletteSectionProps) => {
  const [contextIndex, setContextIndex] = useState<number>();
  const anchorRef = useRef<HTMLElement>(null);
  const menuRef = useRef<HTMLDivElement>(null);
  useEffect(() => setContextIndex(undefined), [JSON.stringify(colors)]);
  useEffect(() => {
    if (contextIndex === undefined) return;
    const dismissOutside = (event: Event) => {
      if (!menuRef.current?.contains(event.target as Node))
        setContextIndex(undefined);
    };
    const dismissEscape = (event: KeyboardEvent) => {
      if (event.key === 'Escape') setContextIndex(undefined);
    };
    document.addEventListener('mousedown', dismissOutside, true);
    document.addEventListener('contextmenu', dismissOutside, true);
    document.addEventListener('keydown', dismissEscape);
    return () => {
      document.removeEventListener('mousedown', dismissOutside, true);
      document.removeEventListener('contextmenu', dismissOutside, true);
      document.removeEventListener('keydown', dismissEscape);
    };
  }, [contextIndex]);
  return (
    <Section title={title}>
      <Stack
        className="CustomSpriteEditor__colors"
        style={{ flexWrap: 'wrap', gap: '0.5rem' }}
      >
        {colors.map((color, i) => {
          const displayColor = colorToCssString(color);
          const disabled = disabledColors?.[i];
          const button = (
            <Button
              inline
              aria-pressed={colorsAreEqual(color, selectedColor)}
              className="SpriteEditor__plainSwatch"
              width="2em"
              height="2em"
              disabled={disabled}
              tooltip={
                disabled
                  ? disabledColorTooltip
                  : 'Wheel or [ / ]: previous / next color.'
              }
              onClick={() => onClickColor(color, false, i)}
              onMouseOver={(ev) => {
                // Unavailable saved colors still support keyboard removal.
                ev.currentTarget.tabIndex = 0;
                ev.currentTarget.focus();
              }}
              onContextMenu={(ev) => {
                anchorRef.current = ev.currentTarget.parentElement;
                setContextIndex(i);
                ev.preventDefault();
              }}
              style={{
                backgroundImage: `linear-gradient(${displayColor}, ${displayColor}), url(${transparency_checkerboard})`,
              }}
            />
          );
          return (
            <Stack.Item
              key={i}
              m={0}
              onKeyDown={(ev) => {
                if (!readOnly && ev.keyCode === KEY_DELETE) {
                  onRemoveColor(i + 1);
                  setContextIndex(undefined);
                  ev.preventDefault();
                }
              }}
            >
              <span style={{ display: 'inline-flex' }}>{button}</span>
              {contextIndex === i && anchorRef.current && (
                <PaletteContextMenu anchor={anchorRef.current}>
                  <div ref={menuRef}>
                    {colorContextMenu(i, () => setContextIndex(undefined))}
                  </div>
                </PaletteContextMenu>
              )}
            </Stack.Item>
          );
        })}
        {!readOnly && canAddColor && (
          <Stack.Item m={0}>
            <Button
              inline
              icon="plus"
              width="2em"
              height="2em"
              onClick={onClickAddColor}
            />
          </Stack.Item>
        )}
      </Stack>
      {!!footer && (
        <>
          <Divider />
          {footer}
        </>
      )}
    </Section>
  );
};

export const CustomSpritePalette = ({
  blending,
  serverPalette,
  customPalette,
  availableColors,
  maxCustomColors,
  displayTint,
}: {
  serverPalette: string[];
  customPalette: string[];
  availableColors: string[];
  maxCustomColors: number;
  displayTint: string | null;
  blending?: ReactNode;
}) => {
  const { act } = useBackend();
  const [currentColor, setCurrentColor] = useAtom(currentColorAtom);
  const colors = serverPalette.map(parseHexColorString);
  const tint = displayTint ? parseHexColorString(displayTint) : undefined;
  const savedColors = customPalette.map((color) => {
    const raw = parseHexColorString(color);
    return tint ? tintColor(raw, tint) : raw;
  });
  const disabledColors = savedColors.map(
    (color) => !availableColors.includes(colorToCssString(color)),
  );
  const swatches = [...colors, ...savedColors];
  const paletteKey = JSON.stringify([
    serverPalette,
    customPalette,
    displayTint,
    disabledColors,
  ]);
  const lastSelection = useRef<
    | {
        index: number;
        previousColor: EditorColor;
        paletteKey: string;
      }
    | undefined
  >(undefined);
  const selectSwatch = (index: number) => {
    // Keep rapid cycles moving while the server acknowledges a saved shade.
    lastSelection.current = { index, previousColor: currentColor, paletteKey };
    if (index < colors.length) {
      setCurrentColor(swatches[index]);
    } else {
      act('selectCustomColor', { color: customPalette[index - colors.length] });
    }
  };
  useEffect(() => {
    const cycle = (step: number) => {
      const previous = lastSelection.current;
      let index =
        previous?.paletteKey === paletteKey &&
        (colorsAreEqual(currentColor, previous.previousColor) ||
          colorsAreEqual(currentColor, swatches[previous.index]))
          ? previous.index
          : swatches.findIndex((color) => colorsAreEqual(color, currentColor));
      if (index === -1) index = step > 0 ? -1 : 0;
      for (let checked = 0; checked < swatches.length; checked++) {
        index = (index + step + swatches.length) % swatches.length;
        if (disabledColors[index - colors.length]) continue;
        selectSwatch(index);
        return true;
      }
      return false;
    };
    const ignoresShortcut = (event: KeyboardEvent | WheelEvent) => {
      const target = event.target;
      return (
        event.defaultPrevented ||
        event.ctrlKey ||
        event.altKey ||
        event.metaKey ||
        event.shiftKey ||
        !!document.querySelector(
          '.Modal, [role="dialog"], [aria-modal="true"]',
        ) ||
        (target instanceof HTMLElement &&
          (target.closest('input, textarea, select') ||
            target.isContentEditable))
      );
    };
    const keyDown = (event: KeyboardEvent) => {
      if (ignoresShortcut(event) || (event.key !== '[' && event.key !== ']'))
        return;
      if (cycle(event.key === '[' ? -1 : 1)) event.preventDefault();
    };
    const wheel = (event: WheelEvent) => {
      if (ignoresShortcut(event) || !event.deltaY) return;
      const target = event.target;
      if (
        !(target instanceof HTMLElement) ||
        !target.closest(
          '.CustomSpriteEditor__canvas canvas, .CustomSpriteEditor__colors',
        )
      )
        return;
      if (cycle(event.deltaY < 0 ? -1 : 1)) event.preventDefault();
    };
    document.addEventListener('wheel', wheel, { passive: false });
    document.addEventListener('keydown', keyDown);
    return () => {
      document.removeEventListener('wheel', wheel);
      document.removeEventListener('keydown', keyDown);
    };
  });
  return (
    <Stack vertical>
      <Stack.Item>
        <CustomPaletteSection
          colors={colors}
          selectedColor={currentColor}
          onClickColor={(_color, _rightClick, index) => selectSwatch(index)}
          onClickAddColor={() => {}}
          onRemoveColor={() => {}}
          colorContextMenu={(index, close) => {
            const color = serverPalette[index];
            const unavailable = customPalette.includes(color)
              ? 'This color is already saved.'
              : customPalette.length >= maxCustomColors
                ? 'Remove a custom color to make room.'
                : undefined;
            return (
              <Button
                icon="save"
                disabled={!!unavailable}
                tooltip={unavailable}
                onClick={() => {
                  act('savePaletteColor', { color });
                  close();
                }}
              >
                Save
              </Button>
            );
          }}
          readOnly
        />
      </Stack.Item>
      <Stack.Item>
        <CustomPaletteSection
          title="Custom"
          colors={savedColors}
          selectedColor={currentColor}
          onClickColor={(_selected, _rightClick, index) => {
            selectSwatch(colors.length + index);
          }}
          onClickAddColor={() => act('addPaletteColor')}
          onRemoveColor={(index) =>
            act('removePaletteColor', { color: customPalette[index - 1] })
          }
          colorContextMenu={(index, close) => (
            <Button
              icon="trash"
              onClick={() => {
                act('removePaletteColor', { color: customPalette[index] });
                close();
              }}
            >
              Remove
            </Button>
          )}
          canAddColor={customPalette.length < maxCustomColors}
          disabledColors={disabledColors}
          disabledColorTooltip="This drawing has reached its color limit."
          footer={blending}
        />
      </Stack.Item>
    </Stack>
  );
};
