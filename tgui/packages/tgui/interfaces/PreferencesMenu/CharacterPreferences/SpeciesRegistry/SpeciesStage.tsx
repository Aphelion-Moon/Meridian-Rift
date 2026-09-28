// THIS IS AN APHELION UI FILE
import { Button, Section } from 'tgui-core/components';

import type { SpeciesBrowserModel } from './model';
import { SpeciesDecision } from './SpeciesDecision';
import { SpeciesDescription } from './SpeciesDescription';
import { SpeciesDetailTabs } from './SpeciesDetailTabs';
import { SpeciesHeading } from './SpeciesHeading';
import { SpecimenViewer } from './SpecimenViewer';

/**
 * The inspected species: name and choice, the specimen, then its details.
 * Everything above the description keeps its height from species to species,
 * so browsing never moves the page under the pointer.
 */
export function SpeciesStage(props: { model: SpeciesBrowserModel }) {
  const { model } = props;
  const id = model.inspected;
  const entry = model.species[id];

  return (
    <Section fill className="SpeciesStage">
      <div className="SpeciesStage__floor">
        <div className="SpeciesStage__left">
          <div>
            <Button icon="arrow-left" onClick={model.onBack}>
              Character
            </Button>
          </div>
          <SpeciesHeading model={model} id={id} />
          <SpeciesDecision model={model} id={id} />
          <div className="SpeciesStage__description">
            <SpeciesDescription desc={entry.desc} />
          </div>
        </div>
        <div className="SpeciesStage__center">
          <SpecimenViewer
            icon={entry.icon}
            name={entry.name}
            self={id === model.current ? model.selfPreview : undefined}
            onBody={model.loadBodySprites}
          />
        </div>
        <div className="SpeciesStage__right">
          <SpeciesDetailTabs model={model} id={id} />
        </div>
      </div>
    </Section>
  );
}
