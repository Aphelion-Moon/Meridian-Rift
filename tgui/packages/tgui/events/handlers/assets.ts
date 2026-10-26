import { loadMappings } from 'common/assets';
// import { fetchRetry } from 'tgui-core/http'; // APHELION EDIT REMOVAL
import { loadedMappings } from '../../assets';
import { loadIconMap } from '../../iconMap'; // APHELION EDIT ADDITION

/// --------- Handlers ------------------------------------------------------///

export function handleLoadAssets(payload: Record<string, string>): void {
  loadMappings(payload, loadedMappings);

  /* // APHELION EDIT REMOVAL START - iconMap.ts loads, checks and retries the map
  if (
    'icon_ref_map.json' in payload &&
    Byond.iconRefMap &&
    Object.keys(Byond.iconRefMap).length === 0
  ) {
    fetchRetry(payload['icon_ref_map.json'])
      .then((res) => res.json())
      .then(setIconRefMap)
      .catch(console.error);
  }
  */ // APHELION EDIT REMOVAL END
  // APHELION EDIT ADDITION START
  if (payload['icon_ref_map.json']) {
    void loadIconMap(payload['icon_ref_map.json']);
  }
  // APHELION EDIT ADDITION END
}

/* // APHELION EDIT REMOVAL START - unused once iconMap.ts owns the map
/// --------- Helpers -------------------------------------------------------///

// https://biomejs.dev/linter/rules/no-assign-in-expressions/
function setIconRefMap(map: Record<string, string>): void {
  Byond.iconRefMap = map;
}
*/ // APHELION EDIT REMOVAL END
