// THIS IS AN APHELION UI FILE
import { Stack } from 'tgui-core/components';

import { type SpeciesBrowserInput, useSpeciesBrowser } from './model';
import { SpeciesRoster } from './SpeciesRoster';
import { SpeciesStage } from './SpeciesStage';
import { SpeciesToolbar } from './SpeciesToolbar';

/**
 * Presentational root of the species page, laid out like a character select:
 * the inspected species on stage, then the families over the roster they
 * sort. Browsing is local; only choosing a species talks to the server.
 */
export function SpeciesBrowser(props: SpeciesBrowserInput) {
  const model = useSpeciesBrowser(props);

  return (
    <Stack vertical fill className="SpeciesRegistry">
      <Stack.Item className="SpeciesRegistry__stage">
        <SpeciesStage model={model} />
      </Stack.Item>
      <Stack.Item>
        <SpeciesToolbar model={model} />
      </Stack.Item>
      <Stack.Item className="SpeciesRegistry__roster">
        <SpeciesRoster model={model} />
      </Stack.Item>
    </Stack>
  );
}
