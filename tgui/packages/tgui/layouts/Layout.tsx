/**
 * @file
 * @copyright 2020 Aleksej Komarov
 * @license MIT
 */

import { useAtomValue } from 'jotai'; // APHELION EDIT ADDITION - MERIDIAN_UI
import { useEffect, useRef } from 'react';
import type { Box } from 'tgui-core/components';
import { addScrollableNode, removeScrollableNode } from 'tgui-core/events';
import { classes } from 'tgui-core/react';
import { computeBoxClassName, computeBoxProps } from 'tgui-core/ui';
// APHELION EDIT ADDITION START - MERIDIAN_UI
import { resolveMeridianTheme } from '../constants/theme';
import { debugThemeAtom, meridianThemeAtom } from '../events/store';
import { useRootThemeClasses } from '../hooks/useRootThemeClasses';
// APHELION EDIT ADDITION END

type BoxProps = React.ComponentProps<typeof Box>;

type Props = Partial<{
  theme: string;
}> &
  BoxProps;

export function Layout(props: Props) {
  const { className, theme = 'nanotrasen', children, ...rest } = props;
  /* // APHELION EDIT REMOVAL START - MERIDIAN_UI
  const themeClass = `theme-${theme}`;

  useEffect(() => {
    document.documentElement.className = themeClass;
  }, [themeClass]);
  */ // APHELION EDIT REMOVAL END
  // APHELION EDIT ADDITION START - MERIDIAN_UI
  const debugTheme = useAtomValue(debugThemeAtom);
  const preferredTheme = useAtomValue(meridianThemeAtom);
  const resolvedTheme = resolveMeridianTheme({
    requested: theme,
    preferred: preferredTheme,
    debugOverride: process.env.NODE_ENV !== 'production' ? debugTheme : null,
  });
  const managedClasses = resolvedTheme.classes;
  const managedClassKey = managedClasses.join(' ');
  useRootThemeClasses(managedClasses);
  // APHELION EDIT ADDITION END

  return (
    <div className={managedClassKey} data-theme={resolvedTheme.base}> {/* APHELION EDIT CHANGE - MERIDIAN_UI - ORIGINAL: <div className={themeClass}> */}
      <div
        className={classes(['Layout', className, computeBoxClassName(rest)])}
        {...computeBoxProps(rest)}
      >
        {children}
      </div>
    </div>
  );
}

type ContentProps = Partial<{
  scrollable: boolean;
}> &
  BoxProps;

function LayoutContent(props: ContentProps) {
  const { className, scrollable, children, ...rest } = props;
  const node = useRef<HTMLDivElement>(null);

  useEffect(() => {
    const self = node.current;

    if (self && scrollable) {
      addScrollableNode(self);
    }
    return () => {
      if (self && scrollable) {
        removeScrollableNode(self);
      }
    };
  }, []);

  return (
    <div
      className={classes([
        'Layout__content',
        scrollable && 'Layout__content--scrollable',
        className,
        computeBoxClassName(rest),
      ])}
      ref={node}
      {...computeBoxProps(rest)}
    >
      {children}
    </div>
  );
}

Layout.Content = LayoutContent;
