// THIS IS AN APHELION UI FILE
import { useEffect, useRef, useState } from 'react';
import { Button, Stack, Tabs } from 'tgui-core/components';
import { GRAFFITI_WIDE_WIDTH, GRAFFITI_WIDTH } from './graffitiCodec';
import type { GraffitiData } from './types';

/** What the server says when going back to one tile would lose paint (editor.dm's setWidth). */
const WIDTH_CONFIRM_NOTICE =
  'Going back to one tile loses the paint on the right one. Confirm to go ahead.';

/** The footer's pinned line while a surface session paints where graffiti isn't kept. */
export const ROUND_ONLY_NOTICE = 'This graffiti lasts only this round.';

/** The footer's line while nothing else shows in a surface session: the can's charges, unless it never runs out. */
export const chargesLine = (graffiti: GraffitiData) => {
  if (graffiti.kind !== 'surface' || typeof graffiti.charges !== 'number')
    return null;
  const charges = +graffiti.charges.toFixed(1);
  return `${charges} ${charges === 1 ? 'charge' : 'charges'} left in the can`;
};

type GraffitiSaveButtonsProps = {
  graffiti: GraffitiData;
  onSave: (copy: boolean) => void;
};

/** The footer's saves: over the library piece, or as a new copy of it, which only the studio offers. */
export const GraffitiSaveButtons = (props: GraffitiSaveButtonsProps) => {
  const { graffiti, onSave } = props;
  const surface = graffiti.kind === 'surface';
  const full = (graffiti.libraryCount ?? 0) >= graffiti.libraryCap;
  const fullText = `Custom Graffiti is full (${graffiti.libraryCap}). Delete a piece to make room.`;
  return (
    <>
      {!surface && !!graffiti.pieceId && (
        <Stack.Item>
          <Button
            disabled={!graffiti.canSave || full}
            tooltip={
              full
                ? fullText
                : 'Saves a new piece, and leaves the saved one as it was.'
            }
            onClick={() => onSave(true)}
          >
            Save as copy
          </Button>
        </Stack.Item>
      )}
      <Stack.Item>
        <Button
          color="good"
          disabled={!graffiti.canSave}
          tooltip={
            !graffiti.canSave
              ? full && !graffiti.pieceId
                ? fullText
                : 'Paint something to save it.'
              : surface
                ? 'Keeps a copy of your painting in Custom Graffiti. Ctrl+S too.'
                : 'Ctrl+S saves too.'
          }
          onClick={() => onSave(false)}
        >
          {surface ? 'Save to Custom Graffiti' : 'Save'}
        </Button>
      </Stack.Item>
    </>
  );
};

type GraffitiTabsProps = {
  current: 'stencils' | 'graffiti' | 'editor';
  /** The editor's own tab, while it's the window. */
  editor?: boolean;
  onSelect: (tab: 'stencils' | 'graffiti') => void;
};

/** The spray can's tabs, which the editor's window shows too, with its own. */
export const GraffitiTabs = (props: GraffitiTabsProps) => {
  const { current, editor, onSelect } = props;
  return (
    <Tabs className="Graffiti__tabs">
      <Tabs.Tab
        icon="spray-can"
        selected={current === 'stencils'}
        onClick={() => onSelect('stencils')}
      >
        Stencils
      </Tabs.Tab>
      <Tabs.Tab
        icon="images"
        selected={current === 'graffiti'}
        onClick={() => onSelect('graffiti')}
      >
        Custom Graffiti
      </Tabs.Tab>
      {!!editor && (
        <Tabs.Tab icon="paintbrush" selected={current === 'editor'}>
          Editor
        </Tabs.Tab>
      )}
    </Tabs>
  );
};

type GraffitiFieldsProps = {
  graffiti: GraffitiData;
  /** Whether any layer has paint, which fixes a surface session's width. */
  painted: boolean;
  /** The status line's notice and its count, for the width's confirmation. */
  notice?: string | null;
  noticeRevision?: number;
  act: (action: string, params?: Record<string, unknown>) => void;
};

/** Under the canvas: the piece's width. Its name and description are edited in Custom Graffiti. */
export const GraffitiFields = (props: GraffitiFieldsProps) => {
  const { graffiti, painted, notice, noticeRevision, act } = props;
  const wide = graffiti.width > GRAFFITI_WIDTH;
  // Set once the server asks for a confirmation, so the next press gives it.
  const [confirming, setConfirming] = useState(false);
  const seenRevision = useRef(noticeRevision);
  useEffect(() => {
    if (noticeRevision === seenRevision.current) return;
    seenRevision.current = noticeRevision;
    setConfirming(notice === WIDTH_CONFIRM_NOTICE);
  }, [noticeRevision]);
  useEffect(() => setConfirming(false), [graffiti.width]);
  // The surface keeps the width its first paint was put on at.
  const fixed = graffiti.kind === 'surface' && painted;
  return (
    <div className="Graffiti__fields">
      <Button.Checkbox
        checked={wide}
        disabled={fixed}
        // Unset, the checkbox keeps its own transparent look.
        {...(confirming && { color: 'bad' })}
        tooltip={
          fixed
            ? 'The width is fixed once your paint is on the surface.'
            : confirming
              ? "Press again to crop: the right tile's paint goes, and the undo history clears."
              : 'Adds a tile on the right, or crops it off. CLEARS UNDO HISTORY.'
        }
        onClick={() => {
          if (!wide) {
            act('setWidth', { width: GRAFFITI_WIDE_WIDTH });
            return;
          }
          act(
            'setWidth',
            confirming
              ? { width: GRAFFITI_WIDTH, confirm: true }
              : { width: GRAFFITI_WIDTH },
          );
          setConfirming(false);
        }}
      >
        {confirming ? 'Crop to one tile' : 'Two tiles wide'}
      </Button.Checkbox>
    </div>
  );
};
