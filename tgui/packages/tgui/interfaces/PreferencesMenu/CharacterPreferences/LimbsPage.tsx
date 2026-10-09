// THIS IS A NOVA SECTOR UI FILE
import { useSetAtom } from 'jotai';
import {
  type ComponentProps,
  type ComponentRef,
  useMemo,
  useRef,
  useState,
} from 'react';
import { useBackend } from 'tgui/backend';
import { type HsvaColor, hexToHsva, hsvaToHex } from 'tgui-core/color';
import {
  Box,
  Button,
  ColorBox,
  Divider,
  Dropdown,
  Floating,
  Icon,
  Modal,
  Section,
  Stack,
} from 'tgui-core/components';
import type { BooleanLike } from 'tgui-core/react';

import { Hue, SaturationValue } from '../../ColorPickerModal/Color';
import { HexColorInput } from '../../ColorPickerModal/TextSetter';
import {
  ChoicedSelection,
  ChoicedSelectionDropdown,
  MARKING_PREVIEW_AREAS,
} from '../../common/ChoicedSelection';
import type {
  AugmentItem,
  AugmentSlot,
  Marking,
  MarkingColorMode,
  MarkingInfo,
  MarkingPreset,
  PreferencesMenuData,
  RoboticStyle,
} from '../types';
import { useServerPrefs } from '../useServerPrefs';
import { CharacterPreview } from './CharacterPreview';
import { PreviewLightsButton } from './CharacterPreview/lights';
import { turnPreview } from './CharacterPreview/turn';
import {
  AugmentsLayers,
  AugmentsRoom,
  MarkingsRoom,
  MarkingsTools,
  useRoomTheme,
} from './MarkingsRoom';
import { AugmentsStage } from './MarkingsRoom/augments';
import {
  ORGAN_SOCKETS,
  PART_SOCKETS,
  STOCK_AUGMENT,
  type StageOrgan,
  type StagePart,
} from './MarkingsRoom/augments/parts';

/** AugmentSlot with selected augment */
type AugmentData = AugmentSlot & {
  selectedAug: AugmentItem | undefined;
};

/** All the ui_data needed to populate the columns */
type BodypartData = AugmentData & {
  chosen_markings: Marking[] | null;
  chosen_style: RoboticStyle | null;
  marking_choices: string[];
  selectedImplant: AugmentItem | null;
};

type ColumnData = {
  left: BodypartData[];
  right: BodypartData[];
  center: BodypartData[];
  internalImplants: {
    left: AugmentData[];
    right: AugmentData[];
  };
  filteredMarkingPresets: string[];
};

// Portal descriptions above section stacking contexts while retaining the animation.
const HoverText = (props: { text: string; children: any }) => {
  const floatingRef = useRef<ComponentRef<typeof Floating>>(null);
  return (
    <Floating
      ref={floatingRef}
      hoverOpen
      hoverDelay={1}
      disabled={!props.text}
      placement="bottom-start"
      contentOffset={4}
      animationDuration={600}
      contentClasses="LimbsPage__hover-text--tooltip-wrapper"
      content={
        <div className="LimbsPage__hover-text--tooltip">{props.text}</div>
      }
    >
      <div
        className="LimbsPage__hover-text"
        onMouseDown={() => floatingRef.current?.close()}
      >
        {props.children}
      </div>
    </Floating>
  );
};

// The dropdown components with fancy HoverText

const LabeledDropdown = (
  props: {
    label: string;
    options: ComponentProps<typeof Dropdown>['options'];
    selected: string | undefined;
    onSelected: (value: any) => void;
  } & Partial<{
    maxItems: number;
    displayText: string;
    searchInput: boolean;
    tooltip: string;
    disabled: boolean;
  }>,
) => {
  const dropdown = (
    <Dropdown
      width="100%"
      options={props.options}
      selected={props.selected}
      displayText={props.displayText}
      disabled={props.disabled}
      onSelected={props.onSelected}
      maxItems={props.maxItems}
      searchInput={props.searchInput}
      styledInput
    />
  );
  return (
    <Stack.Item>
      <Box>{props.label}</Box>
      {props.tooltip ? (
        <HoverText text={props.tooltip}>{dropdown}</HoverText>
      ) : (
        dropdown
      )}
    </Stack.Item>
  );
};

// Popup to stop users from resetting all their markings accidentally via the preset dropdown

const PresetConfirmPopup = (props: {
  preset: string;
  /** The markings the preset puts on, in order, or null for none. */
  markings: string[] | null;
  /** Whether the preset replaces every marking, on the body parts it leaves bare too. */
  keepTogether: boolean;
  /** The body parts the preset covers, by label. */
  zones: string[];
  onConfirm: () => void;
  onCancel: () => void;
}) => (
  <Modal>
    <Stack vertical textAlign="center" align="center">
      <Stack.Item>
        <Box fontSize="2em">Replace Markings?</Box>
      </Stack.Item>
      <Stack.Item maxWidth="300px">
        {!props.markings?.length || props.keepTogether ? (
          <Box className="LimbsPage__presetScope LimbsPage__presetScope--all">
            {props.markings?.length ? (
              <>
                The <b>{props.preset}</b> preset is kept together: applying it
                will replace all your current markings, on every body part.
              </>
            ) : (
              <>
                Applying the <b>{props.preset}</b> preset will remove all your
                current markings.
              </>
            )}{' '}
            Are you sure?
          </Box>
        ) : (
          <Box className="LimbsPage__presetScope LimbsPage__presetScope--zones">
            Applying the <b>{props.preset}</b> preset will replace your markings
            on the body parts it covers: {props.zones.join(', ')}. Your other
            markings stay. Are you sure?
          </Box>
        )}
        {!!props.markings?.length && (
          <Box className="LimbsPage__presetMarkings">
            It puts on {props.markings.join(', ')}.
          </Box>
        )}
      </Stack.Item>
      <Stack.Item>
        <Stack fill>
          <Stack.Item>
            <Button color="danger" onClick={props.onConfirm}>
              Apply Preset
            </Button>
          </Stack.Item>
          <Stack.Item>
            <Button onClick={props.onCancel}>Cancel</Button>
          </Stack.Item>
        </Stack>
      </Stack.Item>
    </Stack>
  </Modal>
);

