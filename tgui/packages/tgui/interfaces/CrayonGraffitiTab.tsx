// THIS IS AN APHELION UI FILE
import {
  type Dispatch,
  memo,
  type SetStateAction,
  useEffect,
  useMemo,
  useState,
} from 'react';
import { Button, Icon, Input, TextArea, Tooltip } from 'tgui-core/components';
import { type BooleanLike, classes } from 'tgui-core/react';
import { decodeHtmlEntities } from 'tgui-core/string';
import { useBackend } from '../backend';
import { GraffitiTabs } from './common/CustomSpriteEditor/GraffitiFields';
import { GraffitiThumb } from './common/CustomSpriteEditor/GraffitiThumb';
import {
  GRAFFITI_MAX_DESCRIPTION,
  GRAFFITI_MAX_NAME,
  GRAFFITI_WIDTH,
} from './common/CustomSpriteEditor/graffitiCodec';
import type {
  GraffitiLibraryEntry,
  GraffitiUnfinished,
} from './common/CustomSpriteEditor/types';

type CrayonGraffitiData = {
  /** Absent for a can that doesn't paint graffiti. */
  graffiti?: {
    /** null, "freehand", "unfinished", or a library piece's id. */
    armed: string | null;
    /** HTML-escaped; null for freehand or nothing armed. */
    armedName: string | null;
    tab: 'stencils' | 'graffiti';
    /** The player has a graffiti editor open, which opening another piece closes. */
    hasEditor: BooleanLike;
  };
  /** Static data, sent again whenever the library changes. */
  graffitiLibrary?: {
    /** Newest first. */
    entries: GraffitiLibraryEntry[];
    unfinished: GraffitiUnfinished | null;
    count: number;
    cap: number;
  };
};

const UNFINISHED_TIP =
  'Your last interrupted or unsaved piece. Starting another replaces it unless you Keep it.';

/** How long a rename may take to show in Custom Graffiti before its text goes back in the form, in milliseconds. */
const RENAME_WAIT = 2000;

/** A piece's name and description as typed, trimmed. */
type RenameText = { name: string; description: string };

/** The day a piece was made, from its unix seconds. */
const madeOn = (created: string) => {
  const seconds = Number(created);
  if (!created || !Number.isFinite(seconds)) return '';
  const date = new Date(seconds * 1000);
  const pad = (value: number) => String(value).padStart(2, '0');
  return `${date.getFullYear()}-${pad(date.getMonth() + 1)}-${pad(date.getDate())}`;
};

/** The Crayon window's tab bar, for a can that paints graffiti, with Custom Graffiti under it while that's open. */
export const CrayonGraffitiTabs = () => {
  const { act, data } = useBackend<CrayonGraffitiData>();
  const { graffiti } = data;
  if (!graffiti) return null;
  const open = graffiti.tab === 'graffiti';
  return (
    <div className="Graffiti__crayon">
      <GraffitiTabs
        current={graffiti.tab}
        onSelect={(tab) => act('graffitiTab', { tab })}
      />
      {open && <CrayonGraffitiTab />}
    </div>
  );
};

type UnfinishedSlotProps = {
  unfinished: GraffitiUnfinished;
  armed: boolean;
  /** Custom Graffiti has no room to keep it in. */
  full: boolean;
  act: (action: string) => void;
};

