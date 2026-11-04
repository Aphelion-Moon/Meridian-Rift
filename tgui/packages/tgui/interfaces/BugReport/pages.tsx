// THIS IS AN APHELION UI FILE

import type { ReactNode } from 'react';
import { Icon } from 'tgui-core/components';
import { DiagnosticLoader } from '../common/DiagnosticLoader';
import {
  clockText,
  doneLine,
  type EditFields,
  type FieldError,
  type FieldName,
  isBlank,
  type LocalFields,
  lengthOf,
  type Page,
  waitText,
} from './form';
import {
  EXPECTED_ID,
  HEADING_ID,
  NOTICE_ID,
  SUMMARY_ID,
  stepId,
  TITLE_ID,
  VAGUE_ID,
} from './ids';
import { ReportButton } from './ReportButton';
import { type StringId, say } from './strings';
import type {
  BugReportData,
  ReportChoice,
  ReportFeedback,
  ReportLimits,
  ReportPicture,
  ReportReceipt,
} from './types';

type Tone = 'info' | 'warning' | 'danger' | 'muted';

// Where the checker's words about each field go, and the field it points at
const FEEDBACK_FIELD: Record<ReportFeedback['field'], FieldName> = {
  title: 'title',
  // The steps tell what happened now, so anything about it belongs there
  observed: 'steps',
  reproduction: 'steps',
  expected: 'expected',
};
const FIELD_LABEL: Record<FieldName, StringId> = {
  title: 'p4.row.title',
  steps: 'p3.steps',
  expected: 'p4.row.expected',
};
export const FIELD_TARGET: Record<FieldName, string> = {
  title: TITLE_ID,
  steps: stepId(0),
  expected: EXPECTED_ID,
};
export const FIELD_PAGE: Record<FieldName, Page> = {
  title: 1,
  steps: 3,
  expected: 3,
};

/** A boxed message with an icon and words, never colour alone */
export function Notice(props: {
  tone: Tone;
  icon: string;
  title?: ReactNode;
  id?: string;
  children?: ReactNode;
  actions?: ReactNode;
  spin?: boolean;
}) {
  const { tone, icon, title, id, children, actions, spin } = props;
  return (
    <div
      className={`BugReport__notice BugReport__notice--${tone}`}
      id={id}
      tabIndex={id ? -1 : undefined}
    >
      <Icon name={icon} spin={spin} className="BugReport__noticeIcon" />
      <div className="BugReport__noticeBody">
        {title && <h3 className="BugReport__noticeTitle">{title}</h3>}
        {children}
        {actions && <div className="MeridianControlRow">{actions}</div>}
      </div>
    </div>
  );
}

/** The other version notice, which shows on whichever page the player is on */
export function ConflictNotice(props: { onResolve: (keep: boolean) => void }) {
  const { onResolve } = props;
  return (
    <Notice
      tone="warning"
      icon="circle-exclamation"
      actions={
        <>
          <ReportButton onClick={() => onResolve(false)}>
            {say('btn.useSaved')}
          </ReportButton>
          <ReportButton onClick={() => onResolve(true)}>
            {say('btn.keepMine')}
          </ReportButton>
        </>
      }
    >
      <div>{say('st.conflict')}</div>
    </Notice>
  );
}

/** The problems that stopped a page, each a link to its field */
function ErrorSummary(props: {
  errors: FieldError[] | null;
  onFix: (field: FieldName) => void;
}) {
  const { errors, onFix } = props;
  if (!errors?.length) return null;
  return (
    <div
      className="BugReport__summary"
      id={SUMMARY_ID}
      tabIndex={-1}
      role="alert"
      aria-labelledby={`${SUMMARY_ID}-title`}
    >
      <h3 className="BugReport__summaryTitle" id={`${SUMMARY_ID}-title`}>
        <Icon name="circle-exclamation" className="BugReport__summaryIcon" />
        {say('err.summary')}
      </h3>
      <ul className="BugReport__summaryList">
        {errors.map((error) => (
          <li key={error.field}>
            <button
              type="button"
              className="BugReport__link"
              onClick={() => onFix(error.field)}
            >
              {error.text}
            </button>
          </li>
        ))}
      </ul>
    </div>
  );
}

