import { displayGradeFilter, validateDisplayGrade } from './display-grade';

export type DisplayGradeUpdate = {
  revision: number;
  settings: unknown;
  neutral?: boolean;
};

/** One filter on the document root also includes backgrounds and portal content. */
export function installDisplayGrade(document: Document) {
  let revision = -1;
  let svg: SVGSVGElement | undefined;
  let signature = '';
  const root = document.documentElement;
  const originalFilter = root.style.getPropertyValue('filter');
  const originalPriority = root.style.getPropertyPriority('filter');
  return (update: DisplayGradeUpdate) => {
    if (
      !Number.isSafeInteger(update?.revision) ||
      update.revision <= revision
    ) {
      return false;
    }
    const settings =
      update.settings === null ? null : validateDisplayGrade(update.settings);
    if (update.settings !== null && !settings) return false;
    revision = update.revision;
    if (update.neutral || !settings?.strength) {
      root.style.setProperty('filter', originalFilter, originalPriority);
      svg?.remove();
      svg = undefined;
      signature = '';
      return true;
    }
    if (!svg) {
      svg = document.createElementNS('http://www.w3.org/2000/svg', 'svg');
      svg.setAttribute('aria-hidden', 'true');
      svg.setAttribute('width', '0');
      svg.setAttribute('height', '0');
      svg.style.position = 'absolute';
      svg.style.pointerEvents = 'none';
      document.body.appendChild(svg);
    }
    const nextSignature = JSON.stringify(settings);
    if (nextSignature !== signature) {
      svg.innerHTML = `<defs>${displayGradeFilter('aphelion-display-grade-root', settings)}</defs>`;
      signature = nextSignature;
    }
    root.style.setProperty(
      'filter',
      'url(#aphelion-display-grade-root)',
      'important',
    );
    return true;
  };
}

// The bundle is also loaded by legacy pages, where the TGUI bridge is absent.
declare global {
  interface Window {
    displayGradeInitial?: DisplayGradeUpdate;
    displayGradeUpdate?: (encoded: string) => void;
  }
}

if (typeof document !== 'undefined') {
  const update = installDisplayGrade(document);
  window.displayGradeUpdate = (encoded) => {
    try {
      update(JSON.parse(decodeURIComponent(encoded)));
    } catch {
      // A malformed or obsolete transport packet must not erase a valid grade.
    }
  };
  if (window.displayGradeInitial) update(window.displayGradeInitial);
  const bridge = window as Window & {
    update?: {
      listeners: ((type: string, payload: DisplayGradeUpdate) => void)[];
    };
  };
  if (bridge.update) {
    // Do not flush the shared queue: the asynchronously loaded application still
    // needs its initial config/data. Readiness resends the current grade to us.
    bridge.update.listeners.push((type, payload) => {
      if (type === 'display/grade') update(payload);
    });
  }
}
