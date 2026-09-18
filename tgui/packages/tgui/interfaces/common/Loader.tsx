/* // APHELION EDIT REMOVAL START - MERIDIAN_UI
import { Box } from 'tgui-core/components';
import { clamp01 } from 'tgui-core/math';

export const Loader = (props) => {
  const { value } = props;

  return (
    <div className="AlertModal__Loader">
      <Box
        className="AlertModal__LoaderProgress"
        style={{ width: `${clamp01(value) * 100}%` }}
      />
    </div>
  );
};
*/ // APHELION EDIT REMOVAL END
// APHELION EDIT ADDITION START - MERIDIAN_UI
// The implementation moved to the modular TimeoutBar so every blocking input
// window shares one treatment. This file stays as the upstream entry point so
// no tg call site has to be touched.
export { TimeoutBar as Loader } from './TimeoutBar';
// APHELION EDIT ADDITION END
