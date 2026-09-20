import { useState } from 'react';
import { Button } from 'tgui-core/components';

const colors = [
  '#000000',
  '#404040',
  '#808080',
  '#BFBFBF',
  '#FFFFFF',
  '#FF0000',
  '#00FF00',
  '#0000FF',
  '#FFBF00',
  '#00FFFF',
  '#FF00FF',
];

export function DisplayGradeSwatches() {
  const [clicks, setClicks] = useState(0);
  return (
    <div style={{ background: '#202020', padding: '8px' }}>
      {[1, 128 / 255].map((alpha) => (
        <div key={alpha} style={{ display: 'flex' }}>
          {colors.map((color) => (
            <div
              key={color}
              style={{
                background: color,
                opacity: alpha,
                width: '32px',
                height: '32px',
              }}
            />
          ))}
        </div>
      ))}
      <div
        style={{
          height: '20px',
          background: 'linear-gradient(to right, #000, #fff)',
        }}
      />
      <div style={{ color: '#fff' }}>
        Ordinary text / <span style={{ color: '#ff0000' }}>Danger</span> /{' '}
        <span style={{ color: '#ffbf00' }}>Caution</span> /{' '}
        <span style={{ color: '#00ff00' }}>Ready</span>
      </div>
      <Button onClick={() => setClicks(clicks + 1)}>
        Click target ({clicks})
      </Button>
    </div>
  );
}
