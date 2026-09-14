import { useEffect, useRef, useState } from 'react';
import { Box, Button, Dropdown, Floating, Input } from 'tgui-core/components';
import type { CyborgCustomizationData, LayoutAction } from './types';

/** Uses the same floating tile gallery as the character clothing pickers. */
export function ModelPicker({
  data,
  onPreview,
}: {
  data: CyborgCustomizationData;
  onPreview: LayoutAction;
}) {
  const floating = useRef<{ close: () => void }>(null);
  const previewAction = useRef(onPreview);
  previewAction.current = onPreview;
  useEffect(() => () => previewAction.current({ gallery_open: false }), []);
  const current = data.models.find((model) => model.id === data.model);
  const [department, setDepartment] = useState(current?.department || '');
  const [search, setSearch] = useState('');
  const [open, setOpen] = useState(false);
  const [rotating, setRotating] = useState(false);
  const [direction, setDirection] = useState(0);
  useEffect(() => {
    if (!open || !rotating) return;
    const timer = setInterval(
      () => setDirection((value) => (value + 1) % 4),
      900,
    );
    return () => clearInterval(timer);
  }, [open, rotating]);
  const models = data.models.filter(
    (model) =>
      model.department === department &&
      model.skin.toLowerCase().includes(search.toLowerCase()),
  );
  return (
    <Floating
      ref={floating}
      placement="right-start"
      onOpenChange={(isOpen) => {
        setOpen(isOpen);
        const nextDepartment = isOpen
          ? current?.department || department
          : department;
        setDepartment(nextDepartment);
        if (isOpen) setSearch('');
        onPreview({ gallery_open: isOpen, gallery_department: nextDepartment });
      }}
      content={
        <div
          className="CyborgModelPicker"
          role="dialog"
          aria-label="Choose preview model"
        >
          <div className="CyborgModelPicker__header">
            <Box bold>Preview model</Box>
            <Button
              icon="times"
              aria-label="Close model picker"
              onClick={() => floating.current?.close()}
            />
          </div>
          <div className="CyborgModelPicker__controls">
            <Dropdown
              width="100%"
              selected={department}
              options={[
                ...new Set(data.models.map((model) => model.department)),
              ]}
              onSelected={(value) => {
                setDepartment(value);
                onPreview({ gallery_department: value, gallery_open: true });
              }}
            />
            <div className="CyborgPreview__toolbar">
              <Button
                icon="rotate-left"
                aria-label="Rotate model previews left"
                tooltip="Rotate preview icons one quarter turn left."
                onClick={() => {
                  setRotating(false);
                  setDirection((value) => (value + 3) % 4);
                }}
              />
              <Button
                icon="play"
                selected={rotating}
                tooltip="Slowly rotate all model previews."
                onClick={() => setRotating(!rotating)}
              >
                Rotate previews
              </Button>
              <Button
                icon="rotate-right"
                aria-label="Rotate model previews right"
                tooltip="Rotate preview icons one quarter turn right."
                onClick={() => {
                  setRotating(false);
                  setDirection((value) => (value + 1) % 4);
                }}
              />
            </div>
          </div>
          <Input
            fluid
            my={1}
            placeholder="Search skins"
            value={search}
            onChange={setSearch}
          />
          <div className="CyborgModelPicker__grid">
            {models.map((model) => {
              const thumbnail =
                model.thumbnail_directions?.[String([2, 4, 1, 8][direction])] ||
                model.thumbnail;
              return (
                <Button
                  key={model.id}
                  selected={model.id === data.model}
                  tooltip={model.skin}
                  onClick={() => {
                    onPreview({ model: model.id });
                    floating.current?.close();
                  }}
                >
                  <div className="CyborgModelPicker__tileContent">
                    <div className="CyborgModelPicker__image">
                      {thumbnail ? (
                        <img
                          alt=""
                          src={`data:image/png;base64,${thumbnail}`}
                        />
                      ) : (
                        <Box color="label">Loading…</Box>
                      )}
                    </div>
                    <span>{model.skin}</span>
                  </div>
                </Button>
              );
            })}
            {!models.length && <Box color="label">No matching skins.</Box>}
          </div>
          <Box color="label" mt={1}>
            Preview only. Your playable chassis is chosen in round.
          </Box>
        </div>
      }
    >
      <div>
        <Button
          fluid
          icon="robot"
          tooltip={
            open ? undefined : `${current?.department}: ${current?.skin}`
          }
          aria-label="Choose preview model"
        >
          Model
        </Button>
      </div>
    </Floating>
  );
}
