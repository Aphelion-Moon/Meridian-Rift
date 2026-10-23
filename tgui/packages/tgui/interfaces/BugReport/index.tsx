// THIS IS AN APHELION UI FILE

import { useEffect, useRef, useState } from 'react';
import { Section, Stack } from 'tgui-core/components';
import { useBackend } from '../../backend';
import { Window } from '../../layouts';
import { storeDraft, useDraft } from './draft';
import {
  checkAll,
  checkPage,
  type FieldError,
  type Page,
  toWire,
  vagueSteps,
} from './form';
import {
  HEADING_ID,
  NOTICE_ID,
  previewKey,
  SUMMARY_ID,
  stepId,
  TITLE_ID,
} from './ids';
import {
  CheckingState,
  ConflictNotice,
  DoneState,
  ReviewPage,
  StepsPage,
  TitlePage,
} from './pages';
import { type PictureActions, PicturePage } from './pictures';
import { ReportButton } from './ReportButton';
import { say } from './strings';
import type { BugReportData } from './types';

const STEPS = [say('step.1'), say('step.2'), say('step.3'), say('step.4')];
// A preview that hasn't come by then shows as failed, with a way to ask again
const PREVIEW_WAIT = 12000;
// A press DM never answers stops looking busy after this
const PRESS_WAIT = 3000;

/** The control that started what DM is busy with, and whether an update came since */
type Press = { key: string; seen: boolean };

