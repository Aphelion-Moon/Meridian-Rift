// THIS IS AN APHELION UI FILE

import { describe, expect, test } from 'bun:test';
import { readFileSync } from 'node:fs';
import { join } from 'node:path';

/**
 * The helpers tgui inlines into every window, read as text so we test the real thing, and the minified copy DM bakes
 * into its resources, so a copy left stale fails too
 */
const HELPERS = {
  'helpers.js': readFileSync(join(import.meta.dir, 'helpers.js'), 'utf8'),
  'helpers.min.js': readFileSync(
    join(import.meta.dir, '..', '..', 'public', 'helpers.min.js'),
    'utf8',
  ),
};

/** A paper's worth of Cyrillic, which a URL spells in six characters a letter */
const TEXT = 'ж'.repeat(3500);

/**
 * Runs the helpers in a stand-in BYOND page, with WebView2's postMessage when asked for, and returns the page's
 * Byond with what each transport carried
 */
function loadHelpers(helpers: string, webview: boolean) {
  const posted: string[] = [];
  const navigated: string[] = [];
  const requested: string[] = [];
  const page: Record<string, any> = {
    Promise,
    chrome: webview
      ? { webview: { postMessage: (message: string) => posted.push(message) } }
      : {},
  };
  const location = {
    hostname: '127.0.0.1',
    search: '',
    set href(url: string) {
      navigated.push(url);
    },
  };
  const document = {
    getElementById: (name: string) => ({
      getAttribute: () =>
        name === 'tgui:windowId' ? 'tgui-window-1' : `[${name}]`,
    }),
  };
  const navigator = {
    userAgent:
      'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/152.0.0.0 Safari/537.36 Edg/152.0.0.0',
  };
  class XMLHttpRequest {
    open(_method: string, url: string) {
      requested.push(url);
    }
    send() {}
  }
  new Function(
    'window',
    'location',
    'document',
    'navigator',
    'XMLHttpRequest',
    helpers,
  )(page, location, document, navigator, XMLHttpRequest);
  return { page, posted, navigated, requested };
}

/** A big topic, a winset, a winget and a command, the winget's answer as a promise */
function callEach(byond: ByondType) {
  byond.sendMessage('act/add_text', { text: TEXT });
  byond.winset('tgui-window-1', 'focus', true);
  const position = byond.winget('tgui-window-1', 'pos');
  byond.command('.say "hello"');
  return position;
}

for (const [name, helpers] of Object.entries(HELPERS)) {
  describe(name, () => {
    test('a WebView2 page posts each call once, verbatim, whatever its size', async () => {
      const { page, posted, navigated, requested } = loadHelpers(helpers, true);
      expect(page.Byond.POST_MESSAGE).toBe(true);
      const position = callEach(page.Byond);
      expect(navigated.length + requested.length).toBe(0);
      expect(posted.length).toBe(4);
      expect(posted[0].length > 20000).toBe(true);
      expect(posted[0]).toBe(
        `byond://?type=act%2Fadd_text&payload=${encodeURIComponent(JSON.stringify({ text: TEXT }))}&tgui=1&window_id=tgui-window-1`,
      );
      expect(posted.slice(1)).toEqual([
        'byond://winset?focus=true&id=tgui-window-1',
        'byond://winget?id=tgui-window-1&property=pos&callback=Byond.__callbacks__%5B0%5D',
        'byond://winset?command=.say%20%22hello%22',
      ]);
      // BYOND answers a winget by calling the callback it was named, the same whichever way the call went
      page.Byond.__callbacks__[0]({ pos: '10,20' });
      expect(await position).toBe('10,20');
    });

    test('a page without WebView2 posts nothing and calls the way it always has', () => {
      const webview = loadHelpers(helpers, true);
      callEach(webview.page.Byond);
      const { page, posted, navigated, requested } = loadHelpers(
        helpers,
        false,
      );
      expect(page.Byond.POST_MESSAGE).toBe(false);
      callEach(page.Byond);
      expect(posted.length).toBe(0);
      // The big topic still takes the http request, and the rest still navigate, to the very same URLs
      expect(requested.map((url) => `byond://${url}`)).toEqual(
        webview.posted.slice(0, 1),
      );
      expect(navigated).toEqual(webview.posted.slice(1));
    });
  });
}
