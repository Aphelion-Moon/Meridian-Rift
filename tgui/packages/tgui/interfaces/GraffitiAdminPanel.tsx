// THIS IS AN APHELION UI FILE
import { memo, useCallback, useState } from 'react';
import {
  Button,
  Icon,
  Input,
  LabeledList,
  Section,
  Stack,
  Table,
  Tooltip,
} from 'tgui-core/components';
import { classes } from 'tgui-core/react';
import { decodeHtmlEntities } from 'tgui-core/string';
import { useBackend } from '../backend';
import { Window } from '../layouts';
import { GraffitiThumb } from './common/CustomSpriteEditor/GraffitiThumb';
import type { GraffitiArt } from './common/CustomSpriteEditor/types';

/** One placement, as SSgraffiti.admin_rows() lists it. A wide piece's halves are two rows with one pid. */
type GraffitiAdminRow = {
  pid: string;
  ckey: string;
  /** The painter's character name, HTML-escaped. */
  who: string;
  /** Its area's type path, or null when its anchor names none. */
  area: string | null;
  x: number | null;
  y: number | null;
  z: number | null;
  /** When it was placed, in unix seconds as text. */
  at: string;
  state: 'shown' | 'dormant' | 'round_only';
  art: GraffitiArt;
};

type GraffitiAdminData = {
  rows: GraffitiAdminRow[];
  /** The rows that match the search, on every page. */
  total: number;
  /** HTML-escaped, as the character names it matches are. */
  search: string;
  sort: 'date' | 'ckey' | 'area';
  page: number;
  pageSize: number;
  mapName: string;
};

const SORTS = [
  { key: 'date', label: 'Newest' },
  { key: 'ckey', label: 'Ckey' },
  { key: 'area', label: 'Area' },
] as const;

const STATES: Record<GraffitiAdminRow['state'], string> = {
  shown: 'Shown',
  dormant: 'Dormant',
  round_only: 'Round only',
};

/** The day and time a placement was made, from its unix seconds, in the viewer's time. */
const placedAt = (at: string) => {
  const seconds = Number(at);
  if (!at || !Number.isFinite(seconds)) return { day: '', time: '' };
  const date = new Date(seconds * 1000);
  const pad = (value: number) => String(value).padStart(2, '0');
  return {
    day: `${date.getFullYear()}-${pad(date.getMonth() + 1)}-${pad(date.getDate())}`,
    time: `${pad(date.getHours())}:${pad(date.getMinutes())}`,
  };
};

