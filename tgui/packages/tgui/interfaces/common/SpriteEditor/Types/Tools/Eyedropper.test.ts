// THIS IS AN APHELION UI FILE
import { expect, it, mock } from 'bun:test';
import { parseHexColorString } from '../../colorSpaces';
import { Dir, type SpriteData, type SpriteEditorToolContext } from '../types';
import { Eyedropper } from './Eyedropper';

const fixture = (pixel: string, backdrop = '#887766') => {
  const data: SpriteData = {
    width: 2,
    height: 1,
    dirs: 1,
    backdrop,
    layers: [
      {
        name: 'Paint',
        visible: true,
        data: {
          [Dir.SOUTH]: [[pixel, pixel]],
          [Dir.NORTH]: undefined,
          [Dir.EAST]: undefined,
          [Dir.WEST]: undefined,
        },
      },
    ],
  };
  const context: SpriteEditorToolContext = {
    currentColor: { r: 255, g: 255, b: 255 },
    selectedDir: Dir.SOUTH,
    selectedLayer: 0,
    setCurrentColor: mock(),
    setPreviewLayer: mock(),
    setPreviewData: mock(),
    onSampleBackdrop: mock(),
  };
  return { data, context, tool: new Eyedropper() };
};

it('prefers painted pixels, including partial opacity, over the guide', () => {
  const { data, context, tool } = fixture('#ff804080');
  tool.onMouseDown(context, data, 0, 0);
  expect(context.setCurrentColor).toHaveBeenCalledWith(
    parseHexColorString('#ff804080'),
  );
  expect(context.onSampleBackdrop).not.toHaveBeenCalled();
});

it('samples the guide only for a transparent painted pixel using image coordinates', () => {
  const { data, context, tool } = fixture('#00000000');
  tool.onMouseDown(context, data, 1.8, 0.5);
  expect(context.onSampleBackdrop).toHaveBeenCalledWith(1, 0);
  expect(context.setCurrentColor).not.toHaveBeenCalled();
});

it('uses the flat backdrop when no guide sampler is provided', () => {
  const { data, context, tool } = fixture('#00000000');
  delete context.onSampleBackdrop;
  tool.onMouseDown(context, data, 0, 0);
  expect(context.setCurrentColor).toHaveBeenCalledWith(
    parseHexColorString('#887766'),
  );
});

it('preserves transparent sampling in general editors without a backdrop', () => {
  const { data, context, tool } = fixture('#00000000', '');
  delete context.onSampleBackdrop;
  tool.onMouseDown(context, data, 0, 0);
  expect(context.setCurrentColor).toHaveBeenCalledWith(
    parseHexColorString('#00000000'),
  );
});

it('ignores right clicks and points outside the image', () => {
  const { data, context, tool } = fixture('#00000000');
  tool.onMouseDown(context, data, 0, 0, true);
  tool.onMouseDown(context, data, -0.1, 0);
  tool.onMouseDown(context, data, 2, 0);
  tool.onMouseDown(context, data, 0, 1);
  expect(context.onSampleBackdrop).not.toHaveBeenCalled();
  expect(context.setCurrentColor).not.toHaveBeenCalled();
});
