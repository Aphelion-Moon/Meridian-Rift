// THIS IS AN APHELION UI FILE
const LOBBY_PICKER_SELECTOR = [
  '.lobby__display-controls',
  '.MeridianThemePicker',
  '.MeridianThemePicker__floating',
].join(', ');
const KEYBOARD_INTERACTIVE_SELECTOR = [
  'button:not(:disabled)',
  'a[href]',
  'input:not(:disabled)',
  'select:not(:disabled)',
  'textarea:not(:disabled)',
  '[contenteditable="true"]',
  '[tabindex]:not([tabindex="-1"])',
  '[role="button"]',
  '[role="menuitemradio"]',
  '[role="menuitemcheckbox"]',
].join(', ');

/** Keep the lobby's map-focus hack away from portaled display-control menus. */
export function isLobbyDisplayControlInteractionTarget(
  target: EventTarget | null,
) {
  return (
    target instanceof Element && Boolean(target.closest(LOBBY_PICKER_SELECTOR))
  );
}

/** Let native lobby controls keep focus for Tab, Enter, and Space handling. */
export function isLobbyKeyboardInteractionTarget(target: EventTarget | null) {
  return (
    target instanceof Element &&
    Boolean(
      target.closest(
        `${LOBBY_PICKER_SELECTOR}, ${KEYBOARD_INTERACTIVE_SELECTOR}`,
      ),
    )
  );
}