/** Focuses a field the summary or a notice points at */
function focusField(field: FieldName) {
  document.getElementById(FIELD_TARGET[field])?.focus();
}

/** The same words as the summary, just above the field */
function FieldProblem(props: { id: string; error?: FieldError }) {
  const { id, error } = props;
  if (!error) return null;
  return (
    <div className="BugReport__error" id={id}>
      <Icon name="circle-exclamation" className="BugReport__errorIcon" />
      <span>
        <span className="BugReport__sr">{say('err.prefix')} </span>
        {error.text}
      </span>
    </div>
  );
}

/** What the automatic check said about a field, under the player's own words */
function Feedback(props: { items: ReportFeedback[] }) {
  const { items } = props;
  if (!items.length) return null;
  return (
    <div className="BugReport__feedback">
      {items.map((item) => (
        <div key={item.message} className="BugReport__feedbackItem">
          {!!item.quote && (
            <div className="BugReport__hint">
              {say('st.back.quote', { quote: item.quote })}
            </div>
          )}
          <div className="BugReport__feedbackMessage">
            <Icon name="circle-info" className="BugReport__feedbackIcon" />
            <span>{item.message}</span>
          </div>
        </div>
      ))}
    </div>
  );
}

const feedbackFor = (
  feedback: ReportFeedback[] | null | undefined,
  field: FieldName,
) => feedback?.filter((item) => FEEDBACK_FIELD[item.field] === field) ?? [];

/** The character count, only once the text is three quarters of the way to its limit, read with its field rather than as it changes */
function Count(props: { id: string; value: string; max: number }) {
  const { id, value, max } = props;
  const length = lengthOf(value);
  return (
    <div className="BugReport__count" id={id}>
      {length >= max * 0.75 ? say('count', { n: length, max }) : ''}
    </div>
  );
}

const errorFor = (errors: FieldError[] | null, field: FieldName) =>
  errors?.find((error) => error.field === field);

const describedBy = (...ids: (string | false | undefined)[]) =>
  ids.filter(Boolean).join(' ') || undefined;

export function TitlePage(props: {
  fields: LocalFields;
  edit: EditFields;
  limits: ReportLimits;
  errors: FieldError[] | null;
  feedback: ReportFeedback[] | null | undefined;
  top: ReactNode;
  onEnter: () => void;
}) {
  const { fields, edit, limits, errors, feedback, top, onEnter } = props;
  const error = errorFor(errors, 'title');
  return (
    <div className="BugReport__pageBody">
      <h2 className="BugReport__heading" id={HEADING_ID} tabIndex={-1}>
        <label htmlFor={TITLE_ID}>{say('p1.heading')}</label>
      </h2>
      {top}
      <ErrorSummary errors={errors} onFix={focusField} />
      <div className="BugReport__field">
        <div className="BugReport__hint" id={`${TITLE_ID}-hint`}>
          {say('p1.title.hint')}
        </div>
        <Feedback items={feedbackFor(feedback, 'title')} />
        <FieldProblem id={`${TITLE_ID}-error`} error={error} />
        <input
          id={TITLE_ID}
          className="Input Input--fluid BugReport__input"
          type="text"
          autoComplete="off"
          value={fields.title}
          aria-invalid={!!error}
          aria-describedby={describedBy(
            `${TITLE_ID}-hint`,
            !!error && `${TITLE_ID}-error`,
            `${TITLE_ID}-count`,
          )}
          onChange={(event) => {
            const title = event.currentTarget.value;
            edit((previous) => ({ ...previous, title }));
          }}
          onKeyDown={(event) => {
            // An Enter that ends an IME composition picks the word, it doesn't go on
            if (event.key !== 'Enter' || event.nativeEvent.isComposing) return;
            event.preventDefault();
            onEnter();
          }}
        />
        <Count
          id={`${TITLE_ID}-count`}
          value={fields.title}
          max={limits.title}
        />
      </div>
    </div>
  );
}

