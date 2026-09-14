import { loadMappings } from 'common/assets';
import { fetchRetry } from 'tgui-core/http';
/* // APHELION EDIT REMOVAL START
import { loadedMappings } from '../../assets';
*/ // APHELION EDIT REMOVAL END
import { loadedMappings } from '../../assets'; // APHELION EDIT ADDITION
import { loadIconMap } from '../../iconMap'; // APHELION EDIT ADDITION

/// --------- Handlers ------------------------------------------------------///

export function handleLoadAssets(payload: Record<string, string>): void {
  loadMappings(payload, loadedMappings);

  /* // APHELION EDIT REMOVAL START
  if (
    'icon_ref_map.json' in payload &&
    Byond.iconRefMap &&
    Object.keys(Byond.iconRefMap).length === 0
  ) {
    fetchRetry(payload['icon_ref_map.json'])
      .then((res) => res.json())
      .then(setIconRefMap)
      .catch(console.error);
  */ // APHELION EDIT REMOVAL END
  // APHELION EDIT ADDITION START
  if (payload['icon_ref_map.json']) {
    void loadIconMap(payload['icon_ref_map.json']);
    // APHELION EDIT ADDITION START
  }
}

/// --------- Helpers -------------------------------------------------------///

// https://biomejs.dev/linter/rules/no-assign-in-expressions/
function setIconRefMap(map: Record<string, string>): void {
  Byond.iconRefMap = map;
}
