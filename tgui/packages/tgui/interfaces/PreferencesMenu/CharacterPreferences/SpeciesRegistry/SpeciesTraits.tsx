// THIS IS AN APHELION UI FILE
import { Icon } from 'tgui-core/components';
import { classes } from 'tgui-core/react';

import type { Species } from '../../types';
import { PERK_KINDS } from './constants';

/** Every perk spelled out, grouped by kind; no hover needed to read them. */
export function SpeciesTraits(props: { perks: Species['perks'] }) {
  const { perks } = props;
  const groups = PERK_KINDS.filter(({ kind }) => perks[kind].length > 0);

  return (
    <div className="SpeciesTraits">
      {!groups.length && (
        <div className="SpeciesTraits__empty">No notable traits on record.</div>
      )}
      {groups.map(({ kind, title }) => (
        <div
          key={kind}
          className={classes([
            'SpeciesTraits__group',
            `SpeciesTraits__group--${kind}`,
          ])}
        >
          <div className="SpeciesTraits__heading">{title}</div>
          <ul className="SpeciesTraits__list">
            {perks[kind].map((perk) => (
              <li key={perk.name} className="SpeciesTrait">
                <span className="SpeciesTrait__icon">
                  <Icon name={perk.ui_icon} />
                </span>
                <span className="SpeciesTrait__text">
                  <span className="SpeciesTrait__name">{perk.name}</span>
                  <span className="SpeciesTrait__description">
                    {perk.description}
                  </span>
                </span>
              </li>
            ))}
          </ul>
        </div>
      ))}
    </div>
  );
}
