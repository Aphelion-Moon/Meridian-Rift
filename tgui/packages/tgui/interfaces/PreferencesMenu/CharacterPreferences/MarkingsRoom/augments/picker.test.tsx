// THIS IS AN APHELION UI FILE
import { afterEach, describe, expect, it } from 'bun:test';
import { cleanup, fireEvent, render, screen } from '@testing-library/react';

import { Picker } from '.';

const option = (
  name: string,
  info = '',
  tags: string[] = [],
  current = false,
) => ({
  key: name,
  name,
  cost: 0,
  info,
  item: null,
  tags: tags.map((text) => ({ text })),
  current,
  dear: false,
});

const OPTIONS = [
  option('None', '', [], true),
  option('Cybernetic eyes', 'See in the dark', ['ROBOTIC']),
  option('Moth eyes', 'Bright light hurts', ['ORGANIC']),
];

function renderPicker() {
  render(
    <Picker
      open={{ slot: 'Eyes', field: 'organ', side: 'l', oy: 0 }}
      options={OPTIONS}
      peek={null}
      title="EYES"
      pointsOn={false}
      onPeek={() => {}}
      onPick={() => {}}
      onClose={() => {}}
    />,
  );
  return screen.getByRole('searchbox', { name: 'Search options' });
}

const shownNames = () =>
  screen
    .queryAllByRole('option')
    .map((element) => element.querySelector('.opt-n')?.textContent);

afterEach(cleanup);

describe("the augments picker's search", () => {
  it('lists every option until something is typed', () => {
    const search = renderPicker();
    expect(search.getAttribute('placeholder')).toBe('Search 3 options');
    expect(shownNames()).toEqual(['None', 'Cybernetic eyes', 'Moth eyes']);
  });

  it("narrows the list by an option's name, description or tag, in any case", () => {
    const search = renderPicker();
    fireEvent.change(search, { target: { value: 'MOTH' } });
    expect(shownNames()).toEqual(['Moth eyes']);
    fireEvent.change(search, { target: { value: 'in the dark' } });
    expect(shownNames()).toEqual(['Cybernetic eyes']);
    fireEvent.change(search, { target: { value: 'organic' } });
    expect(shownNames()).toEqual(['Moth eyes']);
    fireEvent.change(search, { target: { value: '  eyes ' } });
    expect(shownNames()).toEqual(['Cybernetic eyes', 'Moth eyes']);
  });

  it('says so when nothing matches', () => {
    const search = renderPicker();
    fireEvent.change(search, { target: { value: 'wings' } });
    expect(shownNames()).toEqual([]);
    expect(screen.getByText('No options match that.')).toBeDefined();
  });
});