/** Three bars, as many filled as how much it gets in the way */
function Meter(props: { level: number }) {
  const { level } = props;
  return (
    <svg
      className="BugReport__meter"
      width="18"
      height="16"
      viewBox="0 0 18 16"
      aria-hidden
    >
      {[0, 1, 2].map((bar) => (
        <rect
          key={bar}
          className={bar < level ? 'BugReport__meterOn' : undefined}
          x={1 + bar * 6}
          y={10 - bar * 4.5}
          width="4"
          height={5 + bar * 4.5}
        />
      ))}
    </svg>
  );
}

/** An optional question as a row of radio chips, nothing picked to start with */
function Choices(props: {
  name: string;
  legend: StringId;
  options: ReportChoice[];
  value: string;
  onPick: (value: string) => void;
  wide?: boolean;
}) {
  const { name, legend, options, value, onPick, wide } = props;
  return (
    <fieldset className="BugReport__choices">
      <legend className="BugReport__label">
        {say(legend)}{' '}
        <span className="BugReport__optional">{say('optional')}</span>
      </legend>
      <div
        className={`BugReport__chips${wide ? ' BugReport__chips--rows' : ''}`}
      >
        {options.map((option, index) => {
          const id = `bug-report-${name}-${option.value}`;
          const checked = option.value === value;
          return (
            <label
              key={option.value}
              className={`BugReport__chip${checked ? ' BugReport__chip--on' : ''}`}
              htmlFor={id}
            >
              <input
                className="BugReport__sr"
                type="radio"
                id={id}
                name={`bug-report-${name}`}
                value={option.value}
                checked={checked}
                onChange={() => onPick(option.value)}
              />
              {option.icon ? (
                <Icon name={option.icon} className="BugReport__chipIcon" />
              ) : (
                <Meter level={options.length - index} />
              )}
              <span className="BugReport__chipLabel">{option.label}</span>
              {checked && (
                <Icon name="check" className="BugReport__chipCheck" />
              )}
            </label>
          );
        })}
      </div>
    </fieldset>
  );
}

