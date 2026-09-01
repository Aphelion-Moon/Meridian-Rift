// THIS IS AN APHELION UI FILE
import { afterEach, beforeEach, describe, expect, it, mock } from 'bun:test';
import {
  act,
  cleanup,
  fireEvent,
  render,
  screen,
} from '@testing-library/react';
import { MERIDIAN_BASE_THEME_IDS } from 'tgui/constants/theme';
import { assetMap } from './assets';
import type { ServerState } from './LobbyMenu';
import { LobbyMenu } from './LobbyMenu';

type LobbySubscription = (payload: unknown) => void;

const originalSendMessage = Byond.sendMessage;
const originalSubscribeTo = Byond.subscribeTo;
const originalRequestAnimationFrame = window.requestAnimationFrame;
const originalCancelAnimationFrame = window.cancelAnimationFrame;

const subscriptions = new Map<string, LobbySubscription>();
let sendMessage: ReturnType<typeof mock>;

function makeServerState(overrides: Partial<ServerState> = {}): ServerState {
  return {
    titleImageUrl: 'asset://title.png',
    titleImageTreatment: 'mask',
    titleMarkUrl: 'asset://meridian-rift-mark.png',
    titleVariant: 'convex',
    titleBezel: 'rusty',
    titleTexture: 'scanlines-classic',
    titleClassicAlt: false,
    canSetTitleScreen: true,
    gamePhase: 'startup',
    isReady: false,
    canReady: true,
    canJoin: false,
    canObserve: false,
    assetsReady: true,
    countdown: '30s',
    playerCount: 1,
    readyCount: 0,
    adminReadyCount: 0,
    adminCount: 0,
    mapName: 'Test Station',
    shiftTime: 'Pre-Game',
    isAdmin: false,
    isLocalhost: false,
    stationTraits: [],
    hasNewPoll: false,
    canPoll: false,
    canSwapServers: false,
    overflowJob: null,
    traitFeedback: null,
    transparent: false,
    notice: null,
    latejoinQueue: 'PRE-ROUND',
    characterName: 'TEST PLAYER',
    isAntag: false,
    startupMessages: [{ text: 'Loading test systems', warning: false }],
    progressCurrent: 25,
    progressTotal: 100,
    initializedSubsystems: 12,
    totalSubsystems: 26,
    startupSubsystem: 'Mapping',
    meridianTheme: 'meridian',
    ...overrides,
  };
}

function emit(name: 'init' | 'state', payload: unknown) {
  act(() => subscriptions.get(name)?.(payload));
}

beforeEach(() => {
  subscriptions.clear();
  sendMessage = mock(() => {});
  Byond.sendMessage = sendMessage as typeof Byond.sendMessage;
  Byond.subscribeTo = mock((name: string, callback: LobbySubscription) => {
    subscriptions.set(name, callback);
  }) as typeof Byond.subscribeTo;
  assetMap['meridian_rift_scanlines_classic.png'] =
    'asset://scanlines-classic.png';
});

afterEach(() => {
  cleanup();
  Byond.sendMessage = originalSendMessage;
  Byond.subscribeTo = originalSubscribeTo;
  window.requestAnimationFrame = originalRequestAnimationFrame;
  window.cancelAnimationFrame = originalCancelAnimationFrame;
  document.documentElement.classList.remove('runtime-marker');
  document.documentElement.style.removeProperty('--lobby-bg');
  delete assetMap['meridian_rift_scanlines_classic.png'];
});

