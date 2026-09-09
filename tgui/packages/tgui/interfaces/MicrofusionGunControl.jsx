// THIS IS A NOVA SECTOR UI FILE
import { useState } from 'react';
import { Box, Icon, Stack, Tooltip } from 'tgui-core/components';
import { toFixed } from 'tgui-core/math';

import { useBackend } from '../backend';
import { Window } from '../layouts';

// Phosphor on smoked glass.
const T = {
  void: '#03100b',
  glass: 'rgba(9, 34, 27, 0.82)',
  glassLit: 'rgba(16, 58, 46, 0.9)',
  edge: '#1d6a52',
  edgeLit: '#4fe3ab',
  dim: 'rgba(79, 227, 171, 0.16)',
  phosphor: '#4fe3ab',
  phosphorHot: '#a8ffe4',
  label: '#5f9d88',
  amber: '#ffc042',
  danger: '#ff6a5f',
  cool: '#57c4f5',
  coolHot: '#c2e9ff',
};

const TONE = {
  primary: { line: T.edgeLit, text: T.phosphorHot, glow: 'rgba(79,227,171,0.55)' },
  amber: { line: T.amber, text: '#ffe4a8', glow: 'rgba(255,192,66,0.55)' },
  danger: { line: T.danger, text: '#ffc9c4', glow: 'rgba(255,106,95,0.55)' },
  cool: { line: T.cool, text: T.coolHot, glow: 'rgba(87,196,245,0.55)' },
};

// Keyframes can't be done inline.
const KEYFRAMES = `
@keyframes mfd-flash { 0%, 100% { opacity: 1; } 50% { opacity: 0.2; } }
@keyframes mfd-throb {
  0%, 100% { box-shadow: 0 0 6px rgba(255,106,95,0.35), inset 0 0 6px rgba(255,106,95,0.2); }
  50% { box-shadow: 0 0 20px rgba(255,106,95,0.95), inset 0 0 16px rgba(255,106,95,0.5); }
}
`;

// Cut corners, top left and bottom right.
const CHAMFER = (n) =>
  `polygon(${n}px 0, 100% 0, 100% calc(100% - ${n}px), calc(100% - ${n}px) 100%, 0 100%, 0 ${n}px)`;

const SCANLINES =
  'repeating-linear-gradient(0deg, rgba(0,0,0,0.22) 0px, rgba(0,0,0,0.22) 1px, transparent 1px, transparent 3px)';

const ICON_W = 40;
const ICON_H = 32;

const SLOT_ANCHORS = {
  rail: { x: 17, y: 3, ax: 20, ay: 10, label: 'RAIL' },
  camo: { x: 4, y: 5, ax: 14, ay: 15, label: 'FRAME' },
  unique: { x: 31, y: 3, ax: 19, ay: 15, label: 'UNIQUE' },
  underbarrel: { x: 19, y: 29, ax: 22, ay: 18, label: 'UNDER' },
  barrel: { x: 34, y: 27, ax: 31, ay: 15, label: 'BARREL' },
};

// Back to front. Camo covers the whole receiver, so it goes under the fittings.
const SLOT_DEPTH = ['camo', 'unique', 'barrel', 'underbarrel', 'rail'];

// The src DmIcon would have built, so the sprite can live in an SVG.
const iconUrl = (icon, iconState) => {
  const ref = globalThis.Byond?.iconRefMap?.[icon];
  if (!ref || !iconState) {
    return null;
  }
  return `${ref}?state=${iconState}&dir=2&movement=false&frame=1`;
};

const clamp01 = (n) => Math.max(0, Math.min(1, Number.isFinite(n) ? n : 0));

const bandColor = (fraction, invert) => {
  const f = invert ? 1 - fraction : fraction;
  if (f <= 0.25) {
    return T.danger;
  }
  if (f <= 0.5) {
    return T.amber;
  }
  return T.phosphor;
};

const Legend = (props) => (
  <Box
    style={{
      fontFamily: 'monospace',
      fontSize: props.size || '0.72rem',
      letterSpacing: '0.22em',
      textTransform: 'uppercase',
      color: props.color || T.label,
    }}
  >
    {props.children}
  </Box>
);

