import { useState } from 'react';
import { Box } from 'tgui-core/components';

/** Displays the saved, backend-validated portrait without disturbing its editor. */
export function PortraitPreview({
  value,
  label,
}: {
  value: unknown;
  label: string;
}) {
  const [failedUrl, setFailedUrl] = useState<string>();
  const url = typeof value === 'string' ? value : '';
  return (
    <div className="CyborgEditor__portrait">
      {url && failedUrl !== url ? (
        <img
          src={url}
          alt={`${label} preview`}
          referrerPolicy="no-referrer"
          onError={() => setFailedUrl(url)}
        />
      ) : (
        <Box color="label">
          {url
            ? 'Preview unavailable. Check the saved image link.'
            : 'No headshot selected.'}
        </Box>
      )}
    </div>
  );
}
