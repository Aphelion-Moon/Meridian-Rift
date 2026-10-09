// THIS IS AN APHELION UI FILE
import type { CSSProperties } from 'react';
import { Button, Icon } from 'tgui-core/components';

import type { SpeciesBrowserModel } from './model';
import { getParentId } from './taxonomy';

type Props = {
  model: SpeciesBrowserModel;
  id: string;
};

type NameStyle = CSSProperties & { '--name-length': number };

/**
 * Family, the species name and what it is a variant of, each on one line of
 * its own whether there is anything to say, so nothing below them moves.
 */
export function SpeciesHeading(props: Props) {
  const { model, id } = props;
  const { species } = model;
  const entry = species[id];
  const family = model.getFamily(entry.family);
  const parent = getParentId(species, id);
  // Long names shrink to fit their line rather than taking another.
  const nameStyle: NameStyle = { '--name-length': entry.name.length };

  return (
    <div className="SpeciesHeading">
      <div className="SpeciesHeading__eyebrow">
        <Icon name={family.icon} />
        <span>{family.name}</span>
      </div>
      <div className="SpeciesHeading__nameLine">
        <h2
          className="SpeciesHeading__name ConsoleDisplay"
          style={nameStyle}
          title={entry.name}
        >
          {entry.name}
        </h2>
      </div>
      <div className="SpeciesHeading__variant">
        {parent && (
          <>
            <Icon name="code-branch" />
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
        {!parent && !!entry.template && (
          <>
            <span className="SpeciesHeading__template">Template</span>
            <span>A base for your own species</span>
          </>
        )}
      </div>
    </div>
  );
}
