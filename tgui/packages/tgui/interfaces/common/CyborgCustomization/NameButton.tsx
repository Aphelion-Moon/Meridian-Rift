// THIS IS AN APHELION UI FILE
import { Button, Stack } from 'tgui-core/components';
import { useBackend } from '../../../backend';

/** Opens the cyborg editor's window from the borg's row in character setup's alternate names. */
export function CyborgEditorNameButton(props: { nameKey: string }) {
  const { act } = useBackend();
  if (props.nameKey !== 'cyborg_name') return null;
  return (
    <Stack.Item>
      <Button icon="robot" onClick={() => act('open_cyborg_editor')}>
        Customize
      </Button>
    </Stack.Item>
  );
}
