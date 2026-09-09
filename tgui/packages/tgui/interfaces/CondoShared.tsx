import { Box, Icon } from 'tgui-core/components';

export const BRIGHTNESS_LEVELS = ['Off', 'Low', 'Normal', 'Bright'];

export const LAMP_COLORS: { name: string; value: string }[] = [
  { name: 'Default', value: '' },
  { name: 'Warm', value: '#ffd6aa' },
  { name: 'White', value: '#ffffff' },
  { name: 'Sun', value: '#fff4c2' },
  { name: 'Red', value: '#ff6b6b' },
  { name: 'Orange', value: '#ffa94d' },
  { name: 'Green', value: '#69db7c' },
  { name: 'Cyan', value: '#66d9e8' },
  { name: 'Blue', value: '#74c0fc' },
  { name: 'Purple', value: '#b197fc' },
  { name: 'Pink', value: '#faa2c1' },
];

type LampColorSwatchesProps = {
  value: string;
  disabled?: boolean;
  onSelect: (value: string) => void;
};

export function LampColorSwatches({
  value,
  disabled = false,
  onSelect,
}: LampColorSwatchesProps) {
  return (
    <Box
      style={{
        display: 'flex',
        flexWrap: 'wrap',
        gap: '4px',
        opacity: disabled ? 0.35 : 1,
      }}
    >
      {LAMP_COLORS.map((swatch) => (
        <button
          key={swatch.name}
          type="button"
          aria-label={swatch.name}
          aria-pressed={value === swatch.value}
          disabled={disabled}
          onClick={() => onSelect(swatch.value)}
          style={{
            width: '22px',
            height: '22px',
            padding: 0,
            borderRadius: '4px',
            cursor: disabled ? 'default' : 'pointer',
            display: 'flex',
            alignItems: 'center',
            justifyContent: 'center',
            background: swatch.value || '#3a3a3a',
            color: '#111',
            border:
              value === swatch.value
                ? '2px solid #69bfff'
                : '2px solid #222',
          }}
        >
          {!swatch.value && <Icon name="ban" size={0.9} />}
        </button>
      ))}
    </Box>
  );
}
