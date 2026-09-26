// THIS IS AN APHELION UI FILE
import { Tooltip } from 'tgui-core/components';
import { sendAction } from '../actions';

export type StationTrait = {
  ref: string;
  name: string;
  description: string;
  iconState: string;
  overlays: string[];
};

function icon(
  assetMap: Record<string, string>,
  name: string,
): string | undefined {
  return assetMap[`${name}.png`];
}

/**
 * Station trait sign-up buttons
 */
export function StationTraitList({
  traits,
  assetMap,
}: {
  traits: StationTrait[];
  assetMap: Record<string, string>;
}) {
  if (!traits.length) {
    return null;
  }

  return (
    <div className="trait_list">
      {traits.map((trait) => (
        <Tooltip key={trait.ref} content={trait.description} position="top">
          <button
            className="trait_button"
            onClick={() => sendAction('sign_up', { ref: trait.ref })}
            type="button"
          >
            <span className="trait_icon_wrapper">
              <img
                alt=""
                className="trait_icon"
                src={icon(assetMap, trait.iconState)}
              />
              {trait.overlays.map((overlay) => (
                <img
                  key={overlay}
                  className="trait_icon trait_icon--overlay"
                  src={icon(assetMap, overlay)}
                  alt=""
                />
              ))}
            </span>
            <span className="trait_name">{trait.name}</span>
          </button>
        </Tooltip>
      ))}
    </div>
  );
}
