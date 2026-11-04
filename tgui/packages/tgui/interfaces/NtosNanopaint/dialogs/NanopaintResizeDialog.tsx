// THIS IS AN APHELION UI FILE
import { useState } from 'react';
import { sendAct as act } from 'tgui/events/act';
import {
  Box,
  Button,
  Dimmer,
  Floating,
  LabeledList,
  NumberInput,
  Section,
  Stack,
} from 'tgui-core/components';

type NanopaintResizeDialogProps = {
  /** The size the drawing has now. */
  width: number;
  height: number;
  minSize: number;
  maxSize: number;
  templateSizes: Record<string, [number, number]>;
};

/** Which edges the drawing keeps when the canvas grows or shrinks, as -1, 0 or 1 per axis. */
const ANCHORS = [-1, 0, 1];

export const NanopaintResizeDialog = (props: NanopaintResizeDialogProps) => {
  const {
    width: currentWidth,
    height: currentHeight,
    minSize,
    maxSize,
    templateSizes,
  } = props;
  const [width, setWidth] = useState(currentWidth);
  const [height, setHeight] = useState(currentHeight);
  const [anchorX, setAnchorX] = useState(0);
  const [anchorY, setAnchorY] = useState(0);
  const [templatesOpen, setTemplatesOpen] = useState(false);
  const loses = width < currentWidth || height < currentHeight;

  return (
    <Dimmer>
      <Section title="Canvas Size" className="MeridianControlDialog">
        <Stack vertical>
          <Stack.Item>
            Now {currentWidth}x{currentHeight}. Your drawing keeps its pixels;
            the canvas grows or is cut around it.
          </Stack.Item>
          <Stack.Item>
            <LabeledList>
              <LabeledList.Item label="Width">
                <NumberInput
                  value={width}
                  minValue={minSize}
                  maxValue={maxSize}
                  step={1}
                  onChange={(v) => setWidth(Math.round(v))}
                />
              </LabeledList.Item>
              <LabeledList.Item label="Height">
                <NumberInput
                  value={height}
                  minValue={minSize}
                  maxValue={maxSize}
                  step={1}
                  onChange={(v) => setHeight(Math.round(v))}
                />
              </LabeledList.Item>
              <LabeledList.Item label="Keep it">
                <Stack vertical>
                  {ANCHORS.map((y) => (
                    <Stack.Item key={y}>
                      <Stack>
                        {ANCHORS.map((x) => (
                          <Stack.Item key={x}>
                            <Button
                              icon="square"
                              selected={anchorX === x && anchorY === y}
                              tooltip={`${y < 0 ? 'top' : y > 0 ? 'bottom' : 'middle'} ${x < 0 ? 'left' : x > 0 ? 'right' : 'centre'}`}
                              onClick={() => {
                                setAnchorX(x);
                                setAnchorY(y);
                              }}
                            />
                          </Stack.Item>
                        ))}
                      </Stack>
                    </Stack.Item>
                  ))}
                </Stack>
              </LabeledList.Item>
            </LabeledList>
          </Stack.Item>
          <Stack.Item>
            <Floating
              handleOpen={templatesOpen}
              disabled
              placement="right"
              preventPortal
              content={
                <Box maxHeight="75%" overflowY="scroll">
                  {Object.entries(templateSizes).map(
                    ([name, [templateWidth, templateHeight]]) => (
                      <Button
                        className="NtosNanopaint__NewDialog__TemplateCell"
                        key={name}
                        width="100%"
                        onClick={() => {
                          setWidth(templateWidth);
                          setHeight(templateHeight);
                        }}
                      >
                        <Stack align="center" justify="space-between">
                          <Stack.Item fontSize="24px">{name}</Stack.Item>
                          <Stack.Item>
                            <Box
                              className="NtosNanopaint__NewDialog__TemplatePreview"
                              width={`${templateWidth * 3}px`}
                              height={`${templateHeight * 3}px`}
                            />
                          </Stack.Item>
                        </Stack>
                      </Button>
                    ),
                  )}
                </Box>
              }
            >
              <Button
                icon={templatesOpen ? 'chevron-left' : 'chevron-right'}
                iconPosition="right"
                onClick={() => setTemplatesOpen(!templatesOpen)}
              >
                Canvas Sizes
              </Button>
            </Floating>
          </Stack.Item>
          <Stack.Item color={loses ? 'average' : 'label'}>
            {loses
              ? 'Anything outside the smaller canvas is cut away. Undo history is cleared either way.'
              : 'Undo history is cleared by a resize.'}
          </Stack.Item>
          <Stack.Item>
            <Stack fill justify="end">
              <Stack.Item>
                <Button
                  disabled={width === currentWidth && height === currentHeight}
                  onClick={() =>
                    act('resize', { width, height, anchorX, anchorY })
                  }
                >
                  Resize
                </Button>
              </Stack.Item>
              <Stack.Item>
                <Button onClick={() => act('closeDialog')}>Cancel</Button>
              </Stack.Item>
            </Stack>
          </Stack.Item>
        </Stack>
      </Section>
    </Dimmer>
  );
};
