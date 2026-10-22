// THIS IS AN APHELION UI FILE

import {
  type CSSProperties,
  type PointerEvent,
  useEffect,
  useRef,
  useState,
} from 'react';
import { createRoot, type Root } from 'react-dom/client';
import { Box, Button } from 'tgui-core/components';
import { configAtom, store } from '../events/store';
import {
  type Crop,
  encodeSnapshot,
  renderUiSnapshot,
  SnapshotRefusal,
} from './dom-snapshot';
import { sendLargeMessage } from './topic';
import { SnapshotTransfer } from './transfer';

/** What the server asks a window for - the capture's nonce, and how it wants the image sent */
type CaptureRequest = { nonce: string; chunk: number; limit: number };

/** The capture this window is working on, and the preview it shows for it */
let current:
  | {
      request: CaptureRequest;
      deadline: ReturnType<typeof setTimeout>;
      host?: HTMLDivElement;
      root?: Root;
      transfer?: SnapshotTransfer;
    }
  | undefined;

/** Takes the preview down, telling the server nothing */
function close() {
  if (!current) return;
  clearTimeout(current.deadline);
  current.root?.unmount();
  current.host?.remove();
  current = undefined;
}

/** Stops this window's capture, telling the server unless it already finished */
export function cancelUiSnapshot() {
  if (!current) return;
  if (current.transfer?.active) current.transfer.cancel();
  else if (!current.transfer)
    sendLargeMessage('bug-report/capture-cancel', {
      nonce: current.request.nonce,
    });
  close();
}

export function acknowledgeUiSnapshot(payload: {
  nonce: string;
  index: number;
}) {
  current?.transfer?.acknowledge(payload);
}

/** The server ended the capture itself, so there is nothing to tell it */
export function abortUiSnapshot(payload: { nonce: string }) {
  if (payload?.nonce === current?.request.nonce) close();
}

/** Only a window the server picked from this client's own gets this, and nothing outside the window opens */
export async function requestUiSnapshot(payload: CaptureRequest) {
  if (typeof payload?.nonce !== 'string' || payload.nonce.length > 128) return;
  const request = {
    nonce: payload.nonce,
    chunk: Number(payload.chunk) || 32768,
    limit: Number(payload.limit) || 2796204,
  };
  const name = store.get(configAtom).interface?.name;
  // A finished preview may still be open, but a capture in progress keeps the window
  if (
    (current && !(current.transfer && !current.transfer.active)) ||
    !name ||
    name === 'BugReport'
  ) {
    sendLargeMessage('bug-report/capture-cancel', { nonce: request.nonce });
    return;
  }
  close();
  current = { request, deadline: setTimeout(cancelUiSnapshot, 170000) };
  let canvas: HTMLCanvasElement | undefined;
  let failure = '';
  try {
    // Drawn before the preview exists, so the preview can never be in it
    canvas = await renderUiSnapshot(document.body);
    Object.assign(canvas.style, {
      display: 'block',
      maxWidth: '100%',
      maxHeight: '65vh',
    });
  } catch (error) {
    failure =
      error instanceof SnapshotRefusal
        ? error.message
        : `Could not create this UI snapshot. Choose a screenshot file in the report instead. ${error instanceof Error ? error.message : error}`;
  }
  if (current?.request.nonce !== request.nonce) return;
  current.host = document.createElement('div');
  document.body.appendChild(current.host);
  current.root = createRoot(current.host);
  current.root.render(
    <SnapshotPreview canvas={canvas} failure={failure} request={request} />,
  );
  Byond.winset(Byond.windowId, { focus: true });
}

const OVERLAY: CSSProperties = {
  position: 'fixed',
  inset: 0,
  zIndex: 2147483647,
  background: '#101820',
  color: '#fff',
  padding: '16px',
  overflow: 'auto',
  font: '14px sans-serif',
};
const STAGE: CSSProperties = {
  position: 'relative',
  display: 'inline-block',
  maxWidth: '100%',
  userSelect: 'none',
  lineHeight: 0,
  touchAction: 'none',
};
const SELECTION: CSSProperties = {
  position: 'absolute',
  border: '2px solid #67d5ff',
  background: '#67d5ff33',
  pointerEvents: 'none',
  display: 'none',
};
const clamp = (value: number) => Math.max(0, Math.min(1, value));

