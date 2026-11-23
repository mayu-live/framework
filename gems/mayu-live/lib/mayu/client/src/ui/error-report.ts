import type { CommandArguments } from "../protocol/commands";

// An error as the server sends it.
export type RenderErrorInfo = {
  file: string;
  type: string;
  message: string;
  backtrace: string[];
  source: string | null;
  treePath: { name: string; path?: string }[];
  // A build error carries its location; a runtime error only a backtrace.
  line: number | null;
  column: number | null;
  hints: string[];
};

// The same error worked out for display. The console and the overlay both
// draw this, so they always agree.
export type ErrorReport = {
  type: string;
  // The file, with the line and column when the error names them.
  location: string;
  message: string;
  hints: string[];
  source: SourceLine[];
  tree: TreeNode[][];
  backtrace: BacktraceFrame[];
};

export type SourceLine = {
  number: number;
  text: string;
  // The error happened on this line, or passed through it.
  marked: boolean;
  // The column the error points at, counted from one.
  caret: number | null;
};

export type TreeNode = {
  name: string;
  // The module of a component; null for elements and internal components.
  path: string | null;
};

export type BacktraceFrame = {
  text: string;
  // "module" is the file the error is in, "app" the rest of the app, and
  // "framework" everything that ran through Mayu, a gem or Ruby itself.
  kind: "module" | "app" | "framework";
};

export function fromCommand(
  args: CommandArguments["RenderError"],
): RenderErrorInfo {
  const [
    file,
    type,
    message,
    backtrace,
    source,
    treePath,
    line,
    column,
    hints,
  ] = args;

  return {
    file,
    type,
    message,
    backtrace,
    source,
    treePath,
    line,
    column,
    hints,
  };
}

export function buildReport(error: RenderErrorInfo): ErrorReport {
  const { file, line, column } = error;
  const frames = error.backtrace.map((text) => ({
    text,
    frame: parseFrame(text),
  }));

  // A build error carries its location directly. A runtime error only has a
  // backtrace, so fall back to the frames that name this file.
  const marked = new Set<number>();
  if (line !== null) marked.add(line);
  for (const { frame } of frames) {
    if (frame?.file === file) marked.add(frame.line);
  }

  return {
    type: error.type,
    location:
      line === null
        ? file
        : `${file}:${[line, column].filter((n) => n !== null).join(":")}`,
    message: error.message,
    hints: error.hints,
    source: sourceLines(error.source, marked, line, column),
    tree: treeLines(error.treePath),
    backtrace: frames.map(({ text, frame }) => ({
      text,
      kind:
        frame?.file === file
          ? "module"
          : isFrameworkFrame(frame)
            ? "framework"
            : "app",
    })),
  };
}

function sourceLines(
  source: string | null,
  marked: Set<number>,
  line: number | null,
  column: number | null,
): SourceLine[] {
  if (!source) return [];

  // A file ends with a newline, which would otherwise show as an empty
  // last line.
  return source
    .replace(/\n$/, "")
    .split("\n")
    .map((text, index) => {
      const number = index + 1;
      return {
        number,
        text,
        marked: marked.has(number),
        caret: number === line ? column : null,
      };
    });
}

// One line per component that comes from a module, each one level deeper.
// Everything between two of those, elements and internal components alike,
// shares a line. This matches the server log.
function treeLines(treePath: RenderErrorInfo["treePath"]): TreeNode[][] {
  const lines: TreeNode[][] = [];
  let run: TreeNode[] | null = null;

  for (const { name, path } of treePath) {
    // Internal components have no source file worth naming.
    const node = {
      name,
      path: path && !path.startsWith("(internal)::") ? path : null,
    };

    if (node.path) {
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
