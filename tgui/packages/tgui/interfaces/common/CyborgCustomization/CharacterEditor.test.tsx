import { afterEach, expect, it } from 'bun:test';
import { cleanup, fireEvent, render, screen } from '@testing-library/react';
import { CyborgCharacterEditor } from './CharacterEditor';
import {
  CYBORG_SLOTS,
  type CyborgCustomizationData,
  type Layout,
  type LayoutEntry,
} from './types';

afterEach(cleanup);

it('offers both cyborg OOC fields and uses the inspect flavor-text labels', () => {
  const data: CyborgCustomizationData = {
    allowed: true,
    moving: false,
    models: [],
    body_width: 32,
    body_height: 32,
    body_scale: 1,
    model: '',
    poses: ['idle'],
    pose: 'idle',
    direction: 2,
    arousal: 'none',
    body: null,
    store: {
      schema_version: 1,
      presets: {},
      model_defaults: {},
      active: Object.fromEntries<LayoutEntry>(
        CYBORG_SLOTS.map((slot) => [
          slot,
          {
            pixel_x: 0,
            pixel_y: 0,
            rotation: 0,
            scale: 1,
            colors: [],
            advanced: {},
          },
        ]),
      ) as Layout,
    },
  };
  render(
    <CyborgCharacterEditor
      data={data}
      name="Test"
      values={{}}
      renderPreference={(key) => <textarea aria-label={key} />}
      onName={() => {}}
      onPreview={() => {}}
      onLayout={() => {}}
    />,
  );
  fireEvent.click(screen.getByText('Profile'));
  expect(screen.getByText('SFW Flavor Text')).toBeTruthy();
  expect(screen.getByText('NSFW Flavor Text')).toBeTruthy();
  expect(screen.getByLabelText('ooc_notes_silicon')).toBeTruthy();
  expect(screen.getByLabelText('ooc_notes_silicon_nsfw')).toBeTruthy();
});
