// Drag and drop for the kanban board.
//
// The server renders the board and owns its DOM, so this element never moves
// the columns or cards. While dragging, it draws a ghost and a drop indicator
// in its shadow root. On drop it dispatches a "kanbanmove" event whose detail
// the page handles in Ruby, and the server renders the result for everyone.
//
// The markup it expects:
//
//   [data-kanban-column=<id>][data-lock-version=<n>]    a column
//     [data-kanban-handle="column"]                     where to grab it
//     [data-kanban-card=<id>][data-lock-version=<n>]    its cards, in order
//
// Cards can also be moved with Alt+Arrow keys while focused.

type Kind = "card" | "column";

type MoveDetail = {
  kind: Kind;
  id: number;
  lockVersion: number;
  toIndex: number;
  toColumnId?: number;
};

type Drag = {
  kind: Kind;
  source: HTMLElement;
  pointerId: number;
  startX: number;
  startY: number;
  offsetX: number;
  offsetY: number;
  started: boolean;
  target: { toIndex: number; toColumnId?: number } | null;
};

// Pixels the pointer has to move before a press becomes a drag, so clicks
// and double-clicks on cards still work.
const DRAG_THRESHOLD = 4;
// How close to the edge of the board, in pixels, dragging scrolls it.
const SCROLL_EDGE = 48;
const SCROLL_STEP = 12;
// How long a dropped item stays dimmed if the server sends no update, for
// example because the move changed nothing.
const SETTLE_TIMEOUT = 1500;

const INTERACTIVE = "button, input, textarea, select, a, form";

const STYLES = `
  :host {
    display: block;
  }

  .ghost {
    position: fixed;
    top: 0;
    left: 0;
    z-index: 1000;
    box-sizing: border-box;
    padding: 0.625rem 0.75rem;
    overflow: hidden;
    color: var(--text);
    font-weight: 600;
    white-space: nowrap;
    text-overflow: ellipsis;
    background: var(--surface-raised);
    border: 1px solid var(--accent);
    border-radius: var(--radius-sm, 6px);
    box-shadow: 0 12px 24px color-mix(in oklab, var(--text) 25%, transparent);
    pointer-events: none;
    rotate: 2deg;
  }

  .indicator {
    position: fixed;
    top: 0;
    left: 0;
    z-index: 999;
    background: var(--accent);
    border-radius: 2px;
    pointer-events: none;
  }
`;

export default class KanbanBoard extends HTMLElement {
  #drag: Drag | null = null;
  #ghost: HTMLElement;
  #indicator: HTMLElement;
  #settle: MutationObserver | null = null;
  #settleTimer = 0;

  constructor() {
    super();

    const root = this.attachShadow({ mode: "open" });
    const style = document.createElement("style");
    style.textContent = STYLES;
    this.#ghost = document.createElement("div");
    this.#ghost.className = "ghost";
    this.#ghost.hidden = true;
    this.#indicator = document.createElement("div");
    this.#indicator.className = "indicator";
    this.#indicator.hidden = true;
    root.append(
      style,
      document.createElement("slot"),
      this.#ghost,
      this.#indicator,
    );
  }

