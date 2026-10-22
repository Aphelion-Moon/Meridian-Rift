export const SNAPSHOT_CHUNK_SIZE = 32768;
export const SNAPSHOT_ENCODED_LIMIT = 2796204; // 2 MiB, base64 encoded.

type Acknowledgment = { nonce: string; index: number; accepted: boolean };
type Send = (type: string, payload: Record<string, unknown>) => void;

/** A single bounded image, with at most one chunk awaiting server acknowledgment. */
export class SnapshotTransfer {
  private nonce = '';
  private encoded = '';
  private index = 0;
  private timer?: ReturnType<typeof setTimeout>;
  private awaiting = false;

  constructor(
    private send: Send,
    private finished: (ok: boolean) => void = () => {},
  ) {}

  get active() {
    return this.nonce !== '';
  }

  start(nonce: string, encoded: string) {
    if (this.active) throw new Error('A snapshot transfer is already active.');
    if (
      !nonce ||
      !encoded.length ||
      encoded.length > SNAPSHOT_ENCODED_LIMIT ||
      encoded.length % 4 ||
      !/^[A-Za-z0-9+/]+={0,2}$/.test(encoded)
    ) {
      throw new Error('The UI snapshot exceeds the 2 MiB limit or is invalid.');
    }
    this.nonce = nonce;
    this.encoded = encoded;
    this.index = 0;
    this.next();
  }

  acknowledge(message: Acknowledgment) {
    if (
      !this.active ||
      !this.awaiting ||
      message.nonce !== this.nonce ||
      message.index !== this.index
    )
      return;
    clearTimeout(this.timer);
    this.awaiting = false;
    if (!message.accepted) {
      this.finish(false);
      return;
    }
    this.index++;
    if (this.index * SNAPSHOT_CHUNK_SIZE >= this.encoded.length) {
      this.finish(true);
    } else {
      this.timer = setTimeout(() => this.next(), 75);
    }
  }

  cancel() {
    if (!this.active) return;
    this.send('bug-report/capture-cancel', { nonce: this.nonce });
    this.finish(false);
  }

  private next() {
    if (!this.active) return;
    this.awaiting = true;
    this.timer = setTimeout(() => this.cancel(), 10000);
    this.send('bug-report/capture-chunk', {
      nonce: this.nonce,
      index: this.index,
      totalLength: this.encoded.length,
      data: this.encoded.slice(
        this.index * SNAPSHOT_CHUNK_SIZE,
        (this.index + 1) * SNAPSHOT_CHUNK_SIZE,
      ),
    });
  }

  private finish(ok: boolean) {
    clearTimeout(this.timer);
    this.nonce = '';
    this.encoded = '';
    this.awaiting = false;
    this.finished(ok);
  }
}
