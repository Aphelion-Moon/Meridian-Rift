// THIS IS AN APHELION UI FILE
import { BlockQuote } from 'tgui-core/components';

/** Every part of the lore, or nothing at all when none is on record. */
export function SpeciesLore(props: { lore: string[] | null }) {
  const { lore } = props;

  if (!lore?.length) {
    return null;
  }

  return (
    <div className="SpeciesLore">
      <BlockQuote className="SpeciesLore__text">
        {lore.map((paragraph, index) => (
          <p key={index}>{paragraph}</p>
        ))}
      </BlockQuote>
    </div>
  );
}
