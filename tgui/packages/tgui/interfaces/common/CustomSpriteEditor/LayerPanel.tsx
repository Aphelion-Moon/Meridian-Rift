// THIS IS AN APHELION UI FILE
import { useRef, useState } from 'react';
import { Button, Input } from 'tgui-core/components';
import { classes } from 'tgui-core/react';
import { decodeHtmlEntities } from 'tgui-core/string';
import { GRAFFITI_MAX_LAYER_NAME } from './graffitiCodec';
import type { GraffitiLayer } from './types';

type LayerPanelProps = {
  layer: GraffitiLayer;
  /** Its place in the stack, from the bottom. */
  index: number;
  count: number;
  onRename: (name: string) => void;
  onGlow: (enabled: boolean) => void;
  onMove: (delta: -1 | 1) => void;
  onRemove: () => void;
  canRemove?: boolean;
};

/** Under the canvas while a graffiti layer is chosen: its name, its glow, its place in the stack, and removing it. */
export const LayerPanel = (props: LayerPanelProps) => {
  const { layer, index, count } = props;
  const name = decodeHtmlEntities(layer.name);
  const [renaming, setRenaming] = useState(false);
  const [draft, setDraft] = useState('');
  // The input blurs after Enter and Esc too, so only the first way out counts.
  const finished = useRef(false);
  const startRename = () => {
    finished.current = false;
    setDraft(name);
    setRenaming(true);
  };
  const finishRename = (value: string | null) => {
    if (finished.current) return;
    finished.current = true;
    setRenaming(false);
    // The server cleans what it's sent.
    if (value?.trim() && value.trim() !== name) props.onRename(value);
  };
  return (
    <section
      className={classes([
        'CustomSpriteEditor__appendagePanel',
        'Graffiti__layerPanel',
        !!layer.glow && 'Graffiti__layerPanel--glow',
      ])}
    >
      <header className="CustomSpriteEditor__panelTitle">
        <span className="CustomSpriteEditor__kindDot" />
        {renaming ? (
          <span className="CustomSpriteEditor__rename">
            <Input
              autoFocus
              autoSelect
              value={name}
              maxLength={GRAFFITI_MAX_LAYER_NAME}
              aria-label="Layer name"
              onChange={setDraft}
              onEnter={finishRename}
              onEscape={() => finishRename(null)}
              onBlur={finishRename}
            />
            <span className="CustomSpriteEditor__renameCount">
              {draft.length}/{GRAFFITI_MAX_LAYER_NAME}
            </span>
          </span>
        ) : (
          <>
            <span className="CustomSpriteEditor__panelName">{name}</span>
            <Button
              className="CustomSpriteEditor__renameButton"
              icon="pencil"
              color="transparent"
              aria-label="Rename layer"
              tooltip={`Rename (up to ${GRAFFITI_MAX_LAYER_NAME} characters)`}
              onClick={startRename}
            />
          </>
        )}
        <span className="CustomSpriteEditor__panelSpacer" />
        <Button.Checkbox
          checked={!!layer.glow}
          tooltip="Makes this layer glow in the dark."
          onClick={() => props.onGlow(!layer.glow)}
        >
          Glow
        </Button.Checkbox>
        <Button
          icon="arrow-down"
          aria-label="Move layer down"
          disabled={index === 0}
          tooltip="Move it under the layer below."
          onClick={() => props.onMove(-1)}
        />
        <Button
          icon="arrow-up"
          aria-label="Move layer up"
          disabled={index >= count - 1}
          tooltip="Move it over the layer above."
          onClick={() => props.onMove(1)}
        />
        {props.canRemove !== false && (
          <Button
            className="CustomSpriteEditor__remove"
            icon="trash"
            disabled={count <= 1}
            tooltip={
              count <= 1
                ? 'The last layer stays. Clear empties it.'
                : 'Remove this layer and its paint. Undo brings it back.'
            }
            onClick={props.onRemove}
          >
            Remove
          </Button>
        )}
      </header>
    </section>
  );
};