const areaName = (row: GraffitiAdminRow) =>
  row.area?.replace(/^\/area\//, '') ?? '';

const tileOf = (row: GraffitiAdminRow) =>
  [row.x, row.y, row.z].map((value) => value ?? '?').join(', ');

/** The applied search as a ckey, or '' unless it is letters and digits alone and so a ckey already. */
const searchedCkey = (search: string) => {
  const text = decodeHtmlEntities(search).toLowerCase();
  return text === text.replace(/[^a-z0-9]/g, '') ? text : '';
};

/** Tells rows apart: a wide piece's halves share a pid but not a tile. */
const rowKey = (row: GraffitiAdminRow) => `${row.pid}@${tileOf(row)}`;

type RowProps = {
  row: GraffitiAdminRow;
  checked: boolean;
  viewed: boolean;
  /** Checks or unchecks the row's pid. */
  onCheck: (pid: string) => void;
  /** Shows the row large, or stops, by its rowKey(). */
  onView: (key: string) => void;
  /** Lists only the row's ckey. */
  onSearch: (ckey: string) => void;
};

/**
 * Whether a row shows the same as it did: every refresh lists each placement anew, so a row compares what it shows and
 * its handlers, which don't change, rather than which row it was given.
 */
const sameAdminRow = (previous: RowProps, next: RowProps) => {
  const [before, after] = [previous.row, next.row];
  return (
    previous.checked === next.checked &&
    previous.viewed === next.viewed &&
    previous.onCheck === next.onCheck &&
    previous.onView === next.onView &&
    previous.onSearch === next.onSearch &&
    before.pid === after.pid &&
    before.ckey === after.ckey &&
    before.who === after.who &&
    before.area === after.area &&
    before.x === after.x &&
    before.y === after.y &&
    before.z === after.z &&
    before.at === after.at &&
    before.state === after.state &&
    before.art.w === after.art.w &&
    before.art.pal === after.art.pal &&
    before.art.grid === after.art.grid
  );
};

/** One placement: its checkbox, thumbnail and record, then View and Jump. */
const GraffitiAdminTableRow = memo((props: RowProps) => {
  const { row, checked, viewed, onCheck, onView, onSearch } = props;
  const { act } = useBackend();
  const who = decodeHtmlEntities(row.who);
  const placed = placedAt(row.at);
  return (
    <Table.Row
      className={classes([
        'candystripe',
        viewed && 'Graffiti__adminRow--viewed',
      ])}
    >
      <Table.Cell collapsing>
        <Button.Checkbox
          {...{ role: 'checkbox' }}
          aria-checked={checked}
          aria-label={`Select graffiti by ${who}`}
          checked={checked}
          onClick={() => onCheck(row.pid)}
        />
      </Table.Cell>
      <Table.Cell collapsing>
        <GraffitiThumb art={row.art} scale={1} label={`Graffiti by ${who}`} />
      </Table.Cell>
      <Table.Cell collapsing>
        <Button
          className="Graffiti__adminCkey"
          color="transparent"
          ellipsis
          tooltip="Lists only this ckey's graffiti."
          onClick={() => onSearch(row.ckey)}
        >
          {row.ckey}
        </Button>
      </Table.Cell>
      <Table.Cell className="Graffiti__adminWho">
        <span className="Graffiti__adminCut">{who}</span>
      </Table.Cell>
      <Table.Cell className="Graffiti__adminWhere">
        <span className="Graffiti__adminCut">{areaName(row)}</span>
        <span className="Graffiti__adminSub">{tileOf(row)}</span>
      </Table.Cell>
      <Table.Cell collapsing>
        {placed.day}
        <span className="Graffiti__adminSub">{placed.time}</span>
      </Table.Cell>
      <Table.Cell collapsing>
        <span
          className={`Graffiti__adminState Graffiti__adminState--${row.state}`}
        >
          {STATES[row.state]}
        </span>
      </Table.Cell>
      <Table.Cell collapsing>
        <div className="Graffiti__rowButtons">
          <Button
            icon="search-plus"
            selected={viewed}
            tooltip="Shows it large."
            onClick={() => onView(rowKey(row))}
          />
          <Button
            icon="location-arrow"
            tooltip="Teleports you to its tile."
            onClick={() => act('jump', { pid: row.pid })}
          >
            Jump
          </Button>
        </div>
      </Table.Cell>
    </Table.Row>
  );
}, sameAdminRow);

type ViewProps = {
  row: GraffitiAdminRow;
  onClose: () => void;
};

/** The viewed placement at six times its size, with all it records. */
const GraffitiAdminView = (props: ViewProps) => {
  const { row, onClose } = props;
  const { act } = useBackend();
  const who = decodeHtmlEntities(row.who);
  const placed = placedAt(row.at);
  return (
    <Section
      fill
      scrollable
      title={`Graffiti by ${who || row.ckey}`}
      buttons={<Button icon="times" tooltip="Closes it." onClick={onClose} />}
    >
      <div className="Graffiti__adminViewArt">
        <GraffitiThumb art={row.art} scale={6} label={`Graffiti by ${who}`} />
      </div>
      <LabeledList>
        <LabeledList.Item label="Ckey">{row.ckey}</LabeledList.Item>
        <LabeledList.Item label="Character">
          <span className="Graffiti__adminViewText">{who}</span>
        </LabeledList.Item>
        <LabeledList.Item label="Area">
          <span className="Graffiti__adminViewText">{areaName(row)}</span>
        </LabeledList.Item>
        <LabeledList.Item label="Tile">{tileOf(row)}</LabeledList.Item>
        <LabeledList.Item label="Placed">
          {placed.day} {placed.time}
        </LabeledList.Item>
        <LabeledList.Item label="State">{STATES[row.state]}</LabeledList.Item>
        <LabeledList.Item label="Id">
          <span className="Graffiti__adminViewText">{row.pid}</span>
        </LabeledList.Item>
      </LabeledList>
      <div className="Graffiti__adminViewButtons">
        <Button
          icon="location-arrow"
          tooltip="Teleports you to its tile."
          onClick={() => act('jump', { pid: row.pid })}
        >
          Jump
        </Button>
        <Button
          icon="trash"
          tooltip="Deletes it, both halves of a wide piece."
          onClick={() => act('delete', { pids: [row.pid] })}
        >
          Delete
        </Button>
      </div>
    </Section>
  );
};

/** The Graffiti Manager: the current map's graffiti, a page at a time, to find, look at, jump to and delete. */
export const GraffitiAdminPanel = () => {
  const { act, data } = useBackend<GraffitiAdminData>();
  const { rows, total, search, sort, page, pageSize, mapName } = data;
  const [selected, setSelected] = useState<string[]>([]);
  const [viewing, setViewing] = useState<string | null>(null);
  // A delete or a refresh can take rows away, so only rows still listed count.
  const chosen = selected.filter((pid) => rows.some((row) => row.pid === pid));
  const chosenCkeys = [
    ...new Set(
      rows.filter((row) => chosen.includes(row.pid)).map((row) => row.ckey),
    ),
  ];
  // The selection's one ckey, else the search when it is a whole ckey.
  const target = chosenCkeys.length
    ? chosenCkeys.length === 1
      ? chosenCkeys[0]
      : ''
    : searchedCkey(search);
  const ckeyTip = target
    ? undefined
    : chosenCkeys.length
      ? 'The selected rows have more than one ckey.'
      : 'Search for a whole ckey, or select its rows.';
  const viewed = rows.find((row) => rowKey(row) === viewing);
  const pages = Math.max(1, Math.ceil(total / pageSize));
  // Another page, order or search starts over with nothing picked.
  const browse = useCallback(
    (action: string, params: Record<string, unknown>) => {
      setSelected([]);
      setViewing(null);
      act(action, params);
    },
    [act],
  );
  // The rows' handlers never change, so a row that shows the same isn't drawn again (sameAdminRow()).
  const toggleRow = useCallback(
    (pid: string) =>
      setSelected((current) =>
        current.includes(pid)
          ? current.filter((each) => each !== pid)
          : [...current, pid],
      ),
    [],
  );
  const viewRow = useCallback(
    (key: string) => setViewing((current) => (current === key ? null : key)),
    [],
  );
  const searchRow = useCallback(
    (ckey: string) => browse('search', { text: ckey }),
    [browse],
  );
  return (
    <Window title="Graffiti Manager" width={1200} height={700}>
      <Window.Content>
        <Stack fill>
          <Stack.Item grow className="Graffiti__adminMain">
            <Stack fill vertical>
              <Stack.Item>
                <div className="Graffiti__adminToolbar">
                  <span className="Graffiti__adminMap">{mapName}</span>
                  <Tooltip content="Finds graffiti by its painter's character name or ckey.">
                    <span className="Graffiti__adminSearchHelp">
                      <Icon name="search" />
                    </span>
                  </Tooltip>
                  <Input
                    placeholder="Enter a name or ckey..."
                    value={decodeHtmlEntities(search)}
                    onEnter={(text) => browse('search', { text })}
                  />
                  {!!search && (
                    <Button
                      icon="times"
                      tooltip="Lists every placement again."
                      onClick={() => browse('search', { text: '' })}
                    />
                  )}
                  {SORTS.map(({ key, label }) => (
                    <Button
                      key={key}
                      selected={sort === key}
                      onClick={() => browse('sort', { key })}
                    >
                      {label}
                    </Button>
                  ))}
                  <div className="Graffiti__adminPager">
                    <Button
                      icon="chevron-left"
                      disabled={page <= 1}
                      tooltip="Previous page."
                      onClick={() => browse('page', { n: page - 1 })}
                    />
                    <span className="Graffiti__adminCount">
                      Page {page} of {pages}, {total}{' '}
                      {total === 1 ? 'placement' : 'placements'}
                    </span>
                    <Button
                      icon="chevron-right"
                      disabled={page >= pages}
                      tooltip="Next page."
                      onClick={() => browse('page', { n: page + 1 })}
                    />
                  </div>
                  <Button
                    icon="sync"
                    tooltip="Reads the map's graffiti again."
                    onClick={() => act('refresh')}
                  >
                    Refresh
                  </Button>
                </div>
              </Stack.Item>
              <Stack.Item grow>
                <Section fill scrollable>
                  {rows.length ? (
                    <Table className="Graffiti__adminTable">
                      <Table.Row header>
                        <Table.Cell header collapsing />
                        <Table.Cell header collapsing />
                        <Table.Cell header collapsing>
                          Ckey
                        </Table.Cell>
                        <Table.Cell header>Character</Table.Cell>
                        <Table.Cell header>Where</Table.Cell>
                        <Table.Cell header collapsing>
                          Placed
                        </Table.Cell>
                        <Table.Cell header collapsing>
                          <Tooltip content="Shown: on its tile now. Dormant: waiting for its tile to come back. Round only: never saved.">
                            <span className="Graffiti__adminHelp">State</span>
                          </Tooltip>
                        </Table.Cell>
                        <Table.Cell header collapsing />
                      </Table.Row>
                      {rows.map((row, index) => {
                        const key = rowKey(row);
                        const checked = chosen.includes(row.pid);
                        return (
                          <GraffitiAdminTableRow
                            key={`${key}#${index}`}
                            row={row}
                            checked={checked}
                            viewed={viewing === key}
                            onCheck={toggleRow}
                            onView={viewRow}
                            onSearch={searchRow}
                          />
                        );
                      })}
                    </Table>
                  ) : (
                    <div className="Graffiti__empty">
                      {search ? 'Nothing matches.' : 'No graffiti on this map.'}
                    </div>
                  )}
                </Section>
              </Stack.Item>
              <Stack.Item>
                <div className="Graffiti__adminBar">
                  <Button
                    icon="trash"
                    disabled={!chosen.length}
                    tooltip="Deletes the checked rows' pieces, both halves of a wide one."
                    onClick={() => act('delete', { pids: chosen })}
                  >
                    Delete selected
                  </Button>
                  <span className="Graffiti__adminCount Graffiti__adminTarget">
                    Ckey: {target || 'none'}
                  </span>
                  <Button
                    icon="user-times"
                    disabled={!target}
                    tooltip={ckeyTip}
                    onClick={() => act('deleteCkeyMap', { ckey: target })}
                  >
                    Delete this ckey on this map
                  </Button>
                  <Button
                    icon="user-times"
                    disabled={!target}
                    tooltip={
                      ckeyTip ?? 'Every map, and their graffiti library.'
                    }
                    onClick={() => act('deleteCkeyAll', { ckey: target })}
                  >
                    Delete this ckey everywhere
                  </Button>
                  <Button
                    className="Graffiti__adminPush"
                    color="bad"
                    icon="eraser"
                    onClick={() => act('clearMap')}
                  >
                    Clear this map
                  </Button>
                  <Button
                    color="bad"
                    icon="eraser"
                    onClick={() => act('clearAll')}
                  >
                    Clear all maps
                  </Button>
                </div>
              </Stack.Item>
            </Stack>
          </Stack.Item>
          {!!viewed && (
            <Stack.Item className="Graffiti__adminView">
              <GraffitiAdminView
                row={viewed}
                onClose={() => setViewing(null)}
              />
            </Stack.Item>
          )}
        </Stack>
      </Window.Content>
    </Window>
  );
};
