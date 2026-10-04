// THIS IS AN APHELION UI FILE
import { Box } from 'tgui-core/components';
import { clamp01 } from 'tgui-core/math';

export type TimeoutBarProps = {
  /** Normalized time remaining, where 1 is full and 0 is expired. */
  value: number;
  ariaLabel?: string;
};

/**
 * A descending, normalized timeout indicator shared by blocking input windows.
 */
export function TimeoutBar(props: TimeoutBarProps) {
  const { ariaLabel = 'Time remaining', value } = props;
  const normalizedValue = Number.isFinite(value) ? clamp01(value) : 0;

  return (
    <div
      aria-label={ariaLabel}
      aria-valuemax={1}
      aria-valuemin={0}
      aria-valuenow={normalizedValue}
      aria-valuetext={`${Math.round(normalizedValue * 100)}% remaining`}
      className="TimeoutBar"
      role="progressbar"
    >
      <Box
        aria-hidden="true"
        className="TimeoutBar__progress"
        style={{ transform: `scaleX(${normalizedValue})` }}
      />
    </div>
  );
}
