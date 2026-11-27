type Child = Node | string | null | false;

// Creates an element: h("li", ["text", h("b", ["bold"])], { class: "item" }).
export default function h(
  tag: string,
  children: Child[] = [],
  attributes: Record<string, string> = {},
) {
  const element = document.createElement(tag);

  for (const [name, value] of Object.entries(attributes)) {
    element.setAttribute(name, value);
  }

  element.append(
    ...children.filter((child) => child !== null && child !== false),
  );

  return element;
}
