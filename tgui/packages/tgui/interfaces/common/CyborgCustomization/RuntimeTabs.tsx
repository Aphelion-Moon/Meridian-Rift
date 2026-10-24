// THIS IS AN APHELION UI FILE
import { Tabs } from 'tgui-core/components';
import { useBackend } from '../../../backend';
import { RuntimeControls, type RuntimeCustomization } from './RuntimeControls';

/** Where a window's backend sends a borg's own part controls, and the action that changes them. */
type RuntimeSource = {
  dataKey: 'cyborg_runtime' | 'reproductionManagement';
};

/** A tab for a borg's own parts, shown only to a borg with a layout. */
export function RuntimeTabButton(
  props: RuntimeSource & { selected: boolean; onClick: () => void },
) {
  const { data } = useBackend<Record<string, RuntimeCustomization | null>>();
  if (!data[props.dataKey]) return null;
  return (
    <Tabs.Tab selected={props.selected} onClick={props.onClick}>
      Genital Options
    </Tabs.Tab>
  );
}

export function RuntimeTab(props: RuntimeSource & { action: string }) {
  const { act, data } =
    useBackend<Record<string, RuntimeCustomization | null>>();
  const runtime = data[props.dataKey];
  if (!runtime) return null;
  return (
    <RuntimeControls
      data={runtime}
      onAction={(params) => act(props.action, params)}
    />
  );
}
