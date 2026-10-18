// THIS IS AN APHELION UI FILE
import { Food } from '../../types';

/** Every Food member has an icon, so no liked food silently drops out. */
export const FOOD_ICONS: Record<Food, string> = {
  [Food.Alcohol]: 'wine-glass',
  [Food.Bloody]: 'droplet',
  [Food.Breakfast]: 'mug-saucer',
  [Food.Bugs]: 'bug',
  [Food.Cloth]: 'tshirt',
  [Food.Dairy]: 'cheese',
  [Food.Egg]: 'egg',
  [Food.Fried]: 'bacon',
  [Food.Fruit]: 'apple-alt',
  [Food.Gore]: 'skull',
  [Food.Grain]: 'bread-slice',
  [Food.Gross]: 'trash',
  [Food.Junkfood]: 'pizza-slice',
  [Food.Meat]: 'hamburger',
  [Food.Nuts]: 'seedling',
  [Food.Oranges]: 'tg-zaphelion-orange',
  [Food.Pineapple]: 'tg-zaphelion-pineapple',
  [Food.Raw]: 'drumstick-bite',
  [Food.Seafood]: 'fish',
  [Food.Stone]: 'gem',
  [Food.Sugar]: 'candy-cane',
  [Food.Toxic]: 'biohazard',
  [Food.Vegetables]: 'carrot',
};

export const FOOD_NAMES: Record<Food, string> = {
  [Food.Alcohol]: 'Alcohol',
  [Food.Bloody]: 'Blood',
  [Food.Breakfast]: 'Breakfast',
  [Food.Bugs]: 'Bugs',
  [Food.Cloth]: 'Clothing',
  [Food.Dairy]: 'Dairy',
  [Food.Egg]: 'Eggs',
  [Food.Fried]: 'Fried food',
  [Food.Fruit]: 'Fruit',
  [Food.Gore]: 'Gore',
  [Food.Grain]: 'Grain',
  [Food.Gross]: 'Gross food',
  [Food.Junkfood]: 'Junk food',
  [Food.Meat]: 'Meat',
  [Food.Nuts]: 'Nuts',
  [Food.Oranges]: 'Oranges',
  [Food.Pineapple]: 'Pineapple',
  [Food.Raw]: 'Raw food',
  [Food.Seafood]: 'Seafood',
  [Food.Stone]: 'Rocks',
  [Food.Sugar]: 'Sugar',
  [Food.Toxic]: 'Toxic food',
  [Food.Vegetables]: 'Vegetables',
};

/** Nearly everyone dislikes these, so they are only worth listing as a like. */
export const IGNORE_UNLESS_LIKED: ReadonlySet<Food> = new Set([
  Food.Bugs,
  Food.Cloth,
  Food.Gross,
  Food.Toxic,
]);

export type PerkKind = 'positive' | 'neutral' | 'negative';

export const PERK_KINDS: readonly {
  kind: PerkKind;
  title: string;
  icon: string;
}[] = [
  { kind: 'positive', title: 'Advantages', icon: 'plus' },
  { kind: 'neutral', title: 'Neutral', icon: 'circle' },
  { kind: 'negative', title: 'Drawbacks', icon: 'minus' },
];

/** Sprite directions in clockwise order, as seen from above. */
export const SPRITE_DIRS = ['south', 'west', 'north', 'east'] as const;
export type SpriteDir = (typeof SPRITE_DIRS)[number];

/** Whole-body 32x32 renders: species_full in uniform, species_body without. */
export const SPECIES_SPRITESHEETS = {
  uniform: 'species_full32x32',
  body: 'species_body32x32',
} as const;

/** The classes that draw one species facing one way. */
export function speciesSpriteClasses(
  icon: string,
  dir: SpriteDir = 'south',
  bare = false,
): string {
  const sheet = bare ? SPECIES_SPRITESHEETS.body : SPECIES_SPRITESHEETS.uniform;
  return `${sheet} ${icon}-${dir}`;
}