export function StepsPage(props: {
  fields: LocalFields;
  edit: EditFields;
  limits: ReportLimits;
  kinds: ReportChoice[];
  impacts: ReportChoice[];
  errors: FieldError[] | null;
  feedback: ReportFeedback[] | null | undefined;
  vague: string | null;
  top: ReactNode;
  onAddSteps: () => void;
  onKeepVague: () => void;
  focus: (id: string) => void;
}) {
  const { fields, edit, limits, kinds, impacts, errors, feedback, vague } =
    props;
  const { top, onAddSteps, onKeepVague, focus } = props;
  const stepsError = errorFor(errors, 'steps');
  const expectedError = errorFor(errors, 'expected');
  const steps = fields.steps;
  const stepsFull = steps.length >= limits.steps;
  const sentBack = feedback?.length ? feedback : null;

  function setStep(index: number, text: string) {
    edit((previous) => ({
      ...previous,
      steps: previous.steps.map((step, at) => (at === index ? text : step)),
    }));
  }
  function addStep(after: number) {
    if (steps.length >= limits.steps) return;
    edit((previous) => {
      const next = [...previous.steps];
      next.splice(after + 1, 0, '');
      return { ...previous, steps: next };
    });
    focus(stepId(after + 1));
  }
  function removeStep(index: number, target = index) {
    edit((previous) => ({
      ...previous,
      steps: previous.steps.filter((_step, at) => at !== index),
    }));
    focus(stepId(Math.max(0, Math.min(target, steps.length - 2))));
  }

  return (
    <div className="BugReport__pageBody">
      <h2 className="BugReport__heading" id={HEADING_ID} tabIndex={-1}>
        {say('p3.heading')}
      </h2>
      {top}
      {sentBack && (
        <Notice
          tone="info"
          icon="circle-info"
          id={NOTICE_ID}
          title={say('st.back.title')}
        >
          <div>{say('st.back.text')}</div>
          {sentBack.map((item) => {
            const field = FEEDBACK_FIELD[item.field];
            return (
              <button
                key={item.message}
                type="button"
                className="BugReport__link"
                onClick={() => focusField(field)}
              >
                {say('st.back.item', {
                  label: say(FIELD_LABEL[field]),
                  message: item.message,
                })}
              </button>
            );
          })}
        </Notice>
      )}
      <ErrorSummary errors={errors} onFix={focusField} />
      <div
        className="BugReport__field"
        role="group"
        aria-labelledby="bug-report-steps-label"
      >
        <div className="BugReport__label" id="bug-report-steps-label">
          {say('p3.steps')}
        </div>
        <div className="BugReport__hint" id="bug-report-steps-hint">
          {say('p3.steps.hint')}
        </div>
        <Feedback items={feedbackFor(feedback, 'steps')} />
        <FieldProblem id="bug-report-steps-error" error={stepsError} />
        <ol className="BugReport__stepList">
          {steps.map((step, index) => (
            // The fields are only ever told apart by where they are, which is what their labels say
            <li key={index} className="BugReport__stepRow">
              <span className="BugReport__stepNo" aria-hidden>
                {index + 1}.
              </span>
              <input
                id={stepId(index)}
                className="Input BugReport__input BugReport__stepInput"
                type="text"
                autoComplete="off"
                value={step}
                aria-label={say('p3.step', { n: index + 1 })}
                aria-invalid={!!stepsError}
                aria-describedby={describedBy(
                  'bug-report-steps-hint',
                  !!stepsError && 'bug-report-steps-error',
                )}
                onChange={(event) => setStep(index, event.currentTarget.value)}
                onKeyDown={(event) => {
                  if (event.nativeEvent.isComposing) return;
                  if (event.key === 'Enter') {
                    event.preventDefault();
                    addStep(index);
                  } else if (
                    event.key === 'Backspace' &&
                    step === '' &&
                    steps.length > 1
                  ) {
                    event.preventDefault();
                    removeStep(index, index - 1);
                  }
                }}
              />
              {steps.length > 1 && (
                <ReportButton
                  icon="xmark"
                  className="BugReport__removeStep"
                  aria-label={say('btn.removeStep.aria', { n: index + 1 })}
                  onClick={() => removeStep(index)}
                />
              )}
            </li>
          ))}
        </ol>
        <div className="MeridianControlRow">
          <ReportButton
            icon="plus"
            aria-disabled={stepsFull || undefined}
            className={stepsFull ? 'BugReport__locked' : undefined}
            aria-describedby={stepsFull ? 'bug-report-steps-max' : undefined}
            onClick={() => addStep(steps.length - 1)}
          >
            {say('btn.addStep')}
          </ReportButton>
          {stepsFull && (
            <span className="BugReport__hint" id="bug-report-steps-max">
              {say('p3.steps.max', { max: limits.steps })}
            </span>
          )}
        </div>
        {vague !== null && (
          <Notice
            tone="warning"
            icon="circle-info"
            id={VAGUE_ID}
            actions={
              <>
                <ReportButton onClick={onAddSteps}>
                  {say('btn.addSteps')}
                </ReportButton>
                <ReportButton onClick={onKeepVague}>
                  {say('btn.keepIt')}
                </ReportButton>
              </>
            }
          >
            <div>{say('p3.vague', { text: vague })}</div>
          </Notice>
        )}
      </div>
      <div className="BugReport__field">
        <label className="BugReport__label" htmlFor={EXPECTED_ID}>
          {say('p3.expected')}
        </label>
        <div className="BugReport__hint" id={`${EXPECTED_ID}-hint`}>
          {say('p3.expected.hint')}
        </div>
        <Feedback items={feedbackFor(feedback, 'expected')} />
        <FieldProblem id={`${EXPECTED_ID}-error`} error={expectedError} />
        <textarea
          id={EXPECTED_ID}
          className="Input TextArea Input--fluid BugReport__textarea"
          rows={3}
          value={fields.expected}
          aria-invalid={!!expectedError}
          aria-describedby={describedBy(
            `${EXPECTED_ID}-hint`,
            !!expectedError && `${EXPECTED_ID}-error`,
            `${EXPECTED_ID}-count`,
          )}
          onChange={(event) => {
            const expected = event.currentTarget.value;
            edit((previous) => ({ ...previous, expected }));
          }}
        />
        <Count
          id={`${EXPECTED_ID}-count`}
          value={fields.expected}
          max={limits.text}
        />
      </div>
      <Choices
        name="kind"
        legend="kind.legend"
        options={kinds}
        value={fields.category}
        onPick={(category) => edit((previous) => ({ ...previous, category }))}
      />
      <Choices
        name="impact"
        legend="impact.legend"
        options={impacts}
        value={fields.severity}
        onPick={(severity) => edit((previous) => ({ ...previous, severity }))}
        wide
      />
    </div>
  );
}

