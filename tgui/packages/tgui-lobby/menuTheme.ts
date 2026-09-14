// THIS IS AN APHELION UI FILE
import {
  MERIDIAN_BASE_THEME_OPTIONS,
  type MeridianBaseThemeId,
  type MeridianTheme,
} from 'tgui/constants/meridian-themes';

/** Both renderers read lobby choices from the theme's editable definition. */
export function getLobbyMenuTheme(theme: MeridianBaseThemeId) {
  const definition: MeridianTheme | undefined =
    MERIDIAN_BASE_THEME_OPTIONS.find(({ id }) => id === theme);
  const heading = definition?.lobby?.heading ?? 'NETWORK ACCESS';
  return {
    heading,
    treatment:
      heading && definition?.lobby?.layout !== 'custom'
        ? 'instrument'
        : undefined,
  };
}
