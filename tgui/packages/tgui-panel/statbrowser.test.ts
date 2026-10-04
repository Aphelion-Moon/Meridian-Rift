import { describe, expect, it } from 'bun:test';
import { readFileSync } from 'node:fs';
import { runInNewContext } from 'node:vm';
import { Window } from 'happy-dom';

const script = readFileSync(
  new URL('../../../html/statbrowser.js', import.meta.url),
  'utf8',
);
const html = readFileSync(
  new URL('../../../html/statbrowser.html', import.meta.url),
  'utf8',
);

// Exercise the shipped statbrowser, including its DOM and Byond message protocol.
const createPanel = () => {
  const window = new Window();
  window.document.body.innerHTML = html;
  const handlers = new Map<string, (payload: unknown) => void>();
  const messages: {
    type: string;
    payload: { tab?: string; tabs?: string[] };
  }[] = [];
  const context = {
    window,
    document: window.document,
    Byond: {
      windowId: 'statbrowser',
      sendMessage: (type: string, payload = {}) =>
        messages.push({ type, payload }),
      subscribeTo: (type: string, handler: (payload: unknown) => void) =>
        handlers.set(type, handler),
      winset: () => {},
      command: () => {},
    },
    setTimeout: () => 0,
    clearTimeout: () => {},
  };
  runInNewContext(script, context);
  messages.length = 0;
  return { handlers, messages, window };
};

describe('statbrowser body transfers', () => {
  it('acknowledges complete verb refreshes once, including identical refreshes', () => {
    const { handlers, messages, window } = createPanel();
    for (let transfer = 0; transfer < 8; transfer++) {
      const tabs = [
        transfer % 2 ? 'AI Commands' : 'Robot Commands',
        'IC',
        'OOC',
        'Object',
        'Preferences',
        'Mob',
        'Movement',
        'Misc',
      ];
      // Login and mind transfer each request a refresh; the backend clears its tab list each time.
      for (let refresh = 0; refresh < 2; refresh++) {
        handlers.get('init_verbs')?.({
          panel_tabs: [...tabs],
          verblist: tabs.map((tab, index) => [tab, `Fixture ${index}`]),
        });
        const last = messages.at(-1);
        expect(last?.type).toBe('Send-Tabs');
        expect(last?.payload.tabs).toEqual(
          expect.arrayContaining(['Status', 'Favourites', ...tabs]),
        );
        const acknowledgedTabs = last?.payload.tabs ?? [];
        expect(new Set(acknowledgedTabs).size).toBe(acknowledgedTabs.length);
      }
    }
    expect(messages).toHaveLength(16);
    expect(window.document.getElementById('AI Commands')).not.toBeNull();
    window.close();
  });

  it('keeps incremental category additions and removals synchronized', () => {
    const { handlers, messages, window } = createPanel();
    handlers.get('add_verb_list')?.([['Fixture', 'Temporary Verb']]);
    expect(messages).toContainEqual({
      type: 'Send-Tabs',
      payload: { tab: 'Fixture' },
    });
    expect(window.document.getElementById('Fixture')).not.toBeNull();
    handlers.get('remove_verb_list')?.([['Fixture', 'Temporary Verb']]);
    expect(messages).toContainEqual({
      type: 'Remove-Tabs',
      payload: { tab: 'Fixture' },
    });
    expect(window.document.getElementById('Fixture')).toBeNull();
    window.close();
  });

  it('preserves a shared tab and falls back when switching removes the selected tab', () => {
    const { handlers, messages, window } = createPanel();
    const refresh = (tabs: string[]) =>
      handlers.get('init_verbs')?.({
        panel_tabs: [...tabs],
        verblist: tabs.map((tab) => [tab, `${tab} fixture`]),
      });
    refresh(['AI Commands', 'IC', 'OOC', 'Object', 'Preferences', 'Mob']);
    window.document
      .getElementById('IC')
      ?.dispatchEvent(new window.MouseEvent('click'));
    messages.length = 0;
    refresh(['AI Commands', 'IC', 'OOC', 'Object', 'Preferences', 'Mob']);
    expect(window.document.getElementById('IC')?.className).toBe(
      'button active',
    );
    expect(messages).toHaveLength(1);

    window.document
      .getElementById('AI Commands')
      ?.dispatchEvent(new window.MouseEvent('click'));
    messages.length = 0;
    refresh(['Robot Commands', 'IC']);
    expect(window.document.getElementById('AI Commands')).toBeNull();
    expect(window.document.getElementById('OOC')).toBeNull();
    expect(window.document.getElementById('Object')).toBeNull();
    expect(window.document.getElementById('Preferences')).toBeNull();
    expect(window.document.getElementById('Mob')).toBeNull();
    expect(window.document.getElementById('Status')?.className).toBe(
      'button active',
    );
    expect(
      window.document.getElementById('statcontent')?.textContent,
    ).not.toContain('AI Commands fixture');
    expect(messages.map((message) => message.type)).toEqual([
      'Send-Tabs',
      'Set-Tab',
    ]);
    expect(messages.at(-1)?.payload.tab).toBe('Status');
    window.close();
  });
});