/** Returns what the review says about the pictures */
function picturesValue(pictures: ReportPicture[]) {
  const count = pictures.length;
  if (!count) return say('p4.pictures.none');
  const shared = pictures.filter((picture) => picture.publicConsent).length;
  if (shared) return say('p4.pictures.public', { n: count, k: shared });
  return count === 1
    ? say('p4.pictures.private.one')
    : say('p4.pictures.private', { n: count });
}

export function ReviewPage(props: {
  fields: LocalFields;
  data: BugReportData;
  pictures: ReportPicture[];
  holding: boolean;
  limited: boolean;
  /** When the hourly limit lets go, made once from the update that brought the limit */
  limitUntil: number;
  offline: boolean;
  triedAgain: boolean;
  top: ReactNode;
  onChange: (page: Page, focusId: string) => void;
}) {
  const { fields, data, pictures, holding, limited, offline, triedAgain } =
    props;
  const { limitUntil, top, onChange } = props;
  const kinds = data.kinds ?? [];
  const impacts = data.impacts ?? [];
  const steps = fields.steps.filter((step) => !isBlank(step));
  const kindLabel = kinds.find((kind) => kind.value === fields.category)?.label;
  const impactLabel = impacts.find(
    (impact) => impact.value === fields.severity,
  )?.label;
  const rows: {
    label: StringId;
    value: string;
    page: Page;
    target: string;
    multiline?: boolean;
  }[] = [
    { label: 'p4.row.title', value: fields.title, page: 1, target: TITLE_ID },
    {
      label: 'p4.row.pictures',
      value: picturesValue(pictures),
      page: 2,
      target: HEADING_ID,
    },
    {
      label: 'p4.row.steps',
      value: steps
        .map((step, index) => `${index + 1}. ${step.trim()}`)
        .join('\n'),
      page: 3,
      target: stepId(0),
      multiline: true,
    },
    {
      label: 'p4.row.expected',
      value: fields.expected,
      page: 3,
      target: EXPECTED_ID,
    },
    {
      label: 'p4.row.kind',
      value: kindLabel ?? say('p4.skipped'),
      page: 3,
      target: `bug-report-kind-${fields.category || kinds[0]?.value}`,
    },
    {
      label: 'p4.row.impact',
      value: impactLabel ?? say('p4.skipped'),
      page: 3,
      target: `bug-report-impact-${fields.severity || impacts[0]?.value}`,
    },
  ];
  const limit = data.limit;
  const retryAt = clockText(new Date(limitUntil));
  // The clock stays put, and the wait is what's left of it now
  const retryWait = waitText(limitUntil - Date.now());
  return (
    <div className="BugReport__pageBody">
      <h2 className="BugReport__heading" id={HEADING_ID} tabIndex={-1}>
        {say('p4.heading')}
      </h2>
      {top}
      <dl className="BugReport__review">
        {rows.map((row) => {
          const label = say(row.label);
          return (
            <div key={row.label} className="BugReport__row">
              <dt className="BugReport__rowLabel">{label}</dt>
              <dd
                className={`BugReport__rowValue${row.multiline ? ' BugReport__rowValue--lines' : ''}`}
              >
                {row.value}
              </dd>
              <div className="BugReport__rowAction">
                <ReportButton
                  aria-label={say('btn.change.aria', {
                    label: label.toLowerCase(),
                  })}
                  onClick={() => onChange(row.page, row.target)}
                >
                  {say('btn.change')}
                </ReportButton>
              </div>
            </div>
          );
        })}
      </dl>
      <p className="BugReport__public">
        <Icon name="globe" className="BugReport__publicIcon" />
        <span>{say('p4.public')}</span>
      </p>
      {holding && (
        <Notice tone="warning" icon="spinner" spin>
          <div>{say('err.pictureBusy')}</div>
        </Notice>
      )}
      {limited && limit && (
        <Notice tone="warning" icon="clock">
          <div>
            {limit.kind === 'reports'
              ? say('st.limit.reports', {
                  reports: data.limits.reports,
                  clock: retryAt,
                  wait: retryWait,
                })
              : say('st.limit.sends', {
                  sends: data.limits.sends,
                  clock: retryAt,
                  wait: retryWait,
                })}
          </div>
        </Notice>
      )}
      {offline && (
        <Notice tone="danger" icon="link-slash" title={say('st.offline.title')}>
          <div>{say(triedAgain ? 'st.offline.again' : 'st.offline.text')}</div>
        </Notice>
      )}
      {!data.enabled && (
        <Notice tone="muted" icon="circle-info">
          <div>{say('st.off')}</div>
        </Notice>
      )}
    </div>
  );
}

