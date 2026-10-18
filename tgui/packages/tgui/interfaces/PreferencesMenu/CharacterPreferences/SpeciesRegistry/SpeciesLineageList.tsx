// THIS IS AN APHELION UI FILE
import { Button, Icon } from 'tgui-core/components';
import { classes } from 'tgui-core/react';

import { SpeciesSprite } from './SpeciesSprite';
import type { SpeciesLineage, SpeciesMap } from './taxonomy';

type Props = {
  species: SpeciesMap;
  lineage: SpeciesLineage;
  inspected: string;
  onInspect: (id: string) => void;
};

/** A species and its variants as a small tree, for hopping between them. */
export function SpeciesLineageList(props: Props) {
  const { species, lineage, inspected, onInspect } = props;

  return (
    <div className="SpeciesLineageList">
      <ul className="SpeciesLineageList__tree">
        {lineage.members.map(({ id, depth }) => (
          <li
            key={id}
            className={classes([
              'SpeciesLineageList__member',
              `SpeciesLineageList__member--depth${Math.min(depth, 3)}`,
            ])}
          >
            <Button
              fluid
              selected={id === inspected}
              onClick={() => onInspect(id)}
            >
              <span className="SpeciesLineageList__row">
                <SpeciesSprite icon={species[id].icon} />
                <span className="SpeciesLineageList__name">
                  {species[id].name}
                </span>
                {!!species[id].off_station && (
                  <Icon name="compass" className="SpeciesLineageList__flag" />
                )}
              </span>
            </Button>
          </li>
        ))}
      </ul>
    </div>
  );
}
