export default function h(
  type: string,
  children: any[] = [],
  attrs: Record<string, any> = {}
) {
  const el = document.createElement(type);

  for (const [key, value] of Object.entries(attrs)) {
    if (value) {
      if (value === true) {
        el.setAttribute(key, key);
      } else {
        el.setAttribute(key, value);
      }
    }
  }

  children.forEach((child) => {
    if ((child as any) instanceof Node) {
      el.appendChild(child);
    } else if (child) {
      el.appendChild(document.createTextNode(String(child)));
    }
  });

  return el;
}
