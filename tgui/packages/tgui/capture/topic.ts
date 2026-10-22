// THIS IS AN APHELION UI FILE

declare global {
  interface Window {
    chrome?: { webview?: { postMessage: (message: string) => void } };
  }
}

/**
 * Byond.sendMessage for a message of any size.
 *
 * Byond.call sends a URL of 2048 characters or more as an XHR GET, which DreamSeeker 516 answers
 * with a 404, so the message never reaches the server (tgui's act chunking works around the same
 * thing). WebView2's postMessage carries it whole: measured byte-identical to 2.8 MB, in order.
 * See the lab's bug-reporting hardening ds-topic-probe.
 */
export function sendLargeMessage(type: string, payload: object) {
  const url =
    `byond://?type=${encodeURIComponent(type)}` +
    `&payload=${encodeURIComponent(JSON.stringify(payload))}` +
    `&tgui=1&window_id=${encodeURIComponent(Byond.windowId)}`;
  const webview = window.chrome?.webview;
  if (webview) webview.postMessage(url);
  else location.href = url;
}

/** An act for this window's UI, sent whole however long its text is */
export function sendLargeAct(action: string, payload: object) {
  sendLargeMessage(`act/${action}`, payload);
}
