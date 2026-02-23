import { useCallback, useRef, useEffect } from 'react';

const DEFAULT_ROOT_MARGIN = '200px';

type Options = { rootMargin?: string; root?: Element | null };

/**
 * Returns a ref callback: pass (id) => ref and assign to the row element.
 * When the row enters the near-viewport (rootMargin), onEnter(id) is called once per id.
 * Uses a single IntersectionObserver for all registered elements (no leak, efficient).
 */
export function useNearViewportWarm(
  onEnter: (id: string) => void,
  options: Options = {}
): (id: string) => (el: HTMLElement | null) => void {
  const rootMargin = options.rootMargin ?? DEFAULT_ROOT_MARGIN;
  const root = options.root ?? null;
  const idByTarget = useRef<WeakMap<Element, string>>(new WeakMap());
  const observerRef = useRef<IntersectionObserver | null>(null);
  const onEnterRef = useRef(onEnter);
  onEnterRef.current = onEnter;

  useEffect(() => {
    observerRef.current = new IntersectionObserver(
      (entries) => {
        entries.forEach((entry) => {
          if (!entry.isIntersecting) return;
          const id = idByTarget.current.get(entry.target);
          if (id) onEnterRef.current(id);
        });
      },
      { root, rootMargin, threshold: 0 }
    );
    return () => {
      observerRef.current?.disconnect();
      observerRef.current = null;
    };
  }, [root, rootMargin]);

  const elementById = useRef<Map<string, Element>>(new Map());

  return useCallback(
    (id: string) =>
      (el: HTMLElement | null) => {
        const obs = observerRef.current;
        if (!obs) return;
        const prev = elementById.current.get(id);
        if (prev) {
          obs.unobserve(prev);
          idByTarget.current.delete(prev);
          elementById.current.delete(id);
        }
        if (el) {
          elementById.current.set(id, el);
          idByTarget.current.set(el, id);
          obs.observe(el);
        }
      },
    []
  );
}
