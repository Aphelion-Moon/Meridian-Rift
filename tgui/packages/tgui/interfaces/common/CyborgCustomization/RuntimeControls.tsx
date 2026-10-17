import { Box, Button, NoticeBox, Section, Table } from 'tgui-core/components';
import type { BooleanLike } from 'tgui-core/react';
import { editorLabel } from './LayoutControls';
import type { LayoutAction } from './types';

export type RuntimeCustomization = {
  parts: {
    slot: string;
    choice: string;
    active: BooleanLike;
    arousal: string;
    can_arouse: BooleanLike;
  }[];
  message?: string;
  character_slot: number;
  allowed: BooleanLike;
  viewer_enabled: BooleanLike;
  body_visible: BooleanLike;
  model_name: string;
  model_default: BooleanLike;
};

/** Shared body-usage controls; no saved configuration is exposed here. */
export function RuntimeControls({
  data,
  onAction,
}: {
  data: RuntimeCustomization;
  onAction: LayoutAction;
}) {
  const act: LayoutAction = (params) =>
    onAction({ ...params, character_slot: data.character_slot });
  return (
    <Section title="Genital options">
      <Box color="label" mb={1}>
        {data.model_name} ·{' '}
        {data.model_default ? 'Model default loaded' : 'Character setup loaded'}
      </Box>
      {data.message && <NoticeBox>{data.message}</NoticeBox>}
      {!data.allowed && (
        <NoticeBox>
          Genital content is disabled in character or server preferences.
        </NoticeBox>
      )}
      <Button.Checkbox
        checked={!!data.viewer_enabled}
        tooltip="Your display preference for cyborg parts. Other players control their own display."
        onClick={() =>
          act({ operation: 'viewer', value: !data.viewer_enabled })
        }
      >
        Show cyborg parts to me
      </Button.Checkbox>
      {!data.viewer_enabled && (
        <Box color="label" my={1}>
          Your display is off. Active parts remain hidden from you.
        </Box>
      )}
      {!!data.allowed && !data.body_visible && (
        <Box color="label" my={1}>
          This chassis or its current state hides visual parts.
        </Box>
      )}
      <Table mt={1}>
        <Table.Row header>
          <Table.Cell>Part</Table.Cell>
          <Table.Cell collapsing textAlign="center">
            Visibility
          </Table.Cell>
          <Table.Cell collapsing textAlign="center">
            Arousal
          </Table.Cell>
        </Table.Row>
        {data.parts.map((part) => (
          <Table.Row key={part.slot} className="candystripe">
            <Table.Cell verticalAlign="middle">
              <Box bold>{editorLabel(part.slot)}</Box>
              <Box color="label" fontSize="0.85em">
                {part.choice}
              </Box>
            </Table.Cell>
            <Table.Cell collapsing textAlign="center">
              <div className="CyborgUsage__buttons">
                {[true, false].map((active) => (
                  <Button
                    key={String(active)}
                    icon={active ? 'eye' : 'eye-slash'}
                    selected={!!part.active === active}
                    disabled={!data.allowed}
                    aria-label={`${active ? 'Show' : 'Hide'} ${part.slot}`}
                    tooltip={
                      active
                        ? 'Show this configured part'
                        : 'Hide this part for this body'
                    }
                    onClick={() =>
                      act({
                        operation: 'activate',
                        slot: part.slot,
                        value: active,
                      })
                    }
                  />
                ))}
              </div>
            </Table.Cell>
            <Table.Cell collapsing textAlign="center">
              <div className="CyborgUsage__buttons">
                {part.can_arouse ? (
                  ['none', 'partial', 'full'].map((value, index) => (
                    <Button
                      key={value}
                      icon={
                        [
                          'temperature-empty',
                          'temperature-half',
                          'temperature-full',
                        ][index]
                      }
                      selected={part.arousal === value}
                      disabled={!data.allowed || !part.active}
                      aria-label={`${editorLabel(value)} ${part.slot}`}
                      tooltip={editorLabel(value)}
                      onClick={() =>
                        act({ operation: 'arousal', slot: part.slot, value })
                      }
                    />
                  ))
                ) : (
                  <Box color="label">—</Box>
                )}
              </div>
            </Table.Cell>
          </Table.Row>
        ))}
      </Table>
      {!data.parts.length && (
        <Box my={1}>No parts configured for this chassis.</Box>
      )}
      <Box color="label" mt={1}>
        Choose parts, positioning, colors, and presets in Setup Character →
        Cyborg.
      </Box>
    </Section>
  );
}
