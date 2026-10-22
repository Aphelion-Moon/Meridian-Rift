import { configAtom, store } from '../events/store';
import { renderUiSnapshot } from './dom-snapshot';
import { SnapshotTransfer } from './transfer';

let activeNonce = '';
let overlay: HTMLDivElement | undefined;
let deadline: ReturnType<typeof setTimeout> | undefined;
let transfer: SnapshotTransfer | undefined;

export function cancelUiSnapshot() {
  if (transfer?.active) transfer.cancel();
  else if (activeNonce)
    Byond.sendMessage('bug-report/capture-cancel', { nonce: activeNonce });
  activeNonce = '';
  transfer = undefined;
  clearTimeout(deadline);
  overlay?.remove();
  overlay = undefined;
}

export function acknowledgeUiSnapshot(payload: {
  nonce: string;
  index: number;
  accepted: boolean;
}) {
  transfer?.acknowledge(payload);
}

export function abortUiSnapshot(payload: { nonce: string }) {
  if (payload.nonce === activeNonce) cancelUiSnapshot();
}

function button(label: string, action: () => void) {
  const element = document.createElement('button');
  element.textContent = label;
  Object.assign(element.style, {
    padding: '8px 12px',
    margin: '6px',
    background: '#28557a',
    color: '#fff',
    border: '1px solid #8fb2d0',
    cursor: 'pointer',
  });
  element.onclick = action;
  return element;
}

