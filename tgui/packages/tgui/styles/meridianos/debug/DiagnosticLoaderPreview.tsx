// THIS IS AN APHELION UI FILE
import { type CSSProperties, useState } from 'react';
import { Button, Dropdown, LabeledList, Section } from 'tgui-core/components';
import { DiagnosticLoader } from '../../../interfaces/common/DiagnosticLoader';

const PREVIEW_SIZES = [48, 64, 96, 144] as const;

const CHECKPOINTS = [
  { label: 'Indeterminate', value: 'indeterminate' },
  { label: '0%', value: '0' },
  { label: '1%', value: '1' },
  { label: '50%', value: '50' },
  { label: '99%', value: '99' },
  { label: '100%', value: '100' },
] as const;

type PreviewSampleStyle = CSSProperties & {
  '--loader-preview-scale': number;
  '--loader-preview-size': string;
};

export function DiagnosticLoaderPreview() {
  const [scale, setScale] = useState(1);
  const [checkpoint, setCheckpoint] = useState('indeterminate');
  const [reducedMotion, setReducedMotion] = useState(false);
  const value = checkpoint === 'indeterminate' ? undefined : Number(checkpoint);

  return (
    <Section fill scrollable title="Diagnostic loader">
      <div className="MeridianLoaderPreview__controls">
        <LabeledList>
          <LabeledList.Item label="Preview scale">
            <Dropdown
              options={[
                { displayText: '100%', value: '1' },
                { displayText: '125%', value: '1.25' },
                { displayText: '150%', value: '1.5' },
              ]}
              selected={String(scale)}
              onSelected={(nextScale) => setScale(Number(nextScale))}
            />
          </LabeledList.Item>
          <LabeledList.Item label="State">
            <Dropdown
              options={CHECKPOINTS.map(({ label, value }) => ({
                displayText: label,
                value,
              }))}
              selected={checkpoint}
              onSelected={setCheckpoint}
            />
          </LabeledList.Item>
        </LabeledList>
        <Button.Checkbox
          checked={reducedMotion}
          onClick={() => setReducedMotion(!reducedMotion)}
        >
          Static reduced-motion
        </Button.Checkbox>
      </div>

      <div className="MeridianLoaderPreview__samples">
        {PREVIEW_SIZES.map((size) => {
          const style: PreviewSampleStyle = {
            '--loader-preview-scale': scale,
            '--loader-preview-size': `${size}px`,
          };
          return (
            <div
              className="MeridianLoaderPreview__sample"
              key={size}
              style={style}
            >
              <DiagnosticLoader
                ariaLabel={`Diagnostic loader ${size}px preview`}
                className={
                  reducedMotion ? 'DiagnosticLoader--motion-reduced' : undefined
                }
                label={null}
                maxValue={100}
                value={value}
              />
              <span className="MeridianLoaderPreview__sampleLabel">
                {size}px · {Math.round(scale * 100)}%
              </span>
            </div>
          );
        })}
      </div>
    </Section>
  );
}
