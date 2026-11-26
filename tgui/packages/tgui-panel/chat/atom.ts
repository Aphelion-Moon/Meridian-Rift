import { atom } from 'jotai';
import { createMainPage } from './model';

export const mainPage = createMainPage();

export const versionAtom = atom(5);
export const scrollTrackingAtom = atom(true);
export const chatPagesAtom = atom([mainPage.id]);
export const currentPageIdAtom = atom(mainPage.id);
export const chatPagesRecordAtom = atom({
  [mainPage.id]: mainPage,
});

/** Chat has been initialized from storage */
export const chatLoadedAtom = atom(false);
// APHELION EDIT ADDITION START - CHAT_SETTINGS
/**
 * Set once the saved chat is read. Until then chat isn't saved. If the read
 * fails, chat isn't saved for the rest of the session, so the defaults never
 * replace the player's saved tabs and history.
 */
export const chatReadAtom = atom(false);
// APHELION EDIT ADDITION END

export const allChatAtom = atom((get) => ({
  version: get(versionAtom),
  currentPageId: get(currentPageIdAtom),
  scrollTracking: get(scrollTrackingAtom),
  pages: get(chatPagesAtom),
  pageById: get(chatPagesRecordAtom),
}));

export const currentPageAtom = atom((get) => {
  const pageId = get(currentPageIdAtom);
  const pagesById = get(chatPagesRecordAtom);
  return pagesById[pageId];
});
