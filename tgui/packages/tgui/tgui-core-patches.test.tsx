// THIS IS AN APHELION UI FILE
import { afterEach, describe, expect, it, jest } from 'bun:test';
import { cleanup, fireEvent, render } from '@testing-library/react';
import { Image, Section } from 'tgui-core/components';

// tgui/patches/tgui-core@6.1.3.patch: a scrollable Section's content leaves
// tgui-core's list of scrollable nodes when the Section unmounts. The list
// focuses whichever of its nodes the pointer moves over.
//
// The same patch has Image retry a failed src with `&attempt=N` when the src
// already has a query, and never over a src that replaced it meanwhile.

afterEach(cleanup);
afterEach(() => jest.useRealTimers());

/** Whether moving the pointer over a node makes the scroll list focus it. */
function focusedOnHover(node: HTMLElement) {
  let focused = false;
  node.focus = () => {
    focused = true;
  };
  node.dispatchEvent(new MouseEvent('mousemove', { bubbles: true }));
  return focused;
}

describe('tgui-core patches', () => {
  it('focuses a mounted scrollable Section under the pointer', () => {
    const view = render(<Section scrollable>Scrolled</Section>);
    const content = view.container.querySelector(
      '.Section__content',
    ) as HTMLElement;

    expect(focusedOnHover(content)).toBe(true);
  });

  it("forgets a scrollable Section's content once it unmounts", () => {
    const view = render(<Section scrollable>Scrolled</Section>);
    const content = view.container.querySelector(
      '.Section__content',
    ) as HTMLElement;
    view.unmount();
    // Back where the pointer can reach it: a list that kept it would focus it.
    document.body.appendChild(content);

    expect(focusedOnHover(content)).toBe(false);
    content.remove();
  });

  it('retries an Image without breaking its query or a newer src', () => {
    jest.useFakeTimers();
    // Absolute, so happy-dom can parse them: it fails a src it can't parse on
    // its own, and here only our error events should.
    const icon = 'https://icons.invalid/0xc000001?state=x&frame=1';
    const nextIcon = 'https://icons.invalid/0xc000002?state=y&frame=1';
    const view = render(<Image src={icon} fixErrors />);
    const image = view.container.querySelector('img') as HTMLImageElement;

    fireEvent.error(image);
    jest.advanceTimersByTime(1000);
    expect(image.getAttribute('src')).toBe(`${icon}&attempt=0`);

    // The next retry is still waiting when the icon changes under it.
    fireEvent.error(image);
    view.rerender(<Image src={nextIcon} fixErrors />);
    jest.advanceTimersByTime(1000);
    expect(image.getAttribute('src')).toBe(nextIcon);
  });
});
