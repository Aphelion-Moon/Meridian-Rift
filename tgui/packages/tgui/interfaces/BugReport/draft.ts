// THIS IS AN APHELION UI FILE

import { storage } from 'common/storage';
import { useCallback, useEffect, useRef, useState } from 'react';
import { fromWire, type LocalFields } from './form';
import type { ReportFields } from './types';

/** Unsent text per report, kept in the browser so typing never touches the server */
const DRAFTS_KEY = 'bug-report-drafts';
const KEPT_DRAFTS = 5;

type StoredDraft = { epoch: number; fields: LocalFields; at: number };

/** Whether a kept draft is in the window's current shape, since older windows kept other fields */
function isLocalFields(fields: unknown): fields is LocalFields {
  const kept = fields as LocalFields | null;
  return (
    !!kept &&
    typeof kept.title === 'string' &&
    Array.isArray(kept.steps) &&
    kept.steps.every((step) => typeof step === 'string') &&
    typeof kept.expected === 'string' &&
    typeof kept.category === 'string' &&
    typeof kept.severity === 'string'
  );
}

/** Titles typed locally, for the report list; the epoch keeps replaced drafts from winning. */
export async function readDraftTitles() {
  const drafts: Record<string, StoredDraft> =
    (await storage.get(DRAFTS_KEY)) ?? {};
  return Object.fromEntries(
    Object.entries(drafts)
      .filter(([, draft]) => isLocalFields(draft.fields))
      .map(([id, draft]) => [
        id,
        { epoch: draft.epoch, title: draft.fields.title },
      ]),
  ) as Record<string, { epoch: number; title: string }>;
}

export async function storeDraft(
  reportId: string,
  epoch: number,
  fields: LocalFields | null,
) {
  const drafts: Record<string, StoredDraft> =
    (await storage.get(DRAFTS_KEY)) ?? {};
  if (fields) drafts[reportId] = { epoch, fields, at: Date.now() };
  else delete drafts[reportId];
  const newest = Object.entries(drafts)
    .sort(([, first], [, second]) => second.at - first.at)
    .slice(0, KEPT_DRAFTS);
  storage.set(DRAFTS_KEY, Object.fromEntries(newest));
}

/** The form's text: the server's copy, then any newer unsent text this browser kept for the same report */
export function useDraft(
  reportId: string,
  epoch: number,
  serverFields: ReportFields,
  maxSteps: number,
) {
  const [fields, setFields] = useState(() => fromWire(serverFields, maxSteps));
  const latest = useRef(fields);
  latest.current = fields;
  const pending = useRef<ReturnType<typeof setTimeout> | undefined>(undefined);

  // The server's text wins whenever it replaces it (a new epoch) or the report changes
  useEffect(() => {
    let current = true;
    setFields(fromWire(serverFields, maxSteps));
    storage.get(DRAFTS_KEY).then((drafts) => {
      const kept: StoredDraft | undefined = drafts?.[reportId];
      if (current && kept?.epoch === epoch && isLocalFields(kept.fields))
        setFields(kept.fields);
    });
    return () => {
      current = false;
    };
  }, [reportId, epoch]);

  // Whatever is still waiting to be kept goes when the window closes
  useEffect(
    () => () => {
      if (pending.current === undefined) return;
      clearTimeout(pending.current);
      storeDraft(reportId, epoch, latest.current);
    },
    [reportId, epoch],
  );

  const edit = useCallback(
    (change: (previous: LocalFields) => LocalFields) => {
      setFields((previous) => {
        const next = change(previous);
        latest.current = next;
        return next;
      });
      clearTimeout(pending.current);
      pending.current = setTimeout(() => {
        pending.current = undefined;
        storeDraft(reportId, epoch, latest.current);
      }, 500);
    },
    [reportId, epoch],
  );
  return [fields, edit] as const;
}
