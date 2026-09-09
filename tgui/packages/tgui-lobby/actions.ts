// THIS IS AN APHELION UI FILE
/** Sends a lobby action to the server, matching /datum/lobby_menu/proc/on_message's "action" handling. */
export function sendAction(action: string, payload?: Record<string, unknown>) {
  Byond.sendMessage('action', { action, ...payload });
}
