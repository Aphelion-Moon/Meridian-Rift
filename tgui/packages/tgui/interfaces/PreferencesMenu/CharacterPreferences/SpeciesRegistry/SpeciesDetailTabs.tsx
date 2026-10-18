// THIS IS AN APHELION UI FILE
import { useEffect, useRef, useState } from 'react';
import { Section, Stack, Tabs } from 'tgui-core/components';

import { IGNORE_UNLESS_LIKED } from './constants';
import type { SpeciesBrowserModel } from './model';
import { SpeciesDiet } from './SpeciesDiet';
import { SpeciesLineageList } from './SpeciesLineageList';
import { SpeciesLore } from './SpeciesLore';
import { SpeciesTraits } from './SpeciesTraits';
import { getLineage } from './taxonomy';

type DetailTab = 'traits' | 'diet' | 'lineage' | 'lore';

type Props = {
  model: SpeciesBrowserModel;
  id: string;
};

/**
 * Traits, diet, lineage and lore behind tabs, so the details never need a
 * long scroll. Tabs for missing information are not drawn.
 */
export function SpeciesDetailTabs(props: Props) {
  const { model, id } = props;
  // Each species opens on Traits. The choice is tied to the species rather
  // than remounting the panel, which also sidesteps tgui-core 6.1.3's Section
  // never unregistering a scrollable node that unmounts: a remount per species
  // leaked its DOM there.
  const [chosen, setChosen] = useState<{ id: string; tab: DetailTab }>({
    id,
    tab: 'traits',
  });
  const tab = chosen.id === id ? chosen.tab : 'traits';
  const panel = useRef<HTMLDivElement>(null);
  const entry = model.species[id];
  const lineage = getLineage(model.groups, id);
  const { positive, neutral, negative } = entry.perks;
  const hasDiet =
    !!entry.diet &&
    [
      ...entry.diet.liked_food,
      ...entry.diet.disliked_food,
      ...entry.diet.toxic_food,
    ].some((food) => !IGNORE_UNLESS_LIKED.has(food));
  const hasLineage = !!lineage && lineage.members.length > 1;
  const hasLore = !!entry.lore?.length;

  const tabs: { id: DetailTab; label: string; icon: string; count?: number }[] =
    [
      {
        id: 'traits',
        label: 'Traits',
        icon: 'list-ul',
        count: positive.length + neutral.length + negative.length,
      },
      ...(hasDiet
        ? [{ id: 'diet' as const, label: 'Diet', icon: 'utensils' }]
        : []),
      ...(hasLineage
        ? [
            {
              id: 'lineage' as const,
              label: 'Lineage',
              icon: 'code-branch',
              count: lineage.members.length,
            },
          ]
        : []),
      ...(hasLore
        ? [
            {
              id: 'lore' as const,
              label: 'Lore',
              icon: 'book',
              count: entry.lore?.length,
            },
          ]
        : []),
    ];
  const active = tabs.some((candidate) => candidate.id === tab)
    ? tab
    : 'traits';

  // A new species or tab starts from the top.
  useEffect(() => {
    if (panel.current) {
      panel.current.scrollTop = 0;
    }
  }, [id, active]);

  let content;
  switch (active) {
    case 'diet':
      content = entry.diet && <SpeciesDiet diet={entry.diet} />;
      break;
    case 'lineage':
      content = lineage && (
        <SpeciesLineageList
          species={model.species}
          lineage={lineage}
          inspected={id}
          onInspect={model.inspect}
        />
      );
      break;
    case 'lore':
      content = <SpeciesLore lore={entry.lore} />;
      break;
    default:
      content = <SpeciesTraits perks={entry.perks} />;
  }

  return (
    <Stack vertical fill className="SpeciesDetailTabs">
      <Stack.Item>
        <Tabs fluid className="SpeciesDetailTabs__tabs">
          {tabs.map((candidate) => (
            <Tabs.Tab
              key={candidate.id}
              icon={candidate.icon}
              selected={candidate.id === active}
              onClick={() => setChosen({ id, tab: candidate.id })}
            >
              {candidate.label}
              {candidate.count !== undefined && (
                <span className="SpeciesDetailTabs__count ConsoleReading">
                  {candidate.count}
                </span>
              )}
            </Tabs.Tab>
          ))}
        </Tabs>
      </Stack.Item>
      <Stack.Item grow basis={0}>
        <Section
          fill
          scrollable
          ref={panel}
          className="SpeciesDetailTabs__panel"
        >
          {content}
        </Section>
      </Stack.Item>
    </Stack>
  );
}
