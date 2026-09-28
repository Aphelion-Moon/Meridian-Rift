// THIS IS AN APHELION UI FILE
import { Button, Icon, Stack, Tabs } from 'tgui-core/components';

import type { SpeciesBrowserModel } from './model';
import { ALL_FAMILIES } from './taxonomy';

type TabLabelProps = {
  icon: string;
  name: string;
  count: number;
};

/** Icon and count over the name, so every family fits without scrolling. */
function TabLabel(props: TabLabelProps) {
  const { icon, name, count } = props;
  return (
    <span className="SpeciesToolbar__tab">
      <span className="SpeciesToolbar__tabTop">
        <Icon name={icon} />
        <span className="SpeciesToolbar__tabCount ConsoleReading">{count}</span>
      </span>
      <span className="SpeciesToolbar__tabName">{name}</span>
    </span>
  );
}

/** One row: the way back, then every family. */
export function SpeciesToolbar(props: { model: SpeciesBrowserModel }) {
  const { model } = props;
  const { groups, order, family, searching } = model;

  // Like the loadout: picking a tab clears the search, and no tab is lit
  // while results are showing.
  const pick = (id: string) => {
    model.setFamily(id);
    model.setQuery('');
  };

  return (
    <Stack align="center" className="SpeciesToolbar">
      <Stack.Item>
        <Button icon="arrow-left" onClick={model.onBack}>
          Character
        </Button>
      </Stack.Item>
      <Stack.Item grow basis={0}>
        <Tabs className="SpeciesToolbar__families" fluid>
          <Tabs.Tab
            selected={!searching && family === ALL_FAMILIES}
            onClick={() => pick(ALL_FAMILIES)}
          >
            <TabLabel icon="border-all" name="All" count={order.length} />
          </Tabs.Tab>
          {groups.map((group) => (
            <Tabs.Tab
              key={group.family.id}
              selected={!searching && family === group.family.id}
              onClick={() => pick(group.family.id)}
            >
              <TabLabel
                icon={group.family.icon}
                name={group.family.name}
                count={group.size}
              />
            </Tabs.Tab>
          ))}
        </Tabs>
      </Stack.Item>
    </Stack>
  );
}
