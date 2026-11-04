// THIS IS AN APHELION UI FILE

import {
  type KeyboardEvent,
  type PointerEvent,
  useEffect,
  useRef,
  useState,
} from 'react';
import { createRoot, type Root } from 'react-dom/client';
import { Icon } from 'tgui-core/components';
import { classes } from 'tgui-core/react';
import { configAtom, store } from '../events/store';
import { ReportButton } from '../interfaces/BugReport/ReportButton';
import { type Crop, encodeSnapshot, renderUiSnapshot } from './dom-snapshot';
import {
  CORNERS,
  type Corner,
  cropBetween,
  isSlip,
  keyAction,
  nextFocus,
  type Point,
  pivotFor,
  type Reason,
  reasonOf,
} from './overlay';
import { type StringId, say } from './strings';
import { SnapshotTransfer } from './transfer';

/** What the server asks a window for - the capture's nonce, and how it wants the image sent */
type CaptureRequest = { nonce: string; chunk: number; limit: number };

/** How long this window gives a capture before it gives up, a little under the server's three minutes */
const DEADLINE = 170000;

/** The capture this window is working on, and the preview it shows for it */
let current:
  | {
      request: CaptureRequest;
      deadline: ReturnType<typeof setTimeout>;
      host?: HTMLDivElement;
      root?: Root;
      transfer?: SnapshotTransfer;
      /** Why its drawing failed, which is what the server hears however the overlay closes */
      failure?: Reason;
      /** Whether the server brought the report window forward when the last chunk arrived */
      forward?: boolean;
    }
  | undefined;

/** When this window started the snapshot it's still drawing, which carries on after the server ends its capture */
let drawingSince: number | undefined;

/** Takes the preview down, telling the server nothing */
function close() {
  if (!current) return;
  clearTimeout(current.deadline);
  current.root?.unmount();
  current.host?.remove();
  current = undefined;
}

/** Turns a capture down before anything is drawn, saying why */
function refuse(nonce: string, reason: Reason) {
  Byond.sendMessage('bug-report/capture-cancel', { nonce, reason });
}

/** Stops this window's capture, telling the server why unless it already finished. A failed drawing keeps its reason */
export function cancelUiSnapshot(reason: Reason = 'cancelled') {
  if (!current) return;
  const why = current.failure ?? reason;
  if (current.transfer?.active) current.transfer.cancel(why);
  else if (!current.transfer) refuse(current.request.nonce, why);
  close();
}

/** The server took a chunk, and with the last one says whether the report window came forward */
export function acknowledgeUiSnapshot(payload: {
  nonce: string;
  index: number;
  forward?: unknown;
}) {
  if (current && payload?.nonce === current.request.nonce)
    current.forward = !!payload.forward;
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
  // A finished preview may still be open, but a capture in progress keeps the window, and so does a drawing left
  // over from an ended one, since two clones at once share one renderer. A drawing older than the deadline counts
  // as stuck, so it stops holding the window
  if (
    (drawingSince !== undefined &&
      performance.now() - drawingSince < DEADLINE) ||
    (current && !(current.transfer && !current.transfer.active))
  ) {
    refuse(request.nonce, 'busy');
    return;
  }
  if (!name || name === 'BugReport') {
    refuse(request.nonce, 'not_allowed');
    return;
  }
  close();
  current = {
    request,
    deadline: setTimeout(() => cancelUiSnapshot('timed_out'), DEADLINE),
  };
  let canvas: HTMLCanvasElement | undefined;
  let failure: Reason | undefined;
  // A steady clock like the deadline timer's, so changing the system clock can't free or hold the window early
  const started = performance.now();
  drawingSince = started;
  try {
    // Drawn before the preview exists, so the preview can never be in it
    canvas = await renderUiSnapshot(document.body);
  } catch (error) {
    failure = reasonOf(error);
  } finally {
    // A render that counted as stuck can still settle later, and mustn't free the window from the one drawing now
    if (drawingSince === started) drawingSince = undefined;
  }
  if (current?.request.nonce !== request.nonce) return;
  current.failure = failure;
  current.host = document.createElement('div');
  document.body.appendChild(current.host);
  current.root = createRoot(current.host);
  current.root.render(
    <SnapshotPreview canvas={canvas} failure={failure} request={request} />,
  );
  Byond.winset(Byond.windowId, { focus: true });
}

