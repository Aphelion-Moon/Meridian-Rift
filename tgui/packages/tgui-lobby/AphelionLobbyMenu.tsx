// THIS IS AN APHELION UI FILE

import type { CSSProperties } from 'react';
import {
  type MeridianBaseThemeId,
  normalizeMeridianBaseTheme,
  resolveMeridianTheme,
} from 'tgui/constants/theme';
import { useRootThemeClasses } from 'tgui/hooks/useRootThemeClasses';
import {
  type LobbyTitleArtVariant,
  type LobbyTitleBezel,
  type LobbyTitleTexture,
  type LobbyTitleTreatment,
  resolveLobbyScreenPresentation,
  resolveLobbyTitleArtVariant,
  resolveLobbyTitleBezel,
  resolveLobbyTitleTexture,
  resolveLobbyTitleTreatment,
  TitleArtwork,
} from 'tgui/interfaces/common/TitleArtwork';
import { MeridianThemePicker } from 'tgui/layouts/MeridianThemePicker';
import { Icon } from 'tgui-core/components';
import { assetMap } from './assets';
import { BootTerminal } from './components/BootTerminal';
import { NavMenu } from './components/NavMenu';
import { NoticeBanner } from './components/NoticeBanner';
import { WhitelistGate } from './components/WhitelistGate';
import type { ServerState } from './LobbyMenu';
import { getLobbyMenuTheme } from './menuTheme';

export type MeridianLobbyState = {
  meridianTheme: MeridianBaseThemeId;
  titleImageTreatment: LobbyTitleTreatment;
  /** Neutral wordmark asset, composited over a picture in overlay treatment. */
  titleMarkUrl: string;
  titleVariant: LobbyTitleArtVariant;
  titleBezel: LobbyTitleBezel | boolean | 0 | 1;
  titleTexture: LobbyTitleTexture;
  titleClassicAlt: boolean;
  /** Only controls button visibility; the server rechecks the rank. */
  canSetTitleScreen: boolean;
};

export function AphelionLobbyMenu({
  onMeridianThemeChange,
  serverState,
}: {
  onMeridianThemeChange: (theme: MeridianBaseThemeId) => void;
  serverState: ServerState;
}) {
  const meridianTheme = normalizeMeridianBaseTheme(serverState.meridianTheme);
  const menuTheme = getLobbyMenuTheme(meridianTheme);
  useRootThemeClasses(
    resolveMeridianTheme({ preferred: meridianTheme }).classes,
  );

  const classicTextureSrc =
    assetMap['meridian_rift_scanlines_classic.png'] || undefined;
  // The server re-checks the rank when the message arrives; this only hides
  // the button.
  const showArtworkButton =
    !serverState.transparent && serverState.canSetTitleScreen;

  const scanlineOverlay = (() => {
    if (
      !menuTheme.heading ||
      serverState.gamePhase === 'startup' ||
      serverState.transparent ||
      !serverState.titleImageUrl
    ) {
      return null;
    }

    const treatment = resolveLobbyTitleTreatment(
      serverState.titleImageTreatment,
    );
    if (
      treatment === 'none' ||
      (treatment === 'overlay' && !serverState.titleMarkUrl)
    ) {
      return null;
    }

    // Match TitleArtwork's explicit choice, document fallback, and asset fallback.
    const texture = resolveLobbyTitleTexture(
      serverState.titleTexture ??
        document.documentElement.dataset.lobbyTitleTexture,
      !!classicTextureSrc,
    );
    if (texture === 'none') {
      return null;
    }

    const requestedVariant =
      serverState.titleVariant ??
      document.documentElement.dataset.lobbyTitleVariant;
    const textureStyle = classicTextureSrc
      ? ({
          '--lobby-title-scanline-image': `url("${classicTextureSrc
            .replaceAll('\\', '\\\\')
            .replaceAll('"', '\\"')}")`,
        } as CSSProperties)
      : undefined;

    return {
      bezel: resolveLobbyTitleBezel(serverState.titleBezel, requestedVariant),
      texture,
      textureStyle,
      variant: resolveLobbyTitleArtVariant(requestedVariant),
    };
  })();

  return (
    <div
      className={`lobby ${serverState.transparent ? 'lobby--transparent' : ''}`}
      data-menu-treatment={menuTheme.treatment}
      data-menu-scanlines={scanlineOverlay ? 'true' : undefined}
    >
      {/* The boot terminal owns the screen during startup, so the title
          artwork stays out of the way until the round is loaded. */}
      {serverState.gamePhase !== 'startup' &&
        !serverState.transparent &&
        !!serverState.titleImageUrl && (
          <TitleArtwork
            bezel={serverState.titleBezel}
            markSrc={serverState.titleMarkUrl}
            presentation={resolveLobbyScreenPresentation(
              serverState.titleImageTreatment,
              serverState.titleClassicAlt,
            )}
            src={serverState.titleImageUrl}
            texture={scanlineOverlay ? 'none' : serverState.titleTexture}
            textureSrc={classicTextureSrc}
            treatment={serverState.titleImageTreatment}
            variant={serverState.titleVariant}
          />
        )}

      <div
        aria-label="Lobby display controls"
        className="lobby__theme-picker lobby__display-controls"
        role="group"
      >
        {showArtworkButton && (
          <button
            aria-label="Manage the lobby title screen"
            className="lobby__display-control"
            onClick={() => Byond.sendMessage('openTitleManager')}
            title="Manage the lobby title screen"
            type="button"
          >
            <Icon name="images" />
          </button>
        )}
        <MeridianThemePicker
          onChange={onMeridianThemeChange}
          placement="bottom-end"
          value={meridianTheme}
        />
      </div>

      {serverState.gamePhase === 'startup' ? (
        <BootTerminal
          messages={serverState.startupMessages}
          progressCurrent={serverState.progressCurrent}
          progressTotal={serverState.progressTotal}
          initializedSubsystems={serverState.initializedSubsystems}
          totalSubsystems={serverState.totalSubsystems}
          startupSubsystem={serverState.startupSubsystem}
        />
      ) : serverState.whitelistGate !== 'open' ? (
        <WhitelistGate
          state={serverState.whitelistGate}
          canSwapServers={serverState.canSwapServers}
        />
      ) : (
        <>
          {!!serverState.notice && <NoticeBanner text={serverState.notice} />}
          <NavMenu serverState={serverState} assetMap={assetMap} />
        </>
      )}

      {/* A decorative sibling allows interleaving without reparenting controls
          into the aria-hidden, clipped artwork. CSS makes this glass transparent. */}
      {scanlineOverlay && (
        <div
          aria-hidden="true"
          className={[
            'lobby-title-art',
            'lobby-menu-scanline-overlay',
            `lobby-title-art--${scanlineOverlay.variant}`,
            `lobby-title-art--texture-${scanlineOverlay.texture}`,
            scanlineOverlay.bezel !== 'none' && 'lobby-title-art--bezel',
            `lobby-title-art--bezel-${scanlineOverlay.bezel}`,
          ]
            .filter(Boolean)
            .join(' ')}
          data-bezel={scanlineOverlay.bezel}
          data-texture={scanlineOverlay.texture}
          data-variant={scanlineOverlay.variant}
        >
          <div className="lobby-title-art__bezel">
            <div className="lobby-title-art__screen">
              <div
                className="lobby-title-art__scanlines"
                style={scanlineOverlay.textureStyle}
              />
            </div>
          </div>
        </div>
      )}
    </div>
  );
}
