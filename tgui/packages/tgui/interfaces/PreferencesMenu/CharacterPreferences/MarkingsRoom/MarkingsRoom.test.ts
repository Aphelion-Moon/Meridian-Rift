// THIS IS AN APHELION UI FILE
import { describe, expect, it } from 'bun:test';

import type { CharacterPreviewDrawing } from '../../types';
import { decodeView, paintedPixels } from './customs';
import { lookMarkings } from './Drawer';
import { type RoomData, unavailableMarkings } from './data';
import {
  frameRegions,
  type MarkingRegions,
  regionAt,
  regionBounds,
} from './regions';

const tile: CharacterPreviewDrawing = {
  id: 1,
  species: 'human',
  slot: 1,
  image: 'data:image/png;base64,tile',
  width: 32,
  height: 32,
  x: 0,
  y: 0,
  frames: { north: 0, south: 32, east: 64, west: 96 },
};

/** 32 rows of `width` with `paint` at some cells: [column, row, character]. */
function rows(width: number, paint: [number, number, string][]) {
  const grid = Array.from({ length: 32 }, () => '0'.repeat(width).split(''));
  for (const [column, row, mark] of paint) {
    grid[row][column] = mark;
  }
  return grid.map((row) => row.join(''));
}

describe('decodeView', () => {
  it('reads a flat view as it is', () => {
    const flat = '1'.repeat(1024);
    expect(decodeView(`f${flat}`, 1024)).toBe(flat);
  });

  it('expands runs of a hex length and an index', () => {
    // 15 transparent, a run of 2, and the other 1007 transparent.
    const runs = `rf022${'f0'.repeat(67)}20`;
    const grid = decodeView(runs, 1024);
    expect(grid?.length).toBe(1024);
    expect(grid?.slice(14, 18)).toBe('0220');
  });

  it("refuses a code that doesn't make the pixels it should", () => {
    expect(decodeView('rf0', 1024)).toBeUndefined();
    expect(decodeView('r00', 16)).toBeUndefined();
    expect(decodeView('x', 1)).toBeUndefined();
    expect(decodeView(`f${'1'.repeat(10)}`, 1024)).toBeUndefined();
  });
});

describe('paintedPixels', () => {
  it('paints each index with its palette colour, from the top left', () => {
    const grid = `${'0'.repeat(33)}1${'0'.repeat(30)}2${'0'.repeat(959)}`;
    const pixels = paintedPixels(
      {
        width: 32,
        palette: ['#ff0000', '#00ff00'],
        dirs: { south: `f${grid}` },
      },
      'south',
    );
    expect(pixels).toEqual([
      { x: 1, y: 1, color: '#ff0000' },
      { x: 0, y: 2, color: '#00ff00' },
    ]);
  });

  it('paints nothing for a view the drawing leaves empty', () => {
    expect(
      paintedPixels({ width: 32, palette: ['#fff'], dirs: {} }, 'north'),
    ).toEqual([]);
  });
});

describe('frameRegions', () => {
  const regions: MarkingRegions = {
    id: 1,
    zones: ['head', 'chest'],
    width: 32,
    rows: {
      south: rows(32, [
        [16, 4, '1'],
        [16, 12, '2'],
        [17, 12, '2'],
      ]),
    },
  };

  it("lays each region on the frame where the character's tile is", () => {
    const map = frameRegions(tile, regions, 'south');
    expect(map && regionAt(map, 16, 4)).toBe('head');
    expect(map && regionAt(map, 17, 12)).toBe('chest');
    expect(map && regionAt(map, 0, 0)).toBeUndefined();
    expect(map && regionBounds(map, 'chest')).toEqual([16, 12, 18, 13]);
    expect(frameRegions(tile, regions, 'north')).toBeUndefined();
  });

  it("follows a frame with headroom above the tile, and height's moved rows", () => {
    // A frame 40 rows high, its tile at the foot; rows 30 and 31 of the
    // frame show what rows 12 and 13 of the tile drew, and row 37 is cleared.
    const tall = {
      ...tile,
      height: 40,
      rows: [
        [30, 2, 20],
        [37, 1, -1],
      ] as [number, number, number][],
    };
    const map = frameRegions(tall, regions, 'south');
    // The tile's row 4 is the frame's row 12.
    expect(map && regionAt(map, 16, 12)).toBe('head');
    expect(map && regionAt(map, 16, 30)).toBe('chest');
    expect(map && regionAt(map, 16, 20)).toBe('chest');
  });

  it("centres a taur's wider canvas on the tile", () => {
    const taur = { ...tile, width: 64, x: 16 };
    const wide: MarkingRegions = {
      id: 1,
      zones: ['taur'],
      width: 64,
      rows: { south: rows(64, [[0, 31, '1']]) },
    };
    const map = frameRegions(taur, wide, 'south');
    expect(map && regionAt(map, 0, 31)).toBe('taur');
  });
});

describe('unavailableMarkings', () => {
  const info = {
    Stripes: {
      color_mode: 'follows_primary' as const,
      exclusion_group: 'pattern',
      recommended_species: null,
    },
    Spots: {
      color_mode: 'follows_primary' as const,
      exclusion_group: 'pattern',
      recommended_species: null,
    },
    Socks: {
      color_mode: 'follows_primary' as const,
      exclusion_group: null,
      recommended_species: null,
    },
  };
  const worn = {
    name: 'Stripes',
    color: '#ffffff',
    marking_id: 'l_arm_1',
    emissive: false,
    locked: false,
  };

  it("keeps a worn marking and the rest of its group off the zone, but not the row it's swapping", () => {
    const offered = ['Stripes', 'Spots', 'Socks'];
    expect([...unavailableMarkings([worn], info, offered)].sort()).toEqual([
      'Spots',
      'Stripes',
    ]);
    expect(unavailableMarkings([worn], info, offered, worn).size).toBe(0);
  });
});

describe('lookMarkings', () => {
  it('keeps picker sprites while carrying native art for the mirror', () => {
    const room = {
      presets: [{ name: 'Look', markings: ['Large', 'Normal'] }],
      icons: { chest: { Large: 'large-picker', Normal: 'normal-picker' } },
      nativeIcons: { chest: { Large: 'preferences45x34 large-native' } },
      max: 3,
      taurLegs: false,
      startColor: () => '#aabbcc',
    } as unknown as RoomData;
    expect(lookMarkings(room, 'Look')).toEqual([
      {
        icon: 'large-picker',
        nativeIcon: 'preferences45x34 large-native',
        color: '#aabbcc',
      },
      { icon: 'normal-picker', nativeIcon: undefined, color: '#aabbcc' },
    ]);
  });
});