// Fault marker, drawn like the bay rings so the two match.
const FaultGlyph = (props) => {
  const { tone, flash } = props;
  const stroke = tone === 'danger' ? T.danger : T.amber;
  return (
    <svg
      viewBox="0 0 16 16"
      width="15"
      height="15"
      style={{
        display: 'block',
        animation: flash ? 'mfd-flash 0.8s steps(1, end) infinite' : undefined,
      }}
    >
      <circle
        cx="8"
        cy="8"
        r="6.6"
        fill="none"
        stroke={stroke}
        strokeWidth="1"
        strokeDasharray="2.6 1.6"
      />
      <line x1="8" y1="4.4" x2="8" y2="9" stroke={stroke} strokeWidth="1.4" />
      <circle cx="8" cy="11.3" r="0.85" fill={stroke} />
    </svg>
  );
};

// Always drawn, dark until it trips. Keeps every gauge the same height.
const Lamp = (props) => {
  const { label, lit, tone, flash } = props;
  const skin = TONE[tone || 'amber'];
  return (
    <Box
      style={{
        flex: '1 1 0',
        minWidth: 0,
        textAlign: 'center',
        padding: '6px 2px',
        border: `1px solid ${lit ? skin.line : 'rgba(29,106,82,0.5)'}`,
        background: lit ? `${skin.line}26` : 'rgba(0,0,0,0.3)',
        clipPath: CHAMFER(5),
        boxShadow: lit ? `0 0 10px ${skin.glow}` : 'none',
        opacity: lit ? 1 : 0.4,
        animation:
          lit && flash ? 'mfd-flash 0.7s steps(1, end) infinite' : undefined,
      }}
    >
      <Box
        style={{
          fontFamily: 'monospace',
          fontSize: '0.78rem',
          fontWeight: 'bold',
          // Four to a tile, so labels stay four characters.
          letterSpacing: '0.04em',
          textTransform: 'uppercase',
          color: lit ? skin.line : T.label,
          whiteSpace: 'nowrap',
          overflow: 'hidden',
          textOverflow: 'ellipsis',
        }}
      >
        {label}
      </Box>
    </Box>
  );
};

const MfdButton = (props) => {
  const { children, icon, onClick, disabled, tone, block, tooltip, active } =
    props;
  const [hover, setHover] = useState(false);
  const skin = TONE[tone || 'primary'];
  const on = !disabled && (hover || active);

  const control = (
    <Box
      onClick={disabled ? undefined : onClick}
      onMouseEnter={() => setHover(true)}
      onMouseLeave={() => setHover(false)}
      style={{
        display: block ? 'block' : 'inline-block',
        width: block ? '100%' : undefined,
        marginRight: block ? undefined : '4px',
        marginTop: '2px',
        padding: block ? '10px 14px' : '7px 13px',
        textAlign: 'center',
        fontFamily: 'monospace',
        fontSize: block ? '1rem' : '0.85rem',
        letterSpacing: '0.16em',
        textTransform: 'uppercase',
        color: disabled ? T.label : skin.text,
        border: `1px solid ${disabled ? T.edge : skin.line}`,
        background: on
          ? T.glassLit
          : active
            ? 'rgba(79,227,171,0.10)'
            : T.glass,
        clipPath: CHAMFER(9),
        boxShadow: on ? `0 0 14px ${skin.glow}, inset 0 0 12px ${skin.glow}` : 'none',
        opacity: disabled ? 0.35 : 1,
        cursor: disabled ? 'not-allowed' : 'pointer',
        transition: 'box-shadow 120ms linear, background 120ms linear',
        userSelect: 'none',
      }}
    >
      {!!icon && <Icon name={icon} mr={children ? 1 : 0} />}
      {children}
    </Box>
  );

  return tooltip ? <Tooltip content={tooltip}>{control}</Tooltip> : control;
};

