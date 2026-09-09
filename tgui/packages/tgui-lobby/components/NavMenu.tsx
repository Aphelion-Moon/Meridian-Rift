// THIS IS AN APHELION UI FILE
import type { MouseEvent } from 'react';
import { sendAction } from '../actions';
import type { ServerState } from '../LobbyMenu';
import { MenuButton } from './MenuButton';
import { StationTraitList } from './StationTraitList';

/** The .container_nav button list */
export function NavMenu({
  serverState,
  assetMap,
}: {
  serverState: ServerState;
  assetMap: Record<string, string>;
}) {
  return (
    <div className="container_nav">
      {!!serverState.canReady && (
        <MenuButton onClick={() => sendAction('ready_toggle')}>
          {serverState.isReady ? (
            <>
              <span className="checked">☑</span> READY
            </>
          ) : (
            <>
              <span className="unchecked">☒</span> READY
            </>
          )}
        </MenuButton>
      )}

      {!!serverState.canJoin && (
        <>
          <MenuButton
            onClick={(event: MouseEvent) =>
              sendAction('join', { ctrlClick: event.ctrlKey })
            }
          >
            JOIN GAME
          </MenuButton>
          <MenuButton onClick={() => sendAction('crew_manifest')}>
            CREW MANIFEST
          </MenuButton>
          <MenuButton onClick={() => sendAction('view_directory')}>
            CHARACTER DIRECTORY
          </MenuButton>
        </>
      )}

      <MenuButton onClick={() => sendAction('observe')}>OBSERVE</MenuButton>

      <hr />

      <MenuButton
        disabled={!serverState.assetsReady}
        onClick={() => sendAction('character_setup')}
      >
        SETUP CHARACTER (
        <span id="character_slot">{serverState.characterName}</span>)
      </MenuButton>
      <MenuButton
        disabled={!serverState.assetsReady}
        onClick={() => sendAction('settings')}
      >
        GAME OPTIONS
      </MenuButton>
      <MenuButton onClick={() => sendAction('toggle_antag')}>
        {serverState.isAntag ? (
          <>
            <span className="checked">☑</span> BE ANTAGONIST
          </>
        ) : (
          <>
            <span className="unchecked">☒</span> BE ANTAGONIST
          </>
        )}
      </MenuButton>
      <MenuButton disabled>
        LATEJOIN QUEUE: {serverState.latejoinQueue}
      </MenuButton>

      <hr />

      {!!serverState.canSwapServers && (
        <MenuButton onClick={() => sendAction('server_swap')}>
          SWAP SERVERS
        </MenuButton>
      )}

      {!!serverState.canPoll && (
        <MenuButton
          newPoll={serverState.hasNewPoll}
          onClick={() => sendAction('poll')}
        >
          {serverState.hasNewPoll ? 'POLLS (NEW)' : 'POLLS'}
        </MenuButton>
      )}

      <hr />

      <MenuButton onClick={() => sendAction('changelog')}>CHANGELOG</MenuButton>

      {!!serverState.isLocalhost &&
        (serverState.gamePhase === 'startup' ||
          serverState.gamePhase === 'pregame') && (
          <MenuButton onClick={() => sendAction('start_now')}>
            START NOW
          </MenuButton>
        )}

      {!!serverState.stationTraits.length && <hr />}
      <StationTraitList traits={serverState.stationTraits} assetMap={assetMap} />

      {!!serverState.traitFeedback && (
        <div className="trait_feedback">{serverState.traitFeedback}</div>
      )}
    </div>
  );
}
