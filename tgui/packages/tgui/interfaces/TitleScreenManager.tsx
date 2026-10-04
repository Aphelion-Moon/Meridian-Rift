// THIS IS AN APHELION UI FILE
import {
  Button,
  Divider,
  LabeledList,
  NoticeBox,
  Section,
  Stack,
  Tabs,
} from 'tgui-core/components';
import type { BooleanLike } from 'tgui-core/react';

import { loadedMappings } from '../assets';
import { useBackend } from '../backend';
import { Window } from '../layouts';
import {
  type LobbyTitleArtVariant,
  type LobbyTitleBezel,
  type LobbyTitleTexture,
  type LobbyTitleTreatment,
  resolveLobbyScreenPresentation,
  resolveLobbyTitleBezel,
  TitleArtwork,
} from './common/TitleArtwork';

type ScreenOption = {
  /** Config file name, or null for the neutral Meridian Rift master. */
  name: string | null;
  isDefault: BooleanLike;
  isAlt: BooleanLike;
  url: string | null;
  variant: LobbyTitleArtVariant;
  bezel: LobbyTitleBezel | BooleanLike;
  texture: LobbyTitleTexture;
  wordmark: BooleanLike;
};

type Choice = { id: string; name: string; desc: string };

type Data = {
  screens: ScreenOption[];
  markUrl: string | null;
  variants: Choice[];
  bezels: Choice[];
  textures: Choice[];
  liveScreen: string | null;
  liveScreenManaged: BooleanLike;
  rotateTitleScreens: BooleanLike;
  draftScreen: string | null;
  draftScreenChosen: BooleanLike;
  draftVariant: LobbyTitleArtVariant;
  draftBezel: LobbyTitleBezel | BooleanLike;
  draftTexture: LobbyTitleTexture;
  draftWordmark: BooleanLike;
  pending: BooleanLike;
};

const DEFAULT_SCREEN_LABEL = 'Meridian Rift (default)';
const ALT_SCREEN_LABEL = 'Meridian Rift (default, alt)';
const DEFAULT_SCREEN_KEY = '__default__';
const SCANLINE_ASSET = 'meridian_rift_scanlines_classic.png';

/** Strips the extension so a long file name still fits the row. */
function screenLabel(screen: ScreenOption): string {
  if (screen.isAlt) {
    return ALT_SCREEN_LABEL;
  }
  if (screen.isDefault || screen.name === null) {
    return DEFAULT_SCREEN_LABEL;
  }
  return screen.name.replace(/\.[a-z0-9]+$/i, '');
}

