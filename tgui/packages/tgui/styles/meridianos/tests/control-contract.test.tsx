// THIS IS AN APHELION UI FILE
import { afterAll, afterEach, beforeAll, describe, expect, it } from 'bun:test';
import { readFileSync } from 'node:fs';
import { join } from 'node:path';
import { cleanup, render } from '@testing-library/react';
import type { CSSProperties } from 'react';
import { compileAsync } from 'sass-embedded';
import {
  Button,
  Dropdown,
  Icon,
  NoticeBox,
  Stack,
  Tabs,
} from 'tgui-core/components';

import {
  MERIDIAN_THEME_IDS,
  resolveMeridianTheme,
} from '../../../constants/theme';
import { LOADOUT_CATEGORY_TABS_CLASS } from '../../../interfaces/PreferencesMenu/CharacterPreferences/loadout';
/** The stylesheets under test live one level up from this directory. */
const styleRoot = join(import.meta.dir, '..');


const COMPONENT_SOURCE = readFileSync(
  join(styleRoot, '_components.scss'),
  'utf8',
);
const DECORATION_SOURCE = readFileSync(
  join(styleRoot, '_decoration.scss'),
  'utf8',
);
const THEME_SOURCE = readFileSync(
  join(styleRoot, '_themes.scss'),
  'utf8',
);
const TOKEN_SOURCE = readFileSync(
  join(styleRoot, '_tokens.scss'),
  'utf8',
);
const CHECKED_ARIA = {
  'aria-checked': true,
  role: 'checkbox',
} as const;
const UNCHECKED_ARIA = {
  'aria-checked': false,
  role: 'checkbox',
} as const;

let productionStyle: HTMLStyleElement;

beforeAll(async () => {
  const [
    controlsCss,
    noticeBoxCss,
    tabsCss,
    tokenCss,
    themeCss,
    componentCss,
    decorationCss,
    preferencesCss,
  ] = await Promise.all(
    [
      // Dropdown @uses Button, which is how the core Button sheet reaches
      // this fixture. In production it arrives the same way -- but from
      // interfaces/Fabricator.scss, which main.scss loads *after* the visual
      // system. So it is appended last below, not first: injecting it first
      // hid a real cascade bug where upstream's `.Button:last-child` margin
      // reset beat an equal-specificity theme-console rule.
      '../../../../node_modules/tgui-core/styles/components/Dropdown.scss',
      '../../../../node_modules/tgui-core/styles/components/NoticeBox.scss',
      '../../../../node_modules/tgui-core/styles/components/Tabs.scss',
      '_tokens.scss',
      '_themes.scss',
      '_components.scss',
      '_decoration.scss',
      '_preferences.scss',
    ].map(
      async (file) => (await compileAsync(join(styleRoot, file))).css,
    ),
  );
  productionStyle = document.createElement('style');
  // happy-dom does not resolve custom properties in background shorthands.
  // Substitute two sentinel colors so the real compiled selectors and import
  // order can still prove that Highline's inverse state wins the cascade.
  productionStyle.textContent = (
    noticeBoxCss +
    tabsCss +
    tokenCss +
    themeCss +
    componentCss +
    decorationCss +
    preferencesCss +
    controlsCss
  )
    // happy-dom misses multiline :is() lists; browsers treat this as whitespace.
    .replace(
      /:is\(([^()]*)\)/g,
      (_match, selectors: string) => `:is(${selectors.replace(/\s+/g, ' ')})`,
    )
    .replaceAll('var(--console-interaction-pressed)', 'rgb(1, 2, 3)')
    .replaceAll('var(--console-text-primary)', 'rgb(255, 255, 255)');
  document.head.appendChild(productionStyle);
});

afterEach(cleanup);

afterAll(() => productionStyle.remove());

