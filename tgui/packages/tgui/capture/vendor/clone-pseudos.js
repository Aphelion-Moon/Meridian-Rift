import { uuid, getStyleProperties } from './util';
function formatCSSText(style) {
    const content = style.getPropertyValue('content');
    return `${style.cssText} content: '${content.replace(/'|"/g, '')}';`;
}
function formatCSSProperties(style, options) {
    return getStyleProperties(options)
        .map((name) => {
        const value = style.getPropertyValue(name);
        const priority = style.getPropertyPriority(name);
        return `${name}: ${value}${priority ? ' !important' : ''};`;
    })
        .join(' ');
}
function getPseudoElementStyle(className, pseudo, style, options) {
    const selector = `.${className}:${pseudo}`;
    const cssText = style.cssText
        ? formatCSSText(style)
        : formatCSSProperties(style, options);
    return document.createTextNode(`${selector}{${cssText}}`);
}
// Meridian: the copier's properties in the rule text formatCSSProperties writes
function formatCopyList(list) {
    return list.names.map((name, index) => `${name}: ${list.values[index]};`).join(' ');
}
function clonePseudoElement(nativeNode, clonedNode, pseudo, options) {
    const copier = options.copier;
    // Meridian: no style could give this pseudo-element content, so its style isn't computed
    if (copier && !copier.mayHave(nativeNode, pseudo)) {
        return;
    }
    const style = window.getComputedStyle(nativeNode, pseudo);
    const content = style.getPropertyValue('content');
    if (content === '' || content === 'none') {
        return;
    }
    // Meridian: the copier's list for this pseudo-element, or null to copy every kept property
    const list = copier && !style.cssText ? copier.pseudo(nativeNode, clonedNode, pseudo, style) : null;
    const className = uuid();
    try {
        clonedNode.className = `${clonedNode.className} ${className}`;
    }
    catch (err) {
        return;
    }
    const styleElement = document.createElement('style');
    // Meridian: with a list, the rule holds only its properties
    styleElement.appendChild(list
        ? document.createTextNode(`.${className}:${pseudo}{${formatCopyList(list)}}`)
        : getPseudoElementStyle(className, pseudo, style, options));
    clonedNode.appendChild(styleElement);
}
export function clonePseudoElements(nativeNode, clonedNode, options) {
    clonePseudoElement(nativeNode, clonedNode, ':before', options);
    clonePseudoElement(nativeNode, clonedNode, ':after', options);
}
