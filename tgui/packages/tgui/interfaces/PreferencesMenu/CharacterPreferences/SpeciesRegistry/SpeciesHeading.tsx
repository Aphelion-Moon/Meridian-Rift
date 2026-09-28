// THIS IS AN APHELION UI FILE
import { Button, Icon } from 'tgui-core/components';

import type { SpeciesBrowserModel } from './model';
import { getParentId } from './taxonomy';

type Props = {
  model: SpeciesBrowserModel;
  id: string;
};

/** Family, parent link and the species name. */
export function SpeciesHeading(props: Props) {
  const { model, id } = props;
  const { species } = model;
  const entry = species[id];
  const family = model.getFamily(entry.family);
  const parent = getParentId(species, id);

  return (
    <div className="SpeciesHeading">
      <div className="SpeciesHeading__eyebrow">
        <Icon name={family.icon} />
        <span>{family.name}</span>
        {parent && (
          <>
            <span className="SpeciesHeading__rule" />
            <span>Variant of</span>
            <Button
              className="SpeciesHeading__parent"
              color="transparent"
              compact
              onClick={() => model.inspect(parent)}
            >
              {species[parent].name}
            </Button>
          </>
        )}
      </div>
      <h2 className="SpeciesHeading__name ConsoleDisplay">{entry.name}</h2>
    </div>
  );
}
