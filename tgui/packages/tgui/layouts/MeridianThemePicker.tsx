// THIS IS AN APHELION UI FILE
import {
  type ComponentProps,
  type ComponentRef,
  type CSSProperties,
  type KeyboardEvent,
  useCallback,
  useEffect,
  useId,
  useRef,
  useState,
} from 'react';
import { Floating, Icon } from 'tgui-core/components';
import { classes } from 'tgui-core/react';
import {
  MERIDIAN_BASE_THEME_OPTIONS,
  type MeridianBaseThemeId,
} from '../constants/theme';
import { useNativeMenuPlacement } from './useNativeMenuPlacement';

type ThemePreviewStyle = CSSProperties & {
  '--theme-preview-primary'?: string;
  '--theme-preview-secondary'?: string;
  '--theme-preview-image'?: string;
};

function getPreviewStyle(
  option: (typeof MERIDIAN_BASE_THEME_OPTIONS)[number],
): ThemePreviewStyle | undefined {
  if (!('palette' in option)) {
    return undefined;
  }
  return {
    '--theme-preview-primary': option.palette.accent,
    '--theme-preview-secondary': option.palette.secondaryAccent,
    ...('preview' in option
      ? { '--theme-preview-image': option.preview }
      : null),
  };
}

export type MeridianThemePickerProps = {
  onChange: (theme: MeridianBaseThemeId) => void;
  value: MeridianBaseThemeId;
} & Partial<{
  className: string;
  placement: ComponentProps<typeof Floating>['placement'];
}>;