describe('MeridianOS shared control geometry', () => {
  it('keeps dropdown arrows on the Stack control row', () => {
    for (const theme of MERIDIAN_THEME_IDS) {
      const view = render(
        <div className={`theme-console theme-${theme}`}>
          <Stack>
            <Stack.Item>
              <Button aria-label="Direct action" fontSize="22px" icon="undo" />
            </Stack.Item>
            <Stack.Item>
              <Dropdown
                buttons
                onSelected={() => undefined}
                options={['First', 'Second']}
                selected="First"
              />
            </Stack.Item>
          </Stack>
        </div>,
      );

      const arrows = view.container.querySelectorAll('.Dropdown > .Button');
      expect(arrows).toHaveLength(2);
      for (const control of [
        view.getByLabelText('Direct action'),
        ...arrows,
      ]) {
        const style = getComputedStyle(control);
        expect(style.marginTop, `${theme}: grouped control top margin`).toBe(
          '0px',
        );
        expect(
          style.marginBottom,
          `${theme}: grouped control bottom margin`,
        ).toBe('0px');
      }
      cleanup();
    }
  });

  it('uses one theme-console contract for every MeridianOS skin', () => {
    expect(COMPONENT_SOURCE).toMatch(
      /^(?:\/\/[^\n]*\n)*\.theme-console \{/,
    );

    for (const theme of MERIDIAN_THEME_IDS) {
      expect(resolveMeridianTheme({ requested: theme }).classes).toContain(
        'theme-console',
      );

      const view = render(
        <div
          className={`theme-console theme-${theme}`}
          style={
            {
              '--space-xs': '2px',
              '--tab-indicator-size': '3px',
            } as CSSProperties
          }
        >
          <Button aria-label="Ungrouped legacy button">Ungrouped</Button>
          <div className="MeridianShowcase__switcherControls">
            <Button aria-label="Switcher inherit" icon="undo" selected>
              Inherit
            </Button>
            <Button aria-label="Icon only" icon="rotate" />
            <div className="Dropdown">
              <div className="Dropdown__control">
                <span className="Dropdown__selected-text">Aligned option</span>
                <span className="Dropdown__icon">V</span>
              </div>
            </div>
          </div>
          <Button aria-label="Short inline height" height="20px">
            Short
          </Button>
          <Button aria-label="Compact icon" compact icon="rotate" />
          <Button
            aria-label="Dense job priority"
            className="PreferencesMenu__Jobs__departments__priority"
          />
          <Button.Checkbox {...CHECKED_ARIA} checked>
            Checked
          </Button.Checkbox>
          <Button.Checkbox {...UNCHECKED_ARIA} checked={false}>
            Unchecked
          </Button.Checkbox>
          <input aria-label="Selected radio" defaultChecked type="radio" />
          <input aria-label="Disabled checkbox" disabled type="checkbox" />
          <div aria-selected="true" className="Tab Tab--selected">
            <span className="Tab__left">L</span>
            <span className="Tab__text">Selected tab</span>
            <span className="Tab__right">R</span>
          </div>
          <div className="Section__buttons">
            <div className="Dropdown">
              <div className="Dropdown__control">
                <span className="Dropdown__selected-text">Section option</span>
                <span className="Dropdown__icon">V</span>
              </div>
            </div>
            <Button aria-label="Section action">Apply</Button>
          </div>
          <Tabs className={LOADOUT_CATEGORY_TABS_CLASS} fluid>
            <Tabs.Tab selected>
              <span>
                <Icon name="hat-cowboy" />
                <br />
                Head
              </span>
            </Tabs.Tab>
          </Tabs>
        </div>,
      );

      const fixture = view.container.firstElementChild as HTMLElement;
      const ungroupedButton = view.getByLabelText('Ungrouped legacy button');
      const switcherInherit = view.getByLabelText('Switcher inherit');
      const iconOnly = view.getByLabelText('Icon only');
      const compact = view.getByLabelText('Compact icon');
      const denseJobPriority = view.getByLabelText('Dense job priority');
      const shortInlineHeight = view.getByLabelText('Short inline height');
      const checked = view.getByRole('checkbox', { name: 'Checked' });
      const unchecked = view.getByRole('checkbox', { name: 'Unchecked' });
      const selectedRadio = view.getByLabelText('Selected radio');
      const disabledCheckbox = view.getByLabelText('Disabled checkbox');
      const selectedTab = view
        .getByText('Selected tab')
        .closest('.Tab') as HTMLElement;
      const dropdownControl = view.getByText('Aligned option').parentElement!;
      const switcherDropdown = dropdownControl.closest('.Dropdown')!;
      const sectionDropdownControl =
        view.getByText('Section option').parentElement!;
      const sectionDropdown = sectionDropdownControl.closest('.Dropdown')!;
      const sectionAction = view.getByLabelText('Section action');
      const sectionButtons = sectionAction.parentElement!;
      const loadoutCategoryTab = view
        .getByText('Head')
        .closest('.Tab') as HTMLElement;
      const iconContent = iconOnly.querySelector(
        '.Button__content',
      ) as HTMLElement;
      const compactContent = compact.querySelector(
        '.Button__content',
      ) as HTMLElement;
      const checkedGlyph = checked.querySelector(
        '.fa-check-square',
      ) as HTMLElement;

      expect(
        getComputedStyle(fixture).getPropertyValue('--button-height').trim(),
        `${theme}: normal control height`,
      ).toBe('22px');
      expect(getComputedStyle(iconContent).display).toBe('flex');
      expect(getComputedStyle(iconContent).alignItems).toBe('center');
      expect(getComputedStyle(iconContent).minHeight).toBe('22px');
      expect(getComputedStyle(compactContent).minHeight).not.toBe('22px');
      expect(getComputedStyle(iconOnly).minWidth).toBe('24px');
      expect(getComputedStyle(iconOnly).minHeight).toBe('24px');
      expect(getComputedStyle(shortInlineHeight).minHeight).toBe('24px');
      expect(getComputedStyle(compact).minWidth).not.toBe('24px');
      expect(getComputedStyle(compact).minHeight).not.toBe('24px');
      expect(getComputedStyle(denseJobPriority).minHeight).not.toBe('24px');

      expect(checked.classList).toContain('Button--selected');
      expect(checked.getAttribute('aria-checked')).toBe('true');
      expect(checkedGlyph).not.toBeNull();
      expect(getComputedStyle(checkedGlyph).display).toBe('inline-flex');
      expect(getComputedStyle(checkedGlyph).overflow).toBe('visible');
      expect(unchecked.classList).not.toContain('Button--selected');
      expect(unchecked.getAttribute('aria-checked')).toBe('false');
      expect(unchecked.querySelector('.fa-square')).not.toBeNull();

      expect(getComputedStyle(selectedRadio).width).toBe('16px');
      expect(getComputedStyle(selectedRadio).height).toBe('16px');
      expect(getComputedStyle(disabledCheckbox).opacity).toBe(
        theme === 'meridian_highline' ? '1' : '0.58',
      );
      expect(getComputedStyle(dropdownControl).height).toBe('24px');
      expect(getComputedStyle(sectionDropdownControl).height).toBe('24px');
      expect(
        getComputedStyle(sectionButtons).gap,
        `${theme}: section actions use the shared 8px gutter`,
      ).toBe('8px');

      // Horizontal gutters are upstream's and unchanged.
      expect(getComputedStyle(ungroupedButton).marginRight).toBe('2px');
      for (const groupedControl of [
        switcherInherit,
        iconOnly,
        switcherDropdown,
        sectionDropdown,
        sectionAction,
      ]) {
        expect(getComputedStyle(groupedControl).marginRight).toBe('0px');
      }

      // Vertical margins must stay symmetric on every button, `:last-child`
      // included. `vertical-align: middle` centres the margin box, so an
      // uneven block margin drops that button below its neighbours -- which is
      // what upstream's `:last-child { margin-bottom: 0 }` used to do to the
      // last button of every row. The total gutter is preserved, just split.
      for (const button of [
        ungroupedButton,
        switcherInherit,
        iconOnly,
        sectionAction,
        view.getByLabelText('Compact icon'),
      ]) {
        const style = getComputedStyle(button);
        expect(style.marginTop).toBe(style.marginBottom);
      }
      // happy-dom does not evaluate calc(), so the total gutter is pinned at
      // the source instead: the same --space-xs upstream uses, split in two.
      expect(COMPONENT_SOURCE).toContain(
        'margin-top: calc(var(--space-xs) / 2)',
      );
      expect(COMPONENT_SOURCE).toContain(
        'margin-bottom: calc(var(--space-xs) / 2)',
      );

      // Every inline control shares one alignment, or a row that mixes them
      // steps by ~1px. NumberInput was the worst of these at 3.3px.
      for (const control of [
        ungroupedButton,
        switcherDropdown,
        sectionDropdown,
      ]) {
        expect(getComputedStyle(control).verticalAlign).toBe('middle');
      }
      expect(getComputedStyle(loadoutCategoryTab).paddingTop).toBe('3px');
      expect(getComputedStyle(loadoutCategoryTab).paddingBottom).toBe('3px');
      expect(
        getComputedStyle(selectedTab.querySelector('.Tab__left')!).display,
      ).toBe('inline-flex');

      if (theme === 'meridian_highline') {
        expect(getComputedStyle(selectedTab).backgroundColor).toBe(
          'rgb(255, 255, 255)',
        );
      }

      cleanup();
    }
  });

  it('keeps compact sizing out of individual skin decoration', () => {
    for (const source of [DECORATION_SOURCE, THEME_SOURCE]) {
      expect(source).not.toContain('.Button--compact');
      expect(source).not.toContain('--button-height');
    }

    // The window skin was reverted, so no theme decoration may reintroduce
    // frame artwork that changes the shared control box.
    expect(DECORATION_SOURCE).not.toContain('border-image-source');

    expect(COMPONENT_SOURCE).toContain(
      ".Tab:where(.Tab--selected, [aria-selected='true'])",
    );
  });

  it('keeps skin paint off caller-styled section headers', () => {
    // tgui-core deliberately gives .Section__title no background, which is
    // what lets a caller colour a whole section and have the header inherit
    // it. StyleableSection reuses these class names under a caller-styled
    // root that carries no `.Section` class, so an unscoped paint rule here
    // covers the caller's colour while the caller's own text colour survives
    // -- that is how JobSelection's department headers went dark-on-dark.
    // Skin paint therefore has to be scoped to a real Section.
    const headerRule =
      /([^\n{}]*\.Section__title(?:Text)?\b[^\n{}]*?)\{([^{}]*)\}/g;
    const paints = /(^|[\s;])(background|color)[-a-z]*\s*:/;
    const offenders: string[] = [];

    for (const [label, source] of [
      ['_components.scss', COMPONENT_SOURCE],
      ['_decoration.scss', DECORATION_SOURCE],
    ] as const) {
      for (const [, selector, body] of source.matchAll(headerRule)) {
        if (!paints.test(body) || selector.includes('.Section >')) {
          continue;
        }
        offenders.push(`${label}: ${selector.trim()}`);
      }
    }

    expect(offenders).toEqual([]);
  });

  it('preserves caller-selected NoticeBox banners and semantic anchors', () => {
    const view = render(
      <div className="theme-console theme-meridian">
        <NoticeBox aria-label="Caller-colored notice" color="blue">
          Blue alert
        </NoticeBox>
        <NoticeBox aria-label="Information notice" info>
          Information
        </NoticeBox>
        <NoticeBox aria-label="Success notice" success>
          Success
        </NoticeBox>
        <NoticeBox aria-label="Warning notice">Warning</NoticeBox>
        <NoticeBox aria-label="Danger notice" danger>
          Danger
        </NoticeBox>
      </div>,
    );

    const callerColored = view.getByLabelText('Caller-colored notice');
    expect(callerColored.classList).toContain('NoticeBox--color--blue');
    expect(
      getComputedStyle(callerColored)
        .getPropertyValue('--noticebox-background')
        .trim(),
    ).toBe('hsl(210, 65%, 47.5%)');
    expect(getComputedStyle(callerColored).backgroundImage).toContain(
      'repeating-linear-gradient',
    );

    const noticeRule = COMPONENT_SOURCE.match(/\.NoticeBox \{([^}]*)\}/)?.[1];
    expect(noticeRule).toBeDefined();
    expect(noticeRule).not.toMatch(/(^|\s)background(?:-color|-image)?\s*:/);
    expect(noticeRule).not.toContain('--noticebox-background:');
    expect(noticeRule).toContain(
      'border: 1px solid var(--noticebox-background)',
    );
    expect(TOKEN_SOURCE).toContain(
      '--notice-box-background: var(--console-status-warning)',
    );

    for (const [type, anchor] of [
      ['info', 'information'],
      ['success', 'success'],
      ['warning', 'warning'],
      ['danger', 'danger'],
    ] as const) {
      expect(COMPONENT_SOURCE).toMatch(
        new RegExp(
          `\\.NoticeBox--type--${type} \\{[^}]*` +
            `--noticebox-background: var\\(--console-status-${anchor}\\)`,
          's',
        ),
      );
    }
  });
});