  connectedCallback() {
    this.addEventListener("pointerdown", this.#onPointerDown);
    this.addEventListener("pointermove", this.#onPointerMove);
    this.addEventListener("pointerup", this.#onPointerUp);
    this.addEventListener("pointercancel", this.#cancel);
    this.addEventListener("keydown", this.#onKeyDown);
  }

  disconnectedCallback() {
    this.removeEventListener("pointerdown", this.#onPointerDown);
    this.removeEventListener("pointermove", this.#onPointerMove);
    this.removeEventListener("pointerup", this.#onPointerUp);
    this.removeEventListener("pointercancel", this.#cancel);
    this.removeEventListener("keydown", this.#onKeyDown);
    this.#cancel();
    this.#stopSettling();
  }

  #onPointerDown = (event: PointerEvent) => {
    if (event.button !== 0 || this.#drag) return;

    const target = event.target as Element;
    if (target.closest(INTERACTIVE)) return;

    const handle = target.closest<HTMLElement>(
      "[data-kanban-card], [data-kanban-handle='column']",
    );
    if (!handle || !this.contains(handle)) return;

    const kind: Kind = handle.matches("[data-kanban-card]") ? "card" : "column";
    const source =
      kind === "card"
        ? handle
        : handle.closest<HTMLElement>("[data-kanban-column]");
    if (!source) return;

    const rect = source.getBoundingClientRect();
    this.#drag = {
      kind,
      source,
      pointerId: event.pointerId,
      startX: event.clientX,
      startY: event.clientY,
      offsetX: event.clientX - rect.left,
      offsetY: event.clientY - rect.top,
      started: false,
      target: null,
    };
  };

  #onPointerMove = (event: PointerEvent) => {
    const drag = this.#drag;
    if (!drag || event.pointerId !== drag.pointerId) return;

    if (!drag.started) {
      const distance = Math.hypot(
        event.clientX - drag.startX,
        event.clientY - drag.startY,
      );
      if (distance < DRAG_THRESHOLD) return;
      this.#start(drag);
    }

    event.preventDefault();
    this.#moveGhost(drag, event.clientX, event.clientY);
    this.#autoScroll(event.clientX);
    drag.target =
      drag.kind === "card"
        ? this.#cardTarget(drag, event.clientX, event.clientY)
        : this.#columnTarget(drag, event.clientX);
  };

  #onPointerUp = (event: PointerEvent) => {
    const drag = this.#drag;
    if (!drag || event.pointerId !== drag.pointerId) return;

    this.#drag = null;
    this.#hideOverlay();

    if (!drag.started || !drag.target) {
      drag.source.removeAttribute("data-dragging");
      return;
    }

    this.#dispatchMove(drag.kind, drag.source, drag.target);
  };

  #cancel = () => {
    const drag = this.#drag;
    if (!drag) return;

    this.#drag = null;
    this.#hideOverlay();
    drag.source.removeAttribute("data-dragging");
  };

  #onKeyDown = (event: KeyboardEvent) => {
    if (event.key === "Escape") {
      this.#cancel();
      return;
    }

    if (!event.altKey) return;

    const card = (event.target as Element).closest<HTMLElement>(
      "[data-kanban-card]",
    );
    if (!card) return;

    const columns = this.#columns();
    const column = card.closest<HTMLElement>("[data-kanban-column]");
    const columnIndex = column ? columns.indexOf(column) : -1;
    if (columnIndex === -1) return;

    const cards = this.#cards(column!);
    const index = cards.indexOf(card);
    let target: { toIndex: number; toColumnId?: number } | null = null;

    switch (event.key) {
      case "ArrowUp":
        if (index > 0) target = { toColumnId: id(column!), toIndex: index - 1 };
        break;
      case "ArrowDown":
        if (index < cards.length - 1)
          target = { toColumnId: id(column!), toIndex: index + 1 };
        break;
      case "ArrowLeft":
      case "ArrowRight": {
        const next =
          columns[columnIndex + (event.key === "ArrowLeft" ? -1 : 1)];
        if (next) {
          const toIndex = Math.min(index, this.#cards(next).length);
          target = { toColumnId: id(next), toIndex };
        }
        break;
      }
    }

    if (!target) return;
    event.preventDefault();
    this.#dispatchMove("card", card, target);
  };

  #start(drag: Drag) {
    drag.started = true;
    this.setPointerCapture(drag.pointerId);
    drag.source.setAttribute("data-dragging", "");

    const rect = drag.source.getBoundingClientRect();
    const label = drag.source.querySelector(
      "[data-kanban-title], input[type='text']",
    );
    this.#ghost.textContent =
      (label instanceof HTMLInputElement ? label.value : label?.textContent) ??
      "";
    this.#ghost.style.width = `${rect.width}px`;
    this.#ghost.style.height =
      drag.kind === "column" ? `${rect.height}px` : "auto";
    this.#ghost.hidden = false;
  }

  #moveGhost(drag: Drag, x: number, y: number) {
    this.#ghost.style.transform = `translate(${x - drag.offsetX}px, ${
      y - drag.offsetY
    }px)`;
  }

  // Where a dragged card would land: the column under the pointer, and how
  // many of that column's other cards are above the pointer.
  #cardTarget(drag: Drag, x: number, y: number) {
    const column = closestByX(this.#columns(), x);
    if (!column) return null;

    const cards = this.#cards(column).filter((card) => card !== drag.source);
    const toIndex = cards.filter((card) => midY(card) < y).length;
    // An empty column has no card list to measure, so the line goes below
    // its header, which spans the same width as the cards.
    const header =
      column.querySelector<HTMLElement>("[data-kanban-handle='column']") ??
      column;
    const headerRect = header.getBoundingClientRect();

    let lineY: number;
    if (cards.length === 0) {
      lineY = headerRect.bottom + 4;
    } else if (toIndex < cards.length) {
      lineY = cards[toIndex].getBoundingClientRect().top - 4;
    } else {
      lineY = cards[cards.length - 1].getBoundingClientRect().bottom + 4;
    }

    this.#showIndicator(headerRect.left, lineY - 2, headerRect.width, 4);
    return { toColumnId: id(column), toIndex };
  }

  // Where a dragged column would land: how many other columns are left of the
  // pointer.
  #columnTarget(drag: Drag, x: number) {
    const columns = this.#columns().filter((column) => column !== drag.source);
    const toIndex = columns.filter((column) => midX(column) < x).length;
    const sourceRect = drag.source.getBoundingClientRect();

    let lineX: number;
    if (columns.length === 0) {
      lineX = sourceRect.left - 6;
    } else if (toIndex < columns.length) {
      lineX = columns[toIndex].getBoundingClientRect().left - 6;
    } else {
      lineX = columns[columns.length - 1].getBoundingClientRect().right + 6;
    }

    this.#showIndicator(lineX - 2, sourceRect.top, 4, sourceRect.height);
    return { toIndex };
  }

  #showIndicator(left: number, top: number, width: number, height: number) {
    const style = this.#indicator.style;
    style.transform = `translate(${left}px, ${top}px)`;
    style.width = `${width}px`;
    style.height = `${height}px`;
    this.#indicator.hidden = false;
  }

  #hideOverlay() {
    this.#ghost.hidden = true;
    this.#indicator.hidden = true;
  }

  #autoScroll(x: number) {
    const rect = this.getBoundingClientRect();
    if (x < rect.left + SCROLL_EDGE) this.scrollLeft -= SCROLL_STEP;
    else if (x > rect.right - SCROLL_EDGE) this.scrollLeft += SCROLL_STEP;
  }

  #dispatchMove(
    kind: Kind,
    source: HTMLElement,
    target: { toIndex: number; toColumnId?: number },
  ) {
    const detail: MoveDetail = {
      kind,
      id: Number(
        kind === "card"
          ? source.dataset.kanbanCard
          : source.dataset.kanbanColumn,
      ),
      lockVersion: Number(source.dataset.lockVersion),
      ...target,
    };

    // The item stays dimmed until the server's update arrives.
    source.setAttribute("data-dragging", "");
    this.#settleAfterUpdate(source);
    this.dispatchEvent(
      new CustomEvent("kanbanmove", { bubbles: true, detail }),
    );
  }

  #settleAfterUpdate(source: HTMLElement) {
    this.#stopSettling();

    const settle = () => {
      this.#stopSettling();
      source.removeAttribute("data-dragging");
    };

    this.#settle = new MutationObserver(settle);
    this.#settle.observe(this, { childList: true, subtree: true });
    this.#settleTimer = window.setTimeout(settle, SETTLE_TIMEOUT);
  }

  #stopSettling() {
    this.#settle?.disconnect();
    this.#settle = null;
    window.clearTimeout(this.#settleTimer);
  }

  #columns() {
    return Array.from(
      this.querySelectorAll<HTMLElement>("[data-kanban-column]"),
    );
  }

  #cards(column: HTMLElement) {
    return Array.from(
      column.querySelectorAll<HTMLElement>("[data-kanban-card]"),
    );
  }
}

function id(column: HTMLElement) {
  return Number(column.dataset.kanbanColumn);
}

function midX(element: Element) {
  const rect = element.getBoundingClientRect();
  return rect.left + rect.width / 2;
}

function midY(element: Element) {
  const rect = element.getBoundingClientRect();
  return rect.top + rect.height / 2;
}

function closestByX(elements: HTMLElement[], x: number) {
  let closest: HTMLElement | null = null;
  let distance = Infinity;

  for (const element of elements) {
    const rect = element.getBoundingClientRect();
    const d =
      x < rect.left ? rect.left - x : x > rect.right ? x - rect.right : 0;
    if (d < distance) {
      closest = element;
      distance = d;
    }
  }

  return closest;
}