export function TitleScreenManager() {
  const { act, data } = useBackend<Data>();
  const {
    screens = [],
    variants = [],
    bezels = [],
    textures = [],
    markUrl,
    draftScreen,
    liveScreen,
  } = data;

  const selected = data.draftScreenChosen
    ? screens.find((screen) => screen.name === draftScreen)
    : undefined;
  const isDefaultScreen = !!(selected?.isDefault || selected?.name === null);
  const treatment: LobbyTitleTreatment = isDefaultScreen
    ? 'mask'
    : data.draftWordmark
      ? 'overlay'
      : 'screen';
  const draftBezel = resolveLobbyTitleBezel(data.draftBezel);

  return (
    <Window title="Change Lobby Title Screen" width={880} height={640}>
      <Window.Content>
        <Stack fill>
          <Stack.Item basis="19rem">
            <Section fill scrollable title="Title Screens">
              <Tabs vertical>
                {screens.map((screen) => (
                  <Tabs.Tab
                    key={screen.name ?? DEFAULT_SCREEN_KEY}
                    icon={
                      data.liveScreenManaged && screen.name === liveScreen
                        ? 'circle-check'
                        : undefined
                    }
                    selected={
                      !!data.draftScreenChosen && screen.name === draftScreen
                    }
                    onClick={() => act('select', { screen: screen.name ?? '' })}
                  >
                    {screenLabel(screen)}
                  </Tabs.Tab>
                ))}
              </Tabs>
            </Section>
          </Stack.Item>

          <Stack.Item grow>
            <Stack fill vertical>
              <Stack.Item grow>
                <Section fill title="Preview">
                  {!data.draftScreenChosen ? (
                    <NoticeBox info>
                      No editable title screen is selected. Choose a configured
                      title screen to preview or edit it.
                    </NoticeBox>
                  ) : selected?.url ? (
                    <div className="TitleScreenManager__preview">
                      <TitleArtwork
                        bezel={draftBezel}
                        markSrc={markUrl ?? undefined}
                        presentation={resolveLobbyScreenPresentation(
                          treatment,
                          !!selected.isAlt,
                        )}
                        src={selected.url}
                        texture={data.draftTexture}
                        textureSrc={loadedMappings[SCANLINE_ASSET]}
                        treatment={treatment}
                        variant={data.draftVariant}
                      />
                    </div>
                  ) : (
                    <NoticeBox>
                      This screen is no longer in the config directory.
                    </NoticeBox>
                  )}
                </Section>
              </Stack.Item>

              <Stack.Item>
                <Section title="Appearance">
                  {!data.draftScreenChosen ? (
                    <NoticeBox info>
                      Choose a configured title screen to edit its appearance.
                    </NoticeBox>
                  ) : (
                    <>
                      <LabeledList>
                        {[
                          {
                            label: 'Screen',
                            key: 'variant',
                            choices: variants,
                            value: data.draftVariant,
                          },
                          {
                            label: 'Scanlines',
                            key: 'texture',
                            choices: textures,
                            value: data.draftTexture,
                          },
                          {
                            label: 'Bezel',
                            key: 'bezel',
                            choices: bezels,
                            value: draftBezel,
                          },
                        ].map(({ label, key, choices, value }) => (
                          <LabeledList.Item key={key} label={label}>
                            {choices.map((choice) => (
                              <Button
                                aria-pressed={value === choice.id}
                                key={choice.id}
                                {...{ role: 'button' }}
                                selected={value === choice.id}
                                tooltip={choice.desc}
                                onClick={() => act('set', { [key]: choice.id })}
                              >
                                {choice.name}
                              </Button>
                            ))}
                          </LabeledList.Item>
                        ))}
                      </LabeledList>
                      {!isDefaultScreen && (
                        <Button.Checkbox
                          checked={!!data.draftWordmark}
                          mt={0.5}
                          onClick={() =>
                            act('set', { wordmark: !data.draftWordmark })
                          }
                        >
                          Display MERIDIAN RIFT
                        </Button.Checkbox>
                      )}
                    </>
                  )}

                  <Divider />

                  <Stack align="center">
                    <Stack.Item grow>
                      <Button.Checkbox
                        checked={!!data.rotateTitleScreens}
                        tooltip="Saves immediately without changing the current screen draft"
                        onClick={() =>
                          act('set_rotation', {
                            rotate: !data.rotateTitleScreens,
                          })
                        }
                      >
                        Rotate title screens each round
                      </Button.Checkbox>
                    </Stack.Item>
                    <Stack.Item>
                      <Button
                        disabled={!data.pending}
                        icon="rotate-left"
                        tooltip="Discard the draft and re-read what is live"
                        onClick={() => act('revert')}
                      >
                        Revert
                      </Button>
                    </Stack.Item>
                    <Stack.Item>
                      <Button
                        color="good"
                        disabled={!data.pending}
                        icon="check"
                        tooltip="Applies to everyone and persists across rounds"
                        onClick={() => act('apply')}
                      >
                        Apply for everyone
                      </Button>
                    </Stack.Item>
                  </Stack>
                </Section>
              </Stack.Item>
            </Stack>
          </Stack.Item>
        </Stack>
      </Window.Content>
    </Window>
  );
}
