// THIS IS AN APHELION UI FILE
import { Button, Icon } from 'tgui-core/components';
import { classes } from 'tgui-core/react';
import { type Appendage, KINDS, kindGlyph, zoneInfo } from './appendages';

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
          : 'Your hair sits under headwear, and hats with a hair mask trim it to fit. Add an appendage layer for a piece that should stay whole under a hat, or sit on top of one.'
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
