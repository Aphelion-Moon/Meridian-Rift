// THIS IS AN APHELION UI FILE

import type { ReactNode } from 'react';
import { Icon } from 'tgui-core/components';
import { clockText, onTheWay, pictureLine } from './form';
import { HEADING_ID, previewKey } from './ids';
import { ReportButton } from './ReportButton';
import { say } from './strings';
import type { BugReportData, CaptureTarget, ReportPicture } from './types';

export type PictureActions = {
  take: (
    source: ReportPicture['source'],
    extra?: Record<string, unknown>,
  ) => void;
  remove: (picture: ReportPicture) => void;
  share: (picture: ReportPicture) => void;
  reload: (picture: ReportPicture) => void;
  loaded: (picture: ReportPicture) => void;
  lookAgain: () => void;
  pressed: (key: string) => void;
  working: (key: string) => boolean;
  /** Returns the id of the window a window capture was taken of, if it's still open */
  windowFor: (picture: ReportPicture) => string | undefined;
};

const SHOTS_ID = 'bug-report-shots';
const MAX_ID = 'bug-report-pictures-count';
const UPLOADS_ID = 'bug-report-uploads-limit';
const SOURCE_ICON = {
  view: 'camera',
  window: 'window-maximize',
  file: 'image',
};

/**
 * Returns the caption a picture's card shows, with the time it was taken
 *
 * Arguments:
 * * picture - the picture, whose takenAgo counts back from the update that sent the pictures
 * * arrivedAt - when that update came
 */
function caption(picture: ReportPicture, arrivedAt: number) {
  const time = clockText(new Date(arrivedAt - picture.takenAgo));
  if (picture.source === 'view') return say('shot.view', { time });
  if (picture.source === 'window')
    return say('shot.window', { window: picture.title ?? '', time });
  return say('shot.file', { time });
}

/** One tick, which takes its picture when ticked and removes it when unticked */
function Tick(props: {
  id: string;
  icon?: string;
  label: ReactNode;
  hint?: ReactNode;
  hintId?: string;
  checked: boolean;
  locked: boolean;
  describedBy?: string;
  nested?: boolean;
  onToggle: () => void;
}) {
  const { id, icon, label, hint, hintId, checked, locked, nested } = props;
  const { describedBy, onToggle } = props;
  return (
    <label
      className={`BugReport__tick${nested ? ' BugReport__tick--nested' : ''}${locked ? ' BugReport__tick--locked' : ''}`}
      htmlFor={id}
    >
      <input
        type="checkbox"
        id={id}
        className="BugReport__checkbox"
        checked={checked}
        aria-disabled={locked || undefined}
        aria-describedby={describedBy}
        onChange={() => {
          if (!locked) onToggle();
        }}
      />
      <span className="BugReport__tickText">
        <span className="BugReport__tickLabel">
          {icon && <Icon name={icon} className="BugReport__tickIcon" />}
          {label}
        </span>
        {hint && (
          <span className="BugReport__hint" id={hintId}>
            {hint}
          </span>
        )}
      </span>
    </label>
  );
}

/** A picture's preview, or what it's doing instead */
function Preview(props: {
  picture: ReportPicture;
  src: string | null | undefined;
  actions: PictureActions;
}) {
  const { picture, src, actions } = props;
  const alt =
    picture.source === 'window'
      ? say('shot.alt.window', { window: picture.title ?? '' })
      : say(picture.source === 'view' ? 'shot.alt.view' : 'shot.alt.file');
  if (picture.state === 'ready' && src) {
    return (
      <img
        className="BugReport__preview"
        src={src}
        alt={alt}
        onLoad={() => actions.loaded(picture)}
      />
    );
  }
  const failed = picture.state === 'ready' && src === null;
  return (
    <div className="BugReport__placeholder">
      <Icon
        name={
          onTheWay(picture) || (picture.state === 'ready' && !failed)
            ? 'spinner'
            : SOURCE_ICON[picture.source]
        }
        spin={onTheWay(picture) || (picture.state === 'ready' && !failed)}
        className="BugReport__placeholderIcon"
      />
      {picture.state === 'ready' &&
        (failed ? (
          <>
            <span>{say('shot.previewFailed')}</span>
            <ReportButton onClick={() => actions.reload(picture)}>
              {say('btn.loadAgain')}
            </ReportButton>
          </>
        ) : (
          <span>{say('shot.loading')}</span>
        ))}
    </div>
  );
}