const InternalImplantTitle = (props: { name: string; icon: string }) => (
  <span>
    <Icon name={props.icon} style={{ marginRight: '4px' }} />
    {props.name}
  </span>
);

export const RotateCharacterButtons = () => {
  const turn = useSetAtom(turnPreview);
  return (
    <Box mt={1}>
      <Button
        onClick={() => turn(false)}
        fontSize="22px"
        icon="redo"
        tooltip="Rotate Clockwise"
        tooltipPosition="bottom"
      />
      <Button
        onClick={() => turn(true)}
        fontSize="22px"
        icon="undo"
        tooltip="Rotate Counter-Clockwise"
        tooltipPosition="bottom"
      />
      <PreviewLightsButton fontSize="22px" />
    </Box>
  );
};

// Various helpers

// Slot bitflags -- these must match DM defines in code\__DEFINES\inventory.dm
const SLOT_LEGS = (1 << 3) | (1 << 4); // LEG_LEFT | LEG_RIGHT

// ── Slot predicates ───────────────────────────────────────────────────────────
const isLegSlot = (slot_flag?: number) =>
  !!slot_flag && (slot_flag & SLOT_LEGS) !== 0;
const isLeft = (item: AugmentSlot) => item.slot?.startsWith('Left') ?? false;
const isRight = (item: AugmentSlot) => item.slot?.startsWith('Right') ?? false;
const isCenter = (item: AugmentSlot) => !isLeft(item) && !isRight(item);
const isBodypart = (item: AugmentSlot) => item.is_bodypart;
const isImplant = (item: AugmentSlot) => !item.is_bodypart;

// ── Display helpers ───────────────────────────────────────────────────────────
const augDisplayName = (aug: AugmentItem, showCost?: boolean) =>
  showCost && aug.cost
    ? `${aug.name} (${aug.cost > 0 ? '+' : ''}${aug.cost})`
    : aug.name;

/** True when the options list has more than just the default "None" entry */
const hasAnyOptions = (options: AugmentItem[] | null | undefined) =>
  (options?.length ?? 0) > 1;

// ── Filtering ─────────────────────────────────────────────────────────────────
const filterBySpecies = <T extends { recommended_species: string | null }>(
  items: T[],
  species: string,
  allowMismatched: boolean,
): T[] => {
  if (allowMismatched) return items;
  return items.filter(
    (item) =>
      !item.recommended_species ||
      item.recommended_species.split(',').includes(species),
  );
};

/** Whether something meant for these comma-separated species ids, or for any species when there are none, suits this one. */
const suitsSpecies = (
  recommended_species: string | null | undefined,
  species: string,
) => !recommended_species || recommended_species.split(',').includes(species);

const isAugAllowed = (
  aug: AugmentItem,
  species: string,
  ckey: string,
  slot_flag?: number,
  digi_legs?: BooleanLike,
  taur_legs?: BooleanLike,
): boolean => {
  if (isLegSlot(slot_flag) && digi_legs && !aug.has_digi) return false;
  if (isLegSlot(slot_flag) && taur_legs) return false;
  if (aug.species_blacklist?.[species]) return false;
  if (aug.species_whitelist && !aug.species_whitelist[species]) return false;
  if (aug.ckey_whitelist && !aug.ckey_whitelist.includes(ckey)) return false;
  return true;
};

/** The robotic styles an augment can take on a limb: "None" for anything, the rest when it takes styles, fit the slot and suit its legs. */
const availableStyles = (
  styles: RoboticStyle[],
  aug: AugmentItem | undefined,
  slot_flag: number | undefined,
  digi_legs: BooleanLike,
) =>
  styles.filter((style) => {
    if (!aug?.allows_styles && style.name !== 'None') return false;
    if (slot_flag && !(style.supported_slots & slot_flag)) return false;
    if (isLegSlot(slot_flag) && digi_legs && !style.has_digi) return false;
    return true;
  });

const showsInBodyPartsTab = (bodypart: BodypartData, taur_legs: BooleanLike) =>
  hasAnyOptions(bodypart.aug_options) ||
  (!!taur_legs && isLegSlot(bodypart.slot_flag));

/** Resolves internal implant slots into AugmentData with filtered options and selected aug */
const buildInternalImplantData = (
  items: AugmentSlot[],
  augments: Record<string, string>,
  species: string,
  ckey: string,
): AugmentData[] =>
  items.map((item) => {
    const chosen = augments?.[item.slot] ?? null;
    const aug_options = (item.aug_options ?? []).filter((aug) =>
      isAugAllowed(aug, species, ckey),
    );
    return {
      ...item,
      aug_options,
      selectedAug:
        aug_options.find((aug) => aug.path === chosen) ?? aug_options[0],
    };
  });

// Markings

/** What a colour reset gives a row back, by its marking's colour mode. */
const RESET_COLOR_TOOLTIPS: Record<MarkingColorMode, string> = {
  follows_primary: 'Reset to your mutant color',
  follows_secondary: 'Reset to your mutant color 2',
  follows_tertiary: 'Reset to your mutant color 3',
  fixed_default: "Reset to this marking's own color",
  locked: "Reset to this marking's own color",
};

/**
 * The offered markings a zone can't take right now, as the backend refuses them: a marking a row there wears, and any other
 * marking of a worn marking's exclusion group. `renaming` is the row being renamed, whose own marking doesn't count. The
 * pickers leave them out.
 */
