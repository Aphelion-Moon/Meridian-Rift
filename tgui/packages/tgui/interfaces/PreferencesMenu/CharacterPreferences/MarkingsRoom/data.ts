// THIS IS AN APHELION UI FILE
import { useEffect, useMemo } from 'react';
import { useBackend } from 'tgui/backend';

import type {
  Marking,
  MarkingInfo,
  MarkingPreset,
  PreferencesMenuData,
} from '../../types';
import { useServerPrefs } from '../../useServerPrefs';
import { isLeg, MARKING_ZONES, type MarkingZone, TAUR_ZONE } from './constants';
import type { CustomMarkingView } from './customs';
import type { MarkingRegions } from './regions';

/** What the room reads beyond the markings data; see modular_aphelion/modules/markings_room. */
export type MarkingsRoomData = PreferencesMenuData & {
  /** The three mutant colours a marking can follow, as the preview body wears them, or null without one. */
  marking_fur_colors?: [string, string, string] | null;
  /** Each custom drawing as saved, by zone, or null for none. */
  custom_marking_views?: Record<string, CustomMarkingView> | null;
  /** Which region owns each pixel of the preview body, once the room has asked. */
  markings_room_regions?: MarkingRegions;
  /** The station's time when this was sent, in deciseconds into its day: Electra's mirror shows it. */
  markings_room_clock?: number;
  /** Rounds since the engine last delaminated: Hephaestus's tag shows it. */
  markings_room_delam?: number;
};

/** What the room reads of the constant data. */
type MarkingsRoomConstants = {
  /** The colour each marking with one of its own starts in, by name. */
  marking_defaults: Record<string, string>;
  /** Full-size mirror classes for art whose picker thumbnail was scaled. */
  native_marking_icons?: Record<string, Record<string, string>>;
};

/** A worn marking, where it is, and what the room knows of it. */
export type WornMarking = Marking & {
  zone: MarkingZone;
  index: number;
  /** The colour it starts in, and goes back to on a reset. */
  start: string;
  /** Painted another colour than it starts in. */
  painted: boolean;
};

/** Whether something meant for these comma-separated species ids, or for any species when there are none, suits this one. */
export const suitsSpecies = (
  recommended: string | null | undefined,
  species: string,
) => !recommended || recommended.split(',').includes(species);

/**
 * The markings a zone can't take now, as the backend refuses them: a marking
 * a row there wears, and any other of a worn marking's exclusion group.
 * `renaming` is the row being swapped out, whose own marking doesn't count.
 */
export function unavailableMarkings(
  rows: Marking[],
  info: Record<string, MarkingInfo>,
  offered: string[],
  renaming?: Marking,
) {
  const unavailable = new Set<string>();
  for (const row of rows) {
    if (row === renaming) {
      continue;
    }
    unavailable.add(row.name);
    const group = info[row.name]?.exclusion_group;
    if (!group) {
      continue;
    }
    for (const name of offered) {
      if (info[name]?.exclusion_group === group) {
        unavailable.add(name);
      }
    }
  }
  return unavailable;
}

/** The markings a preset puts on a zone: those offered there, three at most, as the mockup's look book shows them. */
export const presetZoneMarkings = (
  preset: MarkingPreset,
  icons: Record<string, string> | undefined,
  max: number,
) => (preset.markings ?? []).filter((name) => icons?.[name]).slice(0, max);

/** Everything the room reads, gathered from the window's data. */
export function useRoomData() {
  const { data, act } = useBackend<MarkingsRoomData>();
  const server = useServerPrefs();
  const markings = server?.limbs_and_markings;
  const constants = server?.markings_room as MarkingsRoomConstants | undefined;
  const info = markings?.marking_info ?? {};
  const sentIcons = markings?.marking_icons;
  // Each marking's sprite, as the classes that draw it from the preferences sheet.
  const icons = useMemo(() => {
    const classes: Record<string, Record<string, string>> = {};
    for (const [zone, names] of Object.entries(sentIcons ?? {})) {
      classes[zone] = {};
      for (const [name, icon] of Object.entries(names)) {
        classes[zone][name] = `preferences32x32 ${icon}`;
      }
    }
    return classes;
  }, [sentIcons]);
  const species = data.character_preferences?.misc?.species ?? '';
  const speciesData = server?.species?.[species];
  const fur = data.marking_fur_colors;
  const defaults = constants?.marking_defaults ?? {};
  const allowMismatched = !!data.allow_mismatched_parts;
  // The species' bare bodies, under every thumbnail: sent when asked for, as the species page asks.
  useEffect(() => {
    act('species_page_sprites', { body: true });
  }, []);
  const taurLegs = !!data.taur_legs;
  const max = markings?.max_markings ?? 3;

  /** The colour a marking starts in: the mutant colour it follows, or its own. */
  const startColor = (name: string) => {
    switch (info[name]?.color_mode) {
      case 'follows_primary':
        return fur?.[0];
      case 'follows_secondary':
        return fur?.[1];
      case 'follows_tertiary':
        return fur?.[2];
      default:
        return defaults[name];
    }
  };

  const worn = (zone: MarkingZone): WornMarking[] =>
    (data.markings?.[zone] ?? []).map((marking, index) => {
      const start = startColor(marking.name) ?? marking.color;
      return {
        ...marking,
        zone,
        index,
        start,
        painted: marking.color.toLowerCase() !== start.toLowerCase(),
      };
    });

  const wornByZone = Object.fromEntries(
    MARKING_ZONES.map((zone) => [zone, worn(zone)]),
  ) as Record<MarkingZone, WornMarking[]>;

  let count = 0;
  let glowing = 0;
  for (const zone of MARKING_ZONES) {
    for (const marking of wornByZone[zone]) {
      count++;
      if (marking.emissive) {
        glowing++;
      }
    }
  }

  const presets = (markings?.marking_presets ?? []).filter(
    (preset) =>
      allowMismatched || suitsSpecies(preset.recommended_species, species),
  );

  /** The zone a card's custom drawing goes on: the taur body takes the legs'. */
  const drawingZone = (zone: MarkingZone) =>
    taurLegs && isLeg(zone) ? TAUR_ZONE : zone;

  const customZones = new Set(data.custom_marking_zones ?? []);
  const allowEmissives =
    data.character_preferences?.secondary_features?.allow_emissives_toggle;

  return {
    data,
    act,
    info,
    icons,
    nativeIcons: constants?.native_marking_icons ?? {},
    species,
    speciesName: speciesData?.name ?? species,
    speciesIcon: speciesData?.icon,
    allowMismatched,
    taurLegs,
    max,
    startColor,
    wornByZone,
    count,
    glowing,
    presets,
    choices: markings?.marking_choices ?? {},
    drawingZone,
    canDraw: !!data.allow_custom_sprite_editing,
    drawn: (zone: string) => customZones.has(zone),
    customViews: data.custom_marking_views ?? {},
    // Glow waits on the character's Allow Emissives; unknown counts as on, and the server decides.
    canGlow: allowEmissives === undefined || !!allowEmissives,
    regions: data.markings_room_regions,
    preview: data.character_preview,
  };
}

export type RoomData = ReturnType<typeof useRoomData>;
