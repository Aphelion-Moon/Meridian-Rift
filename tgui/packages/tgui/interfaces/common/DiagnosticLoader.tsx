// THIS IS AN APHELION UI FILE
import {
  type CSSProperties,
  type ReactNode,
  useEffect,
  useId,
  useState,
} from 'react';
import { clamp } from 'tgui-core/math';
import { classes } from 'tgui-core/react';
import { DiagnosticAcquisition } from './DiagnosticAcquisition';

export type DiagnosticLoaderProps = {
  label?: ReactNode;
  detail?: ReactNode;
  value?: number;
  minValue?: number;
  maxValue?: number;
  size?: 'compact' | 'default' | 'large';
  ariaLabel?: string;
  className?: string;
};

type LoaderStyle = CSSProperties & {
  '--diagnostic-loader-angle': string;
  '--diagnostic-loader-progress': number;
};

const isFiniteNumber = (value: number | undefined): value is number =>
  typeof value === 'number' && Number.isFinite(value);

/**
 * Shared MeridianOS loading instrument. Theme styles alter the fixed layer set
 * or opt into decorative linework; the parent retains progress semantics.
 */
export function DiagnosticLoader(props: DiagnosticLoaderProps) {
  const {
    label = 'Please wait…',
    detail,
    value,
    minValue = 0,
    maxValue = 1,
    size = 'default',
    ariaLabel,
    className,
  } = props;
  const labelId = useId();
  const detailId = useId();
  const [isDocumentVisible, setIsDocumentVisible] = useState(
    () => typeof document === 'undefined' || !document.hidden,
  );

  const isDeterminate =
    isFiniteNumber(value) &&
    isFiniteNumber(minValue) &&
    isFiniteNumber(maxValue) &&
    maxValue > minValue;
  const clampedValue = isDeterminate
    ? clamp(value, minValue, maxValue)
    : undefined;
  const progress =
    isDeterminate && clampedValue !== undefined
      ? (clampedValue - minValue) / (maxValue - minValue)
      : 0;
  const hasLabel = label !== null && label !== undefined;
  const hasDetail = detail !== null && detail !== undefined;
  const style: LoaderStyle = {
    '--diagnostic-loader-angle': `${progress * 360}deg`,
    '--diagnostic-loader-progress': progress,
  };

  useEffect(() => {
    const updateVisibility = () => setIsDocumentVisible(!document.hidden);

    document.addEventListener('visibilitychange', updateVisibility);
    return () => {
      document.removeEventListener('visibilitychange', updateVisibility);
    };
  }, []);

  return (
    <div
      className={classes([
        'DiagnosticLoader',
        `DiagnosticLoader--${size}`,
        isDeterminate
          ? 'DiagnosticLoader--determinate'
          : 'DiagnosticLoader--indeterminate',
        className,
      ])}
      data-motion={isDocumentVisible ? 'running' : 'paused'}
    >
      <div
        aria-describedby={hasDetail ? detailId : undefined}
        aria-label={ariaLabel}
        aria-labelledby={!ariaLabel && hasLabel ? labelId : undefined}
        aria-valuemax={isDeterminate ? maxValue : undefined}
        aria-valuemin={isDeterminate ? minValue : undefined}
        aria-valuenow={clampedValue}
        className="DiagnosticLoader__instrument"
        role="progressbar"
        style={style}
      >
        <DiagnosticAcquisition />
        <span aria-hidden className="DiagnosticLoader__light">
          <span className="DiagnosticLoader__outerCage" />
          <span className="DiagnosticLoader__innerMarks" />
          <span className="DiagnosticLoader__nodes" />
          <span className="DiagnosticLoader__core" />
          <span className="DiagnosticLoader__progressFill" />
        </span>
        <span aria-hidden className="DiagnosticLoader__tickCrown" />
        <span aria-hidden className="DiagnosticLoader__outerCage" />
        <span aria-hidden className="DiagnosticLoader__progressTrack" />
        <span aria-hidden className="DiagnosticLoader__progressFill" />
        <span aria-hidden className="DiagnosticLoader__innerMarks" />
        <span aria-hidden className="DiagnosticLoader__nodes" />
        <span aria-hidden className="DiagnosticLoader__origin" />
        <span aria-hidden className="DiagnosticLoader__core" />
      </div>
      {hasLabel && (
        <div className="DiagnosticLoader__label" id={labelId}>
          {label}
        </div>
      )}
      {hasDetail && (
        <div className="DiagnosticLoader__detail" id={detailId}>
          {detail}
        </div>
      )}
    </div>
  );
}
