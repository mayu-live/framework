export default class IntlTimeElement extends HTMLElement {
  static get observedAttributes(): string[] {
    return ["time", "lang", "date-style", "time-style"];
  }

  connectedCallback(): void {
    this.render();
  }

  attributeChangedCallback(): void {
    if (this.isConnected) this.render();
  }

  render(): void {
    const time = this.getAttribute("time");
    if (!time) return;

    const date = new Date(time);
    if (Number.isNaN(date.getTime())) return;

    const options = this.formatOptions();
    const formatter = new Intl.DateTimeFormat(this.locale(), options);

    this.textContent = formatter.format(date);
  }

  locale(): string {
    return this.getAttribute("lang") || navigator.language;
  }

  formatOptions(): Intl.DateTimeFormatOptions {
    const options: Intl.DateTimeFormatOptions = {};
    const dateStyle = this.getAttribute("date-style");
    const timeStyle = this.getAttribute("time-style");

    if (isDateTimeStyle(dateStyle)) options.dateStyle = dateStyle;
    if (isDateTimeStyle(timeStyle)) options.timeStyle = timeStyle;

    return options;
  }
}

function isDateTimeStyle(
  value: string | null,
): value is NonNullable<Intl.DateTimeFormatOptions["dateStyle"]> {
  return (
    value === "full" ||
    value === "long" ||
    value === "medium" ||
    value === "short"
  );
}