const unavailableMarkings = (
  rows: Marking[],
  info: Record<string, MarkingInfo>,
  offered: string[],
  renaming?: Marking,
): Set<string> => {
  const unavailable = new Set<string>();
  for (const row of rows) {
    if (row === renaming) continue;
    unavailable.add(row.name);
    const group = info[row.name]?.exclusion_group;
    if (!group) continue;
    for (const name of offered) {
      if (info[name]?.exclusion_group === group) unavailable.add(name);
    }
  }
  return unavailable;
};

/** The body parts a preset covers, by their sections' labels: every zone offering one of its markings, in zone order. */
const presetZones = (
  preset: MarkingPreset,
  choices: Record<string, string[]>,
  items: AugmentSlot[],
) =>
  Object.entries(choices)
    .filter(([, names]) =>
      preset.markings?.some((name) => names.includes(name)),
    )
    .map(
      ([zone]) => items.find((item) => item.body_zone === zone)?.slot ?? zone,
    );

/**
 * A row's colour, picked in place with the colour picker window's own controls and sent once, on Apply; a suggested colour is
 * sent as soon as it is picked. A locked marking's colour can't be picked at all.
 */
const MarkingColor = (props: {
  color: string;
  locked: boolean;
  recommended?: string[];
  placement?: ComponentProps<typeof Floating>['placement'];
  tooltipPosition?: ComponentProps<typeof Floating>['placement'];
  onPick: (color: string) => void;
}) => {
  const { color, locked, recommended, placement, tooltipPosition, onPick } =
    props;
  const floatingRef = useRef<ComponentRef<typeof Floating>>(null);
  const [hsva, setHsva] = useState<HsvaColor>(() => hexToHsva(color));
  // A typed colour is sent as typed, not as its round trip through HSV.
  const [typed, setTyped] = useState<string | null>(null);
  const [edited, setEdited] = useState(false);
  const picked = typed ?? hsvaToHex(hsva);
  const change = (next: Partial<HsvaColor>) => {
    setHsva((current) => ({ ...current, ...next }));
    setTyped(null);
    setEdited(true);
  };
  const pick = (value: string) => {
    if (value.toLowerCase() !== color.toLowerCase()) {
      onPick(value.toLowerCase());
    }
    floatingRef.current?.close();
  };
  if (locked) {
    return (
      <Button
        disabled
        tooltip="This marking's color is fixed."
        tooltipPosition={tooltipPosition}
        aria-label="Marking color"
      >
        <ColorBox color={color} />
      </Button>
    );
  }
  return (
    <Floating
      ref={floatingRef}
      stopChildPropagation
      placement={placement}
      contentClasses="LimbsPage__colorPicker"
      // Each opening starts from the row's own colour.
      onOpenChange={(open) => {
        if (open) {
          setHsva(hexToHsva(color));
          setTyped(null);
          setEdited(false);
        }
      }}
      content={
        <Stack vertical>
          <Stack.Item>
            <Stack>
              <Stack.Item>
                <div className="react-colorful">
                  <SaturationValue hsva={hsva} onChange={change} />
                  <Hue
                    hue={hsva.h}
                    onChange={change}
                    className="react-colorful__last-control"
                  />
                </div>
              </Stack.Item>
              {!!recommended?.length && (
                <Stack.Item>
                  <Stack vertical>
                    {recommended.map((suggested) => (
                      <Stack.Item key={suggested}>
                        <Button
                          tooltip={`Suggested: ${suggested}`}
                          aria-label={`Suggested color ${suggested}`}
                          onClick={() => pick(suggested)}
                        >
                          <ColorBox color={suggested} />
                        </Button>
                      </Stack.Item>
                    ))}
                  </Stack>
                </Stack.Item>
              )}
            </Stack>
          </Stack.Item>
          <Stack.Item>
            <Stack align="center">
              <Stack.Item>
                <ColorBox color={picked} />
              </Stack.Item>
              <Stack.Item grow>
                <HexColorInput
                  fluid
                  color={picked.substring(1)}
                  onChange={(value) => {
                    setHsva(hexToHsva(value));
                    setTyped(`#${value.toLowerCase()}`);
                    setEdited(true);
                  }}
                />
              </Stack.Item>
              <Stack.Item>
                <Button
                  color="good"
                  disabled={!edited}
                  onClick={() => pick(picked)}
                >
                  Apply
                </Button>
              </Stack.Item>
            </Stack>
          </Stack.Item>
        </Stack>
      }
    >
      {/* The picker anchors to this wrapper: a button's tooltip takes the button's own anchor. */}
      <div className="LimbsPage__colorTrigger">
        <Button
          tooltip="Pick this marking's color"
          tooltipPosition={tooltipPosition}
          aria-label="Marking color"
        >
          <ColorBox color={color} />
        </Button>
      </div>
    </Floating>
  );
};

/** Adds a marking picked from the ones the zone can take right now (`options`), or, from the second button, one at random. */
const AddMarking = (props: {
  body_zone: string;
  options: string[];
  icons?: Record<string, string>;
  placement?: ComponentProps<typeof Floating>['placement'];
  tooltipPosition?: ComponentProps<typeof Floating>['placement'];
  onAdd: (marking_name?: string) => void;
}) => {
  const { body_zone, options, icons, placement, tooltipPosition, onAdd } =
    props;
  const floatingRef = useRef<ComponentRef<typeof Floating>>(null);
  return (
    <Stack>
      <Stack.Item grow={!icons}>
        {icons ? (
          <Floating
            ref={floatingRef}
            stopChildPropagation
            placement={placement}
            content={
              <ChoicedSelection
                name="marking"
                catalog={{ icons }}
                selected=""
                options={options}
                previewArea={MARKING_PREVIEW_AREAS[body_zone]}
                onSelect={(name) => {
                  onAdd(name);
                  floatingRef.current?.close();
                }}
              />
            }
          >
            <Button color="good" aria-label="Add a marking">
              +
            </Button>
          </Floating>
        ) : (
          <Dropdown
            width="100%"
            color="good"
            options={options}
            selected={null}
            placeholder="Add marking..."
            maxItems={7}
            onSelected={(name) => onAdd(name)}
          />
        )}
      </Stack.Item>
      <Stack.Item>
        <Button
          color="good"
          icon="dice"
          tooltip="Add a random marking"
          tooltipPosition={tooltipPosition}
          aria-label="Add a random marking"
          onClick={() => onAdd()}
        />
      </Stack.Item>
    </Stack>
  );
};

