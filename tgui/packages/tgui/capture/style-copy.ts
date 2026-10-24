// THIS IS AN APHELION UI FILE

/**
 * Which computed styles a snapshot's clone has to carry. html-to-image copied every kept property onto every node,
 * but the SVG it draws has no author CSS and nothing else: a property no author style can set on an element comes
 * out the same there anyway, from the same tag, attributes and inherited values, so we never read it; one an author
 * style can set gets written only when the SVG would compute something else, which a hidden frame with no author
 * CSS tells us, once per tag, parent tag and parent value
 */

const SVG_NS = 'http://www.w3.org/2000/svg';
const HTML_NS = 'http://www.w3.org/1999/xhtml';
/** Own values no page uses, so a value the frame derives from them can't pass for a real one */
const SENTINEL_COLOR = 'rgb(1, 2, 3)';
const SENTINEL_SIZE = '17.1171px';
const PROBE_SIZE = '23.7px';
const OWN_CLASS = 'meridian-own';
const PLAIN_CLASS = 'meridian-plain';
/** Computed from the parent by more than plain inheritance, so their SVG value is looked up per parent value */
const FROM_PARENT = new Set([
  'display',
  'font-size',
  'font-weight',
  'justify-items',
  'math-depth',
  'text-align',
  '-webkit-text-decorations-in-effect',
]);
/**
 * Inherited properties whose value resolves on each element - a line height without a unit, colours that can be
 * currentcolor - while the clone gets an ancestor's resolved value, so every element and pseudo-element reads them
 */
const RESOLVED_PER_ELEMENT = [
  'line-height',
  '-webkit-text-fill-color',
  '-webkit-text-stroke-color',
  'text-emphasis-color',
  'text-shadow',
  'fill',
  'stroke',
  'accent-color',
  'scrollbar-color',
];
/**
 * A minimum size of auto reads 0px off a flex or grid item's layout, which the frame never lays out, so whatever an
 * author sets there is written
 */
const LAID_OUT = new Set([
  'min-width',
  'min-height',
  'min-inline-size',
  'min-block-size',
]);
/** Read in the frame without our sentinels, since they are the sentinels */
const PLAIN_READ = new Set(['color', 'font-size']);
/** A border's width is zero while its style is none, so the frame's answer holds only for the same style */
const WIDTH_STYLE: Record<string, string> = {
  'border-top-width': 'border-top-style',
  'border-right-width': 'border-right-style',
  'border-bottom-width': 'border-bottom-style',
  'border-left-width': 'border-left-style',
  'border-block-start-width': 'border-block-start-style',
  'border-block-end-width': 'border-block-end-style',
  'border-inline-start-width': 'border-inline-start-style',
  'border-inline-end-width': 'border-inline-end-style',
  'outline-width': 'outline-style',
  'column-rule-width': 'column-rule-style',
};
/**
 * Elements whose own look hangs on things the frame can't copy - form states, nested lists, table attributes, a
 * clone of another tag - so whatever an author style sets on them is written as it is
 */
const WRITE_AS_IS = new Set([
  'button',
  'canvas',
  'datalist',
  'details',
  'dialog',
  'dir',
  'dl',
  'embed',
  'fieldset',
  'font',
  'form',
  'h1',
  'iframe',
  'input',
  'legend',
  'marquee',
  'menu',
  'meter',
  'object',
  'ol',
  'optgroup',
  'option',
  'output',
  'progress',
  'select',
  'summary',
  'textarea',
  'ul',
  'video',
]);
/** UA states the clone never has in the SVG, links included (it never underlines one): an element in one is read whole */
const STATES = [
  ':any-link',
  ':focus',
  ':hover',
  ':active',
  ':popover-open',
  ':modal',
  ':fullscreen',
];
/** Attributes no UA style reads */
const IGNORED_ATTRIBUTE = /^(class|style|id|data-.*|aria-.*|on.*)$/;
/** Attributes whose presence a UA style may read but never their value */
const PRESENCE_ONLY = new Set([
  'alt',
  'download',
  'for',
  'href',
  'name',
  'placeholder',
  'rel',
  'role',
  'src',
  'srcset',
  'tabindex',
  'target',
  'title',
  'value',
  'xlink:href',
]);
/** Rules that never style an element box */
const IGNORED_RULES = new Set([
  'CSSCounterStyleRule',
  'CSSFontFaceRule',
  'CSSFontFeatureValuesRule',
  'CSSFontPaletteValuesRule',
  'CSSKeyframesRule',
  'CSSPropertyRule',
  'CSSViewTransitionRule',
]);

