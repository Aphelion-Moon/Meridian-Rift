// THIS IS AN APHELION UI FILE
import { type ComponentProps, type ReactNode, useMemo, useState } from 'react';
import {
  Box,
  Button,
  Floating,
  Input,
  Section,
  Stack,
} from 'tgui-core/components';
import { classes } from 'tgui-core/react';
import { createSearch } from 'tgui-core/string';

const CELL_SIZE = 48;
const SELECTION_WIDTH = 5.4;
const SELECTION_HEIGHT = 5.2;
/** Side of the square a zoomed icon fills inside its cell, in CSS pixels. */
const PREVIEW_SIZE = 40;

/** Part of a 32x32 sheet sprite, in sprite pixels from its top left. */
export type SpriteArea = {
  x: number;
  y: number;
  width: number;
  height: number;
};

/**
 * Where each body zone's markings sit in their 32x32 preference sprites, with a pixel to spare,
 * measured from the generated sheet. A marking reaching past its zone's area is cut off in pickers only.
 */
export const MARKING_PREVIEW_AREAS: Record<string, SpriteArea> = {
  head: { x: 6, y: 0, width: 18, height: 16 },
  chest: { x: 6, y: 9, width: 17, height: 19 },
  l_arm: { x: 13, y: 9, width: 12, height: 22 },
  r_arm: { x: 3, y: 9, width: 13, height: 17 },
  l_hand: { x: 16, y: 13, width: 10, height: 13 },
  r_hand: { x: 5, y: 13, width: 11, height: 13 },
  l_leg: { x: 10, y: 17, width: 13, height: 15 },
  r_leg: { x: 6, y: 17, width: 11, height: 15 },
};

/** Zooms a sprite until `area` fills the preview square, over a checkerboard of two-pixel squares. */
function ZoomedSprite(props: { image: string | undefined; area: SpriteArea }) {
  const { image, area } = props;
  const scale = PREVIEW_SIZE / Math.max(area.width, area.height);
  const left = PREVIEW_SIZE / 2 - (area.x + area.width / 2) * scale;
  const top = PREVIEW_SIZE / 2 - (area.y + area.height / 2) * scale;
  return (
    <div
      className="ChoicedSelection__preview"
      style={{
        width: `${PREVIEW_SIZE}px`,
        height: `${PREVIEW_SIZE}px`,
        // Squares follow the sprite's pixel grid, so every pixel borders both shades.
        backgroundSize: `${4 * scale}px ${4 * scale}px`,
        backgroundPosition: `${left}px ${top}px`,
      }}
    >
      <div
        className={classes([
          'preferences32x32',
          image,
          'ChoicedSelection__previewSprite',
        ])}
        style={{ transform: `translate(${left}px, ${top}px) scale(${scale})` }}
      />
    </div>
  );
}

type ChoicedSelectionProps = {
  name: string;
  catalog: { icons?: Record<string, string> };
  selected: string;
  options?: string[];
  onSelect: (value: string) => void;
  buttons?: ReactNode;
  children?: ReactNode;
  /** Zooms every icon to this part of its sprite. */
  previewArea?: SpriteArea;
  /** Options shown but not selectable right now: option -> why, which its tooltip gives. */
  disabledOptions?: Record<string, string>;
};

/** The preferences icon picker, shared with editors using the same spritesheet. */
export function ChoicedSelection(props: ChoicedSelectionProps) {
  const {
    catalog,
    name,
    selected,
    options,
    onSelect,
    buttons,
    children,
    previewArea,
    disabledOptions,
  } = props;
  const [searchText, setSearchText] = useState('');
  const choices = useMemo(
    () =>
      options
        ? options.map((choice) => [choice, catalog.icons?.[choice]] as const)
        : Object.entries(catalog.icons || {}),
    [catalog.icons, options],
  );
  const matchingChoices = useMemo(
    () =>
      searchText
        ? choices.filter(createSearch(searchText, ([choice]) => choice))
        : choices,
    [choices, searchText],
  );

  if (!catalog.icons) {
    return <Box color="red">Provided catalog had no icons!</Box>;
  }

  return (
    <Box
      className="ChoicedSelection"
      style={{
        height: `${CELL_SIZE * SELECTION_HEIGHT}px`,
        width: `${CELL_SIZE * SELECTION_WIDTH}px`,
      }}
    >
      <Stack fill vertical g={0}>
        <Stack.Item>
          <Section
            fill
            title={`Select ${name.toLowerCase()}`}
            buttons={buttons}
          >
            <Input
              autoFocus
              fluid
              placeholder="Search..."
              onChange={setSearchText}
            />
            {children}
          </Section>
        </Stack.Item>
        <Stack.Item grow>
          <Section fill scrollable noTopPadding>
            <Stack wrap>
              {matchingChoices.map(([choice, image]) => {
                const reason = disabledOptions?.[choice];
                return (
                  <Button
                    key={choice}
                    onClick={() => onSelect(choice)}
                    selected={choice === selected}
                    disabled={!!reason}
                    tooltip={reason ? `${choice}: ${reason}` : choice}
                    tooltipPosition="right"
                    aria-label={choice}
                    aria-disabled={reason ? true : undefined}
                    style={{
                      height: `${CELL_SIZE}px`,
                      width: `${CELL_SIZE}px`,
                    }}
                  >
                    {previewArea ? (
                      <ZoomedSprite image={image} area={previewArea} />
                    ) : (
                      <Box
                        className={classes([
                          'preferences32x32',
                          image,
                          'centered-image',
                        ])}
                        style={{
                          transform:
                            'translateX(-50%) translateY(-50%) scale(0.8)',
                        }}
                      />
                    )}
                  </Button>
                );
              })}
            </Stack>
          </Section>
        </Stack.Item>
      </Stack>
    </Box>
  );
}

/** Text-only control opening the shared, locally filtered cached-icon picker. */
export function ChoicedSelectionDropdown(props: {
  name: string;
  icons: Record<string, string>;
  options: string[];
  selected: string;
  onSelect: (value: string) => void;
  disabled?: boolean;
  placement?: ComponentProps<typeof Floating>['placement'];
  previewArea?: SpriteArea;
  /** Options the picker shows but won't select: option -> why. */
  disabledOptions?: Record<string, string>;
}) {
  const { disabled, icons, placement = 'left-start', ...selection } = props;
  return (
    <Floating
      stopChildPropagation
      placement={placement}
      disabled={disabled}
      content={<ChoicedSelection {...selection} catalog={{ icons }} />}
    >
      <Button
        fluid
        disabled={disabled}
        icon="chevron-down"
        iconPosition="right"
        aria-label={`Select ${props.name}`}
      >
        {props.selected}
      </Button>
    </Floating>
  );
}
