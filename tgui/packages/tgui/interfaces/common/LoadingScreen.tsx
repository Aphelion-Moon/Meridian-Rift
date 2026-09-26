//import { Icon, Stack } from 'tgui-core/components';
/** Spinner that represents loading states.
 *
 * @usage
 * ```tsx
 * /// rest of the component
 * return (
 * ///... content to overlay
 * {!!loading && <LoadingScreen />}
 * /// ... content to overlay
 * );
 * ```
 * OR
 * ```tsx
 * return (
 * {loading ? <LoadingScreen /> : <ContentToHide />}
 * )
 * ```
 */
/* // APHELION EDIT REMOVAL START
type LoadingScreenProps = {
  label?: string;
};

export function LoadingScreen(props: LoadingScreenProps) {
  return (
    <Stack align="center" fill justify="center" vertical>
      <Stack.Item>
        <Icon color="blue" name="toolbox" spin size={4} />
      </Stack.Item>
      <Stack.Item>{props.label || 'Please wait...'}</Stack.Item>
    </Stack>
  );
}
*/ // APHELION EDIT REMOVAL END
// APHELION EDIT ADDITION START - MERIDIAN_UI
// The implementation moved to the modular DiagnosticLoader so every loading
// surface shares one instrument. This file stays as the upstream entry point so
// no tg call site has to be touched; DiagnosticLoader takes the same optional
// `label`.
export { DiagnosticLoader as LoadingScreen } from './DiagnosticLoader';
// APHELION EDIT ADDITION END