const Markings = (props: {
  body_zone: string;
  chosen_markings: Marking[] | null;
  marking_choices: string[];
  act: (action: string, params?: Record<string, unknown>) => void;
  pickerPlacement?: ComponentProps<typeof Floating>['placement'];
  tooltipPosition?: ComponentProps<typeof Floating>['placement'];
}) => {
  const {
    body_zone,
    chosen_markings,
    marking_choices,
    act,
    pickerPlacement,
    tooltipPosition,
  } = props;
  const { data } = useBackend<PreferencesMenuData>();
  const serverPrefs = useServerPrefs();
  const serverMarkings = serverPrefs?.limbs_and_markings;
  const maxMarkings = serverMarkings?.max_markings ?? 0;
  const markingIcons = serverMarkings?.marking_icons?.[body_zone];
  const markingInfo = serverMarkings?.marking_info ?? {};
  const markings = chosen_markings ?? [];
  // What a new row could wear: anything the rows here don't already wear or keep off the zone.
  const taken = unavailableMarkings(markings, markingInfo, marking_choices);
  const addable = marking_choices.filter((name) => !taken.has(name));
  // A taur body takes the legs' place, so they get its drawing instead of markings.
  const taurLeg = !!data.taur_legs && ['l_leg', 'r_leg'].includes(body_zone);
  const drawingZone = taurLeg ? 'taur' : body_zone;
  // The drawing button lights up once it has paint; an empty canvas saves nothing.
  const drawn = !!data.custom_marking_zones?.includes(drawingZone);
  return (
    <Stack fill vertical>
      <Stack.Item>Markings:</Stack.Item>
      {markings.map((marking) => {
        // A limb takes each marking once and one of each exclusion group, so a row's picker leaves out what another row
        // wears or keeps off the zone.
        const unavailable = unavailableMarkings(
          markings,
          markingInfo,
          marking_choices,
          marking,
        );
        const choices = marking_choices.filter(
          (name) => name === marking.name || !unavailable.has(name),
        );
        const info = markingInfo[marking.name];
        const changeMarking = (value: string) =>
          act('change_marking', {
            bodypart_slot: body_zone,
            marking_id: marking.marking_id,
            marking_name: value,
          });
        return (
          <Stack.Item
            key={marking.marking_id}
            className="LimbsPage__markingRow"
          >
            <Stack fill>
              <Stack.Item grow style={{ minWidth: 0, overflow: 'hidden' }}>
                {markingIcons ? (
                  <ChoicedSelectionDropdown
                    name="marking"
                    icons={markingIcons}
                    options={choices}
                    selected={marking.name}
                    placement={pickerPlacement}
                    previewArea={MARKING_PREVIEW_AREAS[body_zone]}
                    onSelect={changeMarking}
                  />
                ) : (
                  <Dropdown
                    width="100%"
                    options={choices}
                    selected={marking.name}
                    displayText={marking.name}
                    maxItems={7}
                    styledInput
                    onSelected={changeMarking}
                  />
                )}
              </Stack.Item>
              <Stack.Item>
                <MarkingColor
                  color={marking.color}
                  locked={!!marking.locked}
                  recommended={info?.recommended_colors}
                  placement={pickerPlacement}
                  tooltipPosition={tooltipPosition}
                  onPick={(color) =>
                    act('color_marking', {
                      bodypart_slot: body_zone,
                      marking_id: marking.marking_id,
                      color,
                    })
                  }
                />
              </Stack.Item>
              <Stack.Item>
                <Button
                  icon="rotate-left"
                  tooltip={
                    RESET_COLOR_TOOLTIPS[info?.color_mode ?? 'fixed_default']
                  }
                  tooltipPosition={tooltipPosition}
                  aria-label="Reset marking color"
                  onClick={() =>
                    act('reset_marking_color', {
                      bodypart_slot: body_zone,
                      marking_id: marking.marking_id,
                    })
                  }
                />
              </Stack.Item>
              <Stack.Item>
                <Button
                  color={marking.emissive ? 'good' : 'bad'}
                  tooltipPosition={tooltipPosition}
                  tooltip="The 'E' is for 'Emissive' — does it glow? Green = glow, Red = no glow."
                  onClick={() =>
                    act('change_emissive', {
                      bodypart_slot: body_zone,
                      marking_id: marking.marking_id,
                      emissive: marking.emissive,
                    })
                  }
                >
                  E
                </Button>
              </Stack.Item>
              <Stack.Item>
                <Button
                  color="bad"
                  onClick={() =>
                    act('remove_marking', {
                      bodypart_slot: body_zone,
                      marking_id: marking.marking_id,
                    })
                  }
                >
                  -
                </Button>
              </Stack.Item>
            </Stack>
          </Stack.Item>
        );
      })}
      {!taurLeg && markings.length < maxMarkings && (
        <Stack.Item>
          <AddMarking
            body_zone={body_zone}
            options={addable}
            icons={markingIcons}
            placement={pickerPlacement}
            tooltipPosition={tooltipPosition}
            onAdd={(marking_name) =>
              act(
                'add_marking',
                marking_name
                  ? { bodypart_slot: body_zone, marking_name }
                  : { bodypart_slot: body_zone },
              )
            }
          />
        </Stack.Item>
      )}
      {!!data.allow_custom_sprite_editing && (
        <Stack.Item>
          <Button
            icon="paintbrush"
            selected={drawn}
            tooltip={`Lets you draw a custom marking over ${
              taurLeg ? 'your taur body' : 'this limb'
            }.${drawn ? ' You have one drawn; click to edit it.' : ''}`}
            tooltipPosition={tooltipPosition}
            onClick={() =>
              act('open_custom_sprite_editor', {
                target: 'markings',
                body_zone: drawingZone,
              })
            }
          >
            {taurLeg ? 'Taur body' : 'Custom'}
            {drawn && <Icon name="check" ml={0.5} />}
          </Button>
        </Stack.Item>
      )}
    </Stack>
  );
};