/** What a rule needs an element to have before it can apply, and which box of it the rule styles */
export type Need = {
  /** `id:x`, `class:x` or `tag:x`, or null when it could match any element */
  key: string | null;
  /** The element itself, its ::before or ::after, another pseudo-element, or any of them when we can't tell */
  part: 'self' | 'before' | 'after' | 'other' | 'any';
  /** The compound is CSS nesting's `&`, so it needs what the parent rule needs */
  nested: boolean;
};

const ANY: Need = { key: null, part: 'any', nested: false };
const isIdentChar = (code: number) =>
  (code >= 48 && code <= 57) ||
  (code >= 65 && code <= 90) ||
  (code >= 97 && code <= 122) ||
  code === 45 ||
  code === 95 ||
  code > 127;

/** Skips a bracketed run from its opening character, quotes and nesting included, to just past its close */
function skipGroup(text: string, from: number): number {
  let depth = 0;
  let quote = '';
  for (let at = from; at < text.length; at++) {
    const char = text[at];
    if (quote) {
      if (char === '\\') at++;
      else if (char === quote) quote = '';
    } else if (char === '"' || char === "'") quote = char;
    else if (char === '\\') at++;
    else if (char === '(' || char === '[') depth++;
    else if (char === ')' || char === ']') {
      depth--;
      if (!depth) return at + 1;
    }
  }
  return text.length;
}

/** What one compound selector needs: its id, else a class, else its tag */
function compoundNeed(text: string): Need {
  let key: string | null = null;
  let rank = 0;
  let part: Need['part'] = 'self';
  let nested = false;
  let at = 0;
  const ident = () => {
    const begin = at;
    while (at < text.length && isIdentChar(text.charCodeAt(at))) at++;
    return text.slice(begin, at);
  };
  while (at < text.length) {
    const char = text[at];
    if (char === '\\') return ANY;
    if (char === '.' || char === '#') {
      at++;
      const name = ident();
      if (!name || text[at] === '\\') return ANY;
      const wanted = char === '#' ? 3 : 2;
      if (rank < wanted) {
        key = `${char === '#' ? 'id' : 'class'}:${name}`;
        rank = wanted;
      }
    } else if (char === '&') {
      nested = true;
      at++;
    } else if (char === '*' || char === '|') at++;
    else if (char === '[') at = skipGroup(text, at);
    else if (char === ':') {
      const element = text[at + 1] === ':';
      at += element ? 2 : 1;
      const name = ident().toLowerCase();
      if (text[at] === '(') at = skipGroup(text, at);
      if (name === 'slotted' || name === 'host' || name === 'host-context')
        return ANY;
      const legacy = ['before', 'after', 'first-line', 'first-letter'];
      if (element || legacy.includes(name))
        part =
          name === 'before' ? 'before' : name === 'after' ? 'after' : 'other';
    } else if (isIdentChar(text.charCodeAt(at))) {
      const name = ident();
      // A namespaced type matches by its local name in any case we'd index, so it needs nothing we index
      if (text[at] === '|') at++;
      else if (rank < 1) {
        key = `tag:${name.toLowerCase()}`;
        rank = 1;
      }
    } else return ANY;
  }
  return { key, part, nested };
}

/** What each selector of a selector list needs of an element: the rightmost compound decides */
export function selectorNeeds(selectorText: string): Need[] {
  // An escape can hide a combinator or a class's real name, so we take it for a rule that could match anything
  if (selectorText.includes('\\')) return [ANY];
  const needs: Need[] = [];
  let depth = 0;
  let quote = '';
  let compound = 0;
  for (let at = 0; at < selectorText.length; at++) {
    const char = selectorText[at];
    if (quote) {
      if (char === '\\') at++;
      else if (char === quote) quote = '';
      continue;
    }
    if (char === '\\') at++;
    else if (char === '"' || char === "'") quote = char;
    else if (char === '(' || char === '[') depth++;
    else if (char === ')' || char === ']') depth--;
    else if (!depth) {
      if (char === ',') {
        needs.push(compoundNeed(selectorText.slice(compound, at).trim()));
        compound = at + 1;
      } else if (' \n\t\r\f>+~'.includes(char)) compound = at + 1;
    }
  }
  needs.push(compoundNeed(selectorText.slice(compound).trim()));
  return needs;
}

/** Nesting's `&` alone stands for the parent rule's selectors */
function resolveNesting(needs: Need[], parents: Need[] | null): Need[] {
  if (!parents || !needs.some((need) => need.nested && !need.key)) return needs;
  return needs.flatMap((need) =>
    need.nested && !need.key
      ? parents.map((parent) => ({
          key: parent.key,
          part: need.part === 'self' ? parent.part : need.part,
          nested: false,
        }))
      : [need],
  );
}

