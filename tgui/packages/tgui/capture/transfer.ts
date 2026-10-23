// THIS IS AN APHELION UI FILE

type Send = (type: string, payload: Record<string, unknown>) => void;

export type TransferOptions = {
  /** Base64 characters per chunk, as the server asked */
  chunk: number;
  /** Most base64 characters the server takes for one image */
  limit: number;
  /** Least time between two chunks, which keeps us under the server's 10 topics a second */
  spacing?: number;
  /** How long a chunk waits for its acknowledgement before it goes again */
  ackTimeout?: number;
  /** Sends of one chunk before the transfer gives up */
  tries?: number;
  finished?: (ok: boolean) => void;
  progress?: (sent: number, total: number) => void;
};

/**
 * One image's base64, sent a chunk at a time. Each chunk waits for the server's acknowledgement,
 * a lost one goes again, and the sends stay spaced under the topic rate limit.
 */
export class SnapshotTransfer {
  private nonce = '';
  private encoded = '';
  private index = 0;
  private tries = 0;
  /** When the last chunk went, on the steady clock, so the first one never waits */
  private lastSend = -Infinity;
  private timer?: ReturnType<typeof setTimeout>;
  private options: Required<TransferOptions>;

  constructor(
    private send: Send,
    options: TransferOptions,
  ) {
    this.options = {
      spacing: 125,
      ackTimeout: 3000,
      tries: 3,
      finished: () => {},
      progress: () => {},
      ...options,
    };
  }

  get active() {
    return this.nonce !== '';
  }

  start(nonce: string, encoded: string) {
    if (this.active) throw new Error('A snapshot transfer is already running.');
    if (
      !nonce ||
      !encoded.length ||
      encoded.length > this.options.limit ||
      encoded.length % 4 ||
      !/^[A-Za-z0-9+/]+={0,2}$/.test(encoded)
    ) {
      throw new Error('This snapshot is over the size limit or not an image.');
    }
    this.nonce = nonce;
    this.encoded = encoded;
    this.index = 0;
    this.tries = 0;
    this.schedule();
  }

  acknowledge(message: { nonce: string; index: number }) {
    if (
      !this.active ||
      message?.nonce !== this.nonce ||
      message.index !== this.index
    )
      return;
    this.index++;
    this.tries = 0;
    const sent = Math.min(this.index * this.options.chunk, this.encoded.length);
    this.options.progress(sent, this.encoded.length);
    if (sent === this.encoded.length) this.finish(true);
    else this.schedule();
  }

  cancel() {
    if (!this.active) return;
    this.send('bug-report/capture-cancel', { nonce: this.nonce });
    this.finish(false);
  }

  /** Sends the current chunk as soon as the spacing allows */
  private schedule() {
    clearTimeout(this.timer);
    this.timer = setTimeout(
      () => this.post(),
      Math.max(0, this.lastSend + this.options.spacing - performance.now()),
    );
  }

  private post() {
    if (!this.active) return;
    if (++this.tries > this.options.tries) {
      this.cancel();
      return;
    }
    const { chunk } = this.options;
    // A steady clock like the busy check's, so changing the system clock can't bunch the chunks up or hold them back
    this.lastSend = performance.now();
    this.send('bug-report/capture-chunk', {
      nonce: this.nonce,
      index: this.index,
      totalLength: this.encoded.length,
      data: this.encoded.slice(this.index * chunk, (this.index + 1) * chunk),
    });
    // No acknowledgement in time means a message was lost, so the same chunk goes again
    this.timer = setTimeout(() => this.schedule(), this.options.ackTimeout);
  }

  private finish(ok: boolean) {
    clearTimeout(this.timer);
    this.nonce = '';
    this.encoded = '';
    this.options.finished(ok);
  }
}
