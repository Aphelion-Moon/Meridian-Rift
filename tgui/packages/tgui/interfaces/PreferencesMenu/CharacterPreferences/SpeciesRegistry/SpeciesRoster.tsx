// THIS IS AN APHELION UI FILE
import { Button, Icon, NoticeBox, Section } from 'tgui-core/components';
import { classes } from 'tgui-core/react';

import { rosterHeading, type SpeciesBrowserModel, shownGroups } from './model';
import { noMatchText, SpeciesSearch, stepFocus } from './SpeciesSearch';
import { SpeciesSprite } from './SpeciesSprite';

type Props = {
  model: SpeciesBrowserModel;
};

function RosterTile(props: { model: SpeciesBrowserModel; id: string }) {
  const { model, id } = props;
  const entry = model.species[id];
  const locked = model.isLocked(id);

  return (
    <span
      className={classes([
        'SpeciesRoster__tile',
        id === model.current && 'SpeciesRoster__tile--current',
        locked && 'SpeciesRoster__tile--locked',
        !!entry.template && 'SpeciesRoster__tile--template',
      ])}
      data-species={id}
    >
      <Button
        selected={id === model.inspected}
        tooltip={
          entry.template ? `${entry.name}, a template species` : entry.name
        }
        tooltipPosition="top"
        onClick={() => model.inspect(id)}
        onDoubleClick={() => !locked && model.choose(id)}
      >
        <SpeciesSprite icon={entry.icon} scale={2} />
        <span className="SpeciesRoster__name">{entry.name}</span>
      </Button>
      {!!entry.template && (
        <span className="SpeciesRoster__ribbon">Template</span>
      )}
    </span>
  );
}

/**
 * Small tiles in bracketed lineages, like a character-select roster. Every
 * row shares one grid, so tiles stand in the same columns down the roster
 * and on the same line across it: a lineage's box and label are drawn in the
 * gaps around its tiles rather than taking room of their own.
 */
export function SpeciesRoster(props: Props) {
  const { model } = props;
  const { heading, count } = rosterHeading(model);

  let content;
  if (model.matches && !model.matches.length) {
    content = <NoticeBox info>{noMatchText(model)}</NoticeBox>;
  } else if (model.matches) {
    content = (
      <div className="SpeciesRoster__tiles SpeciesRoster__tiles--results">
        {model.matches.map((id) => (
          <RosterTile key={id} model={model} id={id} />
        ))}
      </div>
    );
  } else {
    content = shownGroups(model).map(({ family, lineages }) => (
      <section key={family.id} className="SpeciesRoster__family">
        <h3 className="SpeciesRoster__familyTitle" title={family.name}>
          <Icon name={family.icon} />
          <span>{family.name}</span>
        </h3>
        <div className="SpeciesRoster__tiles">
          {lineages.map(({ root, members }) =>
            members.length > 1 ? (
              <div
                key={root}
                className="SpeciesRoster__lineage"
                style={{ gridColumn: `span ${members.length}` }}
              >
                <span
                  className="SpeciesRoster__lineageLabel"
                  title={`${model.species[root].name} and its variants`}
                >
                  <Icon name="code-branch" />
                  {model.species[root].name}
                </span>
                {members.map(({ id }) => (
                  <RosterTile key={id} model={model} id={id} />
                ))}
              </div>
            ) : (
              <RosterTile key={root} model={model} id={root} />
            ),
          )}
        </div>
      </section>
    ));
  }

  return (
    <Section
      className="SpeciesRoster"
      fill
      scrollable
      title={
        <span className="SpeciesRoster__heading">
          {heading}
          <span className="SpeciesRoster__count ConsoleReading">{count}</span>
        </span>
      }
      buttons={<SpeciesSearch model={model} />}
    >
      <div
        className="SpeciesRoster__body"
        onKeyDown={(event) => stepFocus(event, model.inspect)}
      >
        {content}
      </div>
    </Section>
  );
}