function SnapshotPreview(props: {
  canvas?: HTMLCanvasElement;
  failure: string;
  request: CaptureRequest;
}) {
  const { canvas, failure, request } = props;
  // Dragging lives in refs and moves the box by hand, so a drag never re-renders
  const selection = useRef<HTMLDivElement>(null);
  const origin = useRef<{ x: number; y: number } | undefined>(undefined);
  const crop = useRef<Crop | undefined>(undefined);
  const [phase, setPhase] = useState<'preview' | 'sending' | 'done'>(
    canvas ? 'preview' : 'done',
  );
  const [note, setNote] = useState(failure);

  // The server ends a capture whose window never says this, since a renderer that died drawing it can't
  useEffect(() => {
    sendLargeMessage('bug-report/capture-ready', { nonce: request.nonce });
  }, [request.nonce]);

  function showCrop(area?: Crop) {
    crop.current = area;
    const style = selection.current?.style;
    if (!style) return;
    style.display = area ? 'block' : 'none';
    if (area) {
      style.left = `${area.x * 100}%`;
      style.top = `${area.y * 100}%`;
      style.width = `${area.width * 100}%`;
      style.height = `${area.height * 100}%`;
    }
  }

  function point(event: PointerEvent) {
    const bounds = canvas!.getBoundingClientRect();
    return {
      x: clamp((event.clientX - bounds.x) / bounds.width),
      y: clamp((event.clientY - bounds.y) / bounds.height),
      bounds,
    };
  }

  async function attach() {
    if (phase !== 'preview' || !canvas) return;
    setPhase('sending');
    setNote('Encoding the snapshot…');
    try {
      const encoded = await encodeSnapshot(canvas, request.limit, crop.current);
      if (current?.request.nonce !== request.nonce) return;
      current.transfer = new SnapshotTransfer(sendLargeMessage, {
        chunk: request.chunk,
        limit: request.limit,
        finished: (ok) => {
          setPhase('done');
          setNote(
            ok
              ? 'Snapshot sent. Return to the bug report to check validation and sharing.'
              : 'Snapshot transfer stopped. Return to the report and try again.',
          );
        },
        progress: (sent, total) =>
          setNote(`Sending the snapshot… ${Math.round((sent / total) * 100)}%`),
      });
      current.transfer.start(request.nonce, encoded);
    } catch (error) {
      setPhase('preview');
      setNote(String(error instanceof Error ? error.message : error));
    }
  }

  return (
    <div role="dialog" aria-label="Report UI snapshot preview" style={OVERLAY}>
      <h2>Preview this UI snapshot</h2>
      <p>
        Only this selected TGUI is reconstructed. Check for missing images or
        sensitive text. Drag a rectangle to crop, or attach the whole preview.
        It stays private until you opt in on the report.
      </p>
      {!!canvas && (
        <div
          style={STAGE}
          onPointerDown={(event) => {
            if (phase !== 'preview') return;
            origin.current = point(event);
            showCrop(undefined);
            event.currentTarget.setPointerCapture(event.pointerId);
            event.preventDefault();
          }}
          onPointerMove={(event) => {
            if (!origin.current || phase !== 'preview') return;
            const end = point(event);
            showCrop({
              x: Math.min(origin.current.x, end.x),
              y: Math.min(origin.current.y, end.y),
              width: Math.abs(origin.current.x - end.x),
              height: Math.abs(origin.current.y - end.y),
            });
          }}
          onPointerUp={(event) => {
            origin.current = undefined;
            const { bounds } = point(event);
            const area = crop.current;
            // A slip of the mouse is not a crop
            if (
              area &&
              (area.width * bounds.width < 8 || area.height * bounds.height < 8)
            )
              showCrop(undefined);
          }}
        >
          <div
            ref={(node) => {
              if (node && canvas.parentNode !== node) node.prepend(canvas);
            }}
          />
          <div ref={selection} style={SELECTION} />
        </div>
      )}
      <Box mt={1}>
        <Button disabled={phase !== 'preview'} onClick={attach}>
          Attach snapshot
        </Button>
        <Button
          disabled={phase !== 'preview'}
          onClick={() => showCrop(undefined)}
        >
          Use whole snapshot
        </Button>
        <Button onClick={cancelUiSnapshot}>
          {phase === 'done' ? 'Close preview' : 'Cancel snapshot'}
        </Button>
      </Box>
      <p role="status">{note}</p>
    </div>
  );
}
