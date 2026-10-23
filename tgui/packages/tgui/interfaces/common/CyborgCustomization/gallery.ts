import { useCallback, useEffect, useMemo, useReducer } from 'react';
import type { CyborgCustomizationData, CyborgGallery } from './types';

type Models = CyborgCustomizationData['models'];
type Thumbnails = Record<string, Record<string, string>>;
type Resource<T> = {
  url: string;
  value?: T;
  error?: boolean;
  controller?: AbortController;
  users: number;
};

/** One public catalog generation, with one successful entry per authored department.
 * Private preview images and layouts never enter this cache.
 */
export class CyborgGalleryCache {
  private generation?: string;
  private catalog?: Resource<Models>;
  private departments = new Map<string, Resource<Thumbnails>>();
  private listeners = new Set<() => void>();

  private notify = () => {
    for (const listener of this.listeners) listener();
  };

  private load<T>(resource: Resource<T>, parse: (value: unknown) => T) {
    if (resource.value || resource.controller || resource.error) return;
    const controller = new AbortController();
    resource.controller = controller;
    void fetch(resource.url, { signal: controller.signal })
      .then((response) => {
        if (!response.ok) throw new Error('Gallery asset unavailable');
        return response.json();
      })
      .then((value) => {
        if (!controller.signal.aborted) resource.value = parse(value);
      })
      .catch(() => {
        if (!controller.signal.aborted) resource.error = true;
      })
      .finally(() => {
        if (resource.controller !== controller) return;
        resource.controller = undefined;
        this.notify();
      });
  }

  acquire(gallery: CyborgGallery, listener: () => void) {
    if (
      this.generation !== gallery.generation ||
      this.catalog?.url !== gallery.catalog_url
    ) {
      this.catalog?.controller?.abort();
      for (const resource of this.departments.values())
        resource.controller?.abort();
      this.generation = gallery.generation;
      this.catalog = { url: gallery.catalog_url, users: 0 };
      this.departments.clear();
    }
    const catalog = this.catalog!;
    let thumbnails: Resource<Thumbnails> | undefined;
    if (gallery.department && gallery.thumbnails_url) {
      thumbnails = this.departments.get(gallery.department);
      if (thumbnails?.url !== gallery.thumbnails_url) {
        thumbnails?.controller?.abort();
        thumbnails = { url: gallery.thumbnails_url, users: 0 };
        this.departments.set(gallery.department, thumbnails);
      }
      thumbnails.users++;
      this.load(thumbnails, parseThumbnails);
    }
    catalog.users++;
    this.listeners.add(listener);
    this.load(catalog, parseModels);
    this.notify();
    return () => {
      this.listeners.delete(listener);
      for (const resource of [catalog, thumbnails]) {
        if (resource && --resource.users === 0 && resource.controller) {
          resource.controller.abort();
          resource.controller = undefined;
        }
      }
    };
  }

  read(gallery?: CyborgGallery) {
    if (
      !gallery ||
      gallery.generation !== this.generation ||
      gallery.catalog_url !== this.catalog?.url
    )
      return { models: [] as Models, loading: !!gallery, error: false };
    const images = gallery.department
      ? this.departments.get(gallery.department)
      : undefined;
    const thumbnails =
      images?.url === gallery.thumbnails_url ? images : undefined;
    const models = this.catalog.value || [];
    return {
      models: thumbnails?.value
        ? models.map((model) =>
            model.department === gallery.department
              ? { ...model, thumbnail_directions: thumbnails.value![model.id] }
              : model,
          )
        : models,
      loading:
        (!this.catalog.value && !this.catalog.error) ||
        (!!gallery.thumbnails_url && !thumbnails?.value && !thumbnails?.error),
      error: !!this.catalog.error || !!thumbnails?.error,
    };
  }

  retry(gallery?: CyborgGallery) {
    if (!gallery || gallery.generation !== this.generation) return;
    if (this.catalog?.error) {
      this.catalog.error = false;
      this.load(this.catalog, parseModels);
    }
    const thumbnails =
      gallery.department && this.departments.get(gallery.department);
    if (
      thumbnails &&
      thumbnails.url === gallery.thumbnails_url &&
      thumbnails.error
    ) {
      thumbnails.error = false;
      this.load(thumbnails, parseThumbnails);
    }
    this.notify();
  }
}

function parseModels(value: unknown): Models {
  if (
    !Array.isArray(value) ||
    !value.every(
      (model) =>
        model &&
        ['id', 'department', 'skin'].every(
          (key) => typeof model[key] === 'string',
        ),
    )
  )
    throw new Error('Invalid gallery catalog');
  return value;
}

function parseThumbnails(value: unknown): Thumbnails {
  if (!value || typeof value !== 'object' || Array.isArray(value))
    throw new Error('Invalid gallery thumbnails');
  for (const directions of Object.values(value)) {
    if (
      !directions ||
      typeof directions !== 'object' ||
      Array.isArray(directions)
    )
      throw new Error('Invalid gallery directions');
    for (const [direction, image] of Object.entries(directions))
      if (
        !['1', '2', '4', '8'].includes(direction) ||
        typeof image !== 'string'
      )
        throw new Error('Invalid gallery image');
  }
  return value as Thumbnails;
}

const publicGallery = new CyborgGalleryCache();

export function useCyborgGallery(gallery?: CyborgGallery) {
  const [revision, refresh] = useReducer((value) => value + 1, 0);
  const { generation, catalog_url, department, thumbnails_url } = gallery || {};
  useEffect(() => {
    if (!generation || !catalog_url) return;
    return publicGallery.acquire(
      { generation, catalog_url, department, thumbnails_url },
      refresh,
    );
  }, [generation, catalog_url, department, thumbnails_url]);
  const retry = useCallback(() => {
    if (generation && catalog_url)
      publicGallery.retry({
        generation,
        catalog_url,
        department,
        thumbnails_url,
      });
  }, [generation, catalog_url, department, thumbnails_url]);
  const result = useMemo(
    () =>
      publicGallery.read(
        generation && catalog_url
          ? { generation, catalog_url, department, thumbnails_url }
          : undefined,
      ),
    [generation, catalog_url, department, thumbnails_url, revision],
  );
  return { ...result, retry };
}