type Bucket = {
  self: Set<number>;
  before: Set<number>;
  after: Set<number>;
  beforeContent: boolean;
  afterContent: boolean;
};
type RuleIndex = Map<string, Bucket>;

const bucketOf = (index: RuleIndex, key: string) => {
  let bucket = index.get(key);
  if (!bucket) {
    bucket = {
      self: new Set(),
      before: new Set(),
      after: new Set(),
      beforeContent: false,
      afterContent: false,
    };
    index.set(key, bucket);
  }
  return bucket;
};

/** Every kept property an author style rule declares, filed under what the rule needs of an element */
function indexRules(
  rules: CSSRuleList,
  parents: Need[] | null,
  covered: Map<string, number[]>,
  index: RuleIndex,
) {
  for (const rule of Array.from(rules)) {
    const kind = rule.constructor?.name;
    if (IGNORED_RULES.has(kind)) continue;
    const grouped = rule as CSSGroupingRule;
    const styled = rule as CSSStyleRule;
    if (kind === 'CSSImportRule') {
      const imported = (rule as CSSImportRule).styleSheet;
      if (imported) indexRules(imported.cssRules, null, covered, index);
      continue;
    }
    let needs = parents ?? [ANY];
    if (typeof styled.selectorText === 'string' && kind !== 'CSSPageRule')
      needs = resolveNesting(selectorNeeds(styled.selectorText), parents);
    if (styled.style) {
      const declared: number[] = [];
      for (let at = 0; at < styled.style.length; at++)
        declared.push(...(covered.get(styled.style[at]) ?? []));
      const content = styled.style.getPropertyValue('content') !== '';
      for (const need of needs) {
        if (need.part === 'other') continue;
        const bucket = bucketOf(index, need.key ?? '');
        for (const position of declared) {
          if (need.part === 'self' || need.part === 'any')
            bucket.self.add(position);
          if (need.part === 'before' || need.part === 'any')
            bucket.before.add(position);
          if (need.part === 'after' || need.part === 'any')
            bucket.after.add(position);
        }
        if (content && (need.part === 'before' || need.part === 'any'))
          bucket.beforeContent = true;
        if (content && (need.part === 'after' || need.part === 'any'))
          bucket.afterContent = true;
      }
    }
    if (grouped.cssRules?.length)
      indexRules(
        grouped.cssRules,
        typeof styled.selectorText === 'string' ? needs : parents,
        covered,
        index,
      );
  }
}

/**
 * The kept names each longhand stands for: itself and any shorthand Chromium lists among the computed properties,
 * such as background-position, which a rule only ever declares as its longhands
 */
function coverageOf(names: readonly string[]): Map<string, number[]> {
  const covered = new Map<string, number[]>();
  const scratch = document.createElement('div').style;
  names.forEach((name, position) => {
    scratch.cssText = '';
    scratch.setProperty(name, 'initial');
    for (const part of new Set([name, ...Array.from(scratch)])) {
      const positions = covered.get(part);
      if (positions) positions.push(position);
      else covered.set(part, [position]);
    }
  });
  return covered;
}

/** A stylesheet's index, kept while its rule count and the kept names stay the same */
type SheetIndex = {
  rules: number;
  names: string;
  index: RuleIndex;
  /** Every position some rule declares for an element itself */
  mentioned: Set<number>;
};
const sheetIndexes = new WeakMap<CSSStyleSheet, SheetIndex>();
let coverage = new Map<string, number[]>();
let coverageFor = '';

/** The sheet's index, built once and again only after rules are added or taken away */
function indexOf(
  sheet: CSSStyleSheet,
  names: string,
  covered: Map<string, number[]>,
): SheetIndex {
  const rules = sheet.cssRules;
  const kept = sheetIndexes.get(sheet);
  if (kept && kept.rules === rules.length && kept.names === names) return kept;
  const index: RuleIndex = new Map();
  indexRules(rules, null, covered, index);
  const mentioned = new Set<number>();
  for (const bucket of index.values())
    for (const position of bucket.self) mentioned.add(position);
  const built = { rules: rules.length, names, index, mentioned };
  sheetIndexes.set(sheet, built);
  return built;
}

/** One element's read plan: the kept properties an author style could set on it and on its pseudo-elements */
type Plan = {
  self: number[];
  before: number[];
  after: number[];
  beforeContent: boolean;
  afterContent: boolean;
};

/** The SVG's own value of a property for one element kind: the same for any parent value, or by parent value */
type Outcome = {
  constant?: string;
  byParent?: Map<string, string>;
  first?: string;
};
type Table = {
  outcomes: Outcome[];
  /** The kind takes its font size from its parent unchanged */
  inheritsFontSize: boolean;
  probed: boolean;
};

