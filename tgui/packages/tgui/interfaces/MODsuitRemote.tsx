// THIS IS AN APHELION UI FILE
import {
  Icon,
  Input,
  LabeledList,
  Modal,
  Section,
  Stack,
} from 'tgui-core/components';

import { useBackend } from '../backend';
import { Window } from '../layouts';
import { MODsuitContent } from './MODsuit';

type Data = {
  ui_theme: string;
  refusal: string | null;
};

/** The MOD remote: the suit's own interface plus a forced emote, or the server's reason it can't be used. */
export const MODsuitRemote = (props) => {
  const { act, data } = useBackend<Data>();
  const { ui_theme, refusal } = data;
  return (
    <Window
      theme={ui_theme}
      width={550}
      height={350}
      title="MOD Remote Interface"
    >
      <Window.Content scrollable>
        {refusal ? (
          <Modal textAlign="center">
            <Icon size={5} name="triangle-exclamation" />
            <br />
            {refusal}
          </Modal>
        ) : (
          <Stack vertical>
            <Stack.Item>
              <Section title="Remote Control">
                <LabeledList>
                  <LabeledList.Item label="Force Emote">
                    <Input
                      fluid
                      selfClear
                      onEnter={(emote) => act('emote', { emote })}
                    />
                  </LabeledList.Item>
                </LabeledList>
              </Section>
            </Stack.Item>
            <Stack.Item>
              <MODsuitContent />
            </Stack.Item>
          </Stack>
        )}
      </Window.Content>
    </Window>
  );
};
