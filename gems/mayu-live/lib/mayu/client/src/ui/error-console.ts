import type { ErrorReport } from "./error-report";

const MUTED = "color: #9aa3b2;";

// Logs the error the way the server log shows it: message, location, hints,
// component path, the source around the error, and the backtrace.
export function logToConsole(report: ErrorReport) {
  const lines: string[] = [];
  const styles: string[] = [];
  const add = (text: string, style: string) => {
    lines.push(`%c${text}`);
    styles.push(style);
  };

  add(`${report.type}: ${report.message}`, "font-size: 1.25em");
  add(report.location, MUTED);

  for (const hint of report.hints) add(hint, "color: #7fd1ff;");

  report.tree.forEach((nodes, depth) => {
    const text = nodes
      .map((node) => {
        const sigil = node.name.startsWith("#") ? "" : "%";
        return sigil + node.name + (node.path ? ` (${node.path})` : "");
      })
      .join(" > ");
    add("  ".repeat(depth) + text, "color: #e39ad0;");
  });

  // A window around the error rather than the whole file.
  const marked = report.source.filter((line) => line.marked);
  if (marked.length > 0) {
    const first = marked[0].number - 2;
    const last = marked[marked.length - 1].number + 3;
    const shown = report.source.filter(
      (line) => line.number >= first && line.number <= last,
    );
    const gutter = String(shown[shown.length - 1].number).length;

    for (const line of shown) {
      const number = String(line.number).padStart(gutter, " ");
      add(
        `${line.marked ? ">" : " "} ${number} | ${line.text}`,
        line.marked ? "color: #ff8fa3;" : MUTED,
      );
    }
  }

  for (const frame of report.backtrace) add(frame.text, "font-size: 1em;");

  console.error(lines.join("\n"), ...styles);
}
