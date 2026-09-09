import { useState } from 'react';
import {
  Box,
  Button,
  ColorBox,
  Dropdown,
  Icon,
  Input,
  NoticeBox,
  Section,
  Stack,
} from 'tgui-core/components';
import type { BooleanLike } from 'tgui-core/react';

import { useBackend } from '../backend';
import { Window } from '../layouts';
import {
  BRIGHTNESS_LEVELS,
  LampColorSwatches,
  LAMP_COLORS,
} from './CondoShared';

type Invited = { ckey: string; name: string };

type Data = {
  name: string;
  private: BooleanLike;
  has_password: BooleanLike;
  brightness: number;
  lamp_color: string;
  ambience: string;
  ambiences: string[];
  invited: Invited[];
};

export function CondoManage() {
  const { act, data } = useBackend<Data>();
  const {
    name,
    private: isPrivate,
    has_password,
    brightness,
    lamp_color,
    ambience,
    ambiences = [],
    invited = [],
  } = data;

  const [newName, setNewName] = useState(name);
  const [password, setPassword] = useState('');
  const [inviteName, setInviteName] = useState('');

  const lightsOff = brightness === 0;
  const isPreset = LAMP_COLORS.some((c) => c.value === lamp_color);

  return (
    <Window title="Room Management" width={540} height={560}>
      <Window.Content scrollable>
        <Section title="Room">
          <Stack vertical>
            <Stack.Item>
              <Stack align="center">
                <Stack.Item grow>
                  <Input
                    fluid
                    value={newName}
                    onChange={(value) => setNewName(value)}
                  />
                </Stack.Item>
                <Stack.Item>
                  <Button
                    icon="pen"
                    onClick={() => act('rename', { value: newName })}
                  >
                    Rename
                  </Button>
                </Stack.Item>
              </Stack>
            </Stack.Item>
            <Stack.Item>
              <Stack align="center">
                <Stack.Item>
                  <Button
                    icon={isPrivate ? 'lock' : 'lock-open'}
                    selected={!!isPrivate}
                    onClick={() => act('set_private', { value: !isPrivate })}
                  >
                    {isPrivate ? 'Private' : 'Public'}
                  </Button>
                </Stack.Item>
                <Stack.Item grow>
                  <Input
                    fluid
                    placeholder={has_password ? 'Password set' : 'Set a password'}
                    value={password}
                    disabled={!isPrivate}
                    onChange={(value) => setPassword(value)}
                  />
                </Stack.Item>
                <Stack.Item>
                  <Button
                    icon="key"
                    disabled={!isPrivate}
                    onClick={() => act('set_password', { value: password })}
                  >
                    Set
                  </Button>
                  <Button
                    icon="xmark"
                    color="bad"
                    disabled={!isPrivate}
                    tooltip="Clear password"
                    onClick={() => {
                      setPassword('');
                      act('set_password', { value: '' });
                    }}
                  />
                </Stack.Item>
              </Stack>
            </Stack.Item>
          </Stack>
        </Section>

        <Section title="Lighting">
          <Stack vertical>
            <Stack.Item>
              <Box color="label" mb={0.5}>
                Brightness
              </Box>
              <Stack>
                {BRIGHTNESS_LEVELS.map((level_name, level) => (
                  <Stack.Item key={level_name}>
                    <Button
                      selected={brightness === level}
                      onClick={() => act('set_brightness', { value: level })}
                    >
                      {level_name}
                    </Button>
                  </Stack.Item>
                ))}
              </Stack>
            </Stack.Item>
            <Stack.Item>
              <Box color="label" mb={0.5}>
                Lamp color
              </Box>
              <Stack align="center">
                <Stack.Item grow>
                  <LampColorSwatches
                    value={lamp_color}
                    disabled={lightsOff}
                    onSelect={(value) => act('set_color', { value })}
                  />
                </Stack.Item>
                <Stack.Item>
                  <Button
                    disabled={lightsOff}
                    selected={!isPreset}
                    onClick={() => act('pick_color')}
                  >
                    <Box style={{ display: 'inline-flex', alignItems: 'center' }}>
                      <ColorBox color={lamp_color || '#000000'} mr={0.5} />
                      Custom
                    </Box>
                  </Button>
                </Stack.Item>
              </Stack>
            </Stack.Item>
          </Stack>
        </Section>

        <Section title="Ambience">
          <Dropdown
            width="100%"
            options={['None', ...ambiences]}
            selected={ambience || 'None'}
            onSelected={(value) =>
              act('set_ambience', { value: value === 'None' ? '' : value })
            }
          />
        </Section>

        <Section title="Invites">
          <Stack align="center">
            <Stack.Item grow>
              <Input
                fluid
                placeholder="Character name to invite"
                value={inviteName}
                onChange={(value) => setInviteName(value)}
              />
            </Stack.Item>
            <Stack.Item>
              <Button
                icon="user-plus"
                color="good"
                onClick={() => {
                  act('invite', { name: inviteName });
                  setInviteName('');
                }}
              >
                Invite
              </Button>
            </Stack.Item>
          </Stack>
          {invited.length === 0 ? (
            <NoticeBox info mt={1}>
              Nobody invited yet — only you can enter a private room.
            </NoticeBox>
          ) : (
            <Box mt={1}>
              {invited.map((person) => (
                <Stack key={person.ckey} align="center" mb={0.5}>
                  <Stack.Item grow>
                    <Icon name="user" mr={0.5} />
                    {person.name}
                  </Stack.Item>
                  <Stack.Item>
                    <Button
                      icon="user-minus"
                      color="bad"
                      onClick={() => act('uninvite', { ckey: person.ckey })}
                    >
                      Remove
                    </Button>
                  </Stack.Item>
                </Stack>
              ))}
            </Box>
          )}
        </Section>
      </Window.Content>
    </Window>
  );
}
