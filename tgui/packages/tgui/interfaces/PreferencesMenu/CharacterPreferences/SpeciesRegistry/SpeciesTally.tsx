// THIS IS AN APHELION UI FILE
import { Icon } from 'tgui-core/components';
import { classes } from 'tgui-core/react';

import type { Species } from '../../types';
import { PERK_KINDS } from './constants';

/** Advantage, neutral and drawback counts, for comparing at a glance. */
export function SpeciesTally(props: { perks: Species['perks'] }) {
  const { perks } = props;
  const summary = PERK_KINDS.map(
    ({ kind, title }) => `${perks[kind].length} ${title.toLowerCase()}`,
  ).join(', ');

  return (
    <span className="SpeciesTally" title={summary}>
      {PERK_KINDS.map(({ kind, icon }) => (
        <span
          key={kind}
          className={classes([
            'SpeciesTally__count',
            `SpeciesTally__count--${kind}`,
            !perks[kind].length && 'SpeciesTally__count--empty',
          ])}
        >
          <Icon name={icon} />
          <span className="ConsoleReading">{perks[kind].length}</span>
        </span>
      ))}
      <span className="SpeciesTally__summary">{summary}</span>
    </span>
  );
}
