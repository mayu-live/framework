import "./custom-elements/mayu-exception";
import type MayuException from "./custom-elements/mayu-exception";
import { logToConsole } from "./error-console";
import { buildReport, type RenderErrorInfo } from "./error-report";

export { fromCommand } from "./error-report";

// Shows an error from the server: in the console, and in an overlay over the
// page. This module and everything it imports is loaded when the first error
// arrives, so a page without errors never downloads it.
export default function renderError(error: RenderErrorInfo) {
  const report = buildReport(error);

  logToConsole(report);

  const element = document.createElement("mayu-exception") as MayuException;
  element.report = report;

  document.querySelectorAll("mayu-exception").forEach((e) => e.remove());
  document.body.appendChild(element);
}
