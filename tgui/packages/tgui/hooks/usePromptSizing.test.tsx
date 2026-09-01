// THIS IS AN APHELION UI FILE
import {
  afterEach,
  beforeEach,
  describe,
  expect,
  it,
  mock,
  spyOn,
} from 'bun:test';
import { fitPromptWindow } from './usePromptSizing';

const originalWinset = Byond.winset;
const restores: (() => void)[] = [];
function property(target: object, key: string, value: unknown) {
  const old = Object.getOwnPropertyDescriptor(target, key);
  Object.defineProperty(target, key, { configurable: true, value });
  restores.push(() =>
    old
      ? Object.defineProperty(target, key, old)
      : Reflect.deleteProperty(target, key),
  );
}

beforeEach(() => {
  property(window, 'innerWidth', 345);
  property(window, 'innerHeight', 175);
  property(window, 'devicePixelRatio', 1);
  property(window, 'screenTop', 0);
  property(window, 'screenLeft', 0);
  property(window.screen, 'availHeight', 900);
  Byond.winset = mock(() => {}) as typeof Byond.winset;
});

afterEach(() => {
  Byond.winset = originalWinset;
  document.body.innerHTML = '';
  while (restores.length) restores.pop()!();
});

function content(bottom: number, zoom = 1) {
  document.body.innerHTML =
    '<div class="MeridianContentFit"><div class="Window__content"><div class="Window__contentPadding" style="margin-bottom: 6px"></div></div></div>';
  const area = document.querySelector<HTMLElement>('.Window__content')!;
  const padding = document.querySelector<HTMLElement>(
    '.Window__contentPadding',
  )!;
  property(padding, 'offsetWidth', 300);
  spyOn(area, 'getBoundingClientRect').mockReturnValue({
    bottom: 165,
  } as DOMRect);
  spyOn(padding, 'getBoundingClientRect').mockReturnValue({
    bottom,
    width: 300 * zoom,
  } as DOMRect);
  return area;
}

describe('Content-sized window geometry', () => {
  it('opens tall enough for content and the bottom frame', () => {
    content(239);
    fitPromptWindow();
    expect(Byond.winset).toHaveBeenCalledWith(Byond.windowId, {
      size: '345x255',
    });
  });

  it('caps at the available screen and converts display pixels', () => {
    content(1200);
    property(window, 'devicePixelRatio', 2);
    property(window.screen, 'availHeight', 600);
    fitPromptWindow();
    expect(Byond.winset).toHaveBeenCalledWith(Byond.windowId, {
      size: '690x1200',
    });
  });

  it('accounts for unscaled BYOND content and scroll position', () => {
    const area = content(239, 0.5);
    area.scrollTop = 30;
    fitPromptWindow();
    expect(Byond.winset).toHaveBeenCalledWith(Byond.windowId, {
      size: '345x282',
    });
  });

  it('preserves a larger user window and ignores unrelated windows', () => {
    content(140);
    fitPromptWindow();
    document.querySelector('.MeridianContentFit')!.className = 'Window';
    fitPromptWindow();
    expect(Byond.winset).not.toHaveBeenCalled();
  });

  it('does not resize a cancelled or removed window', () => {
    content(300);
    fitPromptWindow(() => true);
    document.body.innerHTML = '';
    fitPromptWindow();
    expect(Byond.winset).not.toHaveBeenCalled();
  });
});