// Limb augments section

const BodypartAugmentSection = (props: { limb: BodypartData }) => {
  const { act, data } = useBackend<PreferencesMenuData>();
  const server_data = useServerPrefs()?.limbs_and_markings;
  if (!server_data) return null;

  const { limb } = props;
  const showCost = !!data.quirk_points_enabled;
  const displayName = (aug: AugmentItem) => augDisplayName(aug, showCost);
  const balance = -data.quirks_balance;
  const aug_options = limb.aug_options ?? [];
  const implant_options = limb.implant_options ?? [];

  const available_styles = useMemo(
    () =>
      availableStyles(
        server_data.robotic_styles ?? [],
        limb.selectedAug,
        limb.slot_flag,
        data.digi_legs,
      ),
    [
      server_data.robotic_styles,
      limb.selectedAug,
      limb.slot_flag,
      data.digi_legs,
    ],
  );
  const isTaurRestrictedLeg = !!data.taur_legs && isLegSlot(limb.slot_flag);

  return (
    <div style={{ marginBottom: '1.5em' }}>
      <Section fill title={limb.slot}>
        <Stack fill vertical>
          {isTaurRestrictedLeg ? (
            <LabeledDropdown
              label="Augmentation:"
              options={['Not available']}
              selected="Not available"
              displayText={'Not available'}
              disabled
              searchInput
              maxItems={7}
              onSelected={() => {}}
            />
          ) : (
            <LabeledDropdown
              label="Augmentation:"
              options={aug_options.map((aug) => displayName(aug))}
              selected={
                limb.selectedAug ? displayName(limb.selectedAug) : undefined
              }
              displayText={
                limb.selectedAug ? displayName(limb.selectedAug) : undefined
              }
              tooltip={limb.selectedAug?.extra_info}
              searchInput
              maxItems={7}
              onSelected={(name) => {
                const option = aug_options.find(
                  (aug) => displayName(aug) === name,
                );
                if (option?.path === limb.selectedAug?.path) return;
                if (
                  showCost &&
                  balance -
                    (limb.selectedAug?.cost ?? 0) +
                    (option?.cost ?? 0) >
                    0
                )
                  return;
                act('set_bodypart_aug', {
                  slot: limb.slot,
                  augment_path: option?.path ?? null,
                });
              }}
            />
          )}
          {limb.selectedAug?.path &&
            limb.selectedAug?.allows_styles !== 0 &&
            (available_styles.length <= 1 ? (
              <LabeledDropdown
                label="Style:"
                options={['No available styles']}
                selected="No available styles"
                displayText="No available styles"
                searchInput
                maxItems={7}
                disabled
                onSelected={() => {}}
              />
            ) : (
              <LabeledDropdown
                label="Style:"
                options={available_styles.map((style) => style.name)}
                selected={limb.chosen_style?.name ?? 'None'}
                displayText={limb.chosen_style?.name ?? 'None'}
                searchInput
                onSelected={(value) => {
                  if (value === limb.chosen_style?.name) return;
                  act('set_bodypart_aug_style', {
                    slot: limb.slot,
                    style_name: value,
                  });
                }}
              />
            ))}
          {limb.selectedAug?.allows_implants !== 0 &&
            (limb.has_implant ? (
              <LabeledDropdown
                label="Implant slot:"
                options={implant_options.map((aug) => displayName(aug))}
                selected={
                  limb.selectedImplant
                    ? displayName(limb.selectedImplant)
                    : undefined
                }
                displayText={
                  limb.selectedImplant
                    ? displayName(limb.selectedImplant)
                    : undefined
                }
                searchInput
                maxItems={7}
                tooltip={limb.selectedImplant?.extra_info}
                onSelected={(name) => {
                  const option = implant_options.find(
                    (aug) => displayName(aug) === name,
                  );
                  if (
                    showCost &&
                    balance -
                      (limb.selectedImplant?.cost ?? 0) +
                      (option?.cost ?? 0) >
                      0
                  )
                    return;
                  if (option?.path === limb.selectedImplant?.path) return;
                  act('set_internal_implant_aug', {
                    internal_implant_slot: `${limb.slot} implant`,
                    augment_path: option?.path ?? null,
                  });
                }}
              />
            ) : (
              <LabeledDropdown
                label="Implant slot:"
                options={['None available']}
                selected="None available"
                displayText="None available"
                searchInput
                maxItems={7}
                disabled
                onSelected={() => {}}
              />
            ))}
        </Stack>
      </Section>
    </div>
  );
};

// Internal implant augments

