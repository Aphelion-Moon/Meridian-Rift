// THIS IS AN APHELION UI FILE
import { expect, it, mock } from 'bun:test';
import { act, fireEvent, render, screen } from '@testing-library/react';
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

it('shows disabled options with their reason but never selects one', async () => {
  const onSelect = mock();
  const view = render(
    <ChoicedSelection
      name="Hairstyle"
      catalog={catalog}
      selected="Short Hair"
      onSelect={onSelect}
      disabledOptions={{ 'Long Hair 1': 'Too long for this helmet' }}
    />,
  );
  const disabled = screen.getByLabelText('Long Hair 1');
  expect(disabled.classList.contains('Button--disabled')).toBe(true);
  expect(disabled.getAttribute('aria-disabled')).toBe('true');
  expect(
    screen.getByLabelText('Long Hair 2').classList.contains('Button--disabled'),
  ).toBe(false);
  fireEvent.click(disabled);
  expect(onSelect).not.toHaveBeenCalled();
  // The tooltip opens once the pointer rests on the option.
  await act(async () => fireEvent.mouseMove(disabled));
  expect(
    await screen.findByText('Long Hair 1: Too long for this helmet'),
  ).toBeTruthy();
  // Search still finds a disabled option, and the others stay selectable.
  fireEvent.input(screen.getByPlaceholderText('Search...'), {
    target: { value: 'long hair' },
  });
  expect(view.container.querySelectorAll('.preferences32x32').length).toBe(2);
  fireEvent.click(screen.getByLabelText('Long Hair 2'));
  expect(onSelect.mock.calls).toEqual([['Long Hair 2']]);
});