/** One attached picture: its preview, how it's doing, who can see it, and what to do with it */
function Card(props: {
  picture: ReportPicture;
  src: string | null | undefined;
  arrivedAt: number;
  busy: boolean;
  uploadsLeft: number;
  actions: PictureActions;
}) {
  const { picture, src, arrivedAt, busy, uploadsLeft, actions } = props;
  const label = caption(picture, arrivedAt);
  const line = pictureLine(picture);
  const ready = picture.state === 'ready';
  const shareId = `bug-report-share-${picture.id}`;
  const shareLocked = !ready || !picture.previewSeen || busy;
  const windowId =
    picture.source === 'window' ? actions.windowFor(picture) : undefined;
  const gone = picture.source === 'window' && !windowId;
  const noUploads = picture.source === 'file' && uploadsLeft <= 0;
  const retakeLocked = busy || onTheWay(picture) || gone || noUploads;
  // The page already says the upload limit, so Pick another points at those words
  const retakeWhy = gone
    ? `${shareId}-why`
    : noUploads
      ? UPLOADS_ID
      : undefined;
  // Only a capture waiting on its window can be stopped while DM is busy, since removing it ends the wait
  const removeLocked = busy && picture.state !== 'waiting';
  const retakeLabel =
    picture.source === 'file'
      ? say('btn.pickAnother')
      : picture.state === 'failed' && picture.source === 'view'
        ? say('btn.tryCapture')
        : say('btn.retake');
  return (
    <li className="BugReport__card">
      <Preview picture={picture} src={src} actions={actions} />
      <div className="BugReport__caption">{label}</div>
      {line && (
        <div
          className={`BugReport__cardLine${picture.state === 'failed' ? ' BugReport__cardLine--failed' : ''}`}
        >
          <Icon
            name={picture.state === 'failed' ? 'circle-exclamation' : 'spinner'}
            spin={picture.state !== 'failed'}
          />
          <span>
            {say(
              line === 'shot.unconfirmed' && picture.source === 'file'
                ? 'shot.unconfirmed.file'
                : line,
              { window: picture.title ?? '' },
            )}
          </span>
        </div>
      )}
      {ready && (
        <label
          className={`BugReport__tick${shareLocked ? ' BugReport__tick--locked' : ''}`}
          htmlFor={shareId}
        >
          <input
            type="checkbox"
            id={shareId}
            className="BugReport__checkbox"
            checked={picture.publicConsent}
            aria-disabled={shareLocked || undefined}
            aria-describedby={`${shareId}-hint`}
            onChange={() => {
              if (!shareLocked) actions.share(picture);
            }}
          />
          <span className="BugReport__tickText">
            <span>{say('shot.public')}</span>
            <span className="BugReport__hint" id={`${shareId}-hint`}>
              {picture.previewSeen
                ? say('shot.public.hint')
                : say('shot.public.locked')}
            </span>
          </span>
        </label>
      )}
      <div className="MeridianControlRow">
        <ReportButton
          aria-disabled={retakeLocked || undefined}
          className={retakeLocked ? 'BugReport__locked' : undefined}
          aria-describedby={retakeWhy}
          onClick={() => {
            if (retakeLocked) return;
            actions.take(picture.source, {
              replace: picture.id,
              ...(windowId && { windowId }),
            });
            actions.pressed(`retake:${picture.id}`);
          }}
        >
          {retakeLabel}
        </ReportButton>
        <ReportButton
          aria-disabled={removeLocked || undefined}
          className={removeLocked ? 'BugReport__locked' : undefined}
          aria-label={say('btn.remove.aria', { caption: label })}
          onClick={() => {
            if (!removeLocked) actions.remove(picture);
          }}
        >
          {say('btn.remove')}
        </ReportButton>
      </div>
      {gone && (
        <div className="BugReport__hint" id={`${shareId}-why`}>
          {say('shot.gone')}
        </div>
      )}
    </li>
  );
}