const InternalImplantSection = (props: { internal_implant: AugmentData }) => {
  const { act, data } = useBackend<PreferencesMenuData>();
  const { internal_implant } = props;
  const showCost = !!data.quirk_points_enabled;
  const displayName = (aug: AugmentItem) => augDisplayName(aug, showCost);
  const balance = -data.quirks_balance;
  const aug_options = internal_implant.aug_options ?? [];
  return (
    <div style={{ marginBottom: '1.5em' }}>
      <Section
        fill
        title={
          <InternalImplantTitle
            name={internal_implant.slot}
            icon={internal_implant.icon ?? ''}
          />
        }
      >
        <LabeledDropdown
          label="Implant:"
          options={aug_options.map(displayName)}
          selected={
            internal_implant.selectedAug
              ? displayName(internal_implant.selectedAug)
              : undefined
          }
          displayText={
            internal_implant.selectedAug
              ? displayName(internal_implant.selectedAug)
              : undefined
          }
          searchInput
          maxItems={7}
          onSelected={(name) => {
            const option = aug_options.find((aug) => displayName(aug) === name);
            if (
              showCost &&
              balance -
                (internal_implant.selectedAug?.cost ?? 0) +
                (option?.cost ?? 0) >
                0
            )
              return;
            if (option?.path === internal_implant.selectedAug?.path) return;
            act('set_internal_implant_aug', {
              internal_implant_slot: internal_implant.slot,
              augment_path: option?.path ?? null,
            });
          }}
        />
      </Section>
    </div>
  );
};

const MarkingsColumn = (props: {
  limbs: BodypartData[];
  act: (action: string, params?: Record<string, unknown>) => void;
  tooltipPosition: ComponentProps<typeof Floating>['placement'];
}) => (
  <Section fill scrollable title="Markings">
    {props.limbs.map((bodypart) => (
      <div key={bodypart.slot} style={{ marginBottom: '1.5em' }}>
        <Section fill title={bodypart.slot}>
          {/* Sideways pickers and centred tooltips would land under the preview's map control. */}
          <Markings
            body_zone={bodypart.body_zone ?? bodypart.slot}
            chosen_markings={bodypart.chosen_markings}
            marking_choices={bodypart.marking_choices}
            act={props.act}
            pickerPlacement="bottom-start"
            tooltipPosition={props.tooltipPosition}
          />
        </Section>
      </div>
    ))}
  </Section>
);

const BodyPartsColumn = (props: { limbs: BodypartData[] }) => (
  <Section fill scrollable title="Augmentations">
    <QuirkBalance style={{ marginBottom: '1em' }} />
    {props.limbs.map((bodypart) => (
      <BodypartAugmentSection key={bodypart.slot} limb={bodypart} />
    ))}
  </Section>
);

const InternalImplantsColumn = (props: {
  internal_implants: AugmentData[];
}) => (
  <Section fill scrollable title="Internal Implants">
    {props.internal_implants.map((internal_implant) => (
      <InternalImplantSection
        key={internal_implant.slot}
        internal_implant={internal_implant}
      />
    ))}
  </Section>
);

const QuirkBalance = (props: { style?: Record<string, unknown> }) => {
  const { data } = useBackend<PreferencesMenuData>();
  if (!data.quirk_points_enabled) return null;
  return (
    <Section align="center" title="Quirk Points Balance" style={props.style}>
      <Stack justify="center">
        <Box
          backgroundColor="#eee"
          bold
          color="black"
          fontSize="1.2em"
          py={0.5}
          style={{ width: '20%', alignItems: 'center' }}
        >
          {-data.quirks_balance}
        </Box>
      </Stack>
    </Section>
  );
};

// Things that live in the center columns of the various tabs, below the character preview

const CenterColumnExtras = (props: {
  tab: AugmentsTab | null;
  center: BodypartData[];
  act: (action: string, params?: Record<string, unknown>) => void;
}) => {
  const { data } = useBackend<PreferencesMenuData>();

  if (props.tab === AugmentsTab.BodyParts) {
    return (
      <>
        {props.center
          .filter((bodypart) => showsInBodyPartsTab(bodypart, data.taur_legs))
          .map((bodypart) => (
            <BodypartAugmentSection key={bodypart.slot} limb={bodypart} />
          ))}
      </>
    );
  }

  if (props.tab === AugmentsTab.InternalImplants) {
    return <QuirkBalance style={{ marginTop: '1em' }} />;
  }

  if (props.tab === AugmentsTab.Markings) {
    return (
      <>
        {props.center.map((bodypart) => (
          <div key={bodypart.slot} style={{ marginBottom: '1.5em' }}>
            <Section fill title={bodypart.slot}>
              <Markings
                body_zone={bodypart.body_zone ?? bodypart.slot}
                chosen_markings={bodypart.chosen_markings}
                marking_choices={bodypart.marking_choices}
                act={props.act}
              />
            </Section>
          </div>
        ))}
      </>
    );
  }

  return null;
};

// The character preview section at the top of the center column
const PreviewSection = () => (
  <Section fill title="Character Preview" align="center">
    <Stack vertical fill>
      <Stack.Item grow align="center">
        <CharacterPreview height="100%" width="280px" motif="scanner" />
      </Stack.Item>
      <Stack.Divider />
      <Stack.Item align="center">
        <RotateCharacterButtons />
      </Stack.Item>
    </Stack>
  </Section>
);

// Root page

export enum AugmentsTab {
  Markings = 0,
  BodyParts = 1,
  InternalImplants = 2,
}