export const BugReport = () => {
  const { act, data } = useBackend<BugReportData>();
  const { limits, result } = data;
  const pictures = data.pictures ?? [];
  const [fields, edit] = useDraft(
    data.reportId,
    data.fieldsEpoch,
    data.fields,
    limits.steps,
  );
  const [page, setPage] = useState<Page>(1);
  const [reached, setReached] = useState<Page>(1);
  const [errors, setErrors] = useState<FieldError[] | null>(null);
  const [backToReview, setBackToReview] = useState(false);
  const [vague, setVague] = useState<string | null>(null);
  const [keptVague, setKeptVague] = useState<string | null>(null);
  const [press, setPress] = useState<Press | null>(null);
  const [triedAgain, setTriedAgain] = useState(0);
  const [limitUntil, setLimitUntil] = useState(0);
  const [, setNow] = useState(0);
  const [previews, setPreviews] = useState<Record<string, string | null>>({});
  const requested = useRef(new Set<string>());
  const loaded = useRef(new Set<string>());
  const [shotsOpen, setShotsOpen] = useState(pictures.length > 0);
  const seenPictures = useRef(new Set(pictures.map((picture) => picture.id)));
  // Which window each window capture came from, since two windows can share a title
  const windowOf = useRef(new Map<number, string>());
  const askedWindow = useRef<string | null>(null);
  const focusNext = useRef<string | null>(fields.title ? HEADING_ID : TITLE_ID);

  const kind = result?.kind;
  const accepted = kind === 'accepted';
  const checking = kind === 'checking';
  const sentBack = kind === 'needs_revision';
  const working = (key: string) => press?.key === key;
  const sending = working('send');
  const holding = pictures.some((picture) => picture.state !== 'ready');
  const limited = !!data.limit && limitUntil > Date.now();

  /** Moves focus once the page shows what it should land on */
  const focus = (id: string) => {
    focusNext.current = id;
  };
  useEffect(() => {
    if (!focusNext.current) return;
    const target = document.getElementById(focusNext.current);
    if (!target) return;
    focusNext.current = null;
    target.focus();
  });

  /** Sends an action carrying the form whole */
  function actWithFields(action: string, extra?: Record<string, unknown>) {
    act(action, {
      ...extra,
      fields: toWire(fields),
      fieldsEpoch: data.fieldsEpoch,
    });
  }

  /** Remembers which control started an action, so only it says it's working */
  function pressed(key: string) {
    const mark = { key, seen: false };
    setPress(mark);
    setTimeout(
      () => setPress((current) => (current === mark ? null : current)),
      PRESS_WAIT,
    );
  }

  // Every update after a press says whether DM is still on it
  useEffect(() => {
    setPress((current) => {
      if (!current) return current;
      if (!data.busy) return null;
      return current.seen ? current : { ...current, seen: true };
    });
  }, [data]);

  // A new report or new text from the server starts the pages over
  useEffect(() => {
    setPage(1);
    setReached(1);
    setErrors(null);
    setVague(null);
    setKeptVague(null);
    setBackToReview(false);
  }, [data.reportId, data.fieldsEpoch]);

  // The text is in the report now, so this browser can forget it
  useEffect(() => {
    if (accepted) storeDraft(data.reportId, 0, null);
  }, [accepted]);

  // A send-back opens the steps, where the checker's words are; a sent report shows how it's doing
  useEffect(() => {
    if (sentBack) {
      setPage(3);
      setReached(4);
      setErrors(null);
      focus(NOTICE_ID);
    } else if (accepted || checking) {
      focus(HEADING_ID);
    }
  }, [kind]);

  // The limit's wait counts from the update that brought it, and Send comes back when it passes
  useEffect(() => {
    const wait = data.limit?.retryIn ?? 0;
    setLimitUntil(wait > 0 ? Date.now() + wait : 0);
    if (wait <= 0) return;
    const timer = setTimeout(() => setNow(Date.now()), wait + 50);
    return () => clearTimeout(timer);
  }, [data.limit]);

  // A server that answers again is no longer one we tried and failed to reach
  useEffect(() => {
    if (!data.unreachable) setTriedAgain(0);
  }, [data.unreachable]);

  // Previews come one picture at a time and only when asked, so they're kept here by picture and take
  useEffect(() => {
    const preview = data.preview;
    if (!preview) return;
    setPreviews((kept) => ({ ...kept, [previewKey(preview)]: preview.src }));
  }, [data.preview]);

  // Each ready picture asks for its preview once a take, never while DM is busy since it would drop it
  useEffect(() => {
    if (data.busy) return;
    for (const picture of pictures) {
      const key = previewKey(picture);
      if (
        picture.state !== 'ready' ||
        key in previews ||
        requested.current.has(key)
      )
        continue;
      requested.current.add(key);
      act('preview', { pictureId: picture.id });
      setTimeout(
        () =>
          setPreviews((kept) =>
            key in kept ? kept : { ...kept, [key]: null },
          ),
        PREVIEW_WAIT,
      );
    }
  }, [data.pictures, data.busy, previews]);

  // A new picture opens the attached screenshots, then they stay how the player leaves them
  useEffect(() => {
    for (const picture of pictures) {
      if (seenPictures.current.has(picture.id)) continue;
      seenPictures.current.add(picture.id);
      setShotsOpen(true);
      if (picture.source === 'window' && askedWindow.current) {
        windowOf.current.set(picture.id, askedWindow.current);
        askedWindow.current = null;
      }
    }
  }, [data.pictures]);

  // Other windows open and close without telling this one, so look again on focus
  useEffect(() => {
    const refreshTargets = () => act('targets');
    window.addEventListener('focus', refreshTargets);
    return () => window.removeEventListener('focus', refreshTargets);
  }, []);

  function goTo(next: Page, target = HEADING_ID) {
    setPage(next);
    setReached((previous) => (next > previous ? next : previous));
    setErrors(null);
    setVague(null);
    focus(target);
  }

  function showErrors(found: FieldError[]) {
    const first = found[0].page;
    if (first !== page) goTo(first, SUMMARY_ID);
    setErrors(found.filter((error) => error.page === first));
    focus(SUMMARY_ID);
  }

  function next() {
    const found = checkPage(page, fields, limits);
    if (found.length) return showErrors(found);
    if (page === 3) {
      const text = vagueSteps(fields);
      if (text && text !== keptVague) {
        setErrors(null);
        setVague(text);
        focus(NOTICE_ID);
        return;
      }
    }
    setBackToReview(false);
    goTo(backToReview ? 4 : ((page + 1) as Page));
  }

  function keepVague() {
    setKeptVague(vague);
    setBackToReview(false);
    goTo(4);
  }

  function send() {
    if (sending || data.busy) return;
    const found = checkAll(fields, limits);
    if (found.length) return showErrors(found);
    if (holding) return;
    actWithFields('submit');
    pressed('send');
  }

  function tryAgain() {
    if (working('refresh')) return;
    setTriedAgain((count) => count + 1);
    act('refresh');
    pressed('refresh');
  }

  function change(target: Page, focusId: string) {
    setBackToReview(true);
    goTo(target, focusId);
  }

  // The picture page's actions, which DM refuses while it's busy, so they hold until it isn't
  const targets = data.captureTargets ?? [];
  const pictureActions: PictureActions = {
    take(source, extra) {
      if (source === 'window' && !extra?.replace)
        askedWindow.current = (extra?.windowId as string) ?? null;
      const action =
        source === 'view'
          ? 'capture_view'
          : source === 'window'
            ? 'capture_ui'
            : 'screenshot';
      actWithFields(action, extra);
    },
    remove(picture) {
      act('remove_screenshot', { pictureId: picture.id });
      pressed(`remove:${picture.id}`);
    },
    share(picture) {
      act('screenshot_consent', {
        pictureId: picture.id,
        publicConsent: !picture.publicConsent,
      });
      pressed(`share:${picture.id}`);
    },
    reload(picture) {
      const key = previewKey(picture);
      requested.current.delete(key);
      setPreviews(({ [key]: _dropped, ...kept }) => kept);
    },
    loaded(picture) {
      const key = previewKey(picture);
      if (loaded.current.has(key)) return;
      loaded.current.add(key);
      act('preview_loaded', { pictureId: picture.id, take: picture.take });
    },
    lookAgain: () => act('targets'),
    pressed,
    working,
    windowFor(picture) {
      const asked = windowOf.current.get(picture.id);
      if (asked !== undefined)
        return targets.some((target) => target.id === asked)
          ? asked
          : undefined;
      // A window captured before the window last opened is found by its title
      return targets.find((target) => target.title === picture.title)?.id;
    },
  };
  const conflict = data.conflict ? (
    <ConflictNotice
      onResolve={(keep) => (keep ? actWithFields('keep') : act('reload'))}
    />
  ) : null;

  const editing = !accepted && !(checking && !sending);
  const showStrip = editing;
  const offline = data.unreachable && page === 4;

  let body;
  if (accepted) {
    body = <DoneState receipt={result?.receipt} />;
  } else if (checking && !sending) {
    body = <CheckingState paused={data.pollingPaused} />;
  } else if (page === 1) {
    body = (
      <TitlePage
        fields={fields}
        edit={edit}
        limits={limits}
        errors={errors}
        feedback={sentBack ? result?.feedback : null}
        top={conflict}
        onEnter={next}
      />
    );
  } else if (page === 2) {
    body = (
      <PicturePage
        data={data}
        pictures={pictures}
        previews={previews}
        actions={pictureActions}
        shotsOpen={shotsOpen}
        onShots={setShotsOpen}
        top={conflict}
      />
    );
  } else if (page === 3) {
    body = (
      <StepsPage
        fields={fields}
        edit={edit}
        limits={limits}
        kinds={data.kinds ?? []}
        impacts={data.impacts ?? []}
        errors={errors}
        feedback={sentBack ? result?.feedback : null}
        vague={vague}
        onAddSteps={() => {
          setVague(null);
          focus(stepId(0));
        }}
        onKeepVague={keepVague}
        focus={focus}
        top={conflict}
      />
    );
  } else {
    body = (
      <ReviewPage
        fields={fields}
        data={data}
        pictures={pictures}
        holding={holding}
        limited={limited}
        offline={offline}
        triedAgain={triedAgain > 0}
        onChange={change}
        top={conflict}
      />
    );
  }

  // The footer's buttons stay where they are, Back first and the one main action last
  let back: { label: string; onClick: () => void } | null = null;
  let main: { label: string; onClick: () => void; working?: boolean } | null =
    null;
  if (accepted) {
    back = { label: say('btn.another'), onClick: () => act('new') };
    if (result?.receipt?.issueUrl)
      main = { label: say('btn.openIssue'), onClick: () => act('issue') };
  } else if (checking && !sending) {
    if (data.pollingPaused)
      main = {
        label: say('btn.tryAgain'),
        onClick: tryAgain,
        working: working('refresh'),
      };
  } else if (page < 4) {
    if (page > 1)
      back = {
        label: say('btn.back'),
        onClick: () => goTo((page - 1) as Page),
      };
    main = { label: say('btn.next'), onClick: next };
  } else {
    back = { label: say('btn.back'), onClick: () => goTo(3) };
    if (offline) {
      main = {
        label: say('btn.tryAgain'),
        onClick: tryAgain,
        working: working('refresh'),
      };
    } else if (data.enabled && !limited && !holding) {
      main = {
        label: sending
          ? say('btn.sending')
          : sentBack
            ? say('btn.sendAgain')
            : say('btn.send'),
        onClick: send,
        working: sending,
      };
    }
  }

  const status = sending ? say('st.sending') : (data.status ?? '');

  return (
    <Window title={say('win.title')} width={600} height={700}>
      <Window.Content className="BugReport">
        <Stack vertical fill>
          {showStrip && (
            <Stack.Item>
              <Section className="BugReport__header">
                <StepStrip page={page} reached={reached} onGo={goTo} />
              </Section>
            </Stack.Item>
          )}
          <Stack.Item grow basis={0}>
            <Section fill scrollable className="BugReport__page">
              {body}
            </Section>
          </Stack.Item>
          <Stack.Item>
            <Section className="BugReport__footer">
              <div className="MeridianControlRow BugReport__footerRow">
                <div
                  className="MeridianControlRow__fill BugReport__status"
                  role="status"
                  aria-live="polite"
                >
                  {status}
                </div>
                {back && (
                  <ReportButton onClick={back.onClick}>
                    {back.label}
                  </ReportButton>
                )}
                {main && (
                  <ReportButton
                    color="good"
                    className="BugReport__main"
                    aria-busy={main.working || undefined}
                    onClick={main.onClick}
                  >
                    {main.label}
                  </ReportButton>
                )}
              </div>
            </Section>
          </Stack.Item>
        </Stack>
      </Window.Content>
    </Window>
  );
};

