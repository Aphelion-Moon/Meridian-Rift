// THIS IS AN APHELION UI FILE
import type { Species } from '../../types';

/** Renders nothing when a species has no description on record. */
export function SpeciesDescription(props: { desc: Species['desc'] }) {
  const { desc } = props;
  if (!desc) {
    return null;
  }

  return (
    <div className="SpeciesDescription">
      <p>{desc}</p>
    </div>
  );
}
