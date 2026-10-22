import { loadStyleSheet } from 'common/assets';
import { EventBus } from 'tgui-core/eventbus';
import { handleLoadAssets } from './handlers/assets';
import {
  acknowledgePayloadChunk,
  oversizePayloadResponse,
} from './handlers/chunking';
import { ping } from './handlers/ping';
import { suspend } from './handlers/suspense';
import { update } from './handlers/update';
// APHELION EDIT ADDITION START - bug report captures of this window
import {
  requestUiSnapshot,
  acknowledgeUiSnapshot,
  abortUiSnapshot,
} from '../capture/controller';
// APHELION EDIT ADDITION END

/**
 * A string/handler map.
 * Ideally, these reference a function named after the respective event type.
 */
const listeners = {
  // Assets
  'asset/mappings': handleLoadAssets,
  'asset/stylesheet': loadStyleSheet,
  // Standard window events
  ping,
  suspend,
  update,
  // Chunking
  oversizePayloadResponse,
  acknowledgePayloadChunk,
  // APHELION EDIT ADDITION START - bug report captures of this window
  'bug-report/capture': requestUiSnapshot,
  'bug-report/capture-ack': acknowledgeUiSnapshot,
  'bug-report/capture-abort': abortUiSnapshot,
  // APHELION EDIT ADDITION END
} as const;

export const bus = new EventBus(listeners);
