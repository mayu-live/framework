import h from "./h";

export default function renderError(
  file: string,
  type: string,
  message: string,
  backtrace: string[],
  source: string,
  treePath: { name: string; path?: string }[],
) {
  const formats = [];
  const buf = [];

  buf.push(`%c${type}: ${message}`);
  formats.push("font-size: 1.25em");

  treePath.forEach((path, i) => {
    const indent = "  ".repeat(i);
    if (path.path) {
      buf.push(`%c${indent}%%%c${path.name} %c(${path.path})`);
      formats.push("color: deeppink;", "color: deepskyblue;", "color: gray;");
    } else {
      buf.push(`%c${indent}%%%c${path.name}`);
      formats.push("color: deeppink;", "color: deepskyblue;");
    }
  });

  backtrace.forEach((line) => {
    buf.push(`%c${line}`);

    formats.push(
      line.startsWith(`${file}:`)
        ? "font-size: 1em; font-weight: 600; text-shadow: 0 0 3px #000;"
        : "font-size: 1em;",
    );
  });

  console.error(buf.join("\n"), ...formats);

  const existing = Array.from(document.getElementsByTagName("mayu-exception"));
  existing.forEach((e) => {
    e.remove();
  });

  const element =
    document.getElementsByTagName("mayu-exception")[0] ||
    document.createElement("mayu-exception");

  const interestingLines = new Set<number>();

  backtrace.forEach((line) => {
    if (line.startsWith(`${file}:`)) {
      interestingLines.add(Number(line.split(":")[1]));
    }
  });

  console.log("INTERESTING LINES", interestingLines);

  element.replaceChildren(
    h("span", [`${type}: ${message}`], { slot: "title" }),
    ...treePath.map((path, i) =>
      h(
        "li",
        [
          h("span", ["  ".repeat(i)]),
          h("span", ["%"], { style: "color: deeppink;" }),
          h("span", [path.name], { style: "color: deepskyblue;" }),
          " ",
          path.path &&
            h("span", [`(${path.path})`], { style: "opacity: 50%;" }),
        ],
        { slot: "tree-path" },
      ),
    ),
    ...backtrace.map((line) =>
      h(
        "li",
        [
          line.startsWith(`${file}:`)
            ? h("strong", [line], { style: "color: red;" })
            : line,
        ],
        {
          slot: "backtrace",
        },
      ),
    ),
    ...source.split("\n").map((line, i) =>
      h(
        "li",
        [
          interestingLines.has(i + 1)
            ? h("strong", [line], { style: "color: red;" })
            : line,
        ],
        {
          slot: "source",
        },
      ),
    ),
  );
  console.log("FILE", file);

  document.body.appendChild(element);
}
