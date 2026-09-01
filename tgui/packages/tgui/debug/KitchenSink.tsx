/**
 * @file
 * @copyright 2020 Aleksej Komarov
 * @license MIT
 */
import { useState } from 'react';
import { JSONTree } from 'react-json-tree';
import { Divider, Section, Stack, Tabs } from 'tgui-core/components';
import { useBackend } from '../backend';
import { tgui16 } from '../constants/theme';
import { Pane, Window } from '../layouts';
// APHELION EDIT ADDITION START - MERIDIAN_UI
import { DiagnosticLoaderPreview } from '../styles/meridianos/debug/DiagnosticLoaderPreview';
import {
  MeridianComponentsPage,
  MeridianShowcase,
  MeridianShowcaseModal,
} from '../styles/meridianos/debug/MeridianShowcase';

// APHELION EDIT ADDITION END

type Props = {
  panel?: boolean;
};

enum Tab {
  Config = 'config',
  Data = 'data',
  Shared = 'shared',
  Chunks = 'outgoingPayloadQueues',
  Components = 'components',
  LoaderPreview = 'loader-preview', // APHELION EDIT ADDITION - MERIDIAN_UI
}

const tabs = [
  { name: 'Config', value: Tab.Config },
  { name: 'Data', value: Tab.Data },
  { name: 'Shared', value: Tab.Shared },
  { name: 'Chunks', value: Tab.Chunks },
] as const;

export function KitchenSink(props: Props) {
  const { panel } = props;

  const [activeTab, setActiveTab] = useState(Tab.Config);
  const [showModal, setShowModal] = useState(false); // APHELION EDIT ADDITION - MERIDIAN_UI

  const Layout = panel ? Pane : Window;

  return (
    <Layout title="MeridianOS Development Showcase" width={800} height={720}>
      {/* APHELION EDIT CHANGE - MERIDIAN_UI - ORIGINAL: Kitchen Sink, 600x500 */}
      <Layout.Content>
        {/* APHELION EDIT ADDITION START - MERIDIAN_UI */}
        <MeridianShowcase>
          {/* APHELION EDIT ADDITION END */}
          <Stack fill>
            <Stack.Item grow>
              <Tabs vertical>
                {tabs.map((tab) => (
                  <Tabs.Tab
                    key={tab.name}
                    className="candystripe"
                    selected={activeTab === tab.value}
                    onClick={() => setActiveTab(tab.value)}
                  >
                    {tab.name}
                  </Tabs.Tab>
                ))}
                <Divider />
                <Tabs.Tab
                  selected={activeTab === Tab.Components}
                  onClick={() => setActiveTab(Tab.Components)}
                >
                  Components
                </Tabs.Tab>
                {/* APHELION EDIT ADDITION START - MERIDIAN_UI */}
                <Tabs.Tab
                  selected={activeTab === Tab.LoaderPreview}
                  onClick={() => setActiveTab(Tab.LoaderPreview)}
                >
                  Loader
                </Tabs.Tab>
                {/* APHELION EDIT ADDITION END */}
              </Tabs>
            </Stack.Item>
            <Stack.Item grow={4}>
              {activeTab === Tab.Components ? (
                // APHELION EDIT CHANGE START - MERIDIAN_UI - ORIGINAL: <ComponentsPage />
                <MeridianComponentsPage
                  onShowModal={() => setShowModal(true)}
                />
              ) : activeTab === Tab.LoaderPreview ? (
                <DiagnosticLoaderPreview />
                // APHELION EDIT CHANGE END
              ) : (
                <TreePage tab={activeTab} />
              )}
            </Stack.Item>
          </Stack>
          {/* APHELION EDIT ADDITION START - MERIDIAN_UI */}
        </MeridianShowcase>
        {/* APHELION EDIT ADDITION END */}
      </Layout.Content>
      {/* APHELION EDIT ADDITION START - MERIDIAN_UI */}
      {showModal && (
        <MeridianShowcaseModal onClose={() => setShowModal(false)} />
      )}
      {/* APHELION EDIT ADDITION END */}
    </Layout>
  );
}

/* // APHELION EDIT REMOVAL START - MERIDIAN_UI
function ComponentsPage() {
  return (
    <Section fill>
      <NoticeBox info>All component stories have been moved.</NoticeBox>
      View them here{' '}
      <a href="https://tgstation.github.io/tgui-core">
        https://tgstation.github.io/tgui-core
      </a>
    </Section>
  );
}
*/ // APHELION EDIT REMOVAL END

type TreeProps = {
  tab: Tab;
};

function TreePage(props: TreeProps) {
  const { tab } = props;

  const backend = useBackend();
  const inView = backend[tab];

  return (
    <Section
      fill
      scrollable
      title={`${backend.config.interface.name ?? 'TGUI'} data`}
    >
      <div style={{ border: 'thin solid var(--color-base)' }}>
        <JSONTree data={inView} theme={tgui16} />
      </div>
    </Section>
  );
}
