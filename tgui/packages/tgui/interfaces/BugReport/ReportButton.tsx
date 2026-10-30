// THIS IS AN APHELION UI FILE

import type { ComponentProps } from 'react';
import { Button } from 'tgui-core/components';

// tgui-core's Button is a div that leaves its role out, and its props have no room to pass one
const BUTTON_ROLE = { role: 'button' } as object;

/** A tgui Button that screen readers know is a button */
export function ReportButton(props: ComponentProps<typeof Button>) {
  return <Button {...props} {...BUTTON_ROLE} />;
}