/** The four steps, done ones as buttons back to them, the current one marked, the rest muted */
function StepStrip(props: {
  page: Page;
  reached: Page;
  onGo: (page: Page) => void;
}) {
  const { page, reached, onGo } = props;
  return (
    <nav className="BugReport__steps" aria-label={say('step.strip')}>
      <ol className="BugReport__strip">
        {STEPS.map((name, index) => {
          const number = (index + 1) as Page;
          const inner = (
            <>
              <span className="BugReport__stepNumber">{number}</span>
              <span className="BugReport__stepLabel">{name}</span>
            </>
          );
          return (
            <li key={name} className="BugReport__stripItem">
              {number === page ? (
                <div
                  className="Button Button--selected Button--color--default BugReport__step BugReport__step--current"
                  aria-current="step"
                >
                  <div className="Button__content">{inner}</div>
                </div>
              ) : number <= reached ? (
                <ReportButton
                  className="BugReport__step"
                  aria-label={say('step.done.aria', { n: number, name })}
                  onClick={() => onGo(number)}
                >
                  {inner}
                </ReportButton>
              ) : (
                <div className="Button Button--color--default BugReport__step BugReport__step--todo">
                  <div className="Button__content">{inner}</div>
                </div>
              )}
            </li>
          );
        })}
      </ol>
      <div className="BugReport__stepOf">
        {say('step.of', { n: page, name: STEPS[page - 1] })}
      </div>
    </nav>
  );
}
