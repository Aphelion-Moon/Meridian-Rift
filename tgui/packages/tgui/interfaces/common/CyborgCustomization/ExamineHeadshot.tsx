// THIS IS AN APHELION UI FILE
import { useState } from 'react';
import { Button, Section } from 'tgui-core/components';
import { resolveAsset } from '../../../assets';
import { useBackend } from '../../../backend';

type HeadshotData = {
  headshot: string;
  /** Only a borg's examine sends this. */
  headshot_nsfw?: string;
};

/** Whether the examine panel has a headshot to show, a borg's NSFW one included. */
export function hasHeadshot(data: HeadshotData) {
  return !!data.headshot || !!data.headshot_nsfw;
}

/** The examine panel's headshot, with a borg's NSFW headshot a button away. */
export function ExamineHeadshot(props: { headshot: string }) {
  const { data } = useBackend<HeadshotData>();
  const [headshotIndex, setHeadshotIndex] = useState('SFW');
  const displayedHeadshot =
    headshotIndex === 'NSFW' ? data.headshot_nsfw : props.headshot;
  return (
    <Section
      height="310px"
      title="Headshot"
      buttons={
        data.headshot_nsfw && (
          <Button
            selected={headshotIndex === 'NSFW'}
            onClick={() =>
              setHeadshotIndex(headshotIndex === 'SFW' ? 'NSFW' : 'SFW')
            }
          >
            {headshotIndex === 'SFW' ? 'Show NSFW' : 'Show SFW'}
          </Button>
        )
      }
    >
      {displayedHeadshot && (
        <img
          src={resolveAsset(displayedHeadshot)}
          alt={`${headshotIndex} headshot`}
          height="250px"
          width="250px"
        />
      )}
    </Section>
  );
}
