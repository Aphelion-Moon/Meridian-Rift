// THIS IS AN APHELION UI FILE
import { type ComponentProps, useEffect, useId } from 'react';
import { ByondUi as CoreByondUi } from 'tgui-core/components';
import { registerNativeUi } from './nativeUi';

/** Keep native rendering owned by tgui-core; expose its existing placeholder. */
export function ByondUi(props: ComponentProps<typeof CoreByondUi>) {
  const marker = useId();
  useEffect(() => {
    const element = document.querySelector<HTMLElement>(
      `[data-byond-ui="${marker}"]`,
    );
    if (element) return registerNativeUi(element);
  }, [marker]);
  return <CoreByondUi {...props} data-byond-ui={marker} />;
}
