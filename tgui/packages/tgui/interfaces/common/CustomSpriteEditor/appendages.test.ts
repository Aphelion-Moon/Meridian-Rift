// THIS IS AN APHELION UI FILE
import { expect, it } from 'bun:test';
import {
  type Appendage,
  expandHats,
  layerFate,
  type StackItem,
  type StackLayer,
  stackAround,
  type TryOnHat,
  Zone,
} from './appendages';

const piece = (id: string, outer: boolean, zone: number = Zone.REAR) =>
  ({ id, name: id, zone, outer, edited: {}, emissive: {} }) as Appendage;
const hat = (strict: number): TryOnHat => ({
  label: 'Hat',
  group: '',
  strict,
  masks: { 2: ['1'] },
  views: {},
});
const frame = [['#ff0000ff']];
// Listed out of draw order on purpose: over-hat pieces always draw last.
const layers: StackLayer[] = [
  { id: 'hair', appendage: null, frame },
  { id: 'over', appendage: piece('over', true), frame },
  { id: 'under', appendage: piece('under', false), frame },
];
const names = (items: StackItem[]) =>
  items.map((item) => (item.type === 'frame' ? item.key : item.type));

it('treats pieces as the game treats a hairstyle own ones', () => {
  const back = hat(Zone.REAR);
  const crown = hat(Zone.TOP);
  expect(layerFate(null, crown)).toBe('trimmed');
  expect(layerFate(piece('p', false), back)).toBe('trimmed');
  expect(layerFate(piece('p', false), crown)).toBe('shown');
  expect(layerFate(piece('p', true), back)).toBe('hidden');
  expect(layerFate(piece('p', true), crown)).toBe('shown');
  expect(layerFate(piece('p', true), null)).toBe('shown');
});

it('stacks the other layers in draw order around the one being painted, with no hat', () => {
  const stack = stackAround(layers, 'hair', null, '2');
  expect(names(stack.below)).toEqual([]);
  expect(names(stack.above)).toEqual(['under', 'over']);
});

it('puts the hat between the under and over layers, and the hatching just above the hat', () => {
  const stack = stackAround(layers, 'under', hat(Zone.TOP), '2');
  expect(names(stack.below)).toEqual(['hair']);
  expect(names(stack.above)).toEqual(['hat', 'hatch', 'over']);
});

it('hatches an over-hat piece on top of everything, and leaves out pieces the hat hides', () => {
  const stack = stackAround(
    [...layers, { id: 'tip', appendage: piece('tip', true), frame }],
    'over',
    hat(Zone.REAR),
    '2',
  );
  expect(names(stack.below)).toEqual(['hair', 'under', 'hat']);
  expect(names(stack.above)).toEqual(['hatch']);
});

it('spells out hex mask rows a pixel at a time, the leftmost pixel first', () => {
  const sent = { ...hat(Zone.TOP), masks: { 2: ['f0000001', '00000000'] } };
  const [top, bottom] = expandHats({ fedora: sent }).fedora.masks[2];
  expect(top).toBe(`1111${'0'.repeat(24)}0001`);
  expect(bottom).toBe('0'.repeat(32));
});