/** Only a server-selected owned window receives this message. No external URL or tab is opened. */
export async function requestUiSnapshot(payload: { nonce: string }) {
  if (
    !payload ||
    typeof payload.nonce !== 'string' ||
    payload.nonce.length > 128
  )
    return;
  const config = store.get(configAtom);
  if (
    activeNonce ||
    !config.interface?.name ||
    config.interface.name === 'BugReport'
  ) {
    Byond.sendMessage('bug-report/capture-cancel', { nonce: payload.nonce });
    return;
  }
  if (!document.getElementById('react-root')) return;
  // A completed preview may still be open when another capture is requested.
  cancelUiSnapshot();
  // The React mount has absolutely positioned children and may have zero height.
  const root = document.body;
  activeNonce = payload.nonce;
  deadline = setTimeout(cancelUiSnapshot, 170000);
  try {
    // Render before creating the preview controls, so they can never appear in it.
    const data = await renderUiSnapshot(root);
    if (activeNonce !== payload.nonce) return;
    overlay = document.createElement('div');
    overlay.setAttribute('role', 'dialog');
    overlay.setAttribute('aria-label', 'Report UI snapshot preview');
    Object.assign(overlay.style, {
      position: 'fixed',
      inset: '0',
      zIndex: '2147483647',
      background: '#101820',
      color: '#fff',
      padding: '16px',
      overflow: 'auto',
      font: '14px sans-serif',
    });
    const heading = document.createElement('h2');
    heading.textContent = 'Preview this UI snapshot';
    const explanation = document.createElement('p');
    explanation.textContent =
      'Only this selected TGUI is reconstructed. Check for missing images or sensitive text. Drag a rectangle to crop, or attach the whole preview. It stays private until you opt in on the report.';
    const stage = document.createElement('div');
    Object.assign(stage.style, {
      position: 'relative',
      display: 'inline-block',
      maxWidth: '100%',
      userSelect: 'none',
      lineHeight: '0',
    });
    const image = document.createElement('img');
    image.src = data;
    image.alt = 'Selected UI snapshot';
    image.draggable = false;
    Object.assign(image.style, {
      display: 'block',
      maxWidth: '100%',
      maxHeight: '65vh',
    });
    const selection = document.createElement('div');
    Object.assign(selection.style, {
      position: 'absolute',
      border: '2px solid #67d5ff',
      background: '#67d5ff33',
      pointerEvents: 'none',
      display: 'none',
    });
    let origin: { x: number; y: number } | undefined;
    let crop:
      { x: number; y: number; width: number; height: number } | undefined;
    let uploading = false;
    function position(event: PointerEvent) {
      const bounds = image.getBoundingClientRect();
      return {
        x: Math.max(0, Math.min(1, (event.clientX - bounds.x) / bounds.width)),
        y: Math.max(0, Math.min(1, (event.clientY - bounds.y) / bounds.height)),
      };
    }
    stage.onpointerdown = (event) => {
      if (uploading) return;
      origin = position(event);
      crop = undefined;
      stage.setPointerCapture(event.pointerId);
      event.preventDefault();
    };
    stage.onpointermove = (event) => {
      if (!origin || uploading) return;
      const end = position(event);
      crop = {
        x: Math.min(origin.x, end.x),
        y: Math.min(origin.y, end.y),
        width: Math.abs(origin.x - end.x),
        height: Math.abs(origin.y - end.y),
      };
      Object.assign(selection.style, {
        display: 'block',
        left: `${crop.x * 100}%`,
        top: `${crop.y * 100}%`,
        width: `${crop.width * 100}%`,
        height: `${crop.height * 100}%`,
      });
    };
    stage.onpointerup = () => {
      origin = undefined;
      const bounds = image.getBoundingClientRect();
      if (
        crop &&
        (crop.width * bounds.width < 8 || crop.height * bounds.height < 8)
      ) {
        crop = undefined;
        selection.style.display = 'none';
      }
    };
    stage.append(image, selection);
    const controls = document.createElement('div');
    const status = document.createElement('p');
    status.setAttribute('role', 'status');
    const reset = button('Use whole snapshot', () => {
      if (!uploading) {
        crop = undefined;
        selection.style.display = 'none';
      }
    });
    const attach = button('Attach snapshot', () => {
      if (uploading || activeNonce !== payload.nonce || !image.naturalWidth)
        return;
      let selected = data;
      if (crop) {
        const sx = image.naturalWidth,
          sy = image.naturalHeight;
        const canvas = document.createElement('canvas');
        canvas.width = Math.max(1, Math.round(crop.width * sx));
        canvas.height = Math.max(1, Math.round(crop.height * sy));
        canvas
          .getContext('2d')!
          .drawImage(
            image,
            crop.x * sx,
            crop.y * sy,
            crop.width * sx,
            crop.height * sy,
            0,
            0,
            canvas.width,
            canvas.height,
          );
        selected = canvas.toDataURL('image/png');
      }
      uploading = true;
      attach.disabled = true;
      reset.disabled = true;
      status.textContent = 'Sending the selected snapshot…';
      transfer = new SnapshotTransfer(
        (type, value) => Byond.sendMessage(type, value),
        (ok) => {
          status.textContent = ok
            ? 'Snapshot sent. Return to the bug report to check validation and sharing.'
            : 'Snapshot transfer stopped. Return to the report and try again.';
          clearTimeout(deadline);
          activeNonce = '';
          dismiss.textContent = 'Close preview';
        },
      );
      try {
        transfer.start(
          payload.nonce,
          selected.slice('data:image/png;base64,'.length),
        );
      } catch (error) {
        uploading = false;
        attach.disabled = false;
        reset.disabled = false;
        status.textContent = String(error);
      }
    });
    const dismiss = button('Cancel snapshot', cancelUiSnapshot);
    controls.append(attach, reset, dismiss);
    overlay.append(heading, explanation, stage, controls, status);
    document.body.appendChild(overlay);
    Byond.winset(Byond.windowId, { 'is-focused': true });
  } catch (error) {
    if (activeNonce !== payload.nonce) return;
    cancelUiSnapshot();
    // Native upload remains available if this embedded browser cannot render.
    window.alert(
      `Could not create this UI snapshot. Choose a screenshot file in the report instead. ${String(error)}`,
    );
  }
}
