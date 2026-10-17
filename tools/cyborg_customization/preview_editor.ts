/** Run from the repo root with the maintained Bun runtime, after tgui build. */
import { resolve } from 'node:path';

const root = resolve(import.meta.dir, '../..');
const result = await Bun.build({
  entrypoints: [
    resolve(root, 'tgui/packages/tgui/debug/cyborg-editor.fixture.tsx'),
  ],
  target: 'browser',
  format: 'esm',
  define: { 'process.env.NODE_ENV': '"development"' },
});
if (!result.success)
  throw new AggregateError(result.logs, 'Editor fixture build failed');
const script = await result.outputs[0].text();
const html = `<!doctype html><html><head><meta charset="utf-8"><link rel="stylesheet" href="/font-awesome.css"><link rel="stylesheet" href="/style.css"></head>
<body style="background:#171b20"><div id="tgui-root"></div><script type="module" src="/editor.js"></script></body></html>`;
const server = Bun.serve({
  hostname: '127.0.0.1',
  port: 0,
  fetch(request) {
    switch (new URL(request.url).pathname) {
      case '/':
        return new Response(html, { headers: { 'Content-Type': 'text/html' } });
      case '/editor.js':
        return new Response(script, {
          headers: { 'Content-Type': 'text/javascript' },
        });
      case '/style.css':
        return new Response(
          Bun.file(resolve(root, 'tgui/public/tgui.bundle.css')),
        );
      case '/fixtures.json':
        return new Response(
          Bun.file(resolve(root, 'data/cyborg-editor-preview/fixtures.json')),
        );
      case '/font-awesome.css':
        return new Response(
          Bun.file(resolve(root, 'html/font-awesome/css/all.min.css')),
        );
      case '/fa-solid-900.ttf':
      case '/fa-regular-400.ttf':
      case '/fa-v4compatibility.ttf':
        return new Response(
          Bun.file(
            resolve(
              root,
              'html/font-awesome/webfonts',
              new URL(request.url).pathname.slice(1),
            ),
          ),
        );
      default:
        return new Response('Not found', { status: 404 });
    }
  },
});
console.log(`Cyborg editor fixture: http://127.0.0.1:${server.port}`);
