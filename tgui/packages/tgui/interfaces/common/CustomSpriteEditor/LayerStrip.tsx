// THIS IS AN APHELION UI FILE
import { Button, Icon } from 'tgui-core/components';
import { classes } from 'tgui-core/react';
import { decodeHtmlEntities } from 'tgui-core/string';
import { type Appendage, KINDS, kindGlyph, zoneInfo } from './appendages';
import { GRAFFITI_MAX_LAYERS } from './graffitiCodec';
import type { GraffitiLayer } from './types';

/** The layer kind a tab or panel is coloured by. */
export const layerKind = (appendage: Appendage | null) =>
  !appendage ? 'hair' : appendage.outer ? 'over' : 'under';

type LayerStripProps = {
  appendages: Appendage[];
  selected: string;
  /** Whether the Base hair layer has paint in the view shown. */
  hairPainted: boolean;
  direction: string;
  maxAppendages: number;
  onSelect: (id: string) => void;
  onAdd: () => void;
};

/** The Base hair layer and each appendage layer as tabs, and the button that adds another. */
export const LayerStrip = (props: LayerStripProps) => {
  const {
    appendages,
    selected,
    hairPainted,
    direction,
    maxAppendages,
    onSelect,
    onAdd,
  } = props;
  const tab = (id: string, appendage: Appendage | null, painted: boolean) => (
    <Button
      key={id}
      className={classes([
        'CustomSpriteEditor__layerTab',
        `CustomSpriteEditor__kind--${layerKind(appendage)}`,
      ])}
      selected={selected === id}
      tooltip={
        appendage
          ? `${appendage.name} · ${zoneInfo(appendage.zone).name} · ${KINDS[appendage.outer ? 'over' : 'under'].label}`
          : 'Your main hair. Hats trim it to fit.'
      }
      tooltipPosition="bottom"
      onClick={() => onSelect(id)}
    >
      <Icon
        className="CustomSpriteEditor__kindIcon"
        name={`tg-zaphelion-${kindGlyph(appendage)}`}
      />
      <span className="CustomSpriteEditor__layerName">
        {appendage ? appendage.name : 'Base hair layer'}
      </span>
      {!!appendage && (
        <span className="CustomSpriteEditor__zoneBadge">
          {zoneInfo(appendage.zone).short}
        </span>
      )}
      <span
        className={classes([
          'CustomSpriteEditor__pip',
          painted && 'CustomSpriteEditor__pip--lit',
        ])}
        role="img"
        aria-label={
          painted ? 'Painted in this view' : 'Not painted in this view'
        }
      />
    </Button>
  );
  return (
    <div className="CustomSpriteEditor__strip">
      <div className="CustomSpriteEditor__group CustomSpriteEditor__layerTabs">
        {tab('hair', null, hairPainted)}
        {appendages.map((appendage) =>
          tab(appendage.id, appendage, !!appendage.edited[direction]),
        )}
      </div>
      {appendages.length < maxAppendages && (
        <Button
          className="CustomSpriteEditor__addLayer"
          icon="plus"
          tooltip="Add a piece that attaches to one part of the head."
          onClick={onAdd}
        >
          Appendage layer
        </Button>
      )}
      <span className="CustomSpriteEditor__stripNote">
        {appendages.length} of {maxAppendages} appendages
      </span>
    </div>
  );
};

type GraffitiLayerStripProps = {
  /** Bottom first. */
  layers: GraffitiLayer[];
  selected: string;
  /** Layer id -> whether it has paint. */
  painted: Record<string, boolean>;
  onSelect: (id: string) => void;
  onAdd: () => void;
};

/** Graffiti's layers as tabs, from the bottom up, and the button that adds one on top. */
export const GraffitiLayerStrip = (props: GraffitiLayerStripProps) => {
  const { layers, selected, painted, onSelect, onAdd } = props;
  return (
    <div className="CustomSpriteEditor__strip">
      <div className="CustomSpriteEditor__group CustomSpriteEditor__layerTabs">
        {layers.map((layer) => (
          <Button
            key={layer.id}
            className={classes([
              'CustomSpriteEditor__layerTab',
              'Graffiti__layerTab',
              !!layer.glow && 'Graffiti__layerTab--glow',
            ])}
            selected={selected === layer.id}
            tooltip={layer.glow ? 'Glows in the dark.' : undefined}
            tooltipPosition="bottom"
            onClick={() => onSelect(layer.id)}
          >
            {!!layer.glow && (
              <Icon className="CustomSpriteEditor__kindIcon" name="lightbulb" />
            )}
            <span className="CustomSpriteEditor__layerName">
              {decodeHtmlEntities(layer.name)}
            </span>
            <span
              className={classes([
                'CustomSpriteEditor__pip',
                painted[layer.id] && 'CustomSpriteEditor__pip--lit',
              ])}
              role="img"
              aria-label={painted[layer.id] ? 'Painted' : 'Not painted yet'}
            />
          </Button>
        ))}
      </div>
      {layers.length < GRAFFITI_MAX_LAYERS && (
        <Button
          className="CustomSpriteEditor__addLayer"
          icon="plus"
          tooltip="Add a layer on top."
          onClick={onAdd}
        >
          Layer
        </Button>
      )}
      <span className="CustomSpriteEditor__stripNote">
        {layers.length} of {GRAFFITI_MAX_LAYERS} layers
      </span>
    </div>
  );
};