export function PicturePage(props: {
  data: BugReportData;
  pictures: ReportPicture[];
  previews: Record<string, string | null>;
  /** When the pictures came, which their times count back from */
  arrivedAt: number;
  actions: PictureActions;
  shotsOpen: boolean;
  onShots: (open: boolean) => void;
  top: ReactNode;
}) {
  const { data, pictures, previews, arrivedAt, actions } = props;
  const { shotsOpen, onShots, top } = props;
  const targets: CaptureTarget[] = data.captureTargets ?? [];
  const max = data.maxPictures;
  const full = pictures.length >= max;
  const busy = data.busy;
  const uploadsLeft = data.uploadsLeft;
  const view = pictures.find((picture) => picture.source === 'view');
  const file = pictures.find((picture) => picture.source === 'file');

  /** Whether a tick can't be used right now, and the words that say why */
  function lockFor(picture: ReportPicture | undefined, key: string) {
    const mine = actions.working(key) || (!!picture && onTheWay(picture));
    if (mine) return { locked: true, why: say('p2.busy') };
    // DM turns everything else down while it's busy, so the other ticks wait with it
    if (busy) return { locked: true, why: say('p2.wait') };
    if (!picture && full) return { locked: true, why: null };
    return { locked: false, why: null };
  }
  function toggle(
    picture: ReportPicture | undefined,
    key: string,
    source: ReportPicture['source'],
    extra?: Record<string, unknown>,
  ) {
    if (picture) return actions.remove(picture);
    actions.take(source, extra);
    actions.pressed(key);
  }

  const viewLock = lockFor(view, 'view');
  const fileLock = lockFor(file, 'file');
  const countLine = full
    ? say('p2.max', { max })
    : pictures.length
      ? max - pictures.length === 1
        ? say('p2.more.one')
        : say('p2.more', { n: max - pictures.length })
      : null;
  return (
    <div className="BugReport__pageBody">
      <h2 className="BugReport__heading" id={HEADING_ID} tabIndex={-1}>
        {say('p2.heading')}
      </h2>
      {top}
      <div className="BugReport__hint">{say('p2.intro')}</div>
      <div className="BugReport__ticks">
        <Tick
          id="bug-report-tick-view"
          icon="camera"
          label={say('p2.view')}
          hint={viewLock.why ?? say('p2.view.hint')}
          hintId="bug-report-tick-view-hint"
          describedBy={`bug-report-tick-view-hint${full && !view ? ` ${MAX_ID}` : ''}`}
          checked={!!view || actions.working('view')}
          locked={viewLock.locked}
          onToggle={() => toggle(view, 'view', 'view')}
        />
        <fieldset className="BugReport__windows">
          <legend className="BugReport__tickLabel">
            <Icon name="window-maximize" className="BugReport__tickIcon" />
            {say('p2.windows')}
          </legend>
          <div className="BugReport__hint" id="bug-report-windows-hint">
            {say('p2.windows.hint')}
          </div>
          {targets.length ? (
            targets.map((target) => {
              const picture = pictures.find(
                (each) =>
                  each.source === 'window' &&
                  actions.windowFor(each) === target.id,
              );
              const key = `window:${target.id}`;
              const lock = lockFor(picture, key);
              return (
                <Tick
                  key={target.id}
                  id={`bug-report-tick-${target.id}`}
                  label={target.title}
                  nested
                  describedBy={[
                    'bug-report-windows-hint',
                    lock.why && `bug-report-tick-${target.id}-hint`,
                    full && !picture && MAX_ID,
                  ]
                    .filter(Boolean)
                    .join(' ')}
                  hint={lock.why}
                  hintId={`bug-report-tick-${target.id}-hint`}
                  checked={!!picture || actions.working(key)}
                  locked={lock.locked}
                  onToggle={() =>
                    toggle(picture, key, 'window', { windowId: target.id })
                  }
                />
              );
            })
          ) : (
            <div className="BugReport__hint BugReport__nested">
              {say('p2.windows.none')}
            </div>
          )}
          <div className="MeridianControlRow BugReport__nested">
            <ReportButton icon="rotate" onClick={actions.lookAgain}>
              {say('p2.windows.again')}
            </ReportButton>
          </div>
        </fieldset>
        {uploadsLeft > 0 || file ? (
          <Tick
            id="bug-report-tick-file"
            icon="image"
            label={say('p2.file')}
            hint={fileLock.why ?? say('p2.file.hint')}
            hintId="bug-report-tick-file-hint"
            describedBy={`bug-report-tick-file-hint${full && !file ? ` ${MAX_ID}` : ''}`}
            checked={!!file || actions.working('file')}
            locked={fileLock.locked}
            onToggle={() => toggle(file, 'file', 'file')}
          />
        ) : null}
        {uploadsLeft <= 0 ? (
          <div className="BugReport__hint BugReport__limitLine" id={UPLOADS_ID}>
            <Icon name="clock" />
            <span>
              {say('st.limit.pictures', { uploads: data.limits.uploads })}
            </span>
          </div>
        ) : (
          uploadsLeft <= 3 && (
            <div className="BugReport__hint BugReport__limitLine">
              {uploadsLeft === 1
                ? say('p2.left.one')
                : say('p2.left', { n: uploadsLeft })}
            </div>
          )
        )}
        {countLine && (
          <div className="BugReport__hint" id={MAX_ID}>
            {countLine}
          </div>
        )}
      </div>
      <div className="BugReport__shots">
        <button
          type="button"
          className="BugReport__disclosure"
          aria-expanded={shotsOpen}
          aria-controls={SHOTS_ID}
          onClick={() => onShots(!shotsOpen)}
        >
          <Icon
            name="chevron-right"
            className={`BugReport__chevron${shotsOpen ? ' BugReport__chevron--open' : ''}`}
          />
          <span className="BugReport__disclosureTitle">
            {say('shots.title')}
          </span>
          <span className="BugReport__badge">{pictures.length}</span>
        </button>
        <div id={SHOTS_ID} hidden={!shotsOpen}>
          {pictures.length ? (
            <ul className="BugReport__cards">
              {pictures.map((picture) => (
                <Card
                  key={picture.id}
                  picture={picture}
                  src={previews[previewKey(picture)]}
                  arrivedAt={arrivedAt}
                  busy={busy}
                  uploadsLeft={uploadsLeft}
                  actions={actions}
                />
              ))}
            </ul>
          ) : (
            <div className="BugReport__hint">{say('shots.none')}</div>
          )}
        </div>
      </div>
    </div>
  );
}