export const LimbsPage = ({
  onTabChange,
}: {
  onTabChange?: (tab: AugmentsTab) => void;
}) => {
  const { data, act } = useBackend<PreferencesMenuData>();
  const server_data = useServerPrefs()?.limbs_and_markings;
  const [tab, setTab] = useState<AugmentsTab>(AugmentsTab.Markings);
  const [pendingPreset, setPendingPreset] = useState<string | null>(null);
  const hasWarnedRef = useRef(false);
  // The theme's fixed room, with the markings in its mirror, once that theme's room is built; the rest keep the columns.
  const roomTheme = useRoomTheme();

  const handleTab = (next: AugmentsTab) => {
    setTab(next);
    onTabChange?.(next);
  };

  // Resets the preset warning when a marking is manually changed (e.g. not using the preset dropdown)
  const actAndResetPresetWarning = (
    action: string,
    params?: Record<string, unknown>,
  ) => {
    if (
      [
        'add_marking',
        'remove_marking',
        'change_marking',
        'color_marking',
        'reset_marking_color',
        'change_emissive',
        'surprise_markings',
      ].includes(action)
    ) {
      hasWarnedRef.current = false;
    }
    act(action, params);
  };

  const pendingPresetStyle = {
    position: 'fixed' as const,
    top: '60%',
    left: '50%',
    transform: 'translate(-50%, -50%)',
    width: '400px',
    zIndex: 100,
  };

  // The preset waiting for confirmation: what it puts on, and which body parts it covers.
  const pendingPresetData = server_data?.marking_presets?.find(
    (preset) => preset.name === pendingPreset,
  );
  const pendingPresetZones =
    pendingPresetData && server_data
      ? presetZones(
          pendingPresetData,
          server_data.marking_choices ?? {},
          server_data.augment_items ?? [],
        )
      : [];

  // Build all column data, splitting augment_items into bodyparts and internal implants
  const columns: ColumnData | null = useMemo(() => {
    if (!server_data?.augment_items) return null;

    const species = data.character_preferences?.misc?.species ?? '';
    const ckey = data.ckey ?? '';
    const allowMismatched = !!data.allow_mismatched_parts;

    // Filter marking choices and presets by species/mismatched parts
    const markingInfo = server_data.marking_info ?? {};
    const markingChoices: Record<string, string[]> = {};
    for (const [slot, names] of Object.entries(
      server_data.marking_choices ?? {},
    )) {
      markingChoices[slot] = allowMismatched
        ? names
        : names.filter((name) =>
            suitsSpecies(markingInfo[name]?.recommended_species, species),
          );
    }
    const filteredMarkingPresets = filterBySpecies(
      server_data.marking_presets ?? [],
      species,
      allowMismatched,
    ).map((preset) => preset.name);

    const styles = server_data.robotic_styles ?? [];

    const limbs: BodypartData[] = server_data.augment_items
      .filter(isBodypart)
      .map((item) => {
        const aug_options = (item.aug_options ?? []).filter((aug) =>
          isAugAllowed(
            aug,
            species,
            ckey,
            item.slot_flag,
            data.digi_legs,
            data.taur_legs,
          ),
        );
        const implant_options = (item.implant_options ?? []).filter((aug) =>
          isAugAllowed(
            aug,
            species,
            ckey,
            item.slot_flag,
            data.digi_legs,
            data.taur_legs,
          ),
        );
        const chosen_style_name = data.augment_styles?.[item.slot] ?? null;
        const augByPath = aug_options.length
          ? Object.fromEntries(aug_options.map((aug) => [aug.path, aug]))
          : {};
        const implantByPath = implant_options.length
          ? Object.fromEntries(implant_options.map((aug) => [aug.path, aug]))
          : {};
        return {
          ...item,
          aug_options,
          implant_options,
          chosen_markings: (data.markings?.[item.body_zone ?? item.slot] ??
            null) as Marking[] | null,
          chosen_style:
            styles.find((style) => style.name === chosen_style_name) ?? null,
          marking_choices: markingChoices[item.body_zone ?? item.slot] ?? [],
          selectedAug:
            augByPath[data.augments?.[item.slot] ?? ''] ?? aug_options[0],
          selectedImplant:
            implantByPath[data.augments?.[`${item.slot} implant`] ?? ''] ??
            implant_options[0] ??
            null,
        };
      });

    const internal_implants = server_data.augment_items.filter(isImplant);
    const mid = Math.ceil(internal_implants.length / 2);

    return {
      left: limbs.filter(isLeft),
      right: limbs.filter(isRight),
      center: limbs.filter(isCenter),
      internalImplants: {
        left: buildInternalImplantData(
          internal_implants.slice(0, mid),
          data.augments ?? {},
          species,
          ckey,
        ),
        right: buildInternalImplantData(
          internal_implants.slice(mid),
          data.augments ?? {},
          species,
          ckey,
        ),
      },
      filteredMarkingPresets,
    };
    // What it reads of the window's data, not the whole of it: an update that
    // changes none of these (the preview's drawing, the region map) keeps the
    // columns, and the augments stage built from them, as they are.
  }, [
    server_data,
    data.character_preferences?.misc?.species,
    data.ckey,
    data.allow_mismatched_parts,
    data.digi_legs,
    data.taur_legs,
    data.augment_styles,
    data.augments,
    data.markings,
  ]);

  // The augments stage's sockets, in the room's themes: every body part and internal the server has, as the stage lays them out.
  const stage = useMemo(() => {
    if (!roomTheme || !columns || !server_data) return null;
    const limbs = [...columns.left, ...columns.right, ...columns.center];
    const limbBySlot = Object.fromEntries(
      limbs.map((limb) => [limb.slot, limb]),
    );
    const parts: StagePart[] = PART_SOCKETS.flatMap((socket) => {
      const limb = limbBySlot[socket.slot];
      if (!limb) return [];
      return [
        {
          socket,
          augment: limb.selectedAug ?? STOCK_AUGMENT,
          options: limb.aug_options ?? [],
          finish: limb.chosen_style?.name ?? 'None',
          finishes: availableStyles(
            server_data.robotic_styles ?? [],
            limb.selectedAug,
            limb.slot_flag,
            data.digi_legs,
          ).map((style) => style.name),
          implant: limb.selectedImplant,
          implants: limb.has_implant ? (limb.implant_options ?? []) : null,
          unavailable: !!data.taur_legs && isLegSlot(limb.slot_flag),
        },
      ];
    });
    const internals = [
      ...columns.internalImplants.left,
      ...columns.internalImplants.right,
    ];
    const organBySlot = Object.fromEntries(
      internals.map((organ) => [organ.slot, organ]),
    );
    const organs: StageOrgan[] = ORGAN_SOCKETS.flatMap((socket) => {
      const organ = organBySlot[socket.slot];
      if (!organ?.selectedAug) return [];
      return [
        {
          socket,
          installed: organ.selectedAug,
          options: organ.aug_options ?? [],
        },
      ];
    });
    return { parts, organs };
  }, [roomTheme, columns, server_data, data.digi_legs, data.taur_legs]);

  const columnForTab = (
    limbs: BodypartData[],
    internal_implants: AugmentData[],
    tooltipPosition: ComponentProps<typeof Floating>['placement'],
  ) => {
    if (tab === AugmentsTab.Markings)
      return (
        <MarkingsColumn
          limbs={limbs}
          act={actAndResetPresetWarning}
          tooltipPosition={tooltipPosition}
        />
      );
    if (tab === AugmentsTab.BodyParts)
      return (
        <BodyPartsColumn
          limbs={limbs.filter((b) => showsInBodyPartsTab(b, data.taur_legs))}
        />
      );
    if (tab === AugmentsTab.InternalImplants)
      return <InternalImplantsColumn internal_implants={internal_implants} />;
    return null;
  };

  // Asks before a preset replaces markings, unless it already has since the last change by hand.
  const applyPreset = (preset: string) => {
    if (!hasWarnedRef.current) setPendingPreset(preset);
    else act('set_preset', { preset });
  };

  // The augments, or every marking at once, in three columns round the preview.
  const columnsView = (
    <Stack fill>
      {/* Left column */}
      <Stack.Item minWidth="33%">
        {columnForTab(
          columns?.left ?? [],
          columns?.internalImplants.left ?? [],
          'bottom-end',
        )}
      </Stack.Item>

      {/* Center column — fixed width so CharacterPreview anchors correctly */}
      <Stack.Item width="300px">
        <Stack vertical fill>
          {/* Preview: takes 45% of the column height */}
          <Stack.Item
            height="45%"
            style={{ overflow: 'hidden', position: 'relative' }}
          >
            <PreviewSection />
          </Stack.Item>

          {/* Extras: anything rendering below the preview, takes remaining space */}
          {columns &&
            (tab !== AugmentsTab.InternalImplants ||
              !!data.quirk_points_enabled) && (
              <Stack.Item height="55%" style={{ overflow: 'hidden' }}>
                <Section fill scrollable>
                  {tab === AugmentsTab.Markings && (
                    <>
                      <Box mb={1}>
                        <Dropdown
                          width="100%"
                          options={columns.filteredMarkingPresets}
                          selected={null}
                          placeholder="Apply a preset..."
                          maxItems={7}
                          searchInput
                          styledInput
                          onSelected={applyPreset}
                        />
                      </Box>
                      <Divider />
                    </>
                  )}
                  <CenterColumnExtras
                    tab={tab}
                    center={columns.center}
                    act={actAndResetPresetWarning}
                  />
                </Section>
              </Stack.Item>
            )}
        </Stack>
      </Stack.Item>

      {/* Right column */}
      <Stack.Item minWidth="33%">
        {columnForTab(
          columns?.right ?? [],
          columns?.internalImplants.right ?? [],
          'bottom-start',
        )}
      </Stack.Item>
    </Stack>
  );

  const presetPopup = pendingPreset && (
    <div style={pendingPresetStyle}>
      <PresetConfirmPopup
        preset={pendingPreset}
        markings={pendingPresetData?.markings ?? null}
        keepTogether={!!pendingPresetData?.keep_together}
        zones={pendingPresetZones}
        onConfirm={() => {
          hasWarnedRef.current = true;
          act('set_preset', { preset: pendingPreset });
          setPendingPreset(null);
        }}
        onCancel={() => setPendingPreset(null)}
      />
    </div>
  );

  if (roomTheme) {
    const markings = tab === AugmentsTab.Markings;
    return (
      <>
        {presetPopup}
        <div className="LimbsPage__room">
          <AugmentsRoom
            theme={roomTheme}
            mode={markings ? 'markings' : 'augments'}
            onMode={(mode) =>
              handleTab(
                mode === 'markings'
                  ? AugmentsTab.Markings
                  : AugmentsTab.BodyParts,
              )
            }
            tools={
              markings ? (
                <MarkingsTools theme={roomTheme} />
              ) : (
                <AugmentsLayers
                  internals={tab === AugmentsTab.InternalImplants}
                  onInternals={(internals) =>
                    handleTab(
                      internals
                        ? AugmentsTab.InternalImplants
                        : AugmentsTab.BodyParts,
                    )
                  }
                />
              )
            }
          >
            {markings ? (
              <MarkingsRoom
                theme={roomTheme}
                act={actAndResetPresetWarning}
                onLook={applyPreset}
              />
            ) : (
              !!stage && (
                <AugmentsStage
                  internals={tab === AugmentsTab.InternalImplants}
                  parts={stage.parts}
                  organs={stage.organs}
                  act={act}
                />
              )
            )}
          </AugmentsRoom>
        </div>
      </>
    );
  }

  return (
    <>
      {presetPopup}
      <Stack fill vertical>
        <Stack.Item>
          <Stack>
            <Stack.Item grow>
              <Button
                selected={tab === AugmentsTab.Markings}
                onClick={() => handleTab(AugmentsTab.Markings)}
                fluid
                align="center"
                fontSize="14px"
              >
                Markings
              </Button>
            </Stack.Item>
            <Stack.Item grow>
              <Button
                selected={tab === AugmentsTab.BodyParts}
                onClick={() => handleTab(AugmentsTab.BodyParts)}
                fluid
                align="center"
                fontSize="14px"
              >
                Body Parts
              </Button>
            </Stack.Item>
            <Stack.Item grow>
              <Button
                selected={tab === AugmentsTab.InternalImplants}
                onClick={() => handleTab(AugmentsTab.InternalImplants)}
                fluid
                align="center"
                fontSize="14px"
              >
                Internal Implants
              </Button>
            </Stack.Item>
          </Stack>
        </Stack.Item>
        <Stack.Item grow>{columnsView}</Stack.Item>
      </Stack>
    </>
  );
};
