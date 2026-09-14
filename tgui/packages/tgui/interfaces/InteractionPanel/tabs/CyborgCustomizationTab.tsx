import { useBackend } from '../../../backend';
import {
  RuntimeControls,
  type RuntimeCustomization,
} from '../../common/CyborgCustomization/RuntimeControls';

type CyborgCustomizationData = {
  cyborg_runtime: RuntimeCustomization;
};

export function CyborgCustomizationTab() {
  const { act, data } = useBackend<CyborgCustomizationData>();
  return (
    <RuntimeControls
      data={data.cyborg_runtime}
      onAction={(params) => act('cyborg_runtime', params)}
    />
  );
}
