// THIS IS AN APHELION UI FILE
import { useState } from 'react';
import { sendAct as act } from 'tgui/events/act';
import { Button, Dimmer, Input, Section, Stack } from 'tgui-core/components';
import type { BooleanLike } from 'tgui-core/react';

type NanopaintGalleryDialogProps = {
  /** The title the drawing starts with: its gallery title, when it came from one. */
  defaultTitle?: string;
  /** The character the artwork would be signed as. */
  signature?: string;
  /** How long a title the painting record accepts. */
  maxTitle?: number;
  /** The canvas size the drawing will be archived at. */
  size?: string;
  /** The outcome of a finished save, shown in place of the form. */
  message?: string;
  /** Set while the transaction runs. */
  busy?: BooleanLike;
};

export const NanopaintGalleryDialog = (props: NanopaintGalleryDialogProps) => {
  const { defaultTitle = '', signature, maxTitle, size, message, busy } = props;
  const [title, setTitle] = useState(defaultTitle);
  const [sign, setSign] = useState(true);

  return (
    <Dimmer>
      <Section
        title="Save to Art Galaxy"
        width="500px"
        className="MeridianControlDialog"
      >
        {message ? (
          <Stack vertical>
            <Stack.Item>{message}</Stack.Item>
            <Stack.Item>
              <Stack fill justify="end">
                <Stack.Item>
                  <Button onClick={() => act('closeDialog')}>OK</Button>
                </Stack.Item>
              </Stack>
            </Stack.Item>
          </Stack>
        ) : (
          <Stack vertical>
            <Stack.Item>
              Saved privately to My Artwork, at {size}. Publish it to the web
              gallery from Art Galaxy whenever you like.
            </Stack.Item>
            <Stack.Item>
              <Stack fill align="center" className="MeridianControlRow">
                <Stack.Item>Title</Stack.Item>
                <Stack.Item grow className="MeridianControlRow__fill">
                  <Input
                    fluid
                    value={title}
                    maxLength={maxTitle}
                    onChange={setTitle}
                  />
                </Stack.Item>
              </Stack>
            </Stack.Item>
            <Stack.Item>
              <Button.Checkbox
                checked={sign}
                disabled={!signature}
                onClick={() => setSign(!sign)}
              >
                {signature ? `Sign it as ${signature}` : 'Sign it'}
              </Button.Checkbox>
            </Stack.Item>
            <Stack.Item>
              <Stack fill justify="end">
                <Stack.Item>
                  <Button
                    disabled={!title.trim() || !!busy}
                    onClick={() => act('gallerySave', { title, sign })}
                  >
                    {busy ? 'Saving...' : 'Save'}
                  </Button>
                </Stack.Item>
                <Stack.Item>
                  <Button onClick={() => act('closeDialog')}>Cancel</Button>
                </Stack.Item>
              </Stack>
            </Stack.Item>
          </Stack>
        )}
      </Section>
    </Dimmer>
  );
};
