import { cloneNode } from './vendor/clone-node';
import { embedImages } from './vendor/embed-images';
import { embedWebFonts } from './vendor/embed-webfonts';
import { createImage, nodeToDataURL } from './vendor/util';
import type { Options } from './vendor/types';
import { SNAPSHOT_ENCODED_LIMIT } from './transfer';

/** One DOM reconstruction of the selected UI. This is not an OS/window screenshot. */
export async function renderUiSnapshot(root: HTMLElement): Promise<string> {
  const nodes: HTMLElement[] = [root];
  const walker = document.createTreeWalker(root, NodeFilter.SHOW_ELEMENT);
  while (walker.nextNode()) {
    if (nodes.length >= 5000)
      throw new Error(
        'This UI is too complex to snapshot; use a screenshot file.',
      );
    nodes.push(walker.currentNode as HTMLElement);
  }
  const bounds = root.getBoundingClientRect();
  const width = Math.ceil(bounds.width),
    height = Math.ceil(bounds.height);
  if (!width || !height || width > 4096 || height > 4096)
    throw new Error('This UI is too large to snapshot.');
  const controller = new AbortController();
  const timeout = setTimeout(() => controller.abort(), 12000);
  const marker = 'data-meridian-report-scroll';
  const scrolling = nodes.filter((node) => node.scrollTop || node.scrollLeft);
  const previous = scrolling.map((node) => node.getAttribute(marker));
  const options: Options = {
    width,
    height,
    pixelRatio: 1,
    fetchRequestInit: { signal: controller.signal, credentials: 'same-origin' },
    filter: (node) =>
      !['SCRIPT', 'IFRAME', 'VIDEO'].includes(node.tagName) &&
      !(node instanceof HTMLInputElement && node.type === 'password'),
  };
  try {
    scrolling.forEach((node, index) =>
      node.setAttribute(marker, String(index)),
    );
    const clone = await cloneNode(root, options, true);
    if (!clone) throw new Error('Could not snapshot this UI.');
    // DOM cloning does not retain scroll offsets. Apply them only to the detached
    // clone, leaving the live machine UI untouched.
    scrolling.forEach((source, index) => {
      const target =
        index === Number(clone.getAttribute(marker)) &&
        clone.hasAttribute(marker)
          ? clone
          : clone.querySelector<HTMLElement>(`[${marker}="${index}"]`);
      if (!target) return;
      const content = document.createElement('div');
      const style = getComputedStyle(source);
      for (const property of [
        'display',
        'flex-direction',
        'flex-wrap',
        'align-items',
        'justify-content',
        'gap',
        'grid-template-columns',
        'grid-template-rows',
      ]) {
        content.style.setProperty(property, style.getPropertyValue(property));
      }
      content.style.width = `${source.scrollWidth}px`;
      content.style.transform = `translate(${-source.scrollLeft}px, ${-source.scrollTop}px)`;
      while (target.firstChild) content.appendChild(target.firstChild);
      target.appendChild(content);
      Object.assign(target.style, {
        display: 'block',
        overflow: 'hidden',
        width: `${source.offsetWidth}px`,
        height: `${source.offsetHeight}px`,
      });
    });
    Object.assign(clone.style, {
      margin: '0',
      width: `${width}px`,
      height: `${height}px`,
      overflow: 'hidden',
    });
    await embedWebFonts(clone, options);
    await embedImages(clone, options);
    if (controller.signal.aborted) throw new Error('UI snapshot timed out.');
    const svg = await nodeToDataURL(clone, width, height);
    const image = await createImage(svg);
    const scale = Math.min(1, 1600 / width, 1200 / height);
    const canvas = document.createElement('canvas');
    canvas.width = Math.max(1, Math.round(width * scale));
    canvas.height = Math.max(1, Math.round(height * scale));
    const context = canvas.getContext('2d');
    if (!context) throw new Error('This client cannot render a UI snapshot.');
    context.fillStyle =
      getComputedStyle(document.body).backgroundColor || '#171717';
    context.fillRect(0, 0, canvas.width, canvas.height);
    context.drawImage(image, 0, 0, canvas.width, canvas.height);
    const result = canvas.toDataURL('image/png');
    if (
      result.length - 'data:image/png;base64,'.length >
      SNAPSHOT_ENCODED_LIMIT
    ) {
      throw new Error(
        'This UI snapshot exceeds 2 MiB; use a smaller screenshot file.',
      );
    }
    return result;
  } finally {
    clearTimeout(timeout);
    scrolling.forEach((node, index) => {
      if (previous[index] === null) node.removeAttribute(marker);
      else node.setAttribute(marker, previous[index]!);
    });
  }
}
