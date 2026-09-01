// THIS IS AN APHELION UI FILE
import { useAtom, useSetAtom } from 'jotai';
import { Icon } from 'tgui-core/components';
import {
  debugThemeAtom,
  kitchenSinkAtom,
  meridianThemeAtom,
} from '../events/store';
import { MeridianThemePicker } from './MeridianThemePicker';

export function MeridianTitleBarUtilities() {
  const [kitchenSink, setKitchenSink] = useAtom(kitchenSinkAtom);
  const setDebugTheme = useSetAtom(debugThemeAtom);
  const [meridianTheme, setMeridianTheme] = useAtom(meridianThemeAtom);

  return (
    <div className="TitleBar__utilities">
      <MeridianThemePicker
        className="TitleBar__themePicker"
        onChange={(theme) => {
          setDebugTheme(null);
          setMeridianTheme(theme);
          Byond.sendMessage('setMeridianTheme', { theme });
        }}
        value={meridianTheme}
      />
      {process.env.NODE_ENV !== 'production' && (
        <button
          aria-label="Toggle development showcase"
          aria-pressed={kitchenSink}
          className="TitleBar__utilityButton TitleBar__KitchenSink"
          onClick={() => setKitchenSink((prev) => !prev)}
          type="button"
        >
          <Icon aria-hidden="true" name="bug" />
        </button>
      )}
    </div>
  );
}