export function MeridianThemePicker(props: MeridianThemePickerProps) {
  const { className, onChange, placement = 'bottom-end', value } = props;
  const [isOpen, setIsOpen] = useState(false);
  const floatingRef = useRef<ComponentRef<typeof Floating>>(null);
  const triggerRef = useRef<HTMLButtonElement>(null);
  const close = useCallback(() => floatingRef.current?.close(), []);
  const nativePlacement = useNativeMenuPlacement(
    isOpen,
    triggerRef,
    close,
    placement,
  );
  const optionRefs = useRef<Array<HTMLButtonElement | null>>([]);
  const openFocus = useRef<'first' | 'last' | 'selected'>('selected');
  const typeahead = useRef('');
  const typeaheadTimer = useRef<ReturnType<typeof setTimeout> | null>(null);
  const triggerId = useId();
  const menuId = useId();
  const selectedOption = MERIDIAN_BASE_THEME_OPTIONS.find(
    ({ id }) => id === value,
  );
  const selectedIndex = Math.max(
    MERIDIAN_BASE_THEME_OPTIONS.findIndex(({ id }) => id === value),
    0,
  );

  useEffect(() => {
    typeahead.current = '';
    return () => {
      if (typeaheadTimer.current) {
        clearTimeout(typeaheadTimer.current);
        typeaheadTimer.current = null;
      }
    };
  }, [isOpen]);

  const focusOption = (index: number) => {
    const option = optionRefs.current[index];
    option?.focus();
    option?.scrollIntoView?.({ block: 'nearest' });
  };

  useEffect(() => {
    if (isOpen && nativePlacement.ready) {
      focusOption(
        openFocus.current === 'last'
          ? MERIDIAN_BASE_THEME_OPTIONS.length - 1
          : openFocus.current === 'first'
            ? 0
            : selectedIndex,
      );
    }
  }, [isOpen, nativePlacement.ready]);

  const closeAndFocusTrigger = () => {
    floatingRef.current?.close();
    queueMicrotask(() => document.getElementById(triggerId)?.focus());
  };

  const selectTheme = (theme: MeridianBaseThemeId) => {
    onChange(theme);
    closeAndFocusTrigger();
  };

  const handleTriggerKeyDown = (event: KeyboardEvent<HTMLButtonElement>) => {
    if (event.key !== 'ArrowDown' && event.key !== 'ArrowUp') {
      if (event.key === 'Enter' || event.key === ' ') {
        openFocus.current = 'selected';
      }
      return;
    }
    event.preventDefault();
    event.stopPropagation();
    openFocus.current = event.key === 'ArrowUp' ? 'last' : 'first';
    if (isOpen) {
      focusOption(
        openFocus.current === 'last'
          ? MERIDIAN_BASE_THEME_OPTIONS.length - 1
          : 0,
      );
    } else {
      event.currentTarget.click();
    }
  };

  const handleMenuKeyDown = (event: KeyboardEvent<HTMLDivElement>) => {
    const itemCount = MERIDIAN_BASE_THEME_OPTIONS.length;
    const currentIndex = optionRefs.current.indexOf(
      document.activeElement as HTMLButtonElement,
    );
    let nextIndex: number | undefined;

    switch (event.key) {
      case 'ArrowDown':
        nextIndex = (Math.max(currentIndex, 0) + 1) % itemCount;
        break;
      case 'ArrowUp':
        nextIndex =
          (currentIndex < 0 ? itemCount : currentIndex - 1 + itemCount) %
          itemCount;
        break;
      case 'Home':
        nextIndex = 0;
        break;
      case 'End':
        nextIndex = itemCount - 1;
        break;
      case 'Escape':
        event.preventDefault();
        event.stopPropagation();
        closeAndFocusTrigger();
        return;
      case 'Tab':
        floatingRef.current?.close();
        return;
      default: {
        if (
          event.key.length !== 1 ||
          event.key === ' ' ||
          event.altKey ||
          event.ctrlKey ||
          event.metaKey
        ) {
          return;
        }
        if (typeaheadTimer.current) {
          clearTimeout(typeaheadTimer.current);
        }
        typeahead.current += event.key.toLocaleLowerCase();
        typeaheadTimer.current = setTimeout(() => {
          typeahead.current = '';
        }, 500);

        const findMatch = (search: string) => {
          for (let offset = 1; offset <= itemCount; offset++) {
            const index = (Math.max(currentIndex, -1) + offset) % itemCount;
            if (
              MERIDIAN_BASE_THEME_OPTIONS[index].name
                .toLocaleLowerCase()
                .startsWith(search)
            ) {
              return index;
            }
          }
        };

        nextIndex = findMatch(typeahead.current);
        // Repeated initials continue cycling when the full sequence has no match.
        if (nextIndex === undefined && typeahead.current.length > 1) {
          typeahead.current = event.key.toLocaleLowerCase();
          nextIndex = findMatch(typeahead.current);
        }
      }
    }

    if (nextIndex !== undefined) {
      event.preventDefault();
      event.stopPropagation();
      focusOption(nextIndex);
    }
  };

  return (
    <Floating
      ref={floatingRef}
      animationDuration={1}
      disabled={nativePlacement.disabled}
      contentStyles={nativePlacement.floatingStyle}
      content={
        <div
          aria-labelledby={triggerId}
          className="MeridianThemePicker__menu"
          id={menuId}
          onKeyDown={handleMenuKeyDown}
          ref={nativePlacement.setMenu}
          role="menu"
          style={nativePlacement.menuStyle}
        >
          <div className="MeridianThemePicker__heading" role="presentation">
            Pick your theme!
          </div>
          <div className="MeridianThemePicker__options" role="presentation">
            {MERIDIAN_BASE_THEME_OPTIONS.map((option, index) => {
              const isSelected = option.id === value;
              return (
                <button
                  aria-checked={isSelected}
                  className="MeridianThemePicker__option"
                  key={option.id}
                  onClick={() => selectTheme(option.id)}
                  ref={(node) => {
                    optionRefs.current[index] = node;
                  }}
                  role="menuitemradio"
                  tabIndex={-1}
                  type="button"
                >
                  <span
                    aria-hidden="true"
                    className="MeridianThemePicker__check"
                  >
                    {isSelected ? <Icon name="check" /> : null}
                  </span>
                  <span
                    aria-hidden="true"
                    className="MeridianThemePicker__swatch"
                    style={getPreviewStyle(option)}
                  />
                  <span className="MeridianThemePicker__label">
                    <strong>{option.name}</strong>
                    {option.construction ? (
                      <span>{option.construction}</span>
                    ) : null}
                  </span>
                </button>
              );
            })}
          </div>
        </div>
      }
      contentClasses="MeridianThemePicker__floating"
      contentOffset={4}
      onOpenChange={setIsOpen}
      placement={placement}
    >
      <span className={classes(['MeridianThemePicker', className])}>
        <button
          aria-controls={menuId}
          aria-expanded={isOpen}
          aria-haspopup="menu"
          aria-label={`Change base interface theme. Current: ${selectedOption?.name ?? 'Aphelion'}`}
          className="MeridianThemePicker__trigger"
          disabled={nativePlacement.disabled}
          id={triggerId}
          onMouseDown={() => {
            openFocus.current = 'selected';
          }}
          onKeyDown={handleTriggerKeyDown}
          ref={triggerRef}
          title={
            nativePlacement.disabled
              ? 'Resize this window to make room for the theme menu.'
              : undefined
          }
          type="button"
        >
          <Icon aria-hidden="true" name="gear" />
        </button>
      </span>
    </Floating>
  );
}
