import type { CommandHandlers } from "../protocol/commands";
import { removeAttribute, setAttribute } from "./attributes";
import { replaceChildren } from "./children";
import { callElementMethod } from "./element-calls";
import { createTreeRootNodes, setupTree } from "./hydrate";
import type NodeRegistry from "./node-registry";

export type DomCommandName =
  | "Initialize"
  | "CreateTree"
  | "ReplaceChildren"
  | "RemoveNode"
  | "SetAttribute"
  | "RemoveAttribute"
  | "AddClass"
  | "RemoveClass"
  | "SetListener"
  | "RemoveListener"
  | "SetCSSProperty"
  | "RemoveCSSProperty"
  | "SetTextContent"
  | "ElementCall"
  | "RegisterCustomElement";

// The commands that create, change and remove DOM nodes.
export default function domHandlers(
  registry: NodeRegistry,
): CommandHandlers<DomCommandName> {
  return {
    Initialize(tree) {
      registry.clear();
      setupTree(registry, document, tree);
    },
    CreateTree(html, trees) {
      const roots = createTreeRootNodes(html, trees);
      trees.forEach((tree, index) => setupTree(registry, roots[index], tree));
    },
    ReplaceChildren(id, childIds) {
      replaceChildren(registry, id, childIds);
    },
    RemoveNode(id) {
      registry.deleteNode(id);
    },
    SetAttribute(id, name, value) {
      setAttribute(registry.getElement(id), name, value);
    },
    RemoveAttribute(id, name) {
      removeAttribute(registry.getElement(id), name);
    },
    AddClass(id, classes) {
      registry.getElement(id).classList.add(...classes);
    },
    RemoveClass(id, classes) {
      registry.getElement(id).classList.remove(...classes);
    },
    SetListener(id, name, listenerId) {
      registry.setListener(id, name, listenerId);
    },
    RemoveListener(id, name, listenerId) {
      registry.removeListener(id, name, listenerId);
    },
    SetCSSProperty(id, name, value) {
      registry.getElement(id).style.setProperty(name, value);
    },
    RemoveCSSProperty(id, name) {
      registry.getElement(id).style.removeProperty(name);
    },
    SetTextContent(id, content) {
      registry.getCharacterData(id).data = content;
    },
    // A node removed by an earlier command is reported, not an error.
    ElementCall(id, method, args) {
      callElementMethod(registry.findNode(id), method, args ?? []);
    },
    RegisterCustomElement(name, path) {
      if (customElements.get(name)) return;

      // Klenod appends customElements.define to every custom element module,
      // so importing the module is what registers the element.
      void import(path);
    },
  };
}
