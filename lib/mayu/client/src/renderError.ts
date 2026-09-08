import h from "./h";

export function clearRenderError() {
  document.querySelectorAll("mayu-exception").forEach((e) => e.remove());
}

export default function renderError(
  file: string,
  type: string,
  message: string,
  backtrace: string[],
  source: string | null,
  treePath: { name: string; path?: string }[]
) {
  const formats: string[] = [];
  const buf: string[] = [];

  buf.push(`%c${type}: ${message}`);
  formats.push("font-size: 1.25em");

  treePath.forEach((path, i) => {
    const indent = "  ".repeat(i);
    if (path.path) {
      buf.push(`%c${indent}%%%c${path.name} %c(${path.path})`);
      formats.push("color: #ff4d6d;", "color: #7fd1ff;", "color: #9aa3b2;");
    } else {
      buf.push(`%c${indent}%%%c${path.name}`);
      formats.push("color: #ff4d6d;", "color: #7fd1ff;");
    }
  });

  backtrace.forEach((line) => {
    buf.push(`%c${line}`);

    formats.push(
      line.startsWith(`${file}:`)
        ? "font-size: 1em; font-weight: 600; text-shadow: 0 0 3px #000;"
        : "font-size: 1em;"
    );
  });

  console.error(buf.join("\n"), ...formats);

  clearRenderError();
  const element = document.createElement("mayu-exception");

  const interestingLines = new Set<number>();

  backtrace.forEach((line) => {
    if (line.startsWith(`${file}:`)) {
      interestingLines.add(Number(line.split(":")[1]));
    }
  });

  const exceptionClass = h("span", [type], {
    slot: "exception-class",
    class: "exception-class",
  });

  const filename = h("span", [file || "Runtime Error"], {
    slot: "filename",
    class: "filename",
  });

  const errorMessage = h("span", [message], {
    slot: "message",
    class: "message",
  });

  const treeItems = treePath.map((path, i) => {
    const indent = "  ".repeat(i);
    const line =
      indent + "%" + path.name + (path.path ? ` (${path.path})` : "");

    return h("li", [line], { slot: "tree-path", class: "tree-item" });
  });

  const backtraceItems = backtrace.map((line) => {
    const isInteresting = line.startsWith(`${file}:`);
    const className = isInteresting
      ? "trace-item is-interesting"
      : "trace-item";

    return h("li", [line], {
      slot: "backtrace",
      class: className,
    });
  });

  const sourceItems = (source ? source.split("\n") : []).map((line, i) => {
    const isInteresting = interestingLines.has(i + 1);
    const className = isInteresting
      ? "source-line is-interesting"
      : "source-line";
    const number = String(i + 1).padStart(4, " ");
    const content = `${number}  ${line}`;

    return h("li", [content], {
      slot: "source",
      class: className,
    });
  });

  element.replaceChildren(
    exceptionClass,
    filename,
    errorMessage,
    ...treeItems,
    ...backtraceItems,
    ...sourceItems
  );

  document.body.appendChild(element);
}