const Panel = (props) => {
  const { title, actions, children, footer, scroll, glyph, accent } = props;
  const { titleTooltip } = props;
  const rule = accent || T.edge;
  const heading = (
    <Legend size="0.8rem" color={accent || T.phosphor}>
      {title}
    </Legend>
  );
  return (
    <Box
      style={{
        height: '100%',
        display: 'flex',
        flexDirection: 'column',
        background: T.glass,
        border: `1px solid ${accent || T.edge}`,
        clipPath: CHAMFER(12),
        padding: '10px 12px',
        boxShadow: accent ? `inset 0 0 22px ${accent}22` : undefined,
      }}
    >
      {(!!title || !!actions) && (
        <Box
          style={{
            display: 'flex',
            alignItems: 'center',
            justifyContent: 'space-between',
            gap: '8px',
            borderBottom: `1px solid ${rule}`,
            paddingBottom: '6px',
            marginBottom: '8px',
            flex: '0 0 auto',
            // Reserve a button's height so panels without one still line up.
            minHeight: '34px',
          }}
        >
          <Box
            style={{
              display: 'flex',
              alignItems: 'center',
              gap: '6px',
              minWidth: 0,
            }}
          >
            {glyph}
            {titleTooltip ? (
              <Tooltip content={titleTooltip}>{heading}</Tooltip>
            ) : (
              heading
            )}
          </Box>
          <Box style={{ flex: '0 0 auto' }}>{actions}</Box>
        </Box>
      )}
      <Box
        style={{
          flex: '1 1 auto',
          minHeight: 0,
          overflowY: scroll ? 'auto' : 'visible',
        }}
      >
        {children}
      </Box>
      {!!footer && (
        <Box
          style={{
            flex: '0 0 auto',
            borderTop: `1px solid ${T.edge}`,
            paddingTop: '8px',
            marginTop: '8px',
          }}
        >
          {footer}
        </Box>
      )}
    </Box>
  );
};

const Segments = (props) => {
  const { value, max, count, color, height } = props;
  const total = count || 18;
  const fraction = clamp01(value / (max || 1));
  const lit = Math.round(fraction * total);
  return (
    <Box style={{ display: 'flex', gap: '2px', marginTop: '4px' }}>
      {Array.from({ length: total }, (_, index) => {
        const on = index < lit;
        return (
          <Box
            key={index}
            style={{
              flex: '1 1 0',
              height: height || '11px',
              background: on ? color : T.dim,
              boxShadow: on ? `0 0 7px ${color}` : 'none',
              clipPath: 'polygon(0 0, 100% 0, 100% 68%, 68% 100%, 0 100%)',
            }}
          />
        );
      })}
    </Box>
  );
};

const Gauge = (props) => {
  const { label, value, unit, sub, fraction, color, onClick, active } = props;
  const { actions, lamps, glyph, accent } = props;
  return (
    <Panel title={label} actions={actions} glyph={glyph} accent={accent}>
      <Box
        onClick={onClick}
        style={{
          height: '100%',
          display: 'flex',
          flexDirection: 'column',
          cursor: onClick ? 'pointer' : undefined,
        }}
      >
        <Box style={{ display: 'flex', alignItems: 'baseline', gap: '4px' }}>
          <Box
            style={{
              fontFamily: 'monospace',
              fontSize: '2rem',
              lineHeight: 1,
              fontWeight: 'bold',
              color: active ? T.phosphorHot : color,
              textShadow: `0 0 12px ${color}`,
            }}
          >
            {value}
          </Box>
          {!!unit && <Legend size="0.75rem">{unit}</Legend>}
        </Box>
        <Segments value={fraction || 0} max={1} color={color} />
        <Box
          mt={0.5}
          style={{
            whiteSpace: 'nowrap',
            overflow: 'hidden',
            textOverflow: 'ellipsis',
          }}
        >
          <Legend size="0.68rem">{sub}</Legend>
        </Box>
        <Box
          style={{
            display: 'flex',
            gap: '3px',
            marginTop: 'auto',
            paddingTop: '8px',
          }}
        >
          {(lamps || []).map((lamp) => (
            <Lamp
              key={lamp.label}
              label={lamp.label}
              lit={lamp.lit}
              tone={lamp.tone}
              flash={lamp.flash}
            />
          ))}
        </Box>
      </Box>
    </Panel>
  );
};