describe('LobbyMenu MeridianOS integration', () => {
  it('applies an optimistic picker choice and preserves unrelated root classes', async () => {
    document.documentElement.classList.add('runtime-marker');
    render(<LobbyMenu />);
    emit('init', makeServerState());

    fireEvent.click(
      screen.getByRole('button', { name: /change base interface theme/i }),
    );
    fireEvent.click(screen.getByRole('menuitemradio', { name: /classic/i }));
    await act(async () => Promise.resolve());

    expect(sendMessage).toHaveBeenCalledWith('setMeridianTheme', {
      theme: 'meridian_classic',
    });
    expect(
      document.documentElement.classList.contains('theme-nanotrasen'),
    ).toBe(true);
    expect(document.documentElement.classList.contains('theme-console')).toBe(
      false,
    );
    expect(document.documentElement.classList.contains('runtime-marker')).toBe(
      true,
    );
  });

  it('keeps the same boot loader and RAF when only the theme changes', () => {
    let rafCount = 0;
    window.requestAnimationFrame = mock(() => ++rafCount);
    window.cancelAnimationFrame = mock(() => {});

    render(<LobbyMenu />);
    emit('init', makeServerState());
    const loader = screen.getByRole('progressbar', {
      name: 'Estimated startup progress',
    });
    const cursor = document.querySelector('.boot_terminal__cursor');
    expect(cursor).toBeTruthy();
    const initialRafCount = rafCount;

    emit('state', { meridianTheme: 'meridian_vector' });

    expect(
      screen.getByRole('progressbar', { name: 'Estimated startup progress' }),
    ).toBe(loader);
    expect(document.querySelector('.boot_terminal__cursor')).toBe(cursor);
    expect(rafCount).toBe(initialRafCount);
    expect(
      document.documentElement.classList.contains('theme-meridian_vector'),
    ).toBe(true);
  });

  it('retains theme and transparency behavior across startup and nav phases', () => {
    render(<LobbyMenu />);
    emit(
      'init',
      makeServerState({
        meridianTheme: 'meridian_foundry',
        transparent: true,
      }),
    );

    expect(screen.getByRole('progressbar')).toBeTruthy();
    expect(document.querySelector('.bg')).toBeNull();
    expect(document.documentElement.style.getPropertyValue('--lobby-bg')).toBe(
      'transparent',
    );

    emit('state', { gamePhase: 'pregame' });

    expect(screen.queryByRole('progressbar')).toBeNull();
    expect(screen.getByRole('button', { name: /ready/i })).toBeTruthy();
    expect(
      document.documentElement.classList.contains('theme-meridian_foundry'),
    ).toBe(true);
    expect(document.querySelector('.bg')).toBeNull();

    emit('state', { transparent: false });

    expect(document.querySelector('.lobby-title-art')).toBeTruthy();
    expect(
      document.querySelector<HTMLImageElement>('.lobby-title-art__fallback')
        ?.src,
    ).toContain('asset://title.png');
    expect(document.documentElement.style.getPropertyValue('--lobby-bg')).toBe(
      'black',
    );
  });

  it('asks the server to open the manager rather than editing in the lobby', async () => {
    render(<LobbyMenu />);
    emit('init', makeServerState({ gamePhase: 'pregame' }));

    fireEvent.click(
      screen.getByRole('button', { name: /manage the lobby title screen/i }),
    );
    await act(async () => Promise.resolve());

    // The lobby no longer edits anything: it opens the admin window, and the
    // window applies through the subsystem behind its own confirmation.
    expect(sendMessage).toHaveBeenCalledWith('openTitleManager');

    // Presentation still arrives by broadcast, so every open lobby stays in
    // step rather than only the one an admin happened to be looking at.
    emit('state', {
      titleTexture: 'scanlines-classic',
      titleVariant: 'convex',
      titleBezel: 'rusty',
    });
    let artwork = document.querySelector('.lobby-title-art');
    expect(artwork?.getAttribute('data-texture')).toBe('none');
    expect(
      document
        .querySelector('.lobby-menu-scanline-overlay')
        ?.getAttribute('data-texture'),
    ).toBe('scanlines-classic');
    expect(artwork?.getAttribute('data-variant')).toBe('convex');
    // The rim can change independently of the screen effect.
    expect(artwork?.getAttribute('data-bezel')).toBe('rusty');

    emit('state', { gamePhase: 'pregame', playerCount: 9 });
    artwork = document.querySelector('.lobby-title-art');
    expect(artwork?.getAttribute('data-texture')).toBe('none');
    expect(
      document
        .querySelector('.lobby-menu-scanline-overlay')
        ?.getAttribute('data-texture'),
    ).toBe('scanlines-classic');

    emit('state', { transparent: true });
    expect(
      screen.queryByRole('button', { name: /manage the lobby title screen/i }),
    ).toBeNull();
    expect(document.querySelector('.lobby-title-art')).toBeNull();
  });

  it('initializes every field from a rotated title atomically', () => {
    render(<LobbyMenu />);
    emit(
      'init',
      makeServerState({
        gamePhase: 'pregame',
        titleImageUrl: 'asset://rotated-title.png',
        titleImageTreatment: 'screen',
        titleVariant: 'flat',
        titleBezel: 'none',
        titleTexture: 'scanlines-light',
      }),
    );

    const artwork = document.querySelector('.lobby-title-art');
    expect(artwork?.getAttribute('data-treatment')).toBe('screen');
    expect(artwork?.getAttribute('data-variant')).toBe('flat');
    expect(artwork?.getAttribute('data-bezel')).toBe('none');
    expect(artwork?.getAttribute('data-texture')).toBe('none');
    expect(
      document
        .querySelector('.lobby-menu-scanline-overlay')
        ?.getAttribute('data-texture'),
    ).toBe('scanlines-light');
    expect(
      artwork?.querySelector('.lobby-title-art__fallback')?.getAttribute('src'),
    ).toBe('asset://rotated-title.png');
  });

  it('updates each bezel choice from broadcasts without changing the screen', () => {
    render(<LobbyMenu />);
    emit('init', makeServerState({ gamePhase: 'pregame' }));

    for (const titleBezel of [
      'classic',
      'none',
      'rusty-dark',
      'aphelion',
      'rusty',
    ] as const) {
      emit('state', { titleBezel });

      const artwork = document.querySelector('.lobby-title-art');
      expect(artwork?.getAttribute('data-bezel')).toBe(titleBezel);
      expect(artwork?.classList.contains('lobby-title-art--bezel')).toBe(
        titleBezel !== 'none',
      );
      expect(
        artwork?.classList.contains(`lobby-title-art--bezel-${titleBezel}`),
      ).toBe(true);
      expect(artwork?.getAttribute('data-variant')).toBe('convex');
      expect(artwork?.getAttribute('data-texture')).toBe('none');
      expect(
        document
          .querySelector('.lobby-menu-scanline-overlay')
          ?.getAttribute('data-texture'),
      ).toBe('scanlines-classic');
    }
  });

  for (const meridianTheme of MERIDIAN_BASE_THEME_IDS) {
    it(`keeps ${meridianTheme} menu scanlines aligned with each bezel choice`, () => {
      render(<LobbyMenu />);
      emit('init', makeServerState({ gamePhase: 'pregame', meridianTheme }));

      const choices = [
        { incoming: 'rusty', expected: 'rusty' },
        { incoming: 'rusty-dark', expected: 'rusty-dark' },
        { incoming: 'aphelion', expected: 'aphelion' },
        { incoming: 'classic', expected: 'classic' },
        { incoming: 'none', expected: 'none' },
        { incoming: true, expected: 'classic' },
        { incoming: false, expected: 'none' },
        { incoming: 1, expected: 'classic' },
        { incoming: 0, expected: 'none' },
        { incoming: undefined, expected: 'rusty-dark' },
      ] as const;

      for (const { incoming, expected } of choices) {
        emit('state', { titleBezel: incoming });

        const artwork = document.querySelector(
          '.lobby-title-art:not(.lobby-menu-scanline-overlay)',
        );
        const overlay = document.querySelector('.lobby-menu-scanline-overlay');
        for (const layer of [artwork, overlay]) {
          expect(layer?.getAttribute('data-bezel')).toBe(expected);
          expect(layer?.classList.contains('lobby-title-art--bezel')).toBe(
            expected !== 'none',
          );
          expect(
            layer?.classList.contains(`lobby-title-art--bezel-${expected}`),
          ).toBe(true);
        }
        expect(artwork?.getAttribute('data-texture')).toBe('none');
        expect(overlay?.getAttribute('data-texture')).toBe('scanlines-classic');
      }
    });
  }

  it('shows the title screen button only to an admin who may set it', () => {
    render(<LobbyMenu />);
    emit('init', makeServerState({ canSetTitleScreen: false }));

    expect(
      screen.queryByRole('button', { name: /manage the lobby title screen/i }),
    ).toBeNull();
    // The base theme picker is everyone's, and stays.
    expect(
      screen.getByRole('button', { name: /change base interface theme/i }),
    ).toBeTruthy();

    emit('state', { canSetTitleScreen: true });
    expect(
      screen.getByRole('button', { name: /manage the lobby title screen/i }),
    ).toBeTruthy();
  });

  it('renders a treated screen without a wordmark', () => {
    render(<LobbyMenu />);
    emit(
      'init',
      makeServerState({
        gamePhase: 'pregame',
        titleImageTreatment: 'screen',
      }),
    );

    // Screen treatment and wordmark are independent: this is the combination the old
    // all-or-nothing overlay flag could not express.
    const artwork = document.querySelector('.lobby-title-art');
    expect(artwork).toBeTruthy();
    expect(artwork?.getAttribute('data-treatment')).toBe('screen');
    expect(artwork?.className).toContain('lobby-title-art--screen');
  });

  it('keeps the title artwork off screen while the round is loading', () => {
    render(<LobbyMenu />);
    emit('init', makeServerState({ gamePhase: 'startup' }));

    // The boot terminal owns the screen during startup.
    expect(document.querySelector('.lobby-title-art')).toBeNull();
    expect(document.querySelector('.bg')).toBeNull();
    expect(document.querySelector('.boot_terminal')).toBeTruthy();

    emit('state', { gamePhase: 'pregame' });
    expect(document.querySelector('.lobby-title-art')).toBeTruthy();
  });

  it('renders an untreated screen as a plain backdrop', () => {
    render(<LobbyMenu />);
    emit(
      'init',
      makeServerState({ gamePhase: 'pregame', titleImageTreatment: 'none' }),
    );

    expect(document.querySelector('.lobby-title-art')).toBeNull();
    expect(document.querySelector('.bg')?.getAttribute('src')).toBe(
      'asset://title.png',
    );
  });

  it('composites the wordmark over a screen in the overlay treatment', () => {
    render(<LobbyMenu />);
    emit(
      'init',
      makeServerState({ gamePhase: 'pregame', titleImageTreatment: 'overlay' }),
    );

    const artwork = document.querySelector('.lobby-title-art');
    expect(artwork?.getAttribute('data-treatment')).toBe('overlay');
    expect(artwork?.className).toContain('lobby-title-art--overlay');
  });

  it('renders the texture the server chose', () => {
    render(<LobbyMenu />);
    emit(
      'init',
      makeServerState({
        gamePhase: 'pregame',
        titleTexture: 'scanlines-classic',
      }),
    );

    expect(
      document
        .querySelector('.lobby-menu-scanline-overlay')
        ?.getAttribute('data-texture'),
    ).toBe('scanlines-classic');
    expect(
      document.querySelector('.lobby-title-art')?.getAttribute('data-texture'),
    ).toBe('none');
  });

  it('restores the server presentation after a remount', () => {
    const view = render(<LobbyMenu />);
    emit(
      'init',
      makeServerState({ gamePhase: 'pregame', titleVariant: 'flat' }),
    );
    expect(
      document.querySelector('.lobby-title-art')?.getAttribute('data-variant'),
    ).toBe('flat');

    view.unmount();
    render(<LobbyMenu />);
    emit(
      'init',
      makeServerState({ gamePhase: 'pregame', titleVariant: 'flat' }),
    );

    // Nothing is client-local any more, so the choice survives the remount.
    const artwork = document.querySelector('.lobby-title-art');
    expect(artwork?.getAttribute('data-variant')).toBe('flat');
    expect(artwork?.getAttribute('data-texture')).toBe('none');
    expect(
      document
        .querySelector('.lobby-menu-scanline-overlay')
        ?.getAttribute('data-texture'),
    ).toBe('scanlines-classic');
    expect(artwork?.getAttribute('data-presentation')).toBe('classic-alt');
  });
});
