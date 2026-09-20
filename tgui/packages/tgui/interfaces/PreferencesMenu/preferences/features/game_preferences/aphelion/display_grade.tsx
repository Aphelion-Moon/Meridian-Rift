import { useBackend } from 'tgui/backend';
import { Button, Dropdown, Stack } from 'tgui-core/components';
import type { Feature } from '../../base';

export const display_grade_mode: Feature<string> = {
  name: 'Display grade',
  category: 'DISPLAY',
  description:
    'Grade the world, HUD, and interfaces. Configure a temporary preview before saving a Custom profile.',
  component: ({ value, handleSetValue }) => {
    const { act } = useBackend();
    return (
      <Stack>
        <Stack.Item grow>
          <Dropdown
            selected={value}
            options={['Off', 'Reference', 'Custom']}
            onSelected={handleSetValue}
          />
        </Stack.Item>
        <Stack.Item>
          <Button onClick={() => act('configure_display_grade')}>
            Configure
          </Button>
        </Stack.Item>
      </Stack>
    );
  },
};