/** The hidden frame with no author CSS, shared by every snapshot running in this window */
type Sandbox = {
  frame: HTMLIFrameElement;
  doc: Document;
  win: Window;
  holder: HTMLElement;
  users: number;
};
let sandbox: Sandbox | null = null;
/** The frame's answers, kept for the window's life since only the browser's UA styles decide them */
const tables = new Map<string, Table>();
/** Kept properties whose UA value on a tag follows the tag's own font size, which html-to-image writes smaller */
const sizeFollowers = new Map<string, number[]>();
let tablesFor = '';

function openSandbox(): Sandbox | null {
  if (sandbox) {
    sandbox.users++;
    return sandbox;
  }
  try {
    const frame = document.createElement('iframe');
    frame.hidden = true;
    frame.setAttribute('aria-hidden', 'true');
    (document.head ?? document.documentElement).appendChild(frame);
    const doc = frame.contentDocument;
    const win = frame.contentWindow as (Window & typeof globalThis) | null;
    if (!doc || !win) {
      frame.remove();
      return null;
    }
    doc.open();
    doc.write('<!doctype html><html><head></head><body></body></html>');
    doc.close();
    const sheet = new win.CSSStyleSheet();
    sheet.replaceSync(
      `.${OWN_CLASS}::before, .${OWN_CLASS}::after { content: ''; color: ${SENTINEL_COLOR}; font-size: ${SENTINEL_SIZE} }
.${PLAIN_CLASS}::before, .${PLAIN_CLASS}::after { content: '' }`,
    );
    doc.adoptedStyleSheets = [sheet];
    const holder = doc.createElement('div');
    holder.style.display = 'none';
    doc.body.appendChild(holder);
    if (
      doc.compatMode !== 'CSS1Compat' ||
      win.getComputedStyle(holder).display !== 'none'
    ) {
      frame.remove();
      return null;
    }
    sandbox = { frame, doc, win, holder, users: 1 };
    return sandbox;
  } catch {
    return null;
  }
}

function closeSandbox() {
  if (sandbox && --sandbox.users <= 0) {
    sandbox.frame.remove();
    sandbox = null;
  }
}

/** A clone's tag and the attributes UA styles read, which is all the SVG styles it by */
function kindOf(element: Element): string {
  let kind =
    element.namespaceURI === SVG_NS
      ? `svg:${element.localName}`
      : element.localName;
  for (const attribute of Array.from(element.attributes)) {
    if (IGNORED_ATTRIBUTE.test(attribute.name)) continue;
    kind += PRESENCE_ONLY.has(attribute.name)
      ? ` ${attribute.name}`
      : ` ${attribute.name}=${attribute.value}`;
  }
  return kind;
}

/** A copy of the clone in the frame: same tag and UA-read attributes, no resource to load */
function frameCopy(frame: Sandbox, clone: Element): HTMLElement {
  const copy = frame.doc.createElementNS(clone.namespaceURI, clone.localName);
  for (const attribute of Array.from(clone.attributes)) {
    const { name } = attribute;
    if (IGNORED_ATTRIBUTE.test(name) || name === 'srcset') continue;
    copy.setAttribute(
      name,
      name === 'src'
        ? 'data:,'
        : PRESENCE_ONLY.has(name)
          ? ''
          : attribute.value,
    );
  }
  return copy as HTMLElement;
}

/** Which of an element's computed properties its clone has to carry, and which of its inline ones to take off */
export type CopyList = { names: string[]; values: string[]; drop: string[] };
export type StyleCopier = {
  /** The clone's own style, or null to copy every kept property as html-to-image does */
  element(
    native: Element,
    clone: Element,
    parent: Element | null,
  ): CopyList | null;
  /** False when no style could give this pseudo-element content, so it needn't be looked at */
  mayHave(native: Element, pseudo: string): boolean;
  /** A pseudo-element's style given its computed style, or null to copy every kept property */
  pseudo(
    native: Element,
    clone: Element,
    pseudo: string,
    style: CSSStyleDeclaration,
  ): CopyList | null;
  /** The element is decorated, so its live values can go */
  done(native: Element): void;
  /** Lets the hidden frame go once nothing else is using it */
  release(): void;
};

/** What one property's decision needs: its live value, the SVG's own value, and the values a rule compares */
export type Decision = {
  name: string;
  live: string;
  parent: string | undefined;
  /** What the SVG would compute without it, or undefined when we can't tell */
  predicted: string | undefined;
  ownColor?: string;
  ownStyle?: string;
  predictedStyle?: string;
  inheritsFontSize?: boolean;
};

/**
 * Whether the clone must carry this property: only when the SVG would compute something other than the live value.
 * A pseudo-element always carries its content and its font size, since its element's font size is written smaller
 */
