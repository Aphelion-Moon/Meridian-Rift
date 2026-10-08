import { useEffect, useId, useRef, useState } from 'react';
import { useDebouncedCommit } from './useDebouncedCommit';

/** Bounded, keyboard-accessible adjustment with exact entry and delayed updates. */
export function AdjustmentSlider(props: {
  label: string;
  value: number;
  min: number;
  max: number;
  step?: number;
  wholeNumbers?: boolean;
  unit?: string;
  disabled?: boolean;
  onChange: (value: number) => void;
}) {
  const {
    label,
    value,
    min,
    max,
    step = 1,
    wholeNumbers = false,
    unit = '',
    disabled,
    onChange,
  } = props;
  const id = useId();
  const [draft, setDraft] = useState(value);
  const [exact, setExact] = useState(String(value));
  const editing = useRef(false);
  const dragging = useRef(false);
  const latest = useRef(value);
  const { pending: dirty, schedule, flush } = useDebouncedCommit(onChange);
  useEffect(() => {
    if (!dirty.current && !editing.current && !dragging.current) {
      latest.current = value;
      setDraft(value);
      setExact(String(value));
    }
  }, [value]);
  const update = (next: number) => {
    if (!Number.isFinite(next)) return;
    const bounded = Math.max(
      min,
      Math.min(max, wholeNumbers ? Math.round(next) : next),
    );
    const changed = bounded !== latest.current;
    latest.current = bounded;
    setDraft(bounded);
    setExact(String(bounded));
    if (changed) schedule(bounded);
  };
  const commitExact = () => {
    editing.current = false;
    if (exact.trim() && Number.isFinite(Number(exact))) update(Number(exact));
    else setExact(String(latest.current));
    flush();
  };
  return (
    <div className="AdjustmentSlider">
      <label id={`${id}-label`} htmlFor={id}>
        {label}
      </label>
      <div className="AdjustmentSlider__row">
        <input
          id={id}
          type="range"
          aria-labelledby={`${id}-label`}
          aria-valuetext={draft + unit}
          min={min}
          max={max}
          step={step}
          value={draft}
          disabled={disabled}
          onPointerDown={() => {
            dragging.current = true;
          }}
          onChange={(event) => update(Number(event.currentTarget.value))}
          onPointerUp={() => {
            dragging.current = false;
            flush();
          }}
          onPointerCancel={() => {
            dragging.current = false;
            flush();
          }}
          onKeyUp={flush}
          onBlur={flush}
        />
        <input
          className="Input AdjustmentSlider__number"
          type="text"
          inputMode="decimal"
          aria-label={`${label} exact value`}
          value={exact}
          disabled={disabled}
          onFocus={() => {
            editing.current = true;
          }}
          onChange={(event) => setExact(event.currentTarget.value)}
          onBlur={commitExact}
          onKeyUp={(event) => {
            if (event.key === 'Enter') event.currentTarget.blur();
          }}
        />
        <span>{unit}</span>
      </div>
      <div className="AdjustmentSlider__limits" aria-hidden="true">
        <span>
          {min}
          {unit}
        </span>
        <span>
          {max}
          {unit}
        </span>
      </div>
    </div>
  );
}
