// THIS IS AN APHELION UI FILE
import { expect, it, mock } from 'bun:test';
import { fireEvent, render, screen } from '@testing-library/react';
import { ChoicedSelection } from './ChoicedSelection';

const catalog = {
  icons: {
    'Short Hair': 'hairstyle_name___Short_Hair',
    'Long Hair 1': 'hairstyle_name___Long_Hair_1',
    'Long Hair 2': 'hairstyle_name___Long_Hair_2',
  },
};

it('reuses preference icons and filters locally without selecting a style', () => {
  const onSelect = mock();
  const view = render(
    <ChoicedSelection
      name="Hairstyle"
      catalog={catalog}
      selected="Short Hair"
      onSelect={onSelect}
      buttons={<button type="button">Hair color</button>}
    >
      <button type="button">Custom hair drawing</button>
    </ChoicedSelection>,
  );
  expect(screen.getByText('Select hairstyle')).toBeTruthy();
  expect(screen.getByText('Hair color')).toBeTruthy();
  expect(screen.getByText('Custom hair drawing')).toBeTruthy();
  expect(view.container.querySelectorAll('.preferences32x32').length).toBe(3);
  const selected = screen.getByLabelText('Short Hair');
  expect(selected.classList.contains('Button--selected')).toBe(true);
  expect(selected.querySelector('.hairstyle_name___Short_Hair')).toBeTruthy();

  fireEvent.input(screen.getByPlaceholderText('Search...'), {
    target: { value: 'long hair' },
  });
  expect(view.container.querySelectorAll('.preferences32x32').length).toBe(2);
  expect(screen.queryByLabelText('Short Hair')).toBeNull();
  expect(onSelect).not.toHaveBeenCalled();
  fireEvent.click(screen.getByLabelText('Long Hair 2'));
  expect(onSelect.mock.calls).toEqual([['Long Hair 2']]);
});

it('keeps its search during a selected-style update and uses the current catalog', () => {
  const onSelect = mock();
  const view = render(
    <ChoicedSelection
      name="Hairstyle"
      catalog={catalog}
      selected="Short Hair"
      onSelect={onSelect}
    />,
  );
  fireEvent.input(screen.getByPlaceholderText('Search...'), {
    target: { value: 'long hair' },
  });
  view.rerender(
    <ChoicedSelection
      name="Hairstyle"
      catalog={{ icons: { 'Long Hair 2': catalog.icons['Long Hair 2'] } }}
      selected="Long Hair 2"
      onSelect={onSelect}
    />,
  );
  expect(view.container.querySelectorAll('.preferences32x32').length).toBe(1);
  expect(
    screen.getByLabelText('Long Hair 2').classList.contains('Button--selected'),
  ).toBe(true);
  expect(onSelect).not.toHaveBeenCalled();
});
