// Copyright Andrés Alin <andreas.alin@gmail.com>
//
// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.

import {
  useCallback,
  useEffect,
  useMemo,
  useRef,
  useState,
} from "preact/hooks";

import type Connection from "../connection";
import {
  hideHighlight,
  highlight,
  isDetected,
  reveal,
  selectedId as selectedIdInPage,
} from "../page";
import {
  componentTree,
  findPath,
  isTree,
  ownerComponents,
  topElements,
  type TreeNode,
} from "../tree";

type Status =
  | { kind: "loading" }
  | { kind: "not-detected" }
  | { kind: "disabled" }
  | { kind: "error"; message: string }
  | { kind: "ready" };

// Mayu registers with the hook shortly after the page loads.
const NAVIGATION_REFRESH_DELAY = 1000;
// Revealing a node selects it in the Elements panel, which is reported back
// as a selection. Ignore that echo for a moment.
const REVEAL_ECHO_TIMEOUT = 500;

export default function App({ connection }: { connection: Connection }) {
  const [status, setStatus] = useState<Status>({ kind: "loading" });
  const [tree, setTree] = useState<TreeNode | null>(null);
  const [selectedId, setSelectedId] = useState<string | null>(null);
  const [collapsed, setCollapsed] = useState<Set<string>>(() => new Set());
  const [componentsOnly, setComponentsOnly] = useState(true);
  const [showInternal, setShowInternal] = useState(false);
  const generation = useRef(0);
  const revealing = useRef<string | null>(null);
  const scrolledToId = useRef<string | null>(null);
  const treeJSON = useRef("null");

  const refresh = useCallback(async () => {
    const current = ++generation.current;
    const settle = (next: Status, nextTree: TreeNode | null = null) => {
      if (current !== generation.current) return;
      // Most batches don't change the tree, such as the class changes of an
      // animation. Keeping the same objects then leaves the panel alone.
      setStatus((previous) =>
        JSON.stringify(previous) === JSON.stringify(next) ? previous : next,
      );
      const json = JSON.stringify(nextTree);
      if (json === treeJSON.current) return;
      treeJSON.current = json;
      setTree(nextTree);
    };

    try {
      if (!(await isDetected())) return settle({ kind: "not-detected" });

      const result = await connection.inspect({ type: "tree" });
      if (result === null || result === undefined) {
        settle({ kind: "disabled" });
      } else if (isTree(result)) {
        settle({ kind: "ready" }, result);
      } else {
        const error = (result as { error?: string }).error;
        settle({ kind: "error", message: error ?? "Unexpected answer" });
      }
    } catch (error) {
      settle({ kind: "error", message: String(error) });
    }
  }, [connection]);

  const syncSelection = useCallback(async () => {
    const id = await selectedIdInPage().catch(() => null);
    if (id !== null && id === revealing.current) {
      revealing.current = null;
      return;
    }
    setSelectedId(id);
  }, []);

  useEffect(() => {
    const unsubscribe = connection.subscribe((message) => {
      if (message.type === "detected" || message.type === "batch") {
        void refresh();
      }
    });

    let timer: ReturnType<typeof setTimeout> | null = null;
    const onNavigated = () => {
      generation.current++;
      setStatus({ kind: "loading" });
      treeJSON.current = "null";
      setTree(null);
      setSelectedId(null);
      if (timer !== null) clearTimeout(timer);
      timer = setTimeout(() => void refresh(), NAVIGATION_REFRESH_DELAY);
    };
    chrome.devtools.network.onNavigated.addListener(onNavigated);
    chrome.devtools.panels.elements.onSelectionChanged.addListener(
      syncSelection,
    );

    connection.hello();
    void refresh();
    void syncSelection();

    return () => {
      unsubscribe();
      if (timer !== null) clearTimeout(timer);
      chrome.devtools.network.onNavigated.removeListener(onNavigated);
      chrome.devtools.panels.elements.onSelectionChanged.removeListener(
        syncSelection,
      );
    };
  }, [connection, refresh, syncSelection]);

  const shown = useMemo(() => {
    if (!tree) return null;
    return componentsOnly
      ? componentTree(tree, { internal: showInternal })
      : tree;
  }, [tree, componentsOnly, showInternal]);

  // The row for the selection: in the component view, the closest component
  // that is shown.
  const highlightedId = useMemo(() => {
    if (!tree || !shown || !selectedId) return null;
    if (!componentsOnly) return selectedId;

    const owner = ownerComponents(tree, selectedId).find(
      (component) => showInternal || !component.internal,
    );
    return owner?.id ?? null;
  }, [tree, shown, selectedId, componentsOnly, showInternal]);

  // Expand the rows above the selection and scroll it into view, once per
  // selection. Doing it again when the tree updates would pull the tree back
  // to the selection while scrolling it.
  useEffect(() => {
    if (!shown || !highlightedId) {
      scrolledToId.current = null;
      return;
    }
    if (scrolledToId.current === highlightedId) return;

    const path = findPath(shown, highlightedId);
    // Not in the tree yet; try again when it updates.
    if (!path) return;
    scrolledToId.current = highlightedId;

    const ancestors = path.slice(0, -1);
    setCollapsed((current) => {
      if (!ancestors.some((node) => current.has(node.id))) return current;
      const next = new Set(current);
      ancestors.forEach((node) => next.delete(node.id));
      return next;
    });
    requestAnimationFrame(() => {
      document
        .querySelector(`[data-id="${CSS.escape(highlightedId)}"]`)
        ?.scrollIntoView({ block: "nearest" });
    });
  }, [shown, highlightedId]);

  const select = useCallback(
    (node: TreeNode) => {
      setSelectedId(node.id);
      if (!tree) return;

      // A component has no DOM node of its own; reveal its first element.
      const [element] = renderedElements(tree, node);
      if (!element) return;

      revealing.current = element.id;
      setTimeout(() => {
        if (revealing.current === element.id) revealing.current = null;
      }, REVEAL_ECHO_TIMEOUT);
      void reveal(element.id);
    },
    [tree],
  );

  // Highlights what a row renders in the page, or nothing for null.
  const hover = useCallback(
    (node: TreeNode | null) => {
      const elements = node && tree ? renderedElements(tree, node) : [];
      const shown =
        node && elements.length > 0
          ? highlight(
              elements.map((element) => element.id),
              displayName(node),
            )
          : hideHighlight();
      // The page may be gone, and then there is nothing to highlight.
      shown.catch(() => undefined);
    },
    [tree],
  );

  // Hovering stops when the panel is hidden, without a mouseleave.
  useEffect(() => {
    const onVisibilityChange = () => {
      if (document.hidden) hover(null);
    };
    document.addEventListener("visibilitychange", onVisibilityChange);
    return () =>
      document.removeEventListener("visibilitychange", onVisibilityChange);
  }, [hover]);

  const toggle = useCallback((id: string) => {
    setCollapsed((current) => {
      const next = new Set(current);
      if (!next.delete(id)) next.add(id);
      return next;
    });
  }, []);

  const selectedNode =
    tree && selectedId ? findPath(tree, selectedId)?.at(-1) : null;
  const detailNode =
    tree && highlightedId
      ? findPath(tree, highlightedId)?.at(-1)
      : selectedNode;

  return (
    <div class="app">
      <header class="toolbar">
        <label>
          <input
            type="checkbox"
            checked={componentsOnly}
            onChange={(event) => setComponentsOnly(event.currentTarget.checked)}
          />
          Components only
        </label>
        <label>
          <input
            type="checkbox"
            checked={showInternal}
            disabled={!componentsOnly}
            onChange={(event) => setShowInternal(event.currentTarget.checked)}
          />
          Mayu internal components
        </label>
        <button type="button" onClick={() => void refresh()}>
          Refresh
        </button>
      </header>
      <main class="tree" role="tree" onMouseLeave={() => hover(null)}>
        {status.kind === "ready" && shown ? (
          shown.children.map((child) => (
            <Row
              key={child.id}
              node={child}
              depth={0}
              collapsed={collapsed}
              highlightedId={highlightedId}
              onSelect={select}
              onHover={hover}
              onToggle={toggle}
            />
          ))
        ) : (
          <StatusMessage status={status} />
        )}
      </main>
      {tree && detailNode && (
        <Details
          node={detailNode}
          owners={ownerComponents(tree, detailNode.id)}
        />
      )}
    </div>
  );
}

