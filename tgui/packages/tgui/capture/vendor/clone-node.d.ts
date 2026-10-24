import type { Options } from './types';
export declare function cloneNode<T extends HTMLElement>(node: T, options: Options, isRoot?: boolean, parentNode?: Element | null): Promise<T | null>;
