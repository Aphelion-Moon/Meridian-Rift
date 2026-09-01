// import { ByondUi } from 'tgui-core/components'; // APHELION EDIT REMOVAL - native UI menu avoidance
import { ByondUi } from '../../layouts/ByondUi'; // APHELION EDIT ADDITION - native UI menu avoidance

export const CharacterPreview = (props: {
  width?: string; // NOVA EDIT
  height: string;
  id: string;
}) => {
  // NOVA EDIT
  const { width = '272px' } = props;
  // NOVA EDIT END
  return (
    <ByondUi
      width={width} // NOVA EDIT
      height={props.height}
      params={{
        id: props.id,
        type: 'map',
      }}
    />
  );
};
