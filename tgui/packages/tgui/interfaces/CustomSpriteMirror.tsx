// THIS IS AN APHELION UI FILE
import { memo, useState } from 'react';
import { useBackend } from 'tgui/backend';
import { Window } from 'tgui/layouts';
import { Box, Button, Stack } from 'tgui-core/components';
import { Loader } from './common/Loader';

type Direction = '2' | '1' | '4' | '8';

export type CustomSpriteMirrorData = {
  mode: 'approval' | 'result';
  label: string;
  changes?: string[] | null;
  artistName?: string | null;
  restoration: boolean;
  token?: string | null;
  before?: Record<Direction, string> | null;
  after?: Record<Direction, string> | null;
  timeout?: number | null;
  canSave: boolean;
  saveState?: 'saved' | 'error' | null;
  saveMessage?: string | null;
  messageError?: boolean;
};

const directions: [Direction, string][] = [
  ['2', 'Front'],
  ['1', 'Back'],
  ['4', 'Right'],
  ['8', 'Left'],
];

export const CustomSpriteMirror = () => {
  const { act, data } = useBackend<CustomSpriteMirrorData>();
  const {
    mode,
    label,
    changes,
    artistName,
    restoration,
    token,
    before,
    after,
  } = data;
  const approval = mode === 'approval';

  return (
    <Window width={420} height={approval ? 580 : 240}>
      {approval && <Loader value={data.timeout ?? 0} />}
      <Window.Content>
        <Stack fill vertical>
          <Stack.Item>
            <Box bold>
              {approval
                ? restoration
                  ? `${artistName} offers to restore your previous ${label}.`
                  : `${artistName} finished a custom ${label} for you.`
                : `Your new ${label} is applied for this round.`}
            </Box>
            {approval && !!changes?.length && (
              <Box>{`This changes: ${changes.join(', ')}.`}</Box>
            )}
            {approval && (
              <Box color="label">
                Nothing changes unless you accept. Closing the mirror declines.
              </Box>
            )}
            {!!data.saveMessage && (
              <Box mt={1} color={data.messageError ? 'bad' : 'good'}>
                <div role={data.messageError ? 'alert' : 'status'}>
                  {data.saveMessage}
                </div>
              </Box>
            )}
          </Stack.Item>
          {approval && (
            <>
              <MirrorComparison before={before} after={after} />
              <Stack.Item>
                <Stack>
                  <Stack.Item grow>
                    <Button
                      fluid
                      textAlign="center"
                      color="bad"
                      onClick={() => act('decline')}
                    >
                      Decline
                    </Button>
                  </Stack.Item>
                  <Stack.Item grow>
                    <Button
                      fluid
                      textAlign="center"
                      icon="file-export"
                      tooltip="Download this design without applying it."
                      onClick={() => act('export', { token })}
                    >
                      Export
                    </Button>
                  </Stack.Item>
                </Stack>
              </Stack.Item>
              <Stack.Item>
                <Stack>
                  <Stack.Item grow>
                    <Button
                      fluid
                      textAlign="center"
                      color="good"
                      onClick={() => act('accept', { token })}
                    >
                      Accept for this round
                    </Button>
                  </Stack.Item>
                  <Stack.Item grow>
                    <Button
                      fluid
                      textAlign="center"
                      color="good"
                      tooltip="Apply and save for future rounds on this character. Your previous saved style is kept."
                      onClick={() => act('acceptPermanent', { token })}
                    >
                      Accept permanently
                    </Button>
                  </Stack.Item>
                </Stack>
              </Stack.Item>
            </>
          )}
          {!approval && (
            <>
              <Stack.Item grow color="label">
                Saving keeps it for future rounds on this character. The style
                it replaces is kept as your previous saved style.
              </Stack.Item>
              <Stack.Item>
                <Stack>
                  <Stack.Item grow>
                    <Button
                      fluid
                      textAlign="center"
                      onClick={() => act('close')}
                    >
                      Done
                    </Button>
                  </Stack.Item>
                  <Stack.Item grow>
                    <Button
                      fluid
                      textAlign="center"
                      color="good"
                      disabled={!data.canSave}
                      onClick={() => act('save')}
                    >
                      Save for future rounds
                    </Button>
                  </Stack.Item>
                </Stack>
              </Stack.Item>
            </>
          )}
        </Stack>
      </Window.Content>
    </Window>
  );
};

// Countdown updates do not need to rerender the comparison or reset its position.
const MirrorComparison = memo(function MirrorComparison({
  before,
  after,
}: Pick<CustomSpriteMirrorData, 'before' | 'after'>) {
  const [direction, setDirection] = useState<Direction>('2');
  const [split, setSplit] = useState(50);
  const view = directions.find(([dir]) => dir === direction)?.[1];

  return (
    <>
      <Stack.Item>
        <Stack>
          {directions.map(([dir, name]) => (
            <Stack.Item key={dir} grow>
              <Button
                fluid
                textAlign="center"
                selected={direction === dir}
                onClick={() => setDirection(dir)}
              >
                {name}
              </Button>
            </Stack.Item>
          ))}
        </Stack>
      </Stack.Item>
      <Stack.Item grow>
        <div className="CustomSpriteMirror__frame">
          <div className="CustomSpriteMirror__glass">
            <span className="CustomSpriteMirror__label CustomSpriteMirror__label--before">
              Before
            </span>
            <span className="CustomSpriteMirror__label CustomSpriteMirror__label--after">
              After
            </span>
            <div className="CustomSpriteMirror__comparison">
              <img
                className="CustomSpriteMirror__image"
                src={before?.[direction]}
                alt={`Before, ${view} view`}
                draggable={false}
                style={{ clipPath: `inset(0 ${100 - split}% 0 0)` }}
              />
              <img
                className="CustomSpriteMirror__image"
                src={after?.[direction]}
                alt={`After, ${view} view`}
                draggable={false}
                style={{ clipPath: `inset(0 0 0 ${split}%)` }}
              />
              <div
                className="CustomSpriteMirror__divider"
                style={{ left: `${split}%` }}
                aria-hidden="true"
              >
                <span>↔</span>
              </div>
              <input
                className="CustomSpriteMirror__slider"
                type="range"
                aria-label="Compare before and after"
                aria-valuetext={`${split}% before, ${100 - split}% after`}
                min={0}
                max={100}
                value={split}
                onChange={(event) =>
                  setSplit(Number(event.currentTarget.value))
                }
                onMouseDown={(event) => event.stopPropagation()}
              />
            </div>
            <span className="CustomSpriteMirror__hint">Drag to compare</span>
          </div>
        </div>
      </Stack.Item>
    </>
  );
});
