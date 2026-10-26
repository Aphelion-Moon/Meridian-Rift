// THIS IS AN APHELION UI FILE
import {
  Box,
  Button,
  Image,
  Input,
  NoticeBox,
  Section,
  Stack,
  Tabs,
  VirtualList,
} from 'tgui-core/components';
import type { BooleanLike } from 'tgui-core/react';

import { useBackend } from '../../backend';
import { NtosWindow } from '../../layouts';

type Painting = {
  title: string;
  creator: string;
  image: string;
  ref: string;
  creation_date?: string | null;
  medium?: string | null;
  show_in_webgallery?: BooleanLike;
  framed_count?: number;
  in_rotation?: BooleanLike;
};

type Data = {
  paintings: Painting[];
  selected_painting: Painting | null;
  gallery_tab: 'browse' | 'mine';
  gallery_page: number;
  gallery_pages: number;
  painting_count: number;
  painting_index: number;
  search_string: string | null;
  search_mode: string;
  is_console: BooleanLike;
  gallery_writable: BooleanLike;
  gallery_busy: BooleanLike;
  gallery_error: string | null;
  import_enabled: BooleanLike;
  import_busy: BooleanLike;
  can_retry_import: BooleanLike;
  import_status: string | null;
};

/** Render Art Galaxy tabs and shared storage status using the authenticated viewer's server state. */
export const NtosPortraitPrinter = () => {
  const { act, data } = useBackend<Data>();
  const { gallery_tab: tab, gallery_error, gallery_busy } = data;

  return (
    <NtosWindow title="Art Galaxy" width={400} height={520}>
      <NtosWindow.Content>
        <Stack vertical fill>
          <Stack.Item>
            <Tabs fluid>
              <Tabs.Tab
                selected={tab === 'browse'}
                onClick={() => act('gallery_tab', { tab: 'browse' })}
              >
                Browse
              </Tabs.Tab>
              <Tabs.Tab
                selected={tab === 'mine'}
                onClick={() => act('gallery_tab', { tab: 'mine' })}
              >
                My Artwork
              </Tabs.Tab>
            </Tabs>
          </Stack.Item>
          {!!gallery_error && (
            <Stack.Item>
              <NoticeBox danger>{gallery_error}</NoticeBox>
            </Stack.Item>
          )}
          {!!gallery_busy && (
            <Stack.Item>
              <NoticeBox info>Saving gallery changes...</NoticeBox>
            </Stack.Item>
          )}
          <Gallery key={tab} owned={tab === 'mine'} />
        </Stack>
      </NtosWindow.Content>
    </NtosWindow>
  );
};

