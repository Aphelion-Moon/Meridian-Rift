// THIS IS AN APHELION UI FILE
import { sendAction } from '../actions';
import { MenuButton } from './MenuButton';

/**
 * Replaces the nav menu when the Discord whitelist gate won't let this player into the round.
 * The gate fails closed, so "we couldn't check" and "we checked, and no" both end up here - they
 * get different copy, because telling someone they aren't whitelisted when the database is simply
 * down sends them off to re-link an account that was never the problem.
 */
export function WhitelistGate({
  state,
  canSwapServers,
}: {
  state: 'blocked' | 'checking' | 'unavailable';
  canSwapServers: boolean;
}) {
  return (
    <div className="container_nav container_nav--centered">
      {state === 'checking' ? (
        <p className="menu_notice menu_notice--centered menu_notice--muted">
          CHECKING WHITELIST...
        </p>
      ) : state === 'unavailable' ? (
        <p className="menu_notice menu_notice--centered">
          Whitelist database unreachable.
          <br />
          This is a problem on our end, not your account.
        </p>
      ) : (
        <>
          <p className="menu_notice menu_notice--centered">
            You must be whitelisted to play.
            <br />
            Link your Discord to continue.
          </p>
          <MenuButton
            className="menu_button--centered"
            onClick={() => sendAction('get_whitelisted')}
          >
            GET WHITELISTED
          </MenuButton>
        </>
      )}
      {!!canSwapServers && (
        <MenuButton
          className="menu_button--centered"
          onClick={() => sendAction('server_swap')}
        >
          SWAP SERVERS
        </MenuButton>
      )}
    </div>
  );
}
