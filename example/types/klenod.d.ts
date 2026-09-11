declare namespace Klenod {
  interface ImageBase {
    readonly src: string;
    readonly width: number;
    readonly height: number;
    readonly contentType: string;
    readonly aspectRatio: number;
  }

  interface ImageVariant extends ImageBase {
    readonly format: string;
    readonly descriptor: string;
    readonly quality?: number;
  }

  interface ImageMetadata extends ImageBase {
    readonly variants: ReadonlyArray<ImageVariant>;
    readonly srcset: string | null;
    readonly sizes: string | null;
  }

  interface SvgMetadata {
    readonly src: string;
    readonly width: number | null;
    readonly height: number | null;
    readonly contentType: "image/svg+xml";
    readonly aspectRatio: number | null;
  }
}

declare const __klenod_jsx: {
  h(
    type:
      | string
      | CustomElementConstructor
      | ((
          attrs: Record<string, unknown> | null,
          ...children: unknown[]
        ) => Node),
    attrs: any,
    ...children: unknown[]
  ): Node;

  Fragment(attrs: any, ...children: unknown[]): DocumentFragment;
};

declare module "*.css" {
  const stylesheet: CSSStyleSheet;
  export default stylesheet;
}

declare module "*.svg" {
  const asset: Klenod.SvgMetadata;
  export default asset;
}

declare module "*.avif" {
  const asset: Klenod.ImageMetadata;
  export default asset;
}

declare module "*.png" {
  const asset: Klenod.ImageMetadata;
  export default asset;
}

declare module "*.jpg" {
  const asset: Klenod.ImageMetadata;
  export default asset;
}

declare module "*.jpeg" {
  const asset: Klenod.ImageMetadata;
  export default asset;
}

declare module "*.webp" {
  const asset: Klenod.ImageMetadata;
  export default asset;
}

declare module "*.gif" {
  const asset: Klenod.ImageMetadata;
  export default asset;
}

declare namespace JSX {
  type Element = Node;
  type ElementType =
    | string
    | CustomElementConstructor
    | ((attrs: any, ...children: unknown[]) => Node);

  interface ElementChildrenAttribute {
    children: {};
  }

  interface IntrinsicElements {
    [name: string]: any;
  }
}