/** Display a bounded thumbnail page or a fitted painting detail view with collection navigation. */
const Gallery = ({ owned }: { owned: boolean }) => {
  const { act, data } = useBackend<Data>();
  const {
    search_string,
    search_mode,
    is_console,
    paintings = [],
    selected_painting: painting,
    painting_index: index,
    painting_count: total,
    gallery_page: page,
    gallery_pages: pages,
  } = data;
  /** Request a zero-based selection within the current server-authorized collection. */
  const select = (nextIndex: number) =>
    act('gallery_select', { index: nextIndex });

  return painting ? (
    <>
      <Stack.Item>
        <Button icon="arrow-left" onClick={() => act('gallery_back')}>
          Back to thumbnails
        </Button>
      </Stack.Item>
      <Stack.Item grow minHeight={0} position="relative">
        <Image
          src={painting.image}
          {...{ alt: painting.title || 'Untitled artwork' }}
          position="absolute"
          width="100%"
          height="100%"
          objectFit="contain"
        />
      </Stack.Item>
      <Stack.Item>
        <Section textAlign="center">
          <Box
            bold
            {...{ title: painting.title }}
            style={{
              overflowWrap: 'anywhere',
              display: '-webkit-box',
              WebkitBoxOrient: 'vertical',
              WebkitLineClamp: 2,
              overflow: 'hidden',
            }}
          >
            {painting.title || 'Untitled artwork'}
          </Box>
          <Box
            {...{ title: painting.creator }}
            style={{
              whiteSpace: 'nowrap',
              overflow: 'hidden',
              textOverflow: 'ellipsis',
            }}
          >
            By {painting.creator}
          </Box>
          {owned && (
            <>
              <Box color="label">
                {painting.creation_date || 'Date not recorded'}
                {' · '}
                {painting.medium || 'Medium not recorded'}
              </Box>
              <VisibilityCheckbox painting={painting} />
            </>
          )}
          <Stack mt={1} justify="center">
            {owned && (
              <Stack.Item>
                <Button
                  icon="trash"
                  color="bad"
                  disabled={
                    !data.gallery_writable ||
                    !!data.gallery_busy ||
                    !!data.import_busy
                  }
                  onClick={() =>
                    act('delete_painting', { selected: painting.ref })
                  }
                >
                  Delete
                </Button>
              </Stack.Item>
            )}
            {!!is_console && (
              <Stack.Item>
                <Button
                  icon="print"
                  onClick={() => act('print', { selected: painting.ref })}
                >
                  Print Portrait
                </Button>
              </Stack.Item>
            )}
            <Stack.Item>
              <Button
                icon="download"
                onClick={() => act('download', { selected: painting.ref })}
              >
                Download
              </Button>
            </Stack.Item>
          </Stack>
          <Stack mt={1} align="center" justify="space-between">
            <Stack.Item>
              <Button
                icon="angle-double-left"
                aria-label="First painting"
                disabled={index === 0}
                onClick={() => select(0)}
              />
              <Button
                icon="chevron-left"
                aria-label="Previous painting"
                disabled={index === 0}
                onClick={() => select(index - 1)}
              />
            </Stack.Item>
            <Stack.Item color="label">
              {index + 1} / {total}
            </Stack.Item>
            <Stack.Item>
              <Button
                icon="chevron-right"
                aria-label="Next painting"
                disabled={index === total - 1}
                onClick={() => select(index + 1)}
              />
              <Button
                icon="angle-double-right"
                aria-label="Last painting"
                disabled={index === total - 1}
                onClick={() => select(total - 1)}
              />
            </Stack.Item>
          </Stack>
          {!!is_console && (
            <Box mt={1} color="label">
              Printing costs 10 paper from this machine.
            </Box>
          )}
        </Section>
      </Stack.Item>
    </>
  ) : (
    <>
      <Stack.Item>
        {owned ? (
          <MyArtworkNotice />
        ) : (
          <Section title="Search">
            <Stack>
              <Stack.Item grow>
                <Input
                  fluid
                  placeholder="Search Paintings..."
                  value={search_string ?? ''}
                  onBlur={(value) => act('search', { to_search: value })}
                />
              </Stack.Item>
              <Stack.Item>
                <Button onClick={() => act('change_search_mode')}>
                  {search_mode}
                </Button>
              </Stack.Item>
            </Stack>
          </Section>
        )}
      </Stack.Item>
      <Stack.Item grow minHeight={0}>
        <Section
          fill
          scrollable
          title={`${owned ? 'My Artwork' : 'Paintings'} (${total})`}
        >
          {paintings.length ? (
            <VirtualList
              key={`${page}:${search_string}:${search_mode}:${paintings.length}`}
            >
              {paintings.map((entry) => (
                <Box key={entry.ref} mb={1}>
                  <Button
                    fluid
                    color="transparent"
                    textAlign="left"
                    p={1}
                    {...{ role: 'button' }}
                    aria-label={`View ${entry.title || 'Untitled artwork'}`}
                    onClick={() =>
                      act('gallery_select', { selected: entry.ref })
                    }
                  >
                    <Stack align="center">
                      <Stack.Item>
                        <Image
                          src={entry.image}
                          {...{ alt: '' }}
                          width="64px"
                          height="64px"
                          objectFit="contain"
                        />
                      </Stack.Item>
                      <Stack.Item
                        grow
                        minWidth={0}
                        style={{
                          whiteSpace: 'normal',
                          overflowWrap: 'anywhere',
                          lineHeight: 1.4,
                        }}
                      >
                        <Box bold>{entry.title || 'Untitled artwork'}</Box>
                        <Box color="label">By {entry.creator}</Box>
                      </Stack.Item>
                    </Stack>
                  </Button>
                  {owned && <VisibilityCheckbox painting={entry} />}
                </Box>
              ))}
            </VirtualList>
          ) : (
            <Box color="label">
              {owned
                ? 'No saved paintings belong to your account.'
                : 'No paintings found.'}
            </Box>
          )}
        </Section>
      </Stack.Item>
      {pages > 1 && (
        <Stack.Item>
          <Stack align="center" justify="space-between">
            <Stack.Item>
              <Button
                icon="chevron-left"
                disabled={page === 1}
                onClick={() => act('gallery_page', { page: page - 1 })}
              >
                Previous page
              </Button>
            </Stack.Item>
            <Stack.Item color="label">
              {page} / {pages}
            </Stack.Item>
            <Stack.Item>
              <Button
                icon="chevron-right"
                iconPosition="right"
                disabled={page === pages}
                onClick={() => act('gallery_page', { page: page + 1 })}
              >
                Next page
              </Button>
            </Stack.Item>
          </Stack>
        </Stack.Item>
      )}
    </>
  );
};

/** Show frame and rotation status alongside the per-painting website consent control. */
const VisibilityCheckbox = ({ painting }: { painting: Painting }) => {
  const { act, data } = useBackend<Data>();
  const disabled =
    !data.gallery_writable || !!data.gallery_busy || !!data.import_busy;

  return (
    <>
      <Box color="label" mt={1}>
        {painting.framed_count
          ? `Displayed in ${painting.framed_count} frame(s)`
          : 'Not currently framed'}
        {' · '}
        {painting.in_rotation
          ? 'In station rotation'
          : 'Not in station rotation'}
      </Box>
      <Button.Checkbox
        fluid
        mt={1}
        {...{ role: 'checkbox' }}
        aria-checked={!!painting.show_in_webgallery}
        aria-disabled={disabled}
        checked={!!painting.show_in_webgallery}
        disabled={disabled}
        onClick={() =>
          act('set_webgallery', {
            selected: painting.ref,
            enabled: painting.show_in_webgallery ? 0 : 1,
          })
        }
      >
        Show on public web gallery
      </Button.Checkbox>
    </>
  );
};

/** Explain personal saves and publication delay, and expose confirmed Nova import retries. */
const MyArtworkNotice = () => {
  const { act, data } = useBackend<Data>();
  const {
    gallery_writable,
    gallery_busy,
    import_enabled,
    import_busy,
    can_retry_import,
    import_status,
  } = data;

  return (
    <>
      <NoticeBox info>
        Finished paintings save here automatically. Check a painting to share it
        on the web gallery with its original signature. Web gallery changes may
        take up to 30 minutes. An archive-enabled frame adds it to the station
        rotation.
      </NoticeBox>
      {!!import_enabled && (
        <>
          {!!(import_status || import_busy) && (
            <NoticeBox info>
              {import_status || 'Nova painting import is in progress...'}
            </NoticeBox>
          )}
          {!!can_retry_import && (
            <Button
              icon="redo"
              fluid
              disabled={!gallery_writable || !!gallery_busy || !!import_busy}
              onClick={() => act('retry_nova_import')}
            >
              Retry Nova Import
            </Button>
          )}
        </>
      )}
    </>
  );
};