/** The Unfinished slot, pinned over the saved pieces and drawn apart from them. */
const UnfinishedSlot = (props: UnfinishedSlotProps) => {
  const { unfinished, armed, full, act } = props;
  const name = decodeHtmlEntities(unfinished.name);
  const description = decodeHtmlEntities(unfinished.description);
  // A stopped paint job shows what it reached bright over the rest of the piece, ghosted.
  const job =
    typeof unfinished.progress === 'number' && unfinished.progress >= 0;
  return (
    <div className="Graffiti__unfinished" role="group" aria-label="Unfinished">
      <Tooltip content={UNFINISHED_TIP}>
        <div className="Graffiti__unfinishedInfo">
          <GraffitiThumb
            art={unfinished.thumb}
            scale={2}
            ghost={job}
            over={job ? unfinished.revealed : null}
            label="Unfinished piece"
          />
          <div className="Graffiti__rowInfo">
            <span className="Graffiti__badge">Unfinished</span>
            <div className="Graffiti__rowName">{name || 'Untitled'}</div>
            {!!description && (
              <div className="Graffiti__rowDesc">{description}</div>
            )}
          </div>
        </div>
      </Tooltip>
      <div className="Graffiti__rowButtons">
        <Button
          icon="play"
          selected={armed}
          tooltip={
            unfinished.progress === -1
              ? 'Arms the can: click the same wall, floor or full-tile window to keep painting there.'
              : job
                ? 'Arms the can: click the same spot to carry on. Once its paint there is gone, it starts over wherever you click.'
                : 'Arms the can: the next wall, floor or full-tile window you click gets this piece.'
          }
          onClick={() => act('graffitiResume')}
        >
          Resume
        </Button>
        <Button
          icon="save"
          disabled={full}
          tooltip={
            full
              ? 'Custom Graffiti is full. Delete a piece to make room.'
              : 'Saves it to Custom Graffiti and opens it in the editor.'
          }
          onClick={() => act('graffitiKeep')}
        >
          Keep
        </Button>
        <Button.Confirm
          icon="trash"
          confirmContent="Discard?"
          tooltip="Throws it away."
          onClick={() => act('graffitiDiscard')}
        >
          Discard
        </Button.Confirm>
      </div>
    </div>
  );
};

type PieceRenameProps = {
  id: string;
  /** Decoded, as the library holds it. */
  name: string;
  /** Decoded, as the library holds it. */
  description: string;
  /** What the form opens with: the library's text, or a rename's still on its way or that didn't land. */
  start: RenameText;
  /** Closes the form, given the text it sent, if it sent any. */
  onClose: (sent?: RenameText) => void;
};

/**
 * A saved piece's name and description, open for editing in its row. Enter or Save sends them unless the library
 * holds them already; Esc or Cancel doesn't.
 */
const PieceRename = (props: PieceRenameProps) => {
  const { id, start, onClose } = props;
  const { act } = useBackend();
  const [name, setName] = useState(start.name);
  const [description, setDescription] = useState(start.description);
  const save = (newName: string, newDescription: string) => {
    // As the library cleans them: trimmed, and Untitled without a name.
    const text = { name: newName.trim(), description: newDescription.trim() };
    if (
      (text.name || 'Untitled') === props.name &&
      text.description === props.description
    ) {
      onClose();
      return;
    }
    // Every rename rewrites the library file, which paces the account's next write.
    act('graffitiRename', { id, name: newName, description: newDescription });
    onClose(text);
  };
  return (
    <div className="Graffiti__rename">
      <Input
        autoSelect
        fluid
        maxLength={GRAFFITI_MAX_NAME}
        placeholder="Untitled"
        value={name}
        onChange={setName}
        onEnter={(value) => save(value, description)}
        onEscape={() => onClose()}
      />
      <TextArea
        className="Graffiti__renameDescription"
        dontUseTabForIndent
        fluid
        maxLength={GRAFFITI_MAX_DESCRIPTION}
        placeholder="Description"
        value={description}
        onChange={setDescription}
        onEnter={(value) => save(name, value)}
        onEscape={() => onClose()}
      />
      <div className="Graffiti__rowButtons">
        <Button
          icon="check"
          color="good"
          onClick={() => save(name, description)}
        >
          Save
        </Button>
        <Button icon="times" onClick={() => onClose()}>
          Cancel
        </Button>
      </div>
    </div>
  );
};

type GraffitiRowProps = {
  entry: GraffitiLibraryEntry;
  /** Decoded, as the library holds it. */
  name: string;
  /** Decoded, as the library holds it. */
  description: string;
  armed: boolean;
  renaming: boolean;
  /** Sets the one piece whose form is open, or none. */
  setRenaming: Dispatch<SetStateAction<string | null>>;
  /** The window's act, which never changes. */
  act: (action: string, payload?: object) => void;
};

/**
 * Whether a row shows the same as it did: the spray can resends its whole library whenever any of it changes, every
 * entry anew, so a row compares what it shows rather than which entry it was given.
 */