/** The overlay's element ids, for its name, its description and where focus goes */
const TITLE_ID = 'BugReportCapture-title';
const ABOUT_ID = 'BugReportCapture-about';
const ADD_ID = 'BugReportCapture-add';
const CANCEL_ID = 'BugReportCapture-cancel';
const CLOSE_ID = 'BugReportCapture-close';

/** A failed drawing's line, the same words the report window gets for that reason */
const FAILURE_LINES: Partial<Record<Reason, StringId>> = {
  too_big: 'cap.too_big',
  empty: 'cap.empty',
  timed_out: 'cap.timed_out',
};

const clamp = (value: number) => Math.max(0, Math.min(1, value));

function SnapshotPreview(props: {
  canvas?: HTMLCanvasElement;
  failure?: Reason;
  request: CaptureRequest;
}) {
  const { canvas, failure, request } = props;
  // Dragging lives in refs and moves the box by hand, so a drag never re-renders
  const selection = useRef<HTMLDivElement>(null);
  const pivot = useRef<Point | undefined>(undefined);
  const crop = useRef<Crop | undefined>(undefined);
  // Enter can come again before the next render, and adds once
  const adding = useRef(false);
  const [cropped, setCropped] = useState(false);
  const [phase, setPhase] = useState<'preview' | 'sending' | 'done'>(
    canvas ? 'preview' : 'done',
  );
  const [note, setNote] = useState<{ text: string; failed?: boolean }>();

  // The server ends a capture whose window never says this, since a renderer that died drawing it can't
  useEffect(() => {
    Byond.sendMessage('bug-report/capture-ready', { nonce: request.nonce });
  }, [request.nonce]);

  // Focus goes to what comes next - Add to report, Cancel while it sends, Close at the end - and back to Add
  // when Clear crop goes
  useEffect(() => {
    const target =
      phase === 'preview' ? ADD_ID : phase === 'sending' ? CANCEL_ID : CLOSE_ID;
    document.getElementById(target)?.focus();
  }, [phase, cropped]);

  function showCrop(area?: Crop) {
    crop.current = area;
    const box = selection.current;
    if (!box) return;
    box.hidden = !area;
    if (area) {
      Object.assign(box.style, {
        left: `${area.x * 100}%`,
        top: `${area.y * 100}%`,
        width: `${area.width * 100}%`,
        height: `${area.height * 100}%`,
      });
    }
  }

  function point(event: PointerEvent): Point {
    const bounds = canvas!.getBoundingClientRect();
    return {
      x: clamp((event.clientX - bounds.x) / bounds.width),
      y: clamp((event.clientY - bounds.y) / bounds.height),
    };
  }

  function clearCrop() {
    showCrop(undefined);
    setCropped(false);
  }

  async function attach() {
    if (phase !== 'preview' || !canvas || adding.current) return;
    adding.current = true;
    setPhase('sending');
    setNote({ text: say('ov.preparing') });
    try {
      const encoded = await encodeSnapshot(canvas, request.limit, crop.current);
      if (current?.request.nonce !== request.nonce) return;
      const transfer = new SnapshotTransfer(Byond.sendMessage, {
        chunk: request.chunk,
        limit: request.limit,
        finished: (ok) => {
          // The report window came forward to show the picture, so nothing's left to say here
          if (ok && current?.forward) return close();
          setPhase('done');
          setNote(
            ok
              ? { text: say('ov.sent') }
              : { text: say('ov.stopped'), failed: true },
          );
        },
        progress: (sent, total) =>
          setNote({
            text: say('ov.sending', { n: Math.round((sent / total) * 100) }),
          }),
      });
      // Started before the capture holds it, so one that never starts is still cancelled with the server
      transfer.start(request.nonce, encoded);
      current.transfer = transfer;
    } catch (error) {
      adding.current = false;
      setPhase('preview');
      setNote({
        text: say(
          reasonOf(error) === 'too_big' ? 'ov.tooBigCrop' : 'cap.failed',
        ),
        failed: true,
      });
    }
  }

  function onKeyDown(event: KeyboardEvent<HTMLDivElement>) {
    if (event.key === 'Tab') {
      // The window under the overlay is out of reach, so focus goes round the overlay's own buttons
      const controls = [
        ...event.currentTarget.querySelectorAll<HTMLElement>('[tabindex="0"]'),
      ];
      if (!controls.length) return;
      event.preventDefault();
      controls[
        nextFocus(
          controls.indexOf(document.activeElement as HTMLElement),
          controls.length,
          event.shiftKey,
        )
      ].focus();
      return;
    }
    const action = keyAction(event.key, event.defaultPrevented);
    if (!action) return;
    event.preventDefault();
    if (action === 'cancel') cancelUiSnapshot();
    else attach();
  }

  return (
    <div
      className="BugReportCapture"
      role="dialog"
      aria-modal="true"
      aria-labelledby={TITLE_ID}
      aria-describedby={ABOUT_ID}
      tabIndex={-1}
      onKeyDown={onKeyDown}
    >
      <div className="BugReportCapture__panel">
        <h2 id={TITLE_ID} className="BugReportCapture__title">
          {say('ov.title')}
        </h2>
        {canvas ? (
          <>
            <p id={ABOUT_ID} className="BugReportCapture__text">
              {say('ov.text')}
            </p>
            <div
              className="BugReportCapture__stage"
              onPointerDown={(event) => {
                if (phase !== 'preview') return;
                const corner = (event.target as HTMLElement).dataset?.corner;
                // A corner handle resizes the crop from the corner across from it, anywhere else starts a new one
                if (corner && crop.current) {
                  pivot.current = pivotFor(crop.current, corner as Corner);
                } else {
                  pivot.current = point(event);
                  showCrop(undefined);
                }
                event.currentTarget.setPointerCapture(event.pointerId);
                event.preventDefault();
              }}
              onPointerMove={(event) => {
                if (!pivot.current || phase !== 'preview') return;
                showCrop(cropBetween(pivot.current, point(event)));
              }}
              onPointerUp={() => {
                if (!pivot.current) return;
                pivot.current = undefined;
                const { width, height } = canvas.getBoundingClientRect();
                // A slip of the mouse is not a crop
                if (crop.current && isSlip(crop.current, width, height))
                  showCrop(undefined);
                setCropped(!!crop.current);
              }}
            >
              <div
                ref={(node) => {
                  if (node && canvas.parentNode !== node) node.prepend(canvas);
                }}
              />
              <div
                ref={selection}
                className="BugReportCapture__selection"
                hidden
              >
                {CORNERS.map((corner) => (
                  <div
                    key={corner}
                    className={`BugReportCapture__handle BugReportCapture__handle--${corner}`}
                    data-corner={corner}
                  />
                ))}
              </div>
            </div>
          </>
        ) : (
          <p
            id={ABOUT_ID}
            className="BugReportCapture__text BugReportCapture__failure"
          >
            <Icon name="triangle-exclamation" />
            {say(FAILURE_LINES[failure!] ?? 'cap.failed')}
          </p>
        )}
        <div className="MeridianControlRow BugReportCapture__footer">
          <div
            className={classes([
              'MeridianControlRow__fill',
              'BugReportCapture__status',
              note?.failed && 'BugReportCapture__status--failed',
            ])}
            role="status"
            aria-live="polite"
          >
            {note?.failed && <Icon name="triangle-exclamation" />}
            {note?.text}
          </div>
          {phase === 'done' ? (
            <ReportButton id={CLOSE_ID} onClick={() => cancelUiSnapshot()}>
              {say('ov.close')}
            </ReportButton>
          ) : (
            <ReportButton id={CANCEL_ID} onClick={() => cancelUiSnapshot()}>
              {say('ov.cancel')}
            </ReportButton>
          )}
          {phase === 'preview' && cropped && (
            <ReportButton onClick={clearCrop}>{say('ov.clear')}</ReportButton>
          )}
          {phase === 'preview' && (
            <ReportButton
              id={ADD_ID}
              color="good"
              className="BugReportCapture__add"
              onClick={attach}
            >
              {say('ov.add')}
            </ReportButton>
          )}
        </div>
        {phase === 'preview' && (
          <p className="BugReportCapture__keys">{say('ov.keys')}</p>
        )}
      </div>
    </div>
  );
}