const StatusStrip = (props) => {
  const { act, data, selected, onSelect } = props;
  const {
    has_cell,
    cell_data,
    has_emitter,
    phase_emitter_data,
    gun_heat_dissipation,
  } = data;

  // has_* come from DM as 0 or 1, and React will happily print a bare 0.
  const cellIn = !!has_cell;
  const emitterIn = !!has_emitter;
  const damaged = emitterIn && !!phase_emitter_data.damaged;
  const hacked = emitterIn && !!phase_emitter_data.hacked;
  const cooling = emitterIn && !!phase_emitter_data.cooling_system;
  const meltdown = cellIn && !!cell_data.status;

  const heatPercent = emitterIn ? phase_emitter_data.heat_percent : 0;
  const throttlePercent = emitterIn
    ? phase_emitter_data.throttle_percentage
    : 0;
  const overload = emitterIn && heatPercent >= 100;
  const throttled = emitterIn && !overload && heatPercent >= throttlePercent;

  const chargeFraction = cellIn
    ? clamp01(cell_data.charge / cell_data.max_charge)
    : 0;
  const chargeTone = cellIn ? bandColor(chargeFraction) : T.danger;
  const dry = cellIn && cell_data.shots_left <= 0;

  const heatFraction = clamp01(heatPercent / 100);
  let heatTone = emitterIn ? bandColor(heatFraction, true) : T.danger;
  if (cooling && !overload) {
    heatTone = T.cool;
  }
  const integrityFraction = emitterIn
    ? clamp01(phase_emitter_data.integrity / 100)
    : 0;
  const integrityTone = emitterIn ? bandColor(integrityFraction) : T.danger;

  const lowCharge = cellIn && !dry && chargeFraction <= 0.25;
  const weakEmitter = emitterIn && !damaged && phase_emitter_data.integrity < 50;

  const shotLamps = [
    { label: 'Dry', lit: dry, tone: 'danger', flash: true },
    {
      label: 'Low',
      lit: cellIn && !dry && cell_data.shots_left <= 3,
      tone: 'amber',
    },
    { label: 'None', lit: !cellIn, tone: 'danger' },
  ];
  const cellLamps = [
    { label: 'Melt', lit: meltdown, tone: 'danger', flash: true },
    { label: 'Low', lit: lowCharge, tone: 'amber' },
    { label: 'None', lit: !cellIn, tone: 'danger' },
  ];
  const thermalLamps = [
    { label: 'Cool', lit: cooling, tone: 'cool' },
    { label: 'Thrt', lit: throttled, tone: 'amber' },
    { label: 'Over', lit: overload, tone: 'danger', flash: true },
    { label: 'Gov', lit: hacked, tone: 'danger' },
  ];
  const integrityLamps = [
    { label: 'Dmg', lit: damaged, tone: 'danger', flash: true },
    { label: 'Weak', lit: weakEmitter, tone: 'amber' },
    { label: 'Gov', lit: hacked, tone: 'amber' },
    { label: 'None', lit: !emitterIn, tone: 'danger' },
  ];

  return (
    <Stack>
      <Stack.Item grow basis={0}>
        <Gauge
          label="Shots"
          value={cellIn ? cell_data.shots_left : '--'}
          unit="rds"
          sub={cellIn ? `${cell_data.shot_cost} mf per shot` : 'no cell'}
          fraction={chargeFraction}
          color={chargeTone}
          active={selected === 'cell'}
          onClick={() => onSelect('cell')}
          accent={dry || !cellIn ? T.danger : undefined}
          glyph={dry ? <FaultGlyph tone="danger" flash /> : undefined}
          lamps={shotLamps}
        />
      </Stack.Item>
      <Stack.Item grow basis={0}>
        <Gauge
          label="Cell"
          value={`${toFixed(chargeFraction * 100, 0)}`}
          unit="%"
          fraction={chargeFraction}
          sub={
            cellIn
              ? `${cell_data.charge} / ${cell_data.max_charge} mf`
              : 'no cell seated'
          }
          color={chargeTone}
          active={selected === 'cell'}
          onClick={() => onSelect('cell')}
          accent={meltdown || !cellIn ? T.danger : undefined}
          glyph={meltdown ? <FaultGlyph tone="danger" flash /> : undefined}
          lamps={cellLamps}
          actions={
            <MfdButton
              icon="eject"
              disabled={!cellIn}
              tooltip="Drop the cell into your hands"
              onClick={() => act('eject_cell')}
            />
          }
        />
      </Stack.Item>
      <Stack.Item grow basis={0}>
        <Gauge
          label="Thermal"
          value={emitterIn ? `${toFixed(heatPercent, 0)}` : '--'}
          unit="%"
          fraction={heatFraction}
          sub={
            emitterIn
              ? `throttle ${throttlePercent}% · -${phase_emitter_data.heat_dissipation_per_tick}/t`
              : 'no emitter'
          }
          color={heatTone}
          active={selected === 'emitter'}
          onClick={() => onSelect('emitter')}
          accent={
            overload
              ? T.danger
              : throttled
                ? T.amber
                : cooling
                  ? T.cool
                  : undefined
          }
          glyph={
            overload ? (
              <FaultGlyph tone="danger" flash />
            ) : throttled ? (
              <FaultGlyph tone="amber" />
            ) : undefined
          }
          lamps={thermalLamps}
          actions={
            <MfdButton
              icon="snowflake"
              tone={cooling ? 'cool' : 'primary'}
              disabled={!emitterIn}
              active={cooling}
              tooltip="Toggle active cooling"
              onClick={() => act('toggle_cooling_system')}
            />
          }
        />
      </Stack.Item>
      <Stack.Item grow basis={0}>
        <Gauge
          label="Integrity"
          value={
            emitterIn ? `${toFixed(phase_emitter_data.integrity, 0)}` : '--'
          }
          unit="%"
          fraction={integrityFraction}
          sub={`frame dissipation ${gun_heat_dissipation}`}
          color={integrityTone}
          active={selected === 'emitter'}
          onClick={() => onSelect('emitter')}
          accent={
            damaged || !emitterIn ? T.danger : hacked ? T.amber : undefined
          }
          glyph={
            damaged || !emitterIn ? (
              <FaultGlyph tone="danger" flash={damaged} />
            ) : hacked ? (
              <FaultGlyph tone="amber" />
            ) : undefined
          }
          lamps={integrityLamps}
          actions={
            <>
              {hacked ? (
                <MfdButton
                  icon="bolt"
                  tone="danger"
                  tooltip="Remove the emitter's safety governor"
                  onClick={() => act('overclock_emitter')}
                />
              ) : null}
              <MfdButton
                icon="eject"
                disabled={!emitterIn}
                tooltip="Pull the phase emitter out of the frame"
                onClick={() => act('eject_emitter')}
              />
            </>
          }
        />
      </Stack.Item>
    </Stack>
  );
};