export function mustWrite(decision: Decision, pseudo = false): boolean {
  const { name, live, parent, predicted } = decision;
  if (pseudo && (name === 'content' || name === 'font-size')) return true;
  if (predicted === undefined || LAID_OUT.has(name)) return true;
  // html-to-image writes font sizes a little smaller, so one is left to inheritance only where that matches
  if (name === 'font-size')
    return !(
      live === parent &&
      predicted === live &&
      decision.inheritsFontSize
    );
  if (predicted === SENTINEL_COLOR) return live !== decision.ownColor;
  if (WIDTH_STYLE[name])
    return predicted !== live || decision.ownStyle !== decision.predictedStyle;
  return predicted !== live;
}

const byPosition = (one: number, two: number) => one - two;

/** A node as the copy rules see it: its namespace and tag */
export type CopyNode = { namespace: string | null; tag: string };
/** The presentational attributes a table styles its cells by */
const TABLE_ATTRIBUTES = [
  'border',
  'rules',
  'frame',
  'cellpadding',
  'cellspacing',
  'bordercolor',
];

/**
 * How an element's clone gets its style. `whole` copies every kept property as html-to-image did: a snapshot's
 * root, an element in a UA state the SVG won't have, a clone of another tag, anything outside HTML and inline SVG,
 * a row or ruby text the scroll shift could part from its parent. `as-is` writes whatever an author style could
 * set, unasked: form controls, lists, cells of a table with presentational attributes. `predict` writes only what
 * the SVG would compute otherwise
 */
export function copyMode(
  clone: CopyNode,
  nativeTag: string,
  parent: CopyNode | null,
  inState: boolean,
  styledTable: boolean,
): 'whole' | 'as-is' | 'predict' {
  const { tag } = clone;
  if (
    !parent ||
    inState ||
    nativeTag !== tag ||
    parent.namespace !== HTML_NS ||
    (clone.namespace !== HTML_NS &&
      !(clone.namespace === SVG_NS && tag === 'svg')) ||
    (tag === 'tr' && parent.tag === 'table') ||
    (tag === 'rt' && parent.tag === 'ruby')
  )
    return 'whole';
  if (WRITE_AS_IS.has(tag) || ((tag === 'td' || tag === 'th') && styledTable))
    return 'as-is';
  return 'predict';
}

/**
 * The style copier for one snapshot of `root`, or null when something could style the SVG behind our back - a
 * style element in the clone, a shadow root, a stylesheet we can't read, no frame - so html-to-image copies it all
 */
