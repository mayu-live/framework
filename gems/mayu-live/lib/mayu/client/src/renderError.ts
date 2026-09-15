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
  treePath: { name: string; path?: string }[],
  line: number | null = null,
  column: number | null = null,
  hints: string[] = [],
) {
  const location =
    line === null
      ? file
      : `${file}:${[line, column].filter((n) => n !== null).join(":")}`;

  const interestingLines = new Set<number>();

  // A build error carries its location directly. A runtime error only has a
  // backtrace, so fall back to the frames that name this file.
  if (line !== null) {
    interestingLines.add(line);
  }

  backtrace.forEach((entry) => {
    if (!entry.startsWith(`${file}:`)) return;

    // Module ids contain colons ("app:/page.haml"), so the line number is the
    // first segment after the filename, not after the first colon.
    const lineNumber = Number.parseInt(entry.slice(file.length + 1), 10);

    if (Number.isInteger(lineNumber)) {
      interestingLines.add(lineNumber);
    }
  });

  logToConsole(
    location,
    type,
    message,
    backtrace,
    source,
    treePath,
    hints,
    interestingLines,
  );

  clearRenderError();
  const element = document.createElement("mayu-exception");

  const exceptionClass = h("span", [type], {
    slot: "exception-class",
    class: "exception-class",
  });

  const filename = h("span", [location || "Runtime Error"], {
    slot: "filename",
    class: "filename",
  });

  const errorMessage = h("span", [message], {
    slot: "message",
    class: "message",
  });

  const hintItems = hints.map((hint) =>
    h("li", [hint], { slot: "hints", class: "hint-item" }),
  );

  const treeItems = treePath.map((path, i) => {
    const indent = "  ".repeat(i);
    const text =
      indent + "%" + path.name + (path.path ? ` (${path.path})` : "");

    return h("li", [text], { slot: "tree-path", class: "tree-item" });
  });

  const backtraceItems = backtrace.map((entry) => {
    const isInteresting = entry.startsWith(`${file}:`);
    const className = isInteresting
      ? "trace-item is-interesting"
      : "trace-item";

    return h("li", [entry], {
      slot: "backtrace",
      class: className,
    });
  });

  const sourceLines = source ? source.split("\n") : [];
  const gutter = String(sourceLines.length).length;
  const sourceItems: HTMLElement[] = [];

  sourceLines.forEach((text, i) => {
    const lineNumber = i + 1;
    const isInteresting = interestingLines.has(lineNumber);
    const number = String(lineNumber).padStart(gutter, " ");

    sourceItems.push(
      h("li", [`${number}  ${text}`], {
        slot: "source",
        class: isInteresting ? "source-line is-interesting" : "source-line",
      }),
    );

    if (isInteresting && column !== null && lineNumber === line) {
      const caret = " ".repeat(gutter + 2 + Math.max(column - 1, 0)) + "^";

      sourceItems.push(
        h("li", [caret], { slot: "source", class: "source-caret" }),
      );
    }
  });

  element.replaceChildren(
    exceptionClass,
    filename,
    errorMessage,
    ...hintItems,
    ...treeItems,
    ...backtraceItems,
    ...sourceItems,
  );

  document.body.appendChild(element);

  // Long files would otherwise open scrolled to the top, away from the error.
  try {
    element
      .querySelector(".source-line.is-interesting")
      ?.scrollIntoView({ block: "center" });
  } catch {
    // scrollIntoView is not implemented in every environment.
  }
}

function logToConsole(
  location: string,
  type: string,
  message: string,
  backtrace: string[],
  source: string | null,
  treePath: { name: string; path?: string }[],
  hints: string[],
  interestingLines: Set<number>,
) {
  const formats: string[] = [];
  const buf: string[] = [];

  buf.push(`%c${type}: ${message}`);
  formats.push("font-size: 1.25em");

  buf.push(`%c${location}`);
  formats.push("color: #9aa3b2;");

  hints.forEach((hint) => {
    buf.push(`%c${hint}`);
    formats.push("color: #7fd1ff;");
  });

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

  // Show a window around the error rather than the whole file.
  if (source && interestingLines.size > 0) {
    const lines = source.split("\n");
    const first = Math.max(Math.min(...interestingLines) - 3, 0);
    const last = Math.min(Math.max(...interestingLines) + 2, lines.length - 1);
    const gutter = String(last + 1).length;

    for (let i = first; i <= last; i++) {
      const lineNumber = i + 1;
      const marked = interestingLines.has(lineNumber);
      const number = String(lineNumber).padStart(gutter, " ");

      buf.push(`%c${marked ? ">" : " "} ${number} | ${lines[i]}`);
      formats.push(marked ? "color: #ff8fa3;" : "color: #9aa3b2;");
    }
  }

  backtrace.forEach((entry) => {
    buf.push(`%c${entry}`);
    formats.push("font-size: 1em;");
  });

  console.error(buf.join("\n"), ...formats);
}
