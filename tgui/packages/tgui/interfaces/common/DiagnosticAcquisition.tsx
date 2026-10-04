// THIS IS AN APHELION UI FILE

const calibrationTicks = Array.from({ length: 32 }, (_, index) => {
  const angle = (index / 32) * Math.PI * 2;
  const length = index % 4 === 0 ? 67 : 64;
  const point = (radius: number) =>
    `${(80 + Math.cos(angle) * radius).toFixed(2)} ${(80 + Math.sin(angle) * radius).toFixed(2)}`;
  return `M${point(61)}L${point(length)}`;
}).join(' ');

function AcquisitionTrace() {
  return (
    <>
      <circle
        className="DiagnosticAcquisition__progress"
        cx="80"
        cy="80"
        r="54"
        pathLength="100"
        transform="rotate(-90 80 80)"
      />
      <g className="DiagnosticAcquisition__brackets">
        <path className="DiagnosticAcquisition__northWest" d="M64 71V64H71" />
        <path className="DiagnosticAcquisition__northEast" d="M89 64H96V71" />
        <path className="DiagnosticAcquisition__southEast" d="M96 89V96H89" />
        <path className="DiagnosticAcquisition__southWest" d="M71 96H64V89" />
      </g>
      <path className="DiagnosticAcquisition__target" d="M77 80H83M80 77V83" />
    </>
  );
}

/** Decorative Diagnostic-only linework. The parent owns progress and its ARIA. */
export function DiagnosticAcquisition() {
  return (
    <svg
      aria-hidden="true"
      className="DiagnosticLoader__acquisition"
      focusable="false"
      viewBox="0 0 160 160"
    >
      <g className="DiagnosticAcquisition__grid">
        <path d="M80 10V45M80 115V150M10 80H45M115 80H150" />
        <path d="M17 29V17H29M131 17H143V29M143 131V143H131M29 143H17V131" />
        <path d="M33 54A54 54 0 0 1 54 33M106 33A54 54 0 0 1 127 54M127 106A54 54 0 0 1 106 127M54 127A54 54 0 0 1 33 106" />
        <circle cx="80" cy="80" r="40" strokeDasharray="1 8.973" />
        <path d="M47 46L57 56M103 104L113 114M47 114L57 104M103 56L113 46" />
      </g>
      <path
        className="DiagnosticAcquisition__calibration"
        d={calibrationTicks}
      />
      <g className="DiagnosticAcquisition__glow">
        <AcquisitionTrace />
      </g>
      <g className="DiagnosticAcquisition__trace">
        <AcquisitionTrace />
      </g>
      <path
        className="DiagnosticAcquisition__crosshair"
        d="M70 80H76M84 80H90M80 70V76M80 84V90"
      />
    </svg>
  );
}