const sameRow = (previous: GraffitiRowProps, next: GraffitiRowProps) => {
  const [before, after] = [previous.entry, next.entry];
  return (
    previous.name === next.name &&
    previous.description === next.description &&
    previous.armed === next.armed &&
    previous.renaming === next.renaming &&
    previous.setRenaming === next.setRenaming &&
    previous.act === next.act &&
    before.id === after.id &&
    before.created === after.created &&
    before.width === after.width &&
    before.layers === after.layers &&
    !!before.glow === !!after.glow &&
    before.thumb.w === after.thumb.w &&
    before.thumb.pal === after.thumb.pal &&
    before.thumb.grid === after.thumb.grid
  );
};

/**
 * One saved piece: its thumbnail, name and description, details and buttons. Memoised by what it shows (sameRow()), as
 * the can's window updates every few seconds and after each act: a row whose piece and state didn't change is left
 * alone, even when the library is sent again.
 *
 * A rename shows on the row as it is sent, until the library's text for the piece changes. One the library hasn't
 * taken within RENAME_WAIT, as when its write pacing refused it, goes back in the form: opened again at once unless
 * another piece's is open, else the next time this one's is. Opened meanwhile, the form starts from the text sent, and
 * closing it without sending leaves that rename waiting.
 */
const GraffitiRow = memo((props: GraffitiRowProps) => {
  const { entry, name, description, armed, renaming, setRenaming, act } = props;
  // The rename sent and not yet in the library.
  const [sent, setSent] = useState<RenameText | null>(null);
  // A rename that didn't land, which the form opens with.
  const [draft, setDraft] = useState<RenameText | null>(null);
  useEffect(() => setSent(null), [name, description]);
  useEffect(() => {
    if (!sent) return;
    const timer = setTimeout(() => {
      setSent(null);
      setDraft(sent);
      setRenaming((open) => open ?? entry.id);
    }, RENAME_WAIT);
    return () => clearTimeout(timer);
  }, [sent]);
  const shown = sent ?? { name, description };
  return (
    <li className={classes(['Graffiti__row', armed && 'Graffiti__row--armed'])}>
      <GraffitiThumb art={entry.thumb} scale={2} label={shown.name} />
      <div className="Graffiti__rowInfo">
        {renaming ? (
          <PieceRename
            id={entry.id}
            name={name}
            description={description}
            start={draft ?? sent ?? { name, description }}
            onClose={(text) => {
              setDraft(null);
              setSent((waiting) => text ?? waiting);
              setRenaming(null);
            }}
          />
        ) : (
          <>
            <span
              className="Graffiti__rowName Graffiti__rowName--editable"
              role="button"
              tabIndex={0}
              onClick={() => setRenaming(entry.id)}
              onKeyDown={(event) => {
                if (event.key !== 'Enter' && event.key !== ' ') return;
                event.preventDefault();
                setRenaming(entry.id);
              }}
            >
              <span className="Graffiti__rowNameText">
                {shown.name || 'Untitled'}
              </span>
              <Icon name="pencil" />
            </span>
            {!!shown.description && (
              <Tooltip content={shown.description}>
                <div className="Graffiti__rowDesc">{shown.description}</div>
              </Tooltip>
            )}
          </>
        )}
        <div className="Graffiti__rowMeta">
          <span>{madeOn(entry.created)}</span>
          <span>
            {entry.layers} {entry.layers === 1 ? 'layer' : 'layers'}
          </span>
          {entry.width > GRAFFITI_WIDTH && <span>Two tiles</span>}
          {!!entry.glow && (
            <span className="Graffiti__glow">
              <Icon name="lightbulb" /> Glows
            </span>
          )}
        </div>
      </div>
      <div className="Graffiti__rowButtons">
        <Button
          icon="spray-can"
          selected={armed}
          tooltip="Arms the can: the next wall, floor or full-tile window you click gets this piece."
          onClick={() => act('graffitiArm', { id: entry.id })}
        >
          Paint
        </Button>
        <Button
          icon="pen"
          tooltip="Opens it in the editor."
          onClick={() => act('graffitiEdit', { id: entry.id })}
        >
          Edit
        </Button>
        <Button
          icon="file-export"
          tooltip="Exports it as a file."
          onClick={() => act('graffitiExport', { id: entry.id })}
        >
          Export
        </Button>
        <Button.Confirm
          icon="trash"
          confirmContent="Delete?"
          tooltip="Deletes it from Custom Graffiti."
          onClick={() => act('graffitiDelete', { id: entry.id })}
        />
      </div>
    </li>
  );
}, sameRow);

