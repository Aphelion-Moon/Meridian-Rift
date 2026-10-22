// Local browser evidence for the actual client renderer. No game or external API.
// node tests/bug_reporting_capture_browser.mjs <Playwright package root> <built renderer module>
import assert from "node:assert/strict";
import { createRequire } from "node:module";
import { resolve } from "node:path";
import { readFile } from "node:fs/promises";
import { createServer } from "node:http";
const { chromium } = createRequire(resolve(process.argv[2], "package.json"))(
  "@playwright/test",
);
const moduleBytes = await readFile(process.argv[3]);
const server = createServer((req, res) => {
  if (req.url === "/capture.js") {
    res.writeHead(200, { "Content-Type": "text/javascript" });
    res.end(moduleBytes);
    return;
  }
  res.writeHead(200, { "Content-Type": "text/html" });
  res.end(
    `<html><head><style>body{margin:0;background:#222;color:white;min-height:100vh}#fixture{width:400px;height:300px;background:#f00}#scroll{width:100px;height:100px;overflow:auto}.tile{width:100px;height:100px}input{color:black}</style></head><body><div id="react-root"><div id="fixture"><h1>Active machine UI</h1><input value="visible text"><div id="scroll"><div class="tile" style="background:#0f0"></div><div class="tile" style="background:#00f"></div></div></div></div><script type="module">import*as api from'/capture.js';window.api=api;window.capture=api.renderUiSnapshot;window.sent=[];window.Byond={windowId:'fixture',winset(){},sendMessage(type,payload){window.sent.push({type,payload});if(type==='bug-report/capture-chunk')setTimeout(()=>api.acknowledgeUiSnapshot({...payload,accepted:true}),0);}};</script></body></html>`,
  );
});
await new Promise((resolve) => server.listen(0, "127.0.0.1", resolve));
const browser = await chromium.launch({ channel: "chrome", headless: true });
try {
  const page = await browser.newPage({ viewport: { width: 800, height: 600 } });
  await page.goto(`http://127.0.0.1:${server.address().port}`);
  await page.waitForFunction(() => typeof window.capture === "function");
  const result = await page.evaluate(async () => {
    document.getElementById("scroll").scrollTop = 100;
    const data = await window.capture(document.getElementById("fixture"));
    const image = new Image();
    image.src = data;
    await image.decode();
    const canvas = document.createElement("canvas");
    canvas.width = image.width;
    canvas.height = image.height;
    const context = canvas.getContext("2d");
    context.drawImage(image, 0, 0);
    const source = document.getElementById("scroll").getBoundingClientRect();
    const root = document.getElementById("fixture").getBoundingClientRect();
    return {
      width: image.width,
      height: image.height,
      bytes: data.length,
      background: [...context.getImageData(390, 290, 1, 1).data],
      scrolled: [
        ...context.getImageData(
          source.x - root.x + 30,
          source.y - root.y + 30,
          1,
          1,
        ).data,
      ],
    };
  });
  assert.equal(result.width, 400);
  assert.equal(result.height, 300);
  assert.ok(result.bytes < 2796250);
  assert.deepEqual(result.background, [255, 0, 0, 255]);
  assert.deepEqual(
    result.scrolled,
    [0, 0, 255, 255],
    "capture reflects the currently visible scrolled content",
  );
  await page.evaluate(async () => {
    window.api.setInterface("BugReport");
    await window.api.requestUiSnapshot({ nonce: "excluded" });
  });
  assert.equal(await page.getByRole("dialog").count(), 0);
  assert.equal(
    await page.evaluate(() => window.sent[0].type),
    "bug-report/capture-cancel",
  );
  await page.evaluate(async () => {
    window.api.setInterface("Machine");
    await window.api.requestUiSnapshot({ nonce: "selected-window" });
  });
  assert.equal(await page.getByRole("dialog").count(), 1);
  assert.equal(
    await page.evaluate(
      () =>
        window.sent.filter((event) => event.type === "bug-report/capture-chunk")
          .length,
    ),
    0,
    "preview requires explicit confirmation",
  );
  const preview = page.getByAltText("Selected UI snapshot");
  const bounds = await preview.boundingBox();
  const natural = await preview.evaluate((image) => ({
    width: image.naturalWidth,
    height: image.naturalHeight,
  }));
  await page.mouse.move(bounds.x + 20, bounds.y + 20);
  await page.mouse.down();
  await page.mouse.move(bounds.x + 120, bounds.y + 80, { steps: 5 });
  await page.mouse.up();
  await page.screenshot({ path: ".tmp/native-ui-snapshot-preview.png" });
  await page.getByText("Attach snapshot", { exact: true }).click();
  await page
    .getByText(
      "Snapshot sent. Return to the bug report to check validation and sharing.",
    )
    .waitFor();
  const cropped = await page.evaluate(async () => {
    const encoded = window.sent
      .filter((event) => event.type === "bug-report/capture-chunk")
      .map((event) => event.payload.data)
      .join("");
    const image = new Image();
    image.src = "data:image/png;base64," + encoded;
    await image.decode();
    return {
      width: image.width,
      height: image.height,
      encoded: encoded.length,
    };
  });
  assert.equal(cropped.width, Math.round((100 * natural.width) / bounds.width));
  assert.equal(
    cropped.height,
    Math.round((60 * natural.height) / bounds.height),
  );
  assert.ok(cropped.encoded <= 2796204);
  await page.getByText("Close preview", { exact: true }).click();
  await page.evaluate(async () =>
    window.api.requestUiSnapshot({ nonce: "cancelled" }),
  );
  await page.getByText("Cancel snapshot", { exact: true }).click();
  assert.equal(await page.getByRole("dialog").count(), 0);
  assert.equal(
    await page.evaluate(() => window.sent.at(-1).payload.nonce),
    "cancelled",
  );
  console.log(
    JSON.stringify({
      ok: true,
      ...result,
      cropped,
      exclusion: true,
      explicitPreview: true,
      cancelled: true,
    }),
  );
} finally {
  await browser.close();
  await new Promise((resolve) => server.close(resolve));
}
