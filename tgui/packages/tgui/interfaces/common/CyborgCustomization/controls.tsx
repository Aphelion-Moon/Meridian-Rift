// THIS IS AN APHELION UI FILE
import {
  type ComponentProps,
  type HTMLAttributes,
  useEffect,
  useRef,
  useState,
} from 'react';
import { Box, Button, Stack } from 'tgui-core/components';
import { useDebouncedCommit } from './useDebouncedCommit';

/** Scope missing tgui-core semantics to the editor without changing global controls. */
function buttonSemantics(
  props: ComponentProps<typeof Button>,
): Pick<
  HTMLAttributes<HTMLDivElement>,
  'role' | 'aria-disabled' | 'onKeyDownCapture'
> {
  return {
    role: 'button',
    'aria-disabled': !!props.disabled,
    // Floating clones tooltip children and replaces Button's key handler.
    // Activate through its click handler so Confirm retains its two-step state.
    onKeyDownCapture: props.tooltip
      ? (event) => {
          if (event.key !== 'Enter' && event.key !== ' ') return;
          event.preventDefault();
          event.stopPropagation();
          if (!props.disabled) event.currentTarget.click();
        }
      : undefined,
  };
}

export const EditorButton = Object.assign(
  (props: ComponentProps<typeof Button>) => (
    <Button
      {...buttonSemantics(props)}
      aria-pressed={props.selected === undefined ? undefined : !!props.selected}
      {...props}
    />
  ),
  {
    Checkbox: (props: ComponentProps<typeof Button.Checkbox>) => (
      <Button.Checkbox
        {...buttonSemantics(props)}
        {...{ role: 'checkbox' }}
        aria-checked={!!props.checked}
        {...props}
      />
    ),
    Confirm: (props: ComponentProps<typeof Button.Confirm>) => (
      <Button.Confirm {...buttonSemantics(props)} {...props} />
    ),
  },
);

export function EditorSelect({
  label,
  value,
  options,
  onChange,
  disabled,
  placeholder,
}: {
  label: string;
  value: string;
  options: { value: string; label: string }[];
  onChange: (value: string) => void;
  disabled?: boolean;
  placeholder?: string;
}) {
  return (
    <select
      className="Input Input--fluid CyborgEditor__select"
      aria-label={label}
      value={value}
      disabled={disabled}
      onChange={(event) => onChange(event.currentTarget.value)}
    >
      {placeholder && <option value="">{placeholder}</option>}
      {options.map((option) => (
        <option key={option.value} value={option.value}>
          {option.label}
        </option>
      ))}
    </select>
  );
}

export function ColorControls({
  colors,
  channels,
  disabled,
  onChange,
}: {
  colors: string[];
  channels: number[];
  disabled?: boolean;
  onChange: (colors: string[]) => void;
}) {
  const [draft, setDraft] = useState(colors);
  const latest = useRef(colors);
  const { pending, schedule, flush } = useDebouncedCommit(onChange);
  // Compare channel values, since unrelated preview updates can rebuild arrays.
  const saved = JSON.stringify(colors);
  useEffect(() => {
    if (!pending.current) {
      latest.current = colors;
      setDraft(colors);
    }
  }, [saved]);
  const setColor = (index: number, value: string) => {
    if (!/^#[\da-f]{6}$/i.test(value) || value === latest.current[index])
      return;
    const next = [...latest.current];
    next[index] = value;
    latest.current = next;
    setDraft(next);
    schedule(next);
  };
  return channels.map((channel) => {
    const index = channel - 1;
    const color = draft[index] || '#ffffff';
    return (
      <Stack key={channel} align="center" mb={0.5}>
        <Stack.Item grow>
          <Box color="label">Channel {channel}</Box>
        </Stack.Item>
        <Stack.Item>
          <input
            type="color"
            aria-label={`Color channel ${channel}`}
            disabled={disabled}
            value={color}
            onChange={(event) => setColor(index, event.currentTarget.value)}
            onBlur={flush}
          />
        </Stack.Item>
        <Stack.Item width="7rem">
          <HexInput
            color={color}
            channel={channel}
            disabled={disabled}
            onCommit={(value) => {
              setColor(index, value);
              flush();
            }}
          />
        </Stack.Item>
      </Stack>
    );
  });
}

/** Rejected text is restored on commit; incomplete text remains editable. */
function HexInput({
  color,
  channel,
  disabled,
  onCommit,
}: {
  color: string;
  channel: number;
  disabled?: boolean;
  onCommit: (value: string) => void;
}) {
  const [text, setText] = useState(color);
  useEffect(() => setText(color), [color]);
  return (
    <input
      className="Input Input--fluid"
      aria-label={`Color channel ${channel} hex`}
      value={text}
      maxLength={7}
      disabled={disabled}
      spellCheck={false}
      onChange={(event) => setText(event.currentTarget.value)}
      onBlur={() => {
        if (/^#[\da-f]{6}$/i.test(text)) onCommit(text);
        else setText(color);
      }}
      onKeyDown={(event) => {
        if (event.key === 'Enter') {
          event.preventDefault();
          event.currentTarget.blur();
        }
      }}
    />
  );
}
