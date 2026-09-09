// THIS IS AN APHELION UI FILE
import { assetMap } from './assets';
import { BootTerminal } from './components/BootTerminal';
import { NavMenu } from './components/NavMenu';
import { NoticeBanner } from './components/NoticeBanner';
import { WhitelistGate } from './components/WhitelistGate';
import type { ServerState } from './LobbyMenu';

/**
 * Aphelion's own lobby layout - plain-text/Fixedsys nav menu and boot terminal,
 * in place of upstream's sprite buttons and TV panel.
 */
export function AphelionLobbyMenu({
  serverState,
}: {
  serverState: ServerState;
}) {
  return (
    <div
      className={`lobby ${serverState.transparent ? 'lobby--transparent' : ''}`}
    >
      {!serverState.transparent && !!serverState.titleImageUrl && (
        <img className="bg" src={serverState.titleImageUrl} alt="" />
      )}

      {serverState.gamePhase === 'startup' ? (
        <BootTerminal
          messages={serverState.startupMessages}
          progressCurrent={serverState.progressCurrent}
          progressTotal={serverState.progressTotal}
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
    </div>
  );
}
