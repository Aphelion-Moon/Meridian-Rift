// THIS IS AN APHELION UI FILE
import type { SyntheticEvent } from 'react';

/**
 * Keeps a press on a control that hangs on the glass to that control: the
 * character under the glass turns, pans and resets on presses, and must not
 * take this one.
 */
export const keepPress = (event: SyntheticEvent) => event.stopPropagation();