// Sprite is display only. SVG images hit-test their whole rect and not their
// pixels, so the top layer would eat every click. Bays get rings instead.
const Schematic = (props) => {
  const { gunIcon, gunIconState, frameOverlays, attachments } = props;
  const { slots, filledSlots, selected, hovered, onSelect, onHover } = props;

  const base = iconUrl(gunIcon, gunIconState);
  if (!base) {
    return <Legend color={T.danger}>Sprite feed unavailable</Legend>;
  }

  return (
    <svg
      viewBox={`0 0 ${ICON_W} ${ICON_H}`}
      width="100%"
      style={{ imageRendering: 'pixelated', display: 'block' }}
    >
      <defs>
        <filter
          id="mfd-outline"
          x="-25%"
          y="-25%"
          width="150%"
          height="150%"
          colorInterpolationFilters="sRGB"
        >
          <feMorphology
            in="SourceAlpha"
            operator="dilate"
            radius="1"
            result="fat"
          />
          <feFlood floodColor={T.amber} result="tint" />
          <feComposite in="tint" in2="fat" operator="in" result="ring" />
          <feMerge>
            <feMergeNode in="ring" />
            <feMergeNode in="SourceGraphic" />
          </feMerge>
        </filter>
      </defs>

      <image
        href={base}
        x={0}
        y={0}
        width={ICON_W}
        height={ICON_H}
        style={{ pointerEvents: 'none' }}
      />
      {frameOverlays.map((state) => {
        const url = iconUrl(gunIcon, state);
        return (
          url && (
            <image
              key={state}
              href={url}
              x={0}
              y={0}
              width={ICON_W}
              height={ICON_H}
              style={{ pointerEvents: 'none' }}
            />
          )
        );
      })}

      {[...attachments]
        .sort(
          (a, b) =>
            SLOT_DEPTH.indexOf(a.slot_id) - SLOT_DEPTH.indexOf(b.slot_id),
        )
        .map((attachment) => {
          const url = iconUrl(gunIcon, attachment.overlay_state);
          if (!url) {
            return null;
          }
          const lit =
            selected === attachment.slot_id || hovered === attachment.slot_id;
          return (
            <image
              key={attachment.ref}
              href={url}
              x={0}
              y={0}
              width={ICON_W}
              height={ICON_H}
              filter={lit ? 'url(#mfd-outline)' : undefined}
              style={{ pointerEvents: 'none' }}
            />
          );
        })}

      {slots.map((slot) => {
        const anchor = SLOT_ANCHORS[slot];
        if (!anchor) {
          return null;
        }
        const filled = !!filledSlots[slot];
        const lit = selected === slot || hovered === slot;
        const stroke = lit ? T.amber : filled ? T.phosphor : T.edge;
        return (
          <g
            key={slot}
            style={{ cursor: 'pointer' }}
            onClick={() => onSelect(slot)}
            onMouseEnter={() => onHover(slot)}
            onMouseLeave={() => onHover(null)}
          >
            <line
              x1={anchor.x}
              y1={anchor.y}
              x2={anchor.ax}
              y2={anchor.ay}
              stroke={stroke}
              strokeWidth={0.35}
              opacity={0.75}
            />
            <circle cx={anchor.ax} cy={anchor.ay} r={0.6} fill={stroke} />
            {/* pad so you hit the ring and not just its stroke */}
            <circle cx={anchor.x} cy={anchor.y} r={3.4} fill="transparent" />
            <circle
              cx={anchor.x}
              cy={anchor.y}
              r={2.6}
              fill={filled ? 'rgba(79,227,171,0.14)' : 'transparent'}
              stroke={stroke}
              strokeWidth={filled ? 0.8 : 0.6}
              strokeDasharray={filled ? undefined : '1.4 1'}
            />
            {filled && (
              <circle cx={anchor.x} cy={anchor.y} r={1.1} fill={stroke} />
            )}
          </g>
        );
      })}
    </svg>
  );
};

