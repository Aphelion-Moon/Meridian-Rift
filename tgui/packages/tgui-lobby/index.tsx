import './styles/main.scss';

import { loadMappings, loadStyleSheet } from 'common/assets';
import { createRoot, type Root } from 'react-dom/client';
import { focusMap } from 'tgui/focus';
import { globalEvents } from 'tgui-core/events';
import { assetMap } from './assets';
import { LobbyMenu } from './LobbyMenu';
import { updateScaling } from './scaling';
// APHELION EDIT ADDITION START - MERIDIAN_UI
import {
  isLobbyDisplayControlInteractionTarget,
  isLobbyKeyboardInteractionTarget,
} from './themeFocus';
// APHELION EDIT ADDITION END

let reactRoot: Root | null = null;

document.onreadystatechange = () => {
  if (document.readyState !== 'complete') return;

  updateScaling();

  window.addEventListener('resize', () => {
    updateScaling();
  });

  globalEvents.on('keydown', (key) => {
    /* // APHELION EDIT REMOVAL START - MERIDIAN_UI
    if (key.isModifierKey()) return;
    */ // APHELION EDIT REMOVAL END
    // APHELION EDIT ADDITION START - MERIDIAN_UI
    if (
      key.isModifierKey() ||
      key.event.key === 'Tab' ||
      isLobbyKeyboardInteractionTarget(key.event.target)
    ) {
      return;
    }
    // APHELION EDIT ADDITION END
    setTimeout(focusMap);
  });
  /* // APHELION EDIT REMOVAL START - MERIDIAN_UI
  window.addEventListener('mouseup', () => {
  */ // APHELION EDIT REMOVAL END
  // APHELION EDIT ADDITION START - MERIDIAN_UI
  window.addEventListener('mouseup', (event) => {
    if (isLobbyDisplayControlInteractionTarget(event.target)) {
      return;
    }
    // APHELION EDIT ADDITION END
    setTimeout(focusMap);
  });

  Byond.winget('mapwindow.map_lobby_selector').then(
    (info: { size: string }) => {
      Byond.winset('lobby_menu', { size: info.size });
    },
  );

  if (!reactRoot) {
    const root = document.getElementById('react-root');
    reactRoot = createRoot(root!);
  }

  reactRoot.render(<LobbyMenu />);

  Byond.subscribeTo('asset/stylesheet', loadStyleSheet);
  Byond.subscribeTo('asset/mappings', (payload: Record<string, string>) => {
    loadMappings(payload, assetMap);
  });
};
