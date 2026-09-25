// THIS IS AN APHELION UI FILE
import { useAtomValue } from 'jotai';
import { Button, NoticeBox } from 'tgui-core/components';
import { iconMapStateAtom, retryIconMap } from '../iconMap';

export function IconResourceNotice() {
  const state = useAtomValue(iconMapStateAtom);
  if (state.status !== 'error') return null;
  return (
    <NoticeBox>
      Some icons could not load.{' '}
      <Button icon="rotate" onClick={retryIconMap}>
        Retry icons
      </Button>
    </NoticeBox>
  );
}