const Row = (props) => (
  <Box
    style={{
      display: 'flex',
      justifyContent: 'space-between',
      gap: '10px',
      padding: '3px 0',
      borderBottom: `1px solid rgba(29,106,82,0.35)`,
    }}
  >
    <Legend>{props.label}</Legend>
    <Box
      style={{
        fontFamily: 'monospace',
        fontSize: '0.85rem',
        color: props.color || T.phosphorHot,
        textAlign: 'right',
      }}
    >
      {props.children}
    </Box>
  </Box>
);

const Alert = (props) => (
  <Box
    style={{
      border: `1px solid ${T.danger}`,
      background: 'rgba(255,106,95,0.12)',
      clipPath: CHAMFER(8),
      padding: '6px 10px',
      marginBottom: '8px',
      boxShadow: `0 0 12px rgba(255,106,95,0.35)`,
    }}
  >
    <Legend color={T.danger}>{props.children}</Legend>
  </Box>
);

const EmitterPanel = (props) => {
  const { emitter, present } = props;
  if (!present) {
    return <Alert>No phase emitter seated</Alert>;
  }
  return (
    <>
      {!!emitter.damaged && <Alert>Emitter damaged</Alert>}
      <Row label="Unit">{emitter.type}</Row>
      <Row label="Integrity">{toFixed(emitter.integrity, 1)}%</Row>
      <Row label="Thermal">
        {emitter.current_heat} / {emitter.max_heat}
      </Row>
      <Row label="Throttle at">{emitter.throttle_percentage}%</Row>
      <Row label="Dissipation">{emitter.heat_dissipation_per_tick} / tick</Row>
      <Row label="Cycle time">{emitter.process_time}</Row>
      <Row
        label="Active cooling"
        color={emitter.cooling_system ? T.phosphor : T.label}
      >
        {emitter.cooling_system
          ? `Engaged · ${emitter.cooling_system_rate}/tick`
          : 'Disengaged'}
      </Row>
      <Row label="Governor" color={emitter.hacked ? T.danger : T.label}>
        {emitter.hacked ? 'Bypassed' : 'Intact'}
      </Row>
    </>
  );
};

const CellPanel = (props) => {
  const { cell, present } = props;
  if (!present) {
    return <Alert>No cell seated</Alert>;
  }
  return (
    <>
      {!!cell.status && <Alert>Cell meltdown imminent</Alert>}
      <Row label="Unit">{cell.type}</Row>
      <Row label="Charge">
        {cell.charge} / {cell.max_charge} MF
      </Row>
      <Row label="Remaining">
        {cell.shots_left} shots @ {cell.shot_cost} MF
      </Row>
      <Row label="Modules">
        {cell.attachments.length ? cell.attachments.join(', ') : 'None'}
      </Row>
    </>
  );
};

