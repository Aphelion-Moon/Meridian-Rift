import type { Options } from './types';
/** Meridian: parentNode is the native node the clone inherits from, for the style copier */
export declare function cloneNode<T extends HTMLElement>(node: T, options: Options, isRoot?: boolean, parentNode?: Element | null): Promise<T | null>;