/** The spray can's Custom Graffiti tab: the Unfinished slot, then the saved pieces, searchable and sortable. */
export const CrayonGraffitiTab = () => {
  const { act, data } = useBackend<CrayonGraffitiData>();
  const { graffiti, graffitiLibrary: library } = data;
  const [search, setSearch] = useState('');
  const [sort, setSort] = useState<'newest' | 'name'>('newest');
  // The saved piece whose name and description are open for editing.
  const [renaming, setRenaming] = useState<string | null>(null);
  // Names and descriptions come escaped; they're shown, and searched, as written.
  const pieces = useMemo(
    () =>
      (library?.entries ?? []).map((entry) => ({
        entry,
        name: decodeHtmlEntities(entry.name),
        description: decodeHtmlEntities(entry.description),
      })),
    [library?.entries],
  );
  if (!library) {
    return (
      <div className="Graffiti__empty">
        Your graffiti library isn't available.
      </div>
    );
  }
  const query = search.trim().toLowerCase();
  const shown = pieces.filter(
    ({ name, description }) =>
      !query ||
      name.toLowerCase().includes(query) ||
      description.toLowerCase().includes(query),
  );
  // The library comes newest first.
  if (sort === 'name') {
    shown.sort((first, second) =>
      first.name.localeCompare(second.name, undefined, { sensitivity: 'base' }),
    );
  }
  const armed = graffiti?.armed ?? null;
  const banner =
    armed === 'freehand'
      ? 'Click a wall, floor or window to paint freehand.'
      : armed
        ? `Click a wall, floor or window to paint: ${decodeHtmlEntities(graffiti?.armedName ?? '') || 'Untitled'}`
        : null;
  return (
    <div className="Graffiti__tab">
      {!!banner && (
        <div className="Graffiti__armed" role="status">
          <Icon name="spray-can" />
          <span className="Graffiti__armedText">{banner}</span>
          <Button icon="times" onClick={() => act('graffitiDisarm')}>
            Disarm
          </Button>
        </div>
      )}
      <div className="Graffiti__toolbar">
        <Button
          icon="plus"
          tooltip="Plan your graffiti in advance."
          onClick={() => act('graffitiNew')}
        >
          New
        </Button>
        <Button
          icon="file-import"
          tooltip="Adds a graffiti file to Custom Graffiti."
          onClick={() => act('graffitiImport')}
        >
          Import
        </Button>
        <Button
          icon="spray-can"
          selected={armed === 'freehand'}
          tooltip="Draw as you go."
          onClick={() => act('graffitiFreehand')}
        >
          Freehand
        </Button>
      </div>
      {!!graffiti?.hasEditor && (
        <div className="Graffiti__hint">
          Your graffiti editor is still open. Opening another piece closes it.
        </div>
      )}
      {!!library.unfinished && (
        <UnfinishedSlot
          unfinished={library.unfinished}
          armed={armed === 'unfinished'}
          full={library.count >= library.cap}
          act={act}
        />
      )}
      <div className="Graffiti__filters">
        <Input fluid value={search} onChange={setSearch} />
        <Button
          selected={sort === 'newest'}
          tooltip="Newest first."
          onClick={() => setSort('newest')}
        >
          Newest
        </Button>
        <Button
          selected={sort === 'name'}
          tooltip="By name."
          onClick={() => setSort('name')}
        >
          Name
        </Button>
        <span className="Graffiti__count">
          {library.count} / {library.cap}
        </span>
      </div>
      {shown.length ? (
        <ul className="Graffiti__list" aria-label="Custom Graffiti">
          {shown.map(({ entry, name, description }) => (
            <GraffitiRow
              key={entry.id}
              entry={entry}
              name={name}
              description={description}
              armed={armed === entry.id}
              renaming={renaming === entry.id}
              setRenaming={setRenaming}
              act={act}
            />
          ))}
        </ul>
      ) : (
        <div className="Graffiti__empty">
          {query
            ? 'Nothing matches.'
            : 'Nothing saved yet. New plans a piece in advance; Freehand draws as you go on a wall.'}
        </div>
      )}
    </div>
  );
};
