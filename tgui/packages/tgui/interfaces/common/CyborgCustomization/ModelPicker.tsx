import { useEffect, useId, useMemo, useRef, useState } from 'react';
import { Box, Floating, Icon } from 'tgui-core/components';
import { EditorButton as Button, EditorSelect } from './controls';
import type { CyborgCustomizationData, LayoutAction } from './types';

/** Uses the same floating tile gallery as the character clothing pickers. */
export function ModelPicker({
  data,
  onPreview,
  onRetry,
}: {
  data: CyborgCustomizationData;
  onPreview: LayoutAction;
  onRetry?: () => void;
}) {
  const floating = useRef<{ close: () => void }>(null);
  const trigger = useRef<HTMLDivElement>(null);
  const searchInput = useRef<HTMLInputElement>(null);
  const dialog = useRef<HTMLDivElement>(null);
  const dialogId = useId();
  const previewAction = useRef(onPreview);
  const serverGalleryOpen = useRef(false);
  const requestedDepartment = useRef('');
  previewAction.current = onPreview;
  useEffect(
    () => () => {
      if (serverGalleryOpen.current) {
        serverGalleryOpen.current = false;
        previewAction.current({ gallery_open: false });
      }
    },
    [],
  );
  const current = data.models.find((model) => model.id === data.model);
  const [department, setDepartment] = useState(current?.department || '');
  const [search, setSearch] = useState('');
  const [open, setOpen] = useState(false);
  const [rotating, setRotating] = useState(false);
  const [direction, setDirection] = useState(0);
  useEffect(() => {
    if (open) searchInput.current?.focus();
  }, [open]);
  useEffect(() => {
    if (!open || !rotating) return;
    const timer = setInterval(
      () => setDirection((value) => (value + 1) % 4),
      900,
    );
    return () => clearInterval(timer);
  }, [open, rotating]);
  const departments = useMemo(
    () => [...new Set(data.models.map((model) => model.department))],
    [data.models],
  );
  const selectedDepartment = departments.includes(department)
    ? department
    : current?.department || departments[0] || '';
  useEffect(() => {
    // The shared catalog can arrive after the picker has already opened.
    if (
      open &&
      serverGalleryOpen.current &&
      selectedDepartment &&
      requestedDepartment.current !== selectedDepartment
    ) {
      requestedDepartment.current = selectedDepartment;
      previewAction.current({
        gallery_open: true,
        gallery_department: selectedDepartment,
      });
    }
  }, [open, selectedDepartment]);
  const models = useMemo(() => {
    if (!open) return [];
    const query = search.toLowerCase();
    return data.models.filter(
      (model) =>
        model.department === selectedDepartment &&
        model.skin.toLowerCase().includes(query),
    );
  }, [data.models, selectedDepartment, search, open]);
  return (
    <div ref={trigger}>
      <Floating
        ref={floating}
        placement="right-start"
        onOpenChange={(isOpen) => {
          if (!isOpen && dialog.current?.contains(document.activeElement)) {
            trigger.current?.querySelector('button')?.focus();
          }
          setOpen(isOpen);
          const nextDepartment = isOpen
            ? current?.department || selectedDepartment
            : selectedDepartment;
          setDepartment(nextDepartment);
          if (isOpen) setSearch('');
          if (serverGalleryOpen.current === isOpen) return;
          serverGalleryOpen.current = isOpen;
          requestedDepartment.current = nextDepartment;
          onPreview({
            gallery_open: isOpen,
            ...(nextDepartment ? { gallery_department: nextDepartment } : {}),
          });
        }}
        content={
          <div
            id={dialogId}
            ref={dialog}
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
              <EditorSelect
                label="Model department"
                value={selectedDepartment}
                options={departments.map((value) => ({ value, label: value }))}
                onChange={(value) => {
                  setDepartment(value);
                  requestedDepartment.current = value;
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
            <input
              ref={searchInput}
              autoFocus
              type="search"
              className="Input Input--fluid CyborgModelPicker__search"
              aria-label="Search skins"
              placeholder="Search skins"
              value={search}
              onChange={(event) => setSearch(event.currentTarget.value)}
            />
            <div className="CyborgModelPicker__grid">
              {models.map((model) => {
                const thumbnail =
                  model.thumbnail_directions?.[
                    String([2, 4, 1, 8][direction])
                  ] || model.thumbnail;
                return (
                  <Button
                    key={model.id}
                    selected={model.id === data.model}
                    tooltip={model.skin}
                    onClick={() => {
                      serverGalleryOpen.current = false;
                      onPreview({ model: model.id, gallery_open: false });
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
                          <Box color="label">
                            {data.gallery_error
                              ? 'Image unavailable'
                              : 'Loading…'}
                          </Box>
                        )}
                      </div>
                      <span>{model.skin}</span>
                    </div>
                  </Button>
                );
              })}
              {!models.length && (
                <Box color="label">
                  {data.gallery_loading
                    ? 'Loading models…'
                    : data.gallery_error
                      ? 'Models unavailable.'
                      : 'No matching skins.'}
                </Box>
              )}
            </div>
            {data.gallery_error && (
              <div role="status">
                Some model previews could not load.{' '}
                <Button onClick={onRetry}>Retry model previews</Button>
              </div>
            )}
            <Box color="label" mt={1}>
              Preview only. Your playable chassis is chosen in round.
            </Box>
          </div>
        }
      >
        <button
          type="button"
          className="Button Button--fluid Button--color--default CyborgModelPicker__trigger"
          title={`${current?.department || ''}: ${current?.skin || ''}`}
          aria-label="Choose preview model"
          aria-haspopup="dialog"
          aria-expanded={open}
          aria-controls={open ? dialogId : undefined}
        >
          <Icon name="robot" />
          Model
        </button>
      </Floating>
    </div>
  );
}
