// THIS IS AN APHELION UI FILE
// Run from tgui/: bun benchmarks/native-menu.ts
// Measures placement arithmetic only, not DOM layout or DreamSeeker rendering.
import {
  type MenuBounds,
  placeNativeMenu,
} from '../packages/tgui/layouts/nativeMenuPlacement';

const bounds = { left: 8, top: 40, right: 842, bottom: 700 };
const preferred = { left: 552, top: 44, width: 264, height: 520 };
const minimum = { width: 180, height: 138 };
const cases: Record<string, MenuBounds[]> = {
  unobstructed: [{ left: 10, top: 70, right: 200, bottom: 600 }],
  camera: [{ left: 220, top: 90, right: 830, bottom: 688 }],
  eightControls: Array.from({ length: 8 }, (_, index) => ({
    left: 190 + (index % 4) * 160,
    right: 300 + (index % 4) * 160,
    top: 70 + Math.floor(index / 4) * 320,
    bottom: 310 + Math.floor(index / 4) * 320,
  })),
};

for (const [name, obstacles] of Object.entries(cases)) {
  const samples: number[] = [];
  let checksum = 0;
  const iterations = 100_000;
  for (let sample = -1; sample < 7; sample++) {
    const start = performance.now();
    for (let i = 0; i < iterations; i++) {
      checksum +=
        placeNativeMenu(bounds, preferred, minimum, obstacles)?.width ?? 0;
    }
    if (sample >= 0)
      samples.push(((performance.now() - start) * 1000) / iterations);
  }
  samples.sort((a, b) => a - b);
  console.log(
    JSON.stringify({
      name,
      iterations,
      medianMicroseconds: samples[3],
      minMicroseconds: samples[0],
      maxMicroseconds: samples[6],
      checksum,
    }),
  );
}
