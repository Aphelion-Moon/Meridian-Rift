// THIS IS AN APHELION UI FILE

/**
 * How long the thumbnails one task draws may take, in ms, before the rest
 * wait for the next frame.
 */
export const DRAW_SLICE_MS = 4;

type Job = { draw: () => void; live: boolean };

const waiting: Job[] = [];
let sliceStart: number | undefined;
let flushing = false;
const nothing = () => {};

/**
 * Thumbnails drawn in slices. A commit that mounts a whole sheet of them (a
 * drawer of seventy markings, the marking sets) draws them in order until
 * DRAW_SLICE_MS has passed since its first, and the rest on the frames after,
 * a slice a frame, so opening one is no longer one long task. A sheet opens
 * on its top, so the ones drawn first are the ones in view, and the drawers
 * fade in over the frames the rest take. A thumbnail drawn alone, or the few
 * of a card, is drawn at once.
 *
 * Returns what forgets the draw if it hasn't happened yet: a thumbnail that
 * changes or goes before its turn.
 */
export function drawInSlices(draw: () => void): () => void {
  const now = performance.now();
  if (sliceStart === undefined) {
    sliceStart = now;
    // The task's own slice ends with it.
    queueMicrotask(() => {
      sliceStart = undefined;
    });
  }
  // Behind any already waiting, so they keep their order.
  if (!waiting.length && now - sliceStart < DRAW_SLICE_MS) {
    draw();
    return nothing;
  }
  const job: Job = { draw, live: true };
  waiting.push(job);
  if (!flushing) {
    flushing = true;
    requestAnimationFrame(drawWaiting);
  }
  return () => {
    job.live = false;
  };
}

/** A frame's slice of the waiting thumbnails; the rest wait for the next. */
function drawWaiting() {
  const start = performance.now();
  while (waiting.length) {
    if (performance.now() - start >= DRAW_SLICE_MS) {
      requestAnimationFrame(drawWaiting);
      return;
    }
    const job = waiting.shift() as Job;
    if (job.live) {
      job.draw();
    }
  }
  flushing = false;
}