export function CheckingState(props: { paused: boolean }) {
  const { paused } = props;
  return (
    <div className="BugReport__state">
      {paused ? (
        <>
          <h2 className="BugReport__sr" id={HEADING_ID} tabIndex={-1}>
            {say('st.checking')}
          </h2>
          <Notice tone="danger" icon="link-slash">
            <div>{say('st.lost')}</div>
          </Notice>
        </>
      ) : (
        <>
          <DiagnosticLoader
            size="large"
            label={null}
            ariaLabel={say('st.checking')}
          />
          <h2 className="BugReport__heading" id={HEADING_ID} tabIndex={-1}>
            {say('st.checking')}
          </h2>
          <p className="BugReport__hint BugReport__stateText">
            {say('st.checking.detail')}
          </p>
        </>
      )}
    </div>
  );
}

export function DoneState(props: {
  receipt?: ReportReceipt | null;
  /** When the result came, which the receipt's wait counts from */
  arrivedAt: number;
}) {
  const { receipt, arrivedAt } = props;
  const line = doneLine(receipt);
  const text =
    line === 'issue'
      ? say('st.done.issue', { n: receipt?.issueNumber ?? '' })
      : line === 'retry'
        ? say('st.done.retry', {
            clock: clockText(
              new Date(arrivedAt + (receipt?.nextAttemptIn ?? 0)),
            ),
          })
        : say(`st.done.${line}`);
  return (
    <div className="BugReport__state">
      <Icon name="circle-check" className="BugReport__doneIcon" />
      <h2 className="BugReport__heading" id={HEADING_ID} tabIndex={-1}>
        {say('st.done.title')}
      </h2>
      <p className="BugReport__stateText">{text}</p>
      {line === 'soon' && (
        <div className="BugReport__hint BugReport__waiting">
          <Icon name="spinner" spin />
          <span>{say('st.done.waiting')}</span>
        </div>
      )}
      {line === 'issue' && (
        <p className="BugReport__hint">{say('st.done.browser')}</p>
      )}
      <p className="BugReport__hint BugReport__small">{say('st.done.next')}</p>
    </div>
  );
}
