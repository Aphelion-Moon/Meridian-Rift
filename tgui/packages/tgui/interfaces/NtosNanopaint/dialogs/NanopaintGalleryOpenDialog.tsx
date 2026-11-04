// THIS IS AN APHELION UI FILE
import { useState } from 'react';
import { sendAct as act } from 'tgui/events/act';
import { Button, Dimmer, Section, Stack } from 'tgui-core/components';
import type { NanopaintGalleryEntry } from '../types';

type NanopaintGalleryOpenDialogProps = {
  /** The artist's own archived paintings; absent until the server answers. */
  galleryFiles?: NanopaintGalleryEntry[];
};

export const NanopaintGalleryOpenDialog = (
  props: NanopaintGalleryOpenDialogProps,
) => {
  const { galleryFiles } = props;
  const [selected, setSelected] = useState<string | null>(null);
  const entries = galleryFiles ?? [];

  return (
    <Dimmer>
      <Section
        title="Open from Art Galaxy"
        width="500px"
        className="MeridianControlDialog"
      >
        <Stack vertical>
          <Stack.Item>
            <Stack
              fill
              height="300px"
              className="MeridianControlRow MeridianControlRow--top"
            >
              <Stack.Item width="100%" className="MeridianControlRow__fill">
                <Stack vertical overflowY="scroll">
                  {entries.length === 0 ? (
                    <Stack.Item color="label">
                      {galleryFiles
                        ? 'Nothing of yours is saved to Art Galaxy yet.'
                        : 'Reading your collection...'}
                    </Stack.Item>
                  ) : (
                    entries.map((entry) => (
                      <Stack.Item key={entry.ref}>
                        <Button
                          width="100%"
                          ellipsis
                          tooltip={`${entry.name} (${entry.size})`}
                          selected={selected === entry.ref}
                          className="NtosNanopaint__SelectDialog__EntryCell"
                          onClick={() => setSelected(entry.ref)}
                        >
                          {`${entry.name} (${entry.size})`}
                        </Button>
                      </Stack.Item>
                    ))
                  )}
                </Stack>
              </Stack.Item>
            </Stack>
          </Stack.Item>
          <Stack.Item>
            Opening a painting starts a new drawing from it. Saving your changes
            back to Art Galaxy archives them as a new painting of its own.
          </Stack.Item>
          <Stack.Item>
            <Stack fill justify="end">
              <Stack.Item>
                <Button
                  disabled={!selected}
                  onClick={() => act('galleryOpen', { ref: selected })}
                >
                  Open
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
