const ByondMock = {
  windowId: 'test-window',
  IS_BYOND: true,
  POST_MESSAGE: true, // APHELION EDIT ADDITION - BUG_REPORTING - BYOND_POST_MESSAGE
  BLINK: true,
  strictMode: true,
  storageCdn: '',

  call: () => ({}),
  callAsync: async () => ({}),
  topic: () => {},
  command: () => {},

  winget: async () => ({}),
  winset: () => {},

  parseJson: (text: string) => JSON.parse(text),

  sendMessage: () => {},
  subscribe: () => {},
  subscribeTo: () => {},

  loadCss: () => {},
  loadJs: () => {},

  iconRefMap: {},
  saveBlob: () => {},
};

// @ts-expect-error
globalThis.Byond = ByondMock;
