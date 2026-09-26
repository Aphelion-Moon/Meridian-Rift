// THIS IS AN APHELION UI FILE
import { type ReactNode, useMemo, useState } from 'react';
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

type ChoicedSelectionProps = {
  name: string;
  catalog: { icons?: Record<string, string> };
  selected: string;
  options?: string[];
  onSelect: (value: string) => void;
  buttons?: ReactNode;
  children?: ReactNode;
};

/** The preferences icon picker, shared with editors using the same spritesheet. */
export function ChoicedSelection(props: ChoicedSelectionProps) {
  const { catalog, name, selected, options, onSelect, buttons, children } =
    props;
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
              {matchingChoices.map(([choice, image]) => (
                <Button
                  key={choice}
                  onClick={() => onSelect(choice)}
                  selected={choice === selected}
                  tooltip={choice}
                  tooltipPosition="right"
                  aria-label={choice}
                  style={{
                    height: `${CELL_SIZE}px`,
                    width: `${CELL_SIZE}px`,
                  }}
                >
                  <Box
                    className={classes([
                      'preferences32x32',
                      image,
                      'centered-image',
                    ])}
                    style={{
                      transform: 'translateX(-50%) translateY(-50%) scale(0.8)',
                    }}
                  />
                </Button>
              ))}
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
}) {
  const { disabled, icons, ...selection } = props;
  return (
    <Floating
      stopChildPropagation
      placement="left-start"
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