function displayName(node: TreeNode) {
  return node.type === "component" ? node.name : `<${node.name}>`;
}

// The outermost elements a node renders. The component view leaves elements
// out of the tree it shows, so look in the full tree.
function renderedElements(tree: TreeNode, node: TreeNode) {
  const full = findPath(tree, node.id)?.at(-1);
  return full ? topElements(full) : [];
}

function StatusMessage({ status }: { status: Status }) {
  switch (status.kind) {
    case "loading":
      return <p class="status">Loading…</p>;
    case "not-detected":
      return <p class="status">Mayu was not detected on this page.</p>;
    case "disabled":
      return (
        <p class="status">
          Devtools are not enabled on this server. They are enabled by{" "}
          <code>mayu dev</code>.
        </p>
      );
    case "error":
      return <p class="status error">{status.message}</p>;
    case "ready":
      return null;
  }
}

type RowProps = {
  node: TreeNode;
  depth: number;
  collapsed: Set<string>;
  highlightedId: string | null;
  onSelect: (node: TreeNode) => void;
  onHover: (node: TreeNode) => void;
  onToggle: (id: string) => void;
};

function Row({
  node,
  depth,
  collapsed,
  highlightedId,
  onSelect,
  onHover,
  onToggle,
}: RowProps) {
  const expandable = node.children.length > 0;
  const expanded = expandable && !collapsed.has(node.id);

  return (
    <>
      <div
        class={[
          "row",
          node.type,
          node.internal && "internal",
          node.id === highlightedId && "selected",
        ]
          .filter(Boolean)
          .join(" ")}
        role="treeitem"
        aria-expanded={expandable ? expanded : undefined}
        aria-selected={node.id === highlightedId}
        data-id={node.id}
        style={{ paddingLeft: `${depth * 12 + 4}px` }}
        onClick={() => onSelect(node)}
        onMouseEnter={() => onHover(node)}
      >
        <span
          class="toggle"
          onClick={(event) => {
            event.stopPropagation();
            if (expandable) onToggle(node.id);
          }}
        >
          {expandable ? (expanded ? "▾" : "▸") : ""}
        </span>
        <span class="name">{displayName(node)}</span>
        {node.path && <span class="path">{node.path}</span>}
      </div>
      {expanded &&
        node.children.map((child) => (
          <Row
            key={child.id}
            node={child}
            depth={depth + 1}
            collapsed={collapsed}
            highlightedId={highlightedId}
            onSelect={onSelect}
            onHover={onHover}
            onToggle={onToggle}
          />
        ))}
    </>
  );
}

function Details({ node, owners }: { node: TreeNode; owners: TreeNode[] }) {
  const ancestors = owners.filter((owner) => owner.id !== node.id);

  return (
    <footer class="details">
      <dl>
        <dt>{node.type === "component" ? "Component" : "Element"}</dt>
        <dd>{displayName(node)}</dd>
        {node.path && (
          <>
            <dt>Path</dt>
            <dd>{node.path}</dd>
          </>
        )}
        <dt>Id</dt>
        <dd>{node.id}</dd>
        {ancestors.length > 0 && (
          <>
            <dt>Rendered by</dt>
            <dd>{ancestors.map((owner) => owner.name).join(" ← ")}</dd>
          </>
        )}
      </dl>
    </footer>
  );
}
