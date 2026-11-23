import h from "./h";

function clearRenderError() {
  document.querySelectorAll("mayu-exception").forEach((e) => e.remove());
}

export default async function renderError(
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
  // Registers <mayu-exception>; loaded here so a page without errors never
  // downloads the overlay.
  await import("./custom-elements/mayu-exception");

  // A file ends with a newline, which would otherwise show as an empty
  // last line.
  const sourceText = source === null ? null : source.replace(/\n$/, "");

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
    const frame = parseFrame(entry);
    if (frame && frame.file === file) {
      interestingLines.add(frame.line);
    }
  });

  logToConsole(
    location,
    type,
    message,
    backtrace,
    sourceText,
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

  const treeItems = treeLines(treePath).map((nodes, depth) => {
    const children = nodes.flatMap((node, i) => [
      ...(i > 0 ? [treeSeparator()] : []),
      ...treeNode(node),
    ]);

    return h("li", children, {
      slot: "tree-path",
      class: "tree-item",
      style: `--depth: ${depth}`,
    });
  });

  const backtraceItems = backtrace.map((entry) => {
    const frame = parseFrame(entry);
    const isInteresting = frame !== null && frame.file === file;
    const className = isInteresting
      ? "trace-item is-interesting"
      : isFrameworkFrame(frame)
        ? "trace-item is-framework"
        : "trace-item";

    return h("li", [entry], {
      slot: "backtrace",
      class: className,
    });
  });

  const sourceLines = sourceText ? sourceText.split("\n") : [];
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

  treeLines(treePath).forEach((nodes, depth) => {
    const indent = "  ".repeat(depth);
    const text = nodes
      .map((node) => {
        const path = modulePath(node);
        const sigil = node.name.startsWith("#") ? "" : "%";
        return sigil + node.name + (path ? ` (${path})` : "");
      })
      .join(" > ");
    buf.push(`%c${indent}${text}`);
    formats.push("color: #e39ad0;");
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

type TreeNode = { name: string; path?: string };

// Internal components have no source file worth naming.
function modulePath(node: TreeNode) {
  return node.path && !node.path.startsWith("(internal)::") ? node.path : null;
}

// One line per component that comes from a module, each one level deeper.
// Everything between two of those, elements and internal components alike,
// shares a line. This matches the server log.
function treeLines(treePath: TreeNode[]): TreeNode[][] {
  const lines: TreeNode[][] = [];
  let run: TreeNode[] | null = null;

  for (const node of treePath) {
    if (modulePath(node)) {
      lines.push([node]);
      run = null;
    } else {
      if (!run) {
        run = [];
        lines.push(run);
      }
      run.push(node);
    }
  }

  return lines;
}

function treeNode(node: TreeNode): Node[] {
  const path = modulePath(node);
  const kind = path ? "component" : "tag";
  const parts: Node[] = [];

  if (!node.name.startsWith("#")) {
    parts.push(h("span", ["%"], { style: `color: var(--tree-${kind}-sigil)` }));
  }
  parts.push(
    h("span", [node.name], {
      style: `color: var(--tree-${kind});${path ? " font-weight: 600;" : ""}`,
    }),
  );
  if (path) {
    parts.push(h("span", [` (${path})`], { style: "color: var(--tree-path)" }));
  }

  return parts;
}

function treeSeparator() {
  return h("span", [" > "], { style: "color: var(--tree-path)" });
}

type Frame = { file: string; line: number };

// The server names app frames by module id ("app:/page.haml:2:in ...").
// Everything else ran through Mayu, a gem or Ruby itself.
function isFrameworkFrame(frame: Frame | null) {
  return frame === null || !/^[a-z][a-z0-9+.-]*:\//.test(frame.file);
}

// "app:/page.haml:2:in 'method'", "app:/x.tsx:2:24" or "<internal:kernel>:1".
// Module ids contain colons, so the line is the number after the file,
// followed by an optional column or ":in" part.
function parseFrame(entry: string): Frame | null {
  const match = /^(.*?):(\d+)(?::\d+)?(?::in .*)?$/.exec(entry);
  if (!match) return null;

  return { file: match[1], line: Number.parseInt(match[2], 10) };
}
