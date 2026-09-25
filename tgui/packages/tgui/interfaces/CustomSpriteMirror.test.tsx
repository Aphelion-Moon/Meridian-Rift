// THIS IS AN APHELION UI FILE

import { afterEach, beforeEach, expect, it, spyOn } from 'bun:test';
import { join } from 'node:path';
import { fireEvent, render, screen } from '@testing-library/react';
import { compileAsync } from 'sass-embedded';
import * as actions from 'tgui/events/act';
import { store as backendStore, gameDataAtom } from 'tgui/events/store';
import {
  CustomSpriteMirror,
  type CustomSpriteMirrorData,
} from './CustomSpriteMirror';

const views = (prefix: string) => ({
  2: `${prefix}-front`,
  1: `${prefix}-back`,
  4: `${prefix}-right`,
  8: `${prefix}-left`,
});

const approval = (): CustomSpriteMirrorData => ({
  mode: 'approval',
  label: 'hairstyle',
  artistName: 'Han',
  restoration: false,
  token: 'reviewed-token',
  before: views('before'),
  after: views('after'),
  timeout: 1,
  canSave: false,
});

let send: ReturnType<typeof spyOn>;
let previousData: Record<string, unknown>;
beforeEach(() => {
  previousData = backendStore.get(gameDataAtom);
  send = spyOn(actions, 'sendAct');
});
afterEach(() => {
  send.mockRestore();
  backendStore.set(gameDataAtom, previousData);
});

it('compares aligned views with a slider and binds both acceptance choices to the reviewed token', () => {
  backendStore.set(gameDataAtom, approval());
  render(<CustomSpriteMirror />);
  const image = (name: string) => screen.getByRole('img', { name });
  expect(image('After, Front view').getAttribute('src')).toBe('after-front');
  for (const [label, key] of [
    ['Back', 'back'],
    ['Right', 'right'],
    ['Left', 'left'],
  ]) {
    fireEvent.click(screen.getByText(label));
    expect(image(`After, ${label} view`).getAttribute('src')).toBe(
      `after-${key}`,
    );
    expect(image(`Before, ${label} view`).getAttribute('src')).toBe(
      `before-${key}`,
    );
    expect(image(`After, ${label} view`).style.transform).toBe('');
  }
  const slider = screen.getByRole('slider', {
    name: 'Compare before and after',
  });
  fireEvent.change(slider, { target: { value: '75' } });
  expect(image('After, Left view').style.clipPath).toBe('inset(0 0 0 75%)');
  expect(image('Before, Left view').style.clipPath).toBe('inset(0 25% 0 0)');
  expect(screen.queryByRole('button', { name: 'Before' })).toBeNull();
  fireEvent.click(screen.getByText('Accept for this round'));
  expect(send).toHaveBeenLastCalledWith('accept', { token: 'reviewed-token' });
  fireEvent.click(screen.getByText('Accept permanently'));
  expect(send).toHaveBeenLastCalledWith('acceptPermanent', {
    token: 'reviewed-token',
  });
  fireEvent.click(screen.getByText('Export'));
  expect(send).toHaveBeenLastCalledWith('export', { token: 'reviewed-token' });
  fireEvent.click(screen.getByText('Decline'));
  expect(send).toHaveBeenLastCalledWith('decline');
});

it('uses the shared timeout bar without a stale expiry sentence', () => {
  backendStore.set(gameDataAtom, approval());
  const view = render(<CustomSpriteMirror />);
  const bar = screen.getByRole('progressbar', { name: 'Time remaining' });
  expect(bar.getAttribute('aria-valuenow')).toBe('1');
  backendStore.set(gameDataAtom, { ...approval(), timeout: 0.5 });
  view.rerender(<CustomSpriteMirror />);
  expect(bar.getAttribute('aria-valuenow')).toBe('0.5');
  expect(screen.queryByText(/Expires in/)).toBeNull();
});

it('fits rectangular previews inside a stable mirror area without stretching them', async () => {
  const { css } = await compileAsync(
    join(import.meta.dir, '../styles/interfaces/CustomSpriteMirror.scss'),
  );
  const style = document.createElement('style');
  style.textContent = css;
  document.head.appendChild(style);
  try {
    backendStore.set(gameDataAtom, approval());
    render(<CustomSpriteMirror />);
    for (const image of screen.getAllByRole('img')) {
      const computed = getComputedStyle(image);
      expect(computed.objectFit).toBe('contain');
      expect(computed.width).toBe('100%');
      expect(computed.height).toBe('100%');
    }
  } finally {
    style.remove();
  }
});

it('offers recipient save without a redundant export after application and reports failures', () => {
  backendStore.set(gameDataAtom, {
    mode: 'result',
    label: 'left arm tattoo',
    restoration: false,
    canSave: true,
    saveState: 'error',
    messageError: true,
    saveMessage:
      "Couldn't save to disk. Your style is still applied this round.",
  });
  render(<CustomSpriteMirror />);
  expect(screen.queryByText('Accept for this round')).toBeNull();
  expect(screen.queryByText('Export')).toBeNull();
  expect(screen.getByRole('alert').textContent).toContain('still applied');
  fireEvent.click(screen.getByText('Save for future rounds'));
  expect(send).toHaveBeenLastCalledWith('save');
});

it('asks the server to draw only the view the mirror shows, and only while approving', () => {
  backendStore.set(gameDataAtom, { ...approval(), visibleView: '2' });
  const view = render(<CustomSpriteMirror />);
  expect(send).not.toHaveBeenCalled();
  fireEvent.click(screen.getByText('Back'));
  expect(send).toHaveBeenLastCalledWith('setView', { dir: '1' });
  send.mockClear();
  backendStore.set(gameDataAtom, { ...approval(), visibleView: '1' });
  view.rerender(<CustomSpriteMirror />);
  expect(send).not.toHaveBeenCalled();
  view.unmount();
  backendStore.set(gameDataAtom, {
    mode: 'result',
    label: 'hairstyle',
    restoration: false,
    canSave: true,
    visibleView: '1',
  });
  render(<CustomSpriteMirror />);
  expect(send).not.toHaveBeenCalled();
});
