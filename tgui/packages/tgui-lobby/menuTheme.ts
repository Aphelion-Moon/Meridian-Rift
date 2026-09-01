// THIS IS AN APHELION UI FILE
import {
  MERIDIAN_BASE_THEME_OPTIONS,
  type MeridianBaseThemeId,
  type MeridianTheme,
} from 'tgui/constants/meridian-themes';

/** Themes may override the shared heading in their own definition. */
export function getLobbyMenuHeading(theme: MeridianBaseThemeId) {
  const definition: MeridianTheme | undefined = MERIDIAN_BASE_THEME_OPTIONS.find(
    ({ id }) => id === theme,
  );
  return definition?.lobbyHeading ?? 'NETWORK ACCESS';
}

/** The first three authored menus retain their independently tuned layouts. */
export function usesSharedLobbyMenu(theme: MeridianBaseThemeId) {
  return (
    !!getLobbyMenuHeading(theme) &&
    !['meridian_pipboy', 'meridian_highline', 'meridian_aphelion'].includes(
      theme,
    )
  );
}