const AttachmentPanel = (props) => {
  const { act, attachment, label } = props;
  if (!attachment) {
    return (
      <>
        <Alert>{label} bay empty</Alert>
        <Legend>Fit a part by striking the weapon with it.</Legend>
      </>
    );
  }
  return (
    <>
      <Box mb={1} style={{ color: T.label, fontSize: '0.9rem' }}>
        {attachment.desc}
      </Box>
      <Row label="Bay">{attachment.slot}</Row>
      {!!attachment.information && (
        <Row label="Readout">{attachment.information}</Row>
      )}
      {!!attachment.has_modifications && (
        <Box mt={1.5}>
          <Legend>Controls</Legend>
          <Box mt={0.5}>
            {attachment.modify.map((option) => (
              <MfdButton
                key={option.reference}
                icon={option.icon}
                tone={option.color === 'red' ? 'danger' : 'amber'}
                onClick={() =>
                  act('modify_attachment', {
                    attachment_ref: attachment.ref,
                    modify_ref: option.reference,
                  })
                }
              >
                {option.title}
              </MfdButton>
            ))}
          </Box>
        </Box>
      )}
    </>
  );
};

export const MicrofusionGunControl = (props) => {
  const { act, data } = useBackend();
  const {
    gun_name,
    gun_desc,
    gun_icon,
    gun_icon_state,
    frame_overlays = [],
    has_cell,
    cell_data,
    has_emitter,
    phase_emitter_data,
    attachments = [],
    slots = [],
  } = data;

  const [selected, setSelected] = useState('cell');
  const [hovered, setHovered] = useState(null);

  const bySlot = {};
  for (const attachment of attachments) {
    bySlot[attachment.slot_id] = attachment;
  }
  const fitted = bySlot[selected];

  let panelTitle = 'Readout';
  if (selected === 'cell') {
    panelTitle = 'Power Cell';
  } else if (selected === 'emitter') {
    panelTitle = 'Phase Emitter';
  } else if (fitted) {
    panelTitle = fitted.name;
  } else if (SLOT_ANCHORS[selected]) {
    panelTitle = `${SLOT_ANCHORS[selected].label} bay`;
  }

  return (
    <Window
      title={`Micron Control Systems Incorporated: ${gun_name}`}
      width={860}
      height={660}
    >
      <Window.Content
        scrollable
        style={{ background: T.void, backgroundImage: SCANLINES }}
      >
        <style>{KEYFRAMES}</style>
        <Stack fill vertical>
          <Stack.Item>
            <StatusStrip
              act={act}
              data={data}
              selected={selected}
              onSelect={setSelected}
            />
          </Stack.Item>
          <Stack.Item grow>
            <Stack fill>
              <Stack.Item grow={3}>
                <Panel title={gun_name} titleTooltip={gun_desc}>
                  <Box
                    style={{
                      background:
                        'radial-gradient(ellipse at 50% 45%, rgba(30,120,95,0.28), rgba(3,16,11,0.9) 70%)',
                      border: `1px solid ${T.edge}`,
                      clipPath: CHAMFER(10),
                      padding: '14px',
                    }}
                  >
                    <Schematic
                      gunIcon={gun_icon}
                      gunIconState={gun_icon_state}
                      frameOverlays={frame_overlays}
                      attachments={attachments}
                      slots={slots}
                      filledSlots={bySlot}
                      selected={selected}
                      hovered={hovered}
                      onSelect={setSelected}
                      onHover={setHovered}
                    />
                  </Box>
                  <Box mt={1}>
                    <Legend size="0.66rem">
                      Solid rings are fitted · dashed rings are empty
                    </Legend>
                  </Box>
                </Panel>
              </Stack.Item>
              <Stack.Item grow={2}>
                <Panel
                  title={panelTitle}
                  scroll
                  footer={
                    fitted ? (
                      <MfdButton
                        block
                        icon="wrench"
                        tone="danger"
                        onClick={() =>
                          act('remove_attachment', {
                            attachment_ref: fitted.ref,
                          })
                        }
                      >
                        Remove part
                      </MfdButton>
                    ) : undefined
                  }
                >
                  {selected === 'emitter' && (
                    <EmitterPanel
                      emitter={phase_emitter_data}
                      present={has_emitter}
                    />
                  )}
                  {selected === 'cell' && (
                    <CellPanel cell={cell_data} present={has_cell} />
                  )}
                  {selected !== 'emitter' && selected !== 'cell' && (
                    <AttachmentPanel
                      act={act}
                      attachment={fitted}
                      label={SLOT_ANCHORS[selected]?.label || 'This'}
                    />
                  )}
                </Panel>
              </Stack.Item>
            </Stack>
          </Stack.Item>
        </Stack>
      </Window.Content>
    </Window>
  );
};
