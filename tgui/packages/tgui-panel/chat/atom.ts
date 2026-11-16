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
 * Set once the stored chat has been read. Chat isn't saved before that, or for
 * the rest of a session whose read failed, so its tabs and history are never
 * saved over with defaults.
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
