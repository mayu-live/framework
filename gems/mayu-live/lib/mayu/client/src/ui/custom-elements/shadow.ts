// What the custom elements share. Each element is a pair of files: its
// markup and styles in `name.html`, its behaviour in `name.ts`.
//
//   const stamp = shadowTemplate(html);
//
//   class MyElement extends HTMLElement {
//     #root = stamp(this);
//     #label = part<HTMLSpanElement>(this.#root, "label");
//   }
//
// The shadow root is filled in the constructor, so the parts exist for the
// whole life of the element and no callback has to check for them.

// Parses an element's HTML once. The function it returns gives an element a
// shadow root with a copy of it.
export function shadowTemplate(html: string) {
  const template = document.createElement("template");
  template.innerHTML = html;

  return (host: HTMLElement): ShadowRoot => {
    const root = host.shadowRoot ?? host.attachShadow({ mode: "open" });
    root.replaceChildren(template.content.cloneNode(true));
    return root;
  };
}

// The element with this id in the template. Ids are scoped to the shadow
// root. A part the template does not have is a mistake in the element, so
// it fails loudly, here, rather than wherever the part is first used.
export function part<T extends Element>(root: ShadowRoot, id: string): T {
  const element = root.getElementById(id);
  if (!element) {
    throw new Error(`<${root.host.localName}> has no #${id} in its template`);
  }
  return element as unknown as T;
}
