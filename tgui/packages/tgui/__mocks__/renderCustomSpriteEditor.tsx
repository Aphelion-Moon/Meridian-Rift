// THIS IS AN APHELION UI FILE
// Test rendering stays outside interfaces/ so it cannot enter the interface bundle.
import { render } from '@testing-library/react';
import { createStore, Provider } from 'jotai';
import type { ComponentProps, ReactNode } from 'react';
import { CustomSpriteEditor } from '../interfaces/common/CustomSpriteEditor';

/** Renders an editor with its own atoms, retaining the same store for rerenders or reopening. */
export const renderEditor = (
  target: ComponentProps<typeof CustomSpriteEditor>['target'] = 'hair',
  options: {
    store?: ReturnType<typeof createStore>;
    children?: ReactNode;
  } = {},
) => {
  const store = options.store ?? createStore();
  const editor = () => (
    <Provider store={store}>
      <CustomSpriteEditor target={target} />
      {options.children}
    </Provider>
  );
  return { store, editor, view: render(editor()) };
};
