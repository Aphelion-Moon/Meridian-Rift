// THIS IS AN APHELION UI FILE
import { memo, useRef, useState } from 'react';
import { Button, Icon, Input, Tooltip } from 'tgui-core/components';
import { classes } from 'tgui-core/react';
import {
  type Appendage,
  cleanName,
  KINDS,
  type TryOnHat,
  verdict,
  ZONES,
  type ZoneInfo,
} from './appendages';
import { layerKind } from './LayerStrip';

/** A zone's pictogram: a grey head with the attaching part lit, as two stacked glyphs. */
const ZonePictogram = ({ zone }: { zone: ZoneInfo }) => (
  <span className="CustomSpriteEditor__zonePictogram" aria-hidden>
    <Icon
      className="CustomSpriteEditor__zoneHead"
      name={`tg-zaphelion-head-${zone.view}`}
    />
    <Icon
      className="CustomSpriteEditor__zoneLit"
      name={`tg-zaphelion-zone-${zone.glyph}`}
    />
  </span>
);

type CoverChipsProps = {
  hats: Record<string, TryOnHat>;
  chips: Record<string, string | undefined>;
  hat: string | null;
  zone: number;
};

/**
 * The hats that cover one zone, as chips of their front views. A Tooltip costs a render even
 * while closed and there's one for each hat in every zone, so these only render again when the
 * hats or the tried-on one change.
 */
const CoverChips = memo((props: CoverChipsProps) => {
  const { hats, chips, hat, zone } = props;
  return (
    <span className="CustomSpriteEditor__coverChips">
      {Object.entries(hats).map(([key, entry]) => {
        const covers = (entry.strict & zone) !== 0;
        return (
          <Tooltip
            key={key}
            content={`${entry.group}: ${covers ? 'cover it' : 'leave it alone'}`}
          >
            <span
              className={classes([
                'CustomSpriteEditor__coverChip',
                covers && 'CustomSpriteEditor__coverChip--covers',
                key === hat && 'CustomSpriteEditor__coverChip--worn',
              ])}
            >
              {!!chips[key] && <img src={chips[key]} alt={entry.label} />}
            </span>
          </Tooltip>
        );
      })}
    </span>
  );
});

type AppendagePanelProps = {
  appendage: Appendage;
  hats: Record<string, TryOnHat>;
  /** Hat key -> the chip image the window cropped from the hat's front view, once it has. */
  chips: Record<string, string | undefined>;
  /** The tried-on hat's key, or null. */
  hat: string | null;
  maxName: number;
  canAdd: boolean;
  onRename: (name: string) => void;
  onZone: (zone: number) => void;
  onKind: (outer: boolean) => void;
  onCopy: () => void;
  onRemove: () => void;
};

/**
 * Under the canvas while an appendage is chosen: its kind and where it attaches, which hats cover
 * each place, and what the tried-on hat does to it.
 */
export const AppendagePanel = (props: AppendagePanelProps) => {
  const { appendage, hats, chips, hat, maxName, canAdd } = props;
  const [renaming, setRenaming] = useState(false);
  const [draft, setDraft] = useState('');
  // The input blurs after Enter and Esc too, so only the first way out counts.
  const finished = useRef(false);
  const worn = hat ? hats[hat] : null;
  const judged = verdict(appendage, worn);
  const startRename = () => {
    finished.current = false;
    setDraft(appendage.name);
    setRenaming(true);
  };
  const finishRename = (value: string | null) => {
    if (finished.current) return;
    finished.current = true;
    setRenaming(false);
    const name = value === null ? '' : cleanName(value, maxName);
    if (name && name !== appendage.name) props.onRename(name);
  };
  return (
    <section
      className={classes([
        'CustomSpriteEditor__appendagePanel',
        `CustomSpriteEditor__kind--${layerKind(appendage)}`,
      ])}
    >
      <header className="CustomSpriteEditor__panelTitle">
        <span className="CustomSpriteEditor__kindDot" />
        Appendage ·{' '}
        {renaming ? (
          <span className="CustomSpriteEditor__rename">
            <Input
              autoFocus
              autoSelect
              value={appendage.name}
              maxLength={maxName}
              aria-label="Appendage name"
              onChange={setDraft}
              onEnter={finishRename}
              onEscape={() => finishRename(null)}
              onBlur={finishRename}
            />
            <span className="CustomSpriteEditor__renameCount">
              {draft.length}/{maxName}
            </span>
          </span>
        ) : (
          <>
            <span className="CustomSpriteEditor__panelName">
              {appendage.name}
            </span>
            <Button
              className="CustomSpriteEditor__renameButton"
              icon="pencil"
              color="transparent"
              tooltip={`Rename (up to ${maxName} characters)`}
              onClick={startRename}
            />
          </>
        )}
        <span className="CustomSpriteEditor__panelSpacer" />
        {!appendage.outer && canAdd && (
          <Button
            icon="copy"
            tooltip="A piece sits either under hats or on top of them. Want both? This copies it to an Over hats layer. Then erase the copy in any view where it should stay under the hat. Good for bangs that fall over a cap's brim."
            onClick={props.onCopy}
          >
            Copy to over-hat layer
          </Button>
        )}
        <Button
          className="CustomSpriteEditor__remove"
          icon="trash"
          tooltip="Remove this layer and its paint. Undo brings it back."
          onClick={props.onRemove}
        >
          Remove
        </Button>
      </header>
      <div className="CustomSpriteEditor__panelBody">
        <div className="CustomSpriteEditor__kindColumn">
          {(['under', 'over'] as const).map((kind) => (
            <button
              key={kind}
              type="button"
              className={classes([
                'CustomSpriteEditor__kindCard',
                `CustomSpriteEditor__kind--${kind}`,
              ])}
              aria-pressed={!!appendage.outer === (kind === 'over')}
              onClick={() => props.onKind(kind === 'over')}
            >
              <Icon
                className="CustomSpriteEditor__kindIcon"
                name={`tg-zaphelion-${kind}-hats`}
              />
              <span>
                <b>{KINDS[kind].label}</b>
                <small>{KINDS[kind].blurb}</small>
              </span>
            </button>
          ))}
          <div
            className={classes([
              'CustomSpriteEditor__verdict',
              judged.tone === 'warn' && 'CustomSpriteEditor__verdict--warn',
            ])}
          >
            {judged.text}
          </div>
        </div>
        <div className="CustomSpriteEditor__zoneColumn" role="radiogroup">
          <div className="CustomSpriteEditor__zoneHeader">
            <Tooltip content="Pick where this piece sits. Hats that cover that spot will trim or hide it.">
              <span>Where it attaches (for hat masking)</span>
            </Tooltip>
            <span className="CustomSpriteEditor__panelSpacer" />
            <span>Hats that cover it</span>
          </div>
          {ZONES.map((zone) => (
            <button
              key={zone.bit}
              type="button"
              role="radio"
              aria-checked={appendage.zone === zone.bit}
              className="CustomSpriteEditor__zoneRow"
              onClick={() => props.onZone(zone.bit)}
            >
              <span className="CustomSpriteEditor__zoneRadio" />
              <ZonePictogram zone={zone} />
              <span className="CustomSpriteEditor__zoneName">{zone.name}</span>
              <span className="CustomSpriteEditor__zoneExamples">
                {zone.examples}
              </span>
              <CoverChips hats={hats} chips={chips} hat={hat} zone={zone.bit} />
            </button>
          ))}
        </div>
      </div>
    </section>
  );
};