export function createStyleCopier(
  root: HTMLElement,
  nodes: readonly Element[],
  names: readonly string[],
): StyleCopier | null {
  if (root.querySelector('style') || nodes.some((node) => node.shadowRoot))
    return null;
  const positions = new Map(names.map((name, position) => [name, position]));
  const joined = names.join(',');
  if (coverageFor !== joined) {
    coverage = coverageOf(names);
    coverageFor = joined;
  }
  const covered = coverage;
  let indexes: SheetIndex[];
  try {
    indexes = [
      ...Array.from(document.styleSheets),
      ...(document.adoptedStyleSheets ?? []),
    ].map((sheet) => indexOf(sheet, joined, covered));
  } catch {
    // A stylesheet from another origin can't be read, so we can't tell what it sets
    return null;
  }
  const frame = openSandbox();
  if (!frame) return null;
  if (tablesFor !== joined) {
    tables.clear();
    sizeFollowers.clear();
    tablesFor = joined;
  }
  const plans = new Map<string, Plan>();
  /** Elements read and written whole, as html-to-image does */
  const whole = new Set<Element>();
  for (const state of STATES) {
    try {
      for (const element of Array.from(root.querySelectorAll(state)))
        whole.add(element);
    } catch {
      // A state this browser doesn't know can't be on screen either
    }
  }
  // Animations and transitions set values no rule we index declares, so their properties are read too
  const animated = new Map<Element, number[]>();
  for (const animation of document.getAnimations?.() ?? []) {
    const effect = animation.effect as KeyframeEffect | null;
    const target = effect?.target;
    if (!effect || !target || !root.contains(target)) continue;
    if (effect.pseudoElement) {
      whole.add(target);
      continue;
    }
    const found = animated.get(target) ?? [];
    const transition = (animation as CSSTransition).transitionProperty;
    const properties = transition
      ? [transition]
      : effect
          .getKeyframes()
          .flatMap((keyframe) => Object.keys(keyframe))
          .filter(
            (key) =>
              !['offset', 'computedOffset', 'easing', 'composite'].includes(
                key,
              ),
          )
          .map((key) =>
            key === 'cssFloat'
              ? 'float'
              : key.replace(/[A-Z]/g, (upper) => `-${upper.toLowerCase()}`),
          );
    for (const property of properties) {
      const covering = covered.get(property);
      if (covering) found.push(...covering);
      else whole.add(target);
    }
    animated.set(target, found);
  }
  // The frame lays out left to right and top to bottom in the default scheme, so any page that changes those
  // has every element checked for them
  const contextNames = ['direction', 'writing-mode', 'color-scheme'];
  const contextPositions = contextNames
    .map((name) => positions.get(name))
    .filter((position): position is number => position !== undefined);
  const contextual =
    !!root.querySelector('[dir]') ||
    contextPositions.some((position) =>
      indexes.some((sheet) => sheet.mentioned.has(position)),
    ) ||
    nodes.some((node) =>
      contextNames.some((name) =>
        (node as HTMLElement).style?.getPropertyValue(name),
      ),
    );
  const all = names.map((_, position) => position);
  const everywhere = RESOLVED_PER_ELEMENT.map((name) =>
    positions.get(name),
  ).filter((position): position is number => position !== undefined);
  const live = new Map<
    Element,
    { style: CSSStyleDeclaration; values: Map<number, string> }
  >();

  const read = (element: Element, position: number) => {
    let entry = live.get(element);
    if (!entry) {
      entry = { style: getComputedStyle(element), values: new Map() };
      live.set(element, entry);
    }
    let value = entry.values.get(position);
    if (value === undefined) {
      value = entry.style.getPropertyValue(names[position]);
      entry.values.set(position, value);
    }
    return value;
  };
  const planOf = (element: Element): Plan => {
    const signature = `${element.localName}#${element.id}.${element.getAttribute('class') ?? ''}`;
    let plan = plans.get(signature);
    if (plan) return plan;
    const keys = [
      '',
      `tag:${element.localName.toLowerCase()}`,
      ...(element.id ? [`id:${element.id}`] : []),
      ...Array.from(element.classList, (name) => `class:${name}`),
    ];
    const buckets = indexes.flatMap(({ index }) =>
      keys.map((key) => index.get(key)),
    );
    const self = new Set<number>();
    const before = new Set<number>();
    const after = new Set<number>();
    // The UA gives quotes their marks through ::before and ::after
    let beforeContent = element.localName === 'q';
    let afterContent = beforeContent;
    for (const bucket of buckets) {
      if (!bucket) continue;
      for (const position of bucket.self) self.add(position);
      for (const position of bucket.before) before.add(position);
      for (const position of bucket.after) after.add(position);
      beforeContent ||= bucket.beforeContent;
      afterContent ||= bucket.afterContent;
    }
    plan = {
      self: [...self].sort(byPosition),
      before: [...before].sort(byPosition),
      after: [...after].sort(byPosition),
      beforeContent,
      afterContent,
    };
    plans.set(signature, plan);
    return plan;
  };
  const tableOf = (key: string): Table => {
    let table = tables.get(key);
    if (!table) {
      table = {
        outcomes: new Array(names.length),
        inheritsFontSize: false,
        probed: false,
      };
      tables.set(key, table);
    }
    return table;
  };
  /** Records one answer of the frame: a property is inherited, set by the parent, or the same for any parent */
  const record = (
    table: Table,
    position: number,
    parentValue: string,
    answer: string,
  ) => {
    const name = names[position];
    let outcome = table.outcomes[position];
    if (!outcome) {
      outcome = {};
      table.outcomes[position] = outcome;
    }
    if (!outcome.byParent) {
      if (FROM_PARENT.has(name) || answer === parentValue) {
        outcome.byParent = new Map([[parentValue, answer]]);
        outcome.first = parentValue;
      } else outcome.constant = answer;
      return;
    }
    outcome.byParent.set(parentValue, answer);
    // Past one parent value, a property that isn't plainly inherited is the same for any parent
    if (
      !FROM_PARENT.has(name) &&
      answer !== parentValue &&
      answer === outcome.byParent.get(outcome.first as string)
    ) {
      outcome.constant = answer;
      outcome.byParent = undefined;
    }
  };
  /**
   * Asks the frame, in one style pass, for the SVG's own value of each missing property: an element copy under a
   * copy of its parent holding the parent's values, or for a pseudo-element, an element copy holding its own
   */
  const fill = (
    table: Table,
    clone: Element,
    parentTag: string | null,
    pseudo: string | null,
    missing: number[],
    parentValues: string[],
  ) => {
    const { doc, win, holder } = frame;
    const holders: HTMLElement[] = [];
    let own: HTMLElement;
    let plain: HTMLElement;
    const give = (target: HTMLElement) => {
      missing.forEach((position, at) => {
        target.style.setProperty(names[position], parentValues[at]);
      });
    };
    if (pseudo) {
      own = frameCopy(frame, clone);
      plain = frameCopy(frame, clone);
      own.classList.add(OWN_CLASS);
      plain.classList.add(PLAIN_CLASS);
      give(own);
      give(plain);
      holders.push(own, plain);
    } else {
      const host = doc.createElementNS(
        HTML_NS,
        parentTag as string,
      ) as HTMLElement;
      give(host);
      own = frameCopy(frame, clone);
      plain = frameCopy(frame, clone);
      own.style.setProperty('color', SENTINEL_COLOR);
      own.style.setProperty('font-size', SENTINEL_SIZE);
      host.append(own, plain);
      holders.push(host);
    }
    holder.append(...holders);
    const ownStyle = win.getComputedStyle(own, pseudo);
    const plainStyle = win.getComputedStyle(plain, pseudo);
    missing.forEach((position, at) => {
      const name = names[position];
      record(
        table,
        position,
        parentValues[at],
        (PLAIN_READ.has(name) ? plainStyle : ownStyle).getPropertyValue(name),
      );
    });
    if (!table.probed && !pseudo) {
      const host = doc.createElementNS(
        HTML_NS,
        parentTag as string,
      ) as HTMLElement;
      host.style.fontSize = PROBE_SIZE;
      const probe = frameCopy(frame, clone);
      host.append(probe);
      holders.push(host);
      holder.append(host);
      table.inheritsFontSize =
        win.getComputedStyle(probe).fontSize === PROBE_SIZE;
    }
    table.probed = true;
    for (const element of holders) element.remove();
  };
  /** Kept properties whose UA value on this tag follows its own font size, which html-to-image writes smaller */
  const followersOf = (clone: Element): number[] => {
    const tag = `${clone.namespaceURI} ${clone.localName}`;
    let followers = sizeFollowers.get(tag);
    if (followers) return followers;
    const { doc, win, holder } = frame;
    const make = () =>
      doc.createElementNS(clone.namespaceURI, clone.localName) as HTMLElement;
    const small = make();
    const large = make();
    const host = doc.createElement('div');
    const inherited = make();
    small.style.fontSize = '16px';
    large.style.fontSize = PROBE_SIZE;
    host.style.fontSize = PROBE_SIZE;
    host.append(inherited);
    holder.append(small, large, host);
    const smallStyle = win.getComputedStyle(small);
    const largeStyle = win.getComputedStyle(large);
    const found: number[] = [];
    names.forEach((name, position) => {
      if (
        name !== 'font-size' &&
        smallStyle.getPropertyValue(name) !== largeStyle.getPropertyValue(name)
      )
        found.push(position);
    });
    const size = positions.get('font-size');
    if (
      size !== undefined &&
      win.getComputedStyle(inherited).fontSize !== PROBE_SIZE
    )
      found.push(size);
    for (const element of [small, large, host]) element.remove();
    followers = found;
    sizeFollowers.set(tag, followers);
    return followers;
  };
  /** The SVG's own value of each wanted property, after asking the frame for any it hasn't answered */
  const predictAll = (
    table: Table,
    clone: Element,
    parentTag: string | null,
    pseudo: string | null,
    wanted: number[],
    parentOf: (position: number) => string,
  ) => {
    const missing: number[] = [];
    const missingValues: string[] = [];
    for (const position of wanted) {
      const outcome = table.outcomes[position];
      if (outcome?.constant !== undefined) continue;
      const value = parentOf(position);
      if (outcome?.byParent?.has(value)) continue;
      missing.push(position);
      missingValues.push(value);
    }
    if (missing.length || !table.probed)
      fill(table, clone, parentTag, pseudo, missing, missingValues);
    return (position: number) => {
      const outcome = table.outcomes[position];
      return outcome?.constant ?? outcome?.byParent?.get(parentOf(position));
    };
  };
  /** Adds the styles the width rule compares to a read list that has their widths */
  const withOwners = (wanted: number[]) => {
    let extra: number[] | null = null;
    for (const position of wanted) {
      const owner = WIDTH_STYLE[names[position]];
      const ownerPosition = owner ? positions.get(owner) : undefined;
      if (ownerPosition !== undefined && !wanted.includes(ownerPosition)) {
        extra = extra ?? [];
        extra.push(ownerPosition);
      }
    }
    return extra
      ? [...new Set([...wanted, ...extra])].sort(byPosition)
      : wanted;
  };
  const colorPosition = positions.get('color');
  const decide = (
    wanted: number[],
    liveOf: (position: number) => string,
    parentOf: (position: number) => string,
    predict: ((position: number) => string | undefined) | null,
    pseudo: boolean,
    inheritsFontSize: boolean,
    inline: CSSStyleDeclaration | null,
  ): CopyList => {
    const list: CopyList = { names: [], values: [], drop: [] };
    const written = new Set<number>();
    for (const position of wanted) {
      const name = names[position];
      const value = liveOf(position);
      if (predict) {
        const predicted = predict(position);
        const decision: Decision = {
          name,
          live: value,
          parent: parentOf(position),
          predicted,
          inheritsFontSize,
        };
        if (predicted === SENTINEL_COLOR && colorPosition !== undefined)
          decision.ownColor = liveOf(colorPosition);
        const owner = WIDTH_STYLE[name];
        const ownerPosition = owner ? positions.get(owner) : undefined;
        if (ownerPosition !== undefined) {
          decision.ownStyle = liveOf(ownerPosition);
          decision.predictedStyle = predict(ownerPosition);
        }
        if (!mustWrite(decision, pseudo)) continue;
      }
      written.add(position);
      list.names.push(name);
      list.values.push(value);
    }
    // The clone keeps the element's inline style, which the SVG would apply where we write nothing
    if (inline)
      for (let at = 0; at < inline.length; at++) {
        const covering = covered.get(inline[at]);
        if (covering && !covering.some((position) => written.has(position)))
          list.drop.push(inline[at]);
      }
    return list;
  };

  return {
    element(native, clone, parent) {
      const tag = clone.localName;
      const cell = tag === 'td' || tag === 'th';
      const table = cell ? native.closest('table') : null;
      const mode = copyMode(
        { namespace: clone.namespaceURI, tag },
        native.localName,
        parent && { namespace: parent.namespaceURI, tag: parent.localName },
        whole.has(native),
        !!table && TABLE_ATTRIBUTES.some((name) => table.hasAttribute(name)),
      );
      if (mode === 'whole' || !parent) return null;
      const inline = (native as HTMLElement).style ?? null;
      const extras: number[] = [
        ...everywhere,
        ...(animated.get(native) ?? []),
        ...followersOf(clone),
      ];
      if (inline)
        for (let at = 0; at < inline.length; at++)
          extras.push(...(covered.get(inline[at]) ?? []));
      if (contextual) extras.push(...contextPositions);
      const plan = planOf(native);
      const wanted = withOwners(
        extras.length
          ? [...new Set([...plan.self, ...extras])].sort(byPosition)
          : plan.self,
      );
      const liveOf = (position: number) => read(native, position);
      const parentOf = (position: number) => read(parent, position);
      if (contextual) {
        const [direction, mode, scheme] = contextPositions.map(liveOf);
        if (
          direction !== 'ltr' ||
          mode !== 'horizontal-tb' ||
          scheme !== 'normal'
        )
          return decide(all, liveOf, parentOf, null, false, false, inline);
      }
      if (mode === 'as-is')
        return decide(wanted, liveOf, parentOf, null, false, false, inline);
      const answers = tableOf(`${parent.localName}>${kindOf(clone)}`);
      const predict = predictAll(
        answers,
        clone,
        parent.localName,
        null,
        wanted,
        parentOf,
      );
      return decide(
        wanted,
        liveOf,
        parentOf,
        predict,
        false,
        answers.inheritsFontSize,
        inline,
      );
    },
    mayHave(native, pseudo) {
      if (whole.has(native)) return true;
      const plan = planOf(native);
      return pseudo === ':before' ? plan.beforeContent : plan.afterContent;
    },
    pseudo(native, clone, pseudo, style) {
      if (whole.has(native) || clone.namespaceURI !== HTML_NS) return null;
      const plan = planOf(native);
      const always = [
        positions.get('content'),
        positions.get('font-size'),
      ].filter((position): position is number => position !== undefined);
      always.push(...everywhere);
      const wanted = withOwners(
        [
          ...new Set([
            ...(pseudo === ':before' ? plan.before : plan.after),
            ...always,
          ]),
        ].sort(byPosition),
      );
      const values = new Map<number, string>();
      const liveOf = (position: number) => {
        let value = values.get(position);
        if (value === undefined) {
          value = style.getPropertyValue(names[position]);
          values.set(position, value);
        }
        return value;
      };
      const parentOf = (position: number) => read(native, position);
      const table = tableOf(`${kindOf(clone)}${pseudo}`);
      const predict = predictAll(table, clone, null, pseudo, wanted, parentOf);
      return decide(wanted, liveOf, parentOf, predict, true, false, null);
    },
    done(native) {
      live.delete(native);
    },
    release() {
      live.clear();
      closeSandbox();
    },
  };
}
