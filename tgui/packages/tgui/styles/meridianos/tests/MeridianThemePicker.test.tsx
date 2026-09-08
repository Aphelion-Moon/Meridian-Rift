// THIS IS AN APHELION UI FILE
import { afterEach, describe, expect, it, mock } from 'bun:test';
import {
  act,
  cleanup,
  fireEvent,
  render,
  screen,
  waitFor,
} from '@testing-library/react';
import { MERIDIAN_BASE_THEME_OPTIONS } from '../../../constants/theme';
import { MeridianThemePicker } from '../../../layouts/MeridianThemePicker';

afterEach(cleanup);

describe('MeridianThemePicker', () => {
  it('starts a fresh typeahead after an outside dismissal', async () => {
    render(
      <MeridianThemePicker onChange={() => {}} value="meridian_diagnostic" />,
    );
    const trigger = screen.getByRole('button', {
      name: /change base interface theme/i,
    });

    await act(async () => {
      fireEvent.click(trigger);
    });
    fireEvent.keyDown(screen.getByRole('menu'), { key: 'c' });
    fireEvent.pointerDown(document.body);
    await waitFor(() => expect(screen.queryAllByRole('menu').length).toBe(0));
    await act(async () => {
      fireEvent.click(trigger);
    });
    const selected = screen.getByRole('menuitemradio', { name: /Diagnostic/ });
    expect(document.activeElement === selected).toBe(true);

    fireEvent.keyDown(screen.getByRole('menu'), { key: 'y' });
    expect(document.activeElement === selected).toBe(true);
  });

  it('renders the ordered theme catalog as an accessible radio menu', async () => {
    render(
      <MeridianThemePicker onChange={() => {}} value="meridian_aphelion" />,
    );

    const trigger = screen.getByRole('button', {
      name: /change base interface theme/i,
    });
    expect(trigger.getAttribute('aria-haspopup')).toBe('menu');
    expect(trigger.getAttribute('aria-expanded')).toBe('false');

    await act(async () => {
      fireEvent.click(trigger);
    });

    expect(trigger.getAttribute('aria-expanded')).toBe('true');
    const options = screen.getAllByRole('menuitemradio');
    expect(options).toHaveLength(MERIDIAN_BASE_THEME_OPTIONS.length);
    expect(options[0].textContent).toContain('Aphelion');
    expect(options[1].textContent).toContain('Classic');
    expect(options[2].textContent).toContain('Electra');
    expect(options[0].getAttribute('aria-checked')).toBe('true');
    expect(options[1].getAttribute('aria-checked')).toBe('false');
    expect(options[2].getAttribute('aria-checked')).toBe('false');
  });

  it('supports complete menu navigation, selection, and focus return', async () => {
    const onChange = mock(() => {});
    render(
      <MeridianThemePicker onChange={onChange} value="meridian_aphelion" />,
    );
    const trigger = screen.getByRole('button', {
      name: /change base interface theme/i,
    });

    await act(async () => {
      fireEvent.click(trigger);
    });
    const menu = screen.getByRole('menu');
    const options = screen.getAllByRole('menuitemradio');

    expect(document.activeElement).toBe(options[0]);
    fireEvent.keyDown(menu, { key: 'ArrowDown' });
    expect(document.activeElement).toBe(options[1]);
    fireEvent.keyDown(menu, { key: 'ArrowUp' });
    expect(document.activeElement).toBe(options[0]);
    fireEvent.keyDown(menu, { key: 'End' });
    expect(document.activeElement).toBe(options[options.length - 1]);
    fireEvent.keyDown(menu, { key: 'Home' });
    expect(document.activeElement).toBe(options[0]);
    fireEvent.keyDown(menu, { key: 'c' });
    expect(document.activeElement).toBe(options[1]);
    fireEvent.keyDown(menu, { key: 'y' });
    expect(document.activeElement).toBe(
      screen.getByRole('menuitemradio', { name: /Cyberpunk/ }),
    );

    await act(async () => {
      fireEvent.keyDown(menu, { key: 'Escape' });
    });
    await waitFor(() => expect(screen.queryAllByRole('menu').length).toBe(0));
    expect(trigger.getAttribute('aria-expanded')).toBe('false');
    expect(document.activeElement).toBe(trigger);

    await act(async () => {
      fireEvent.click(trigger);
    });
    await act(async () => {
      fireEvent.click(screen.getAllByRole('menuitemradio')[1]);
    });
    await waitFor(() => expect(screen.queryAllByRole('menu').length).toBe(0));
    expect(onChange).toHaveBeenCalledWith('meridian_classic');
  });

  it('opens from either arrow key at the corresponding boundary', async () => {
    const view = render(
      <MeridianThemePicker onChange={() => {}} value="meridian_diagnostic" />,
    );
    const trigger = screen.getByRole('button', {
      name: /change base interface theme/i,
    });

    await act(async () => {
      fireEvent.keyDown(trigger, { key: 'ArrowUp' });
    });
    const options = screen.getAllByRole('menuitemradio');
    expect(document.activeElement).toBe(options[options.length - 1]);

    view.unmount();
    render(
      <MeridianThemePicker onChange={() => {}} value="meridian_diagnostic" />,
    );
    const nextTrigger = screen.getByRole('button', {
      name: /change base interface theme/i,
    });
    await act(async () => {
      fireEvent.keyDown(nextTrigger, { key: 'ArrowDown' });
    });
    expect(document.activeElement).toBe(
      screen.getAllByRole('menuitemradio')[0],
    );
  });

  it('dismisses on an outside press', async () => {
    render(<MeridianThemePicker onChange={() => {}} value="meridian_electra" />);
    const trigger = screen.getByRole('button', {
      name: /change base interface theme/i,
    });

    await act(async () => {
      fireEvent.click(trigger);
    });
    expect(screen.getByRole('menu')).toBeTruthy();
    fireEvent.pointerDown(document.body);

    expect(trigger.getAttribute('aria-expanded')).toBe('false');
    expect(
      screen
        .getByRole('menu')
        .closest('.Floating')
        ?.getAttribute('data-transition'),
    ).toBe('close');
    await waitFor(() => expect(screen.queryAllByRole('menu').length).toBe(0));
  });
});
